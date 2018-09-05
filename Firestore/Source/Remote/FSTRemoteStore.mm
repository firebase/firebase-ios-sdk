/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "Firestore/Source/Remote/FSTRemoteStore.h"

#include <cinttypes>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTTransaction.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Remote/FSTDatastore.h"
#import "Firestore/Source/Remote/FSTExistenceFilter.h"
#import "Firestore/Source/Remote/FSTOnlineStateTracker.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Remote/FSTStream.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::User;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

/**
 * The maximum number of pending writes to allow.
 * TODO(bjornick): Negotiate this value with the backend.
 */
static const int kMaxPendingWrites = 10;

#pragma mark - FSTRemoteStore

@interface FSTRemoteStore () <FSTWatchStreamDelegate, FSTWriteStreamDelegate>

/**
 * The local store, used to fill the write pipeline with outbound mutations and resolve existence
 * filter mismatches. Immutable after initialization.
 */
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;

/** The client-side proxy for interacting with the backend. Immutable after initialization. */
@property(nonatomic, strong, readonly) FSTDatastore *datastore;

#pragma mark Watch Stream
// The watchStream is null when the network is disabled. The non-null check is performed by
// isNetworkEnabled.
@property(nonatomic, strong, nullable) FSTWatchStream *watchStream;

/**
 * A mapping of watched targets that the client cares about tracking and the
 * user has explicitly called a 'listen' for this target.
 *
 * These targets may or may not have been sent to or acknowledged by the
 * server. On re-establishing the listen stream, these targets should be sent
 * to the server. The targets removed with unlistens are removed eagerly
 * without waiting for confirmation from the listen stream. */
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTBoxedTargetID *, FSTQueryData *> *listenTargets;

@property(nonatomic, strong, readonly) FSTOnlineStateTracker *onlineStateTracker;

@property(nonatomic, strong, nullable) FSTWatchChangeAggregator *watchChangeAggregator;

#pragma mark Write Stream
// The writeStream is null when the network is disabled. The non-null check is performed by
// isNetworkEnabled.
@property(nonatomic, strong, nullable) FSTWriteStream *writeStream;

/**
 * A list of up to kMaxPendingWrites writes that we have fetched from the LocalStore via
 * fillWritePipeline and have or will send to the write stream.
 *
 * Whenever writePipeline is not empty, the RemoteStore will attempt to start or restart the write
 * stream. When the stream is established, the writes in the pipeline will be sent in order.
 *
 * Writes remain in writePipeline until they are acknowledged by the backend and thus will
 * automatically be re-sent if the stream is interrupted / restarted before they're acknowledged.
 *
 * Write responses from the backend are linked to their originating request purely based on
 * order, and so we can just remove writes from the front of the writePipeline as we receive
 * responses.
 */
@property(nonatomic, strong, readonly) NSMutableArray<FSTMutationBatch *> *writePipeline;
@end

@implementation FSTRemoteStore

- (instancetype)initWithLocalStore:(FSTLocalStore *)localStore
                         datastore:(FSTDatastore *)datastore
               workerDispatchQueue:(FSTDispatchQueue *)queue {
  if (self = [super init]) {
    _localStore = localStore;
    _datastore = datastore;
    _listenTargets = [NSMutableDictionary dictionary];

    _writePipeline = [NSMutableArray array];
    _onlineStateTracker = [[FSTOnlineStateTracker alloc] initWithWorkerDispatchQueue:queue];
  }
  return self;
}

- (void)start {
  // For now, all setup is handled by enableNetwork(). We might expand on this in the future.
  [self enableNetwork];
}

@dynamic onlineStateDelegate;

- (nullable id<FSTOnlineStateDelegate>)onlineStateDelegate {
  return self.onlineStateTracker.onlineStateDelegate;
}

- (void)setOnlineStateDelegate:(nullable id<FSTOnlineStateDelegate>)delegate {
  self.onlineStateTracker.onlineStateDelegate = delegate;
}

#pragma mark Online/Offline state

- (BOOL)isNetworkEnabled {
  HARD_ASSERT((self.watchStream == nil) == (self.writeStream == nil),
              "WatchStream and WriteStream should both be null or non-null");
  return self.watchStream != nil;
}

- (void)enableNetwork {
  if ([self isNetworkEnabled]) {
    return;
  }

  // Create new streams (but note they're not started yet).
  self.watchStream = [self.datastore createWatchStream];
  self.writeStream = [self.datastore createWriteStream];

  // Load any saved stream token from persistent storage
  self.writeStream.lastStreamToken = [self.localStore lastStreamToken];

  if ([self shouldStartWatchStream]) {
    [self startWatchStream];
  } else {
    [self.onlineStateTracker updateState:OnlineState::Unknown];
  }

  [self fillWritePipeline];  // This may start the writeStream.
}

- (void)disableNetwork {
  [self disableNetworkInternal];
  // Set the OnlineState to Offline so get()s return from cache, etc.
  [self.onlineStateTracker updateState:OnlineState::Offline];
}

/** Disables the network, setting the OnlineState to the specified targetOnlineState. */
- (void)disableNetworkInternal {
  if ([self isNetworkEnabled]) {
    // NOTE: We're guaranteed not to get any further events from these streams (not even a close
    // event).
    [self.watchStream stop];
    [self.writeStream stop];

    [self cleanUpWatchStreamState];

    if (self.writePipeline.count > 0) {
      LOG_DEBUG("Stopping write stream with %lu pending writes",
                (unsigned long)self.writePipeline.count);
      [self.writePipeline removeAllObjects];
    }

    self.writeStream = nil;
    self.watchStream = nil;
  }
}

#pragma mark Shutdown

- (void)shutdown {
  LOG_DEBUG("FSTRemoteStore %s shutting down", (__bridge void *)self);
  [self disableNetworkInternal];
  // Set the OnlineState to Unknown (rather than Offline) to avoid potentially triggering
  // spurious listener events with cached data, etc.
  [self.onlineStateTracker updateState:OnlineState::Unknown];
}

- (void)credentialDidChange {
  if ([self isNetworkEnabled]) {
    // Tear down and re-create our network streams. This will ensure we get a fresh auth token
    // for the new user and re-fill the write pipeline with new mutations from the LocalStore
    // (since mutations are per-user).
    LOG_DEBUG("FSTRemoteStore %s restarting streams for new credential", (__bridge void *)self);
    [self disableNetworkInternal];
    [self.onlineStateTracker updateState:OnlineState::Unknown];
    [self enableNetwork];
  }
}

#pragma mark Watch Stream

- (void)startWatchStream {
  HARD_ASSERT([self shouldStartWatchStream],
              "startWatchStream: called when shouldStartWatchStream: is false.");
  _watchChangeAggregator = [[FSTWatchChangeAggregator alloc] initWithTargetMetadataProvider:self];
  [self.watchStream startWithDelegate:self];
  [self.onlineStateTracker handleWatchStreamStart];
}

- (void)listenToTargetWithQueryData:(FSTQueryData *)queryData {
  NSNumber *targetKey = @(queryData.targetID);
  HARD_ASSERT(!self.listenTargets[targetKey], "listenToQuery called with duplicate target id: %s",
              targetKey);

  self.listenTargets[targetKey] = queryData;

  if ([self shouldStartWatchStream]) {
    [self startWatchStream];
  } else if ([self isNetworkEnabled] && [self.watchStream isOpen]) {
    [self sendWatchRequestWithQueryData:queryData];
  }
}

- (void)sendWatchRequestWithQueryData:(FSTQueryData *)queryData {
  [self.watchChangeAggregator recordTargetRequest:@(queryData.targetID)];
  [self.watchStream watchQuery:queryData];
}

- (void)stopListeningToTargetID:(TargetId)targetID {
  FSTBoxedTargetID *targetKey = @(targetID);
  FSTQueryData *queryData = self.listenTargets[targetKey];
  HARD_ASSERT(queryData, "stopListeningToTargetID: target not currently watched: %s", targetKey);

  [self.listenTargets removeObjectForKey:targetKey];
  if ([self isNetworkEnabled] && [self.watchStream isOpen]) {
    [self sendUnwatchRequestForTargetID:targetKey];
  }
  if ([self.listenTargets count] == 0) {
    if ([self isNetworkEnabled]) {
      if ([self.watchStream isOpen]) {
        [self.watchStream markIdle];
      } else {
        // Revert to OnlineState::Unknown if the watch stream is not open and we have no listeners,
        // since without any listens to send we cannot confirm if the stream is healthy and upgrade
        // to OnlineState::Online.
        [self.onlineStateTracker updateState:OnlineState::Unknown];
      }
    }
  }
}

- (void)sendUnwatchRequestForTargetID:(FSTBoxedTargetID *)targetID {
  [self.watchChangeAggregator recordTargetRequest:targetID];
  [self.watchStream unwatchTargetID:[targetID intValue]];
}

/**
 * Returns YES if the network is enabled, the watch stream has not yet been started and there are
 * active watch targets.
 */
- (BOOL)shouldStartWatchStream {
  return [self isNetworkEnabled] && ![self.watchStream isStarted] && self.listenTargets.count > 0;
}

- (void)cleanUpWatchStreamState {
  _watchChangeAggregator = nil;
}

- (void)watchStreamDidOpen {
  // Restore any existing watches.
  for (FSTQueryData *queryData in [self.listenTargets objectEnumerator]) {
    [self sendWatchRequestWithQueryData:queryData];
  }
}

- (void)watchStreamDidChange:(FSTWatchChange *)change
             snapshotVersion:(const SnapshotVersion &)snapshotVersion {
  // Mark the connection as Online because we got a message from the server.
  [self.onlineStateTracker updateState:OnlineState::Online];

  if ([change isKindOfClass:[FSTWatchTargetChange class]]) {
    FSTWatchTargetChange *watchTargetChange = (FSTWatchTargetChange *)change;
    if (watchTargetChange.state == FSTWatchTargetChangeStateRemoved && watchTargetChange.cause) {
      // There was an error on a target, don't wait for a consistent snapshot to raise events
      return [self processTargetErrorForWatchChange:watchTargetChange];
    } else {
      [self.watchChangeAggregator handleTargetChange:watchTargetChange];
    }
  } else if ([change isKindOfClass:[FSTDocumentWatchChange class]]) {
    [self.watchChangeAggregator handleDocumentChange:(FSTDocumentWatchChange *)change];
  } else {
    HARD_ASSERT([change isKindOfClass:[FSTExistenceFilterWatchChange class]],
                "Expected watchChange to be an instance of FSTExistenceFilterWatchChange");
    [self.watchChangeAggregator handleExistenceFilter:(FSTExistenceFilterWatchChange *)change];
  }

  if (snapshotVersion != SnapshotVersion::None() &&
      snapshotVersion >= [self.localStore lastRemoteSnapshotVersion]) {
    // We have received a target change with a global snapshot if the snapshot version is not equal
    // to SnapshotVersion.None().
    [self raiseWatchSnapshotWithSnapshotVersion:snapshotVersion];
  }
}

- (void)watchStreamWasInterruptedWithError:(nullable NSError *)error {
  HARD_ASSERT([self isNetworkEnabled],
              "watchStreamWasInterruptedWithError: should only be called when the network is "
              "enabled");

  [self cleanUpWatchStreamState];

  // If the watch stream closed due to an error, retry the connection if there are any active
  // watch targets.
  if ([self shouldStartWatchStream]) {
    if (error) {
      // There should generally be an error if the watch stream was closed when it's still needed,
      // but it's not quite worth asserting.
      [self.onlineStateTracker handleWatchStreamFailure:error];
    }
    [self startWatchStream];
  } else {
    // We don't need to restart the watch stream because there are no active targets. The online
    // state is set to unknown because there is no active attempt at establishing a connection.
    [self.onlineStateTracker updateState:OnlineState::Unknown];
  }
}

/**
 * Takes a batch of changes from the Datastore, repackages them as a RemoteEvent, and passes that
 * on to the SyncEngine.
 */
- (void)raiseWatchSnapshotWithSnapshotVersion:(const SnapshotVersion &)snapshotVersion {
  HARD_ASSERT(snapshotVersion != SnapshotVersion::None(),
              "Can't raise event for unknown SnapshotVersion");

  FSTRemoteEvent *remoteEvent =
      [self.watchChangeAggregator remoteEventAtSnapshotVersion:snapshotVersion];

  // Update in-memory resume tokens. FSTLocalStore will update the persistent view of these when
  // applying the completed FSTRemoteEvent.
  for (const auto &entry : remoteEvent.targetChanges) {
    NSData *resumeToken = entry.second.resumeToken;
    if (resumeToken.length > 0) {
      FSTBoxedTargetID *targetID = @(entry.first);
      FSTQueryData *queryData = _listenTargets[targetID];
      // A watched target might have been removed already.
      if (queryData) {
        _listenTargets[targetID] =
            [queryData queryDataByReplacingSnapshotVersion:snapshotVersion
                                               resumeToken:resumeToken
                                            sequenceNumber:queryData.sequenceNumber];
      }
    }
  }

  // Re-establish listens for the targets that have been invalidated by existence filter mismatches.
  for (TargetId targetID : remoteEvent.targetMismatches) {
    FSTQueryData *queryData = self.listenTargets[@(targetID)];

    if (!queryData) {
      // A watched target might have been removed already.
      continue;
    }

    // Clear the resume token for the query, since we're in a known mismatch state.
    queryData = [[FSTQueryData alloc] initWithQuery:queryData.query
                                           targetID:targetID
                               listenSequenceNumber:queryData.sequenceNumber
                                            purpose:queryData.purpose];
    self.listenTargets[@(targetID)] = queryData;

    // Cause a hard reset by unwatching and rewatching immediately, but deliberately don't send a
    // resume token so that we get a full update.
    [self sendUnwatchRequestForTargetID:@(targetID)];

    // Mark the query we send as being on behalf of an existence filter mismatch, but don't actually
    // retain that in listenTargets. This ensures that we flag the first re-listen this way without
    // impacting future listens of this target (that might happen e.g. on reconnect).
    FSTQueryData *requestQueryData =
        [[FSTQueryData alloc] initWithQuery:queryData.query
                                   targetID:targetID
                       listenSequenceNumber:queryData.sequenceNumber
                                    purpose:FSTQueryPurposeExistenceFilterMismatch];
    [self sendWatchRequestWithQueryData:requestQueryData];
  }

  // Finally handle remote event
  [self.syncEngine applyRemoteEvent:remoteEvent];
}

/** Process a target error and passes the error along to SyncEngine. */
- (void)processTargetErrorForWatchChange:(FSTWatchTargetChange *)change {
  HARD_ASSERT(change.cause, "Handling target error without a cause");
  // Ignore targets that have been removed already.
  for (FSTBoxedTargetID *targetID in change.targetIDs) {
    if (self.listenTargets[targetID]) {
      int unboxedTargetId = targetID.intValue;
      [self.listenTargets removeObjectForKey:targetID];
      [self.watchChangeAggregator removeTarget:unboxedTargetId];
      [self.syncEngine rejectListenWithTargetID:unboxedTargetId error:change.cause];
    }
  }
}

- (firebase::firestore::model::DocumentKeySet)remoteKeysForTarget:(FSTBoxedTargetID *)targetID {
  return [self.syncEngine remoteKeysForTarget:targetID];
}

- (nullable FSTQueryData *)queryDataForTarget:(FSTBoxedTargetID *)targetID {
  return self.listenTargets[targetID];
}

#pragma mark Write Stream

/**
 * Returns YES if the network is enabled, the write stream has not yet been started and there are
 * pending writes.
 */
- (BOOL)shouldStartWriteStream {
  return [self isNetworkEnabled] && ![self.writeStream isStarted] && self.writePipeline.count > 0;
}

- (void)startWriteStream {
  HARD_ASSERT([self shouldStartWriteStream],
              "startWriteStream: called when shouldStartWriteStream: is false.");

  [self.writeStream startWithDelegate:self];
}

/**
 * Attempts to fill our write pipeline with writes from the LocalStore.
 *
 * Called internally to bootstrap or refill the write pipeline and by SyncEngine whenever there
 * are new mutations to process.
 *
 * Starts the write stream if necessary.
 */
- (void)fillWritePipeline {
  BatchId lastBatchIDRetrieved =
      self.writePipeline.count == 0 ? kFSTBatchIDUnknown : self.writePipeline.lastObject.batchID;
  while ([self canAddToWritePipeline]) {
    FSTMutationBatch *batch = [self.localStore nextMutationBatchAfterBatchID:lastBatchIDRetrieved];
    if (!batch) {
      if (self.writePipeline.count == 0) {
        [self.writeStream markIdle];
      }
      break;
    }
    [self addBatchToWritePipeline:batch];
    lastBatchIDRetrieved = batch.batchID;
  }

  if ([self shouldStartWriteStream]) {
    [self startWriteStream];
  }
}

/**
 * Returns YES if we can add to the write pipeline (i.e. it is not full and the network is enabled).
 */
- (BOOL)canAddToWritePipeline {
  return [self isNetworkEnabled] && self.writePipeline.count < kMaxPendingWrites;
}

/**
 * Queues additional writes to be sent to the write stream, sending them immediately if the write
 * stream is established, else starting the write stream if it is not yet started.
 */
- (void)addBatchToWritePipeline:(FSTMutationBatch *)batch {
  HARD_ASSERT([self canAddToWritePipeline],
              "addBatchToWritePipeline called when mutations can't be written");

  [self.writePipeline addObject:batch];

  if ([self shouldStartWriteStream]) {
    [self startWriteStream];
  } else if ([self isNetworkEnabled] && self.writeStream.handshakeComplete) {
    [self.writeStream writeMutations:batch.mutations];
  }
}

- (void)writeStreamDidOpen {
  [self.writeStream writeHandshake];
}

/**
 * Handles a successful handshake response from the server, which is our cue to send any pending
 * writes.
 */
- (void)writeStreamDidCompleteHandshake {
  // Record the stream token.
  [self.localStore setLastStreamToken:self.writeStream.lastStreamToken];

  // Send the write pipeline now that the stream is established.
  for (FSTMutationBatch *write in self.writePipeline) {
    [self.writeStream writeMutations:write.mutations];
  }
}

/** Handles a successful StreamingWriteResponse from the server that contains a mutation result. */
- (void)writeStreamDidReceiveResponseWithVersion:(const SnapshotVersion &)commitVersion
                                 mutationResults:(NSArray<FSTMutationResult *> *)results {
  // This is a response to a write containing mutations and should be correlated to the first
  // write in our write pipeline.
  NSMutableArray *writePipeline = self.writePipeline;
  FSTMutationBatch *batch = writePipeline[0];
  [writePipeline removeObjectAtIndex:0];

  FSTMutationBatchResult *batchResult =
      [FSTMutationBatchResult resultWithBatch:batch
                                commitVersion:commitVersion
                              mutationResults:results
                                  streamToken:self.writeStream.lastStreamToken];
  [self.syncEngine applySuccessfulWriteWithResult:batchResult];

  // It's possible that with the completion of this mutation another slot has freed up.
  [self fillWritePipeline];
}

/**
 * Handles the closing of the StreamingWrite RPC, either because of an error or because the RPC
 * has been terminated by the client or the server.
 */
- (void)writeStreamWasInterruptedWithError:(nullable NSError *)error {
  HARD_ASSERT([self isNetworkEnabled],
              "writeStreamDidClose: should only be called when the network is enabled");

  // If the write stream closed due to an error, invoke the error callbacks if there are pending
  // writes.
  if (error != nil && self.writePipeline.count > 0) {
    if (self.writeStream.handshakeComplete) {
      // This error affects the actual writes.
      [self handleWriteError:error];
    } else {
      // If there was an error before the handshake finished, it's possible that the server is
      // unable to process the stream token we're sending. (Perhaps it's too old?)
      [self handleHandshakeError:error];
    }
  }

  // The write stream might have been started by refilling the write pipeline for failed writes
  if ([self shouldStartWriteStream]) {
    [self startWriteStream];
  }
}

- (void)handleHandshakeError:(NSError *)error {
  // Reset the token if it's a permanent error or the error code is ABORTED, signaling the write
  // stream is no longer valid.
  if ([FSTDatastore isPermanentWriteError:error] || [FSTDatastore isAbortedError:error]) {
    NSString *token = [self.writeStream.lastStreamToken base64EncodedStringWithOptions:0];
    LOG_DEBUG("FSTRemoteStore %s error before completed handshake; resetting stream token %s: %s",
              (__bridge void *)self, token, error);
    self.writeStream.lastStreamToken = nil;
    [self.localStore setLastStreamToken:nil];
  }
}

- (void)handleWriteError:(NSError *)error {
  // Only handle permanent error. If it's transient, just let the retry logic kick in.
  if (![FSTDatastore isPermanentWriteError:error]) {
    return;
  }

  // If this was a permanent error, the request itself was the problem so it's not going to
  // succeed if we resend it.
  FSTMutationBatch *batch = self.writePipeline[0];
  [self.writePipeline removeObjectAtIndex:0];

  // In this case it's also unlikely that the server itself is melting down--this was just a
  // bad request so inhibit backoff on the next restart.
  [self.writeStream inhibitBackoff];

  [self.syncEngine rejectFailedWriteWithBatchID:batch.batchID error:error];

  // It's possible that with the completion of this mutation another slot has freed up.
  [self fillWritePipeline];
}

- (FSTTransaction *)transaction {
  return [FSTTransaction transactionWithDatastore:self.datastore];
}

@end

NS_ASSUME_NONNULL_END
