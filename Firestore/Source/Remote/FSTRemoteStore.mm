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
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTLogger.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::User;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::DocumentKeySet;

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

/**
 * A mapping of targetId to pending acks needed.
 *
 * If a targetId is present in this map, then we're waiting for watch to
 * acknowledge a removal or addition of the target. If a target is not in this
 * mapping, and it's in the listenTargets map, then we consider the target to
 * be active.
 *
 * We increment the count here everytime we issue a request over the stream to
 * watch or unwatch. We then decrement the count everytime we get a target
 * added or target removed message from the server. Once the count is equal to
 * 0 we know that the client and server are in the same state (once this state
 * is reached the targetId is removed from the map to free the memory).
 */
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTBoxedTargetID *, NSNumber *> *pendingTargetResponses;

@property(nonatomic, strong) NSMutableArray<FSTWatchChange *> *accumulatedChanges;
@property(nonatomic, assign) FSTBatchID lastBatchSeen;

@property(nonatomic, strong, readonly) FSTOnlineStateTracker *onlineStateTracker;

#pragma mark Write Stream
// The writeStream is null when the network is disabled. The non-null check is performed by
// isNetworkEnabled.
@property(nonatomic, strong, nullable) FSTWriteStream *writeStream;

/**
 * A FIFO queue of in-flight writes. This is in-flight from the point of view of the caller of
 * writeMutations, not from the point of view from the Datastore itself. In particular, these
 * requests may not have been sent to the Datastore server if the write stream is not yet running.
 */
@property(nonatomic, strong, readonly) NSMutableArray<FSTMutationBatch *> *pendingWrites;
@end

@implementation FSTRemoteStore

- (instancetype)initWithLocalStore:(FSTLocalStore *)localStore
                         datastore:(FSTDatastore *)datastore
               workerDispatchQueue:(FSTDispatchQueue *)queue {
  if (self = [super init]) {
    _localStore = localStore;
    _datastore = datastore;
    _listenTargets = [NSMutableDictionary dictionary];
    _pendingTargetResponses = [NSMutableDictionary dictionary];
    _accumulatedChanges = [NSMutableArray array];

    _lastBatchSeen = kFSTBatchIDUnknown;
    _pendingWrites = [NSMutableArray array];
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
  FSTAssert((self.watchStream == nil) == (self.writeStream == nil),
            @"WatchStream and WriteStream should both be null or non-null");
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
    [self.onlineStateTracker updateState:FSTOnlineStateUnknown];
  }

  [self fillWritePipeline];  // This may start the writeStream.
}

- (void)disableNetwork {
  [self disableNetworkInternal];
  // Set the FSTOnlineState to Offline so get()s return from cache, etc.
  [self.onlineStateTracker updateState:FSTOnlineStateOffline];
}

/** Disables the network, setting the FSTOnlineState to the specified targetOnlineState. */
- (void)disableNetworkInternal {
  if ([self isNetworkEnabled]) {
    // NOTE: We're guaranteed not to get any further events from these streams (not even a close
    // event).
    [self.watchStream stop];
    [self.writeStream stop];

    [self cleanUpWatchStreamState];
    [self cleanUpWriteStreamState];

    self.writeStream = nil;
    self.watchStream = nil;
  }
}

#pragma mark Shutdown

- (void)shutdown {
  FSTLog(@"FSTRemoteStore %p shutting down", (__bridge void *)self);
  [self disableNetworkInternal];
  // Set the FSTOnlineState to Unknown (rather than Offline) to avoid potentially triggering
  // spurious listener events with cached data, etc.
  [self.onlineStateTracker updateState:FSTOnlineStateUnknown];
}

- (void)userDidChange:(const User &)user {
  FSTLog(@"FSTRemoteStore %p changing users: %s", (__bridge void *)self, user.uid().c_str());
  if ([self isNetworkEnabled]) {
    // Tear down and re-create our network streams. This will ensure we get a fresh auth token
    // for the new user and re-fill the write pipeline with new mutations from the LocalStore
    // (since mutations are per-user).
    [self disableNetworkInternal];
    [self.onlineStateTracker updateState:FSTOnlineStateUnknown];
    [self enableNetwork];
  }
}

#pragma mark Watch Stream

- (void)startWatchStream {
  FSTAssert([self shouldStartWatchStream],
            @"startWatchStream: called when shouldStartWatchStream: is false.");
  [self.watchStream startWithDelegate:self];
  [self.onlineStateTracker handleWatchStreamStart];
}

- (void)listenToTargetWithQueryData:(FSTQueryData *)queryData {
  NSNumber *targetKey = @(queryData.targetID);
  FSTAssert(!self.listenTargets[targetKey], @"listenToQuery called with duplicate target id: %@",
            targetKey);

  self.listenTargets[targetKey] = queryData;

  if ([self shouldStartWatchStream]) {
    [self startWatchStream];
  } else if ([self isNetworkEnabled] && [self.watchStream isOpen]) {
    [self sendWatchRequestWithQueryData:queryData];
  }
}

- (void)sendWatchRequestWithQueryData:(FSTQueryData *)queryData {
  [self recordPendingRequestForTargetID:@(queryData.targetID)];
  [self.watchStream watchQuery:queryData];
}

- (void)stopListeningToTargetID:(FSTTargetID)targetID {
  FSTBoxedTargetID *targetKey = @(targetID);
  FSTQueryData *queryData = self.listenTargets[targetKey];
  FSTAssert(queryData, @"unlistenToTarget: target not currently watched: %@", targetKey);

  [self.listenTargets removeObjectForKey:targetKey];
  if ([self isNetworkEnabled] && [self.watchStream isOpen]) {
    [self sendUnwatchRequestForTargetID:targetKey];
    if ([self.listenTargets count] == 0) {
      [self.watchStream markIdle];
    }
  }
}

- (void)sendUnwatchRequestForTargetID:(FSTBoxedTargetID *)targetID {
  [self recordPendingRequestForTargetID:targetID];
  [self.watchStream unwatchTargetID:[targetID intValue]];
}

- (void)recordPendingRequestForTargetID:(FSTBoxedTargetID *)targetID {
  NSNumber *count = [self.pendingTargetResponses objectForKey:targetID];
  count = @([count intValue] + 1);
  [self.pendingTargetResponses setObject:count forKey:targetID];
}

/**
 * Returns YES if the network is enabled, the watch stream has not yet been started and there are
 * active watch targets.
 */
- (BOOL)shouldStartWatchStream {
  return [self isNetworkEnabled] && ![self.watchStream isStarted] && self.listenTargets.count > 0;
}

- (void)cleanUpWatchStreamState {
  // If the connection is closed then we'll never get a snapshot version for the accumulated
  // changes and so we'll never be able to complete the batch. When we start up again the server
  // is going to resend these changes anyway, so just toss the accumulated state.
  [self.accumulatedChanges removeAllObjects];
  [self.pendingTargetResponses removeAllObjects];
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
  [self.onlineStateTracker updateState:FSTOnlineStateOnline];

  FSTWatchTargetChange *watchTargetChange =
      [change isKindOfClass:[FSTWatchTargetChange class]] ? (FSTWatchTargetChange *)change : nil;

  if (watchTargetChange && watchTargetChange.state == FSTWatchTargetChangeStateRemoved &&
      watchTargetChange.cause) {
    // There was an error on a target, don't wait for a consistent snapshot to raise events
    [self processTargetErrorForWatchChange:(FSTWatchTargetChange *)change];
  } else {
    // Accumulate watch changes but don't process them if there's no snapshotVersion or it's
    // older than a previous snapshot we've processed (can happen after we resume a target
    // using a resume token).
    [self.accumulatedChanges addObject:change];
    if (snapshotVersion == SnapshotVersion::None() ||
        snapshotVersion < [self.localStore lastRemoteSnapshotVersion]) {
      return;
    }

    // Create a batch, giving it the accumulatedChanges array.
    NSArray<FSTWatchChange *> *changes = self.accumulatedChanges;
    self.accumulatedChanges = [NSMutableArray array];

    [self processBatchedWatchChanges:changes snapshotVersion:snapshotVersion];
  }
}

- (void)watchStreamWasInterruptedWithError:(nullable NSError *)error {
  FSTAssert([self isNetworkEnabled],
            @"watchStreamWasInterruptedWithError: should only be called when the network is "
             "enabled");

  [self cleanUpWatchStreamState];
  [self.onlineStateTracker handleWatchStreamFailure];

  // If the watch stream closed due to an error, retry the connection if there are any active
  // watch targets.
  if ([self shouldStartWatchStream]) {
    [self startWatchStream];
  } else {
    // We don't need to restart the watch stream because there are no active targets. The online
    // state is set to unknown because there is no active attempt at establishing a connection.
    [self.onlineStateTracker updateState:FSTOnlineStateUnknown];
  }
}

/**
 * Takes a batch of changes from the Datastore, repackages them as a RemoteEvent, and passes that
 * on to the SyncEngine.
 */
- (void)processBatchedWatchChanges:(NSArray<FSTWatchChange *> *)changes
                   snapshotVersion:(const SnapshotVersion &)snapshotVersion {
  FSTWatchChangeAggregator *aggregator =
      [[FSTWatchChangeAggregator alloc] initWithSnapshotVersion:snapshotVersion
                                                  listenTargets:self.listenTargets
                                         pendingTargetResponses:self.pendingTargetResponses];
  [aggregator addWatchChanges:changes];
  FSTRemoteEvent *remoteEvent = [aggregator remoteEvent];
  [self.pendingTargetResponses removeAllObjects];
  [self.pendingTargetResponses setDictionary:aggregator.pendingTargetResponses];

  // Handle existence filters and existence filter mismatches
  [aggregator.existenceFilters enumerateKeysAndObjectsUsingBlock:^(FSTBoxedTargetID *target,
                                                                   FSTExistenceFilter *filter,
                                                                   BOOL *stop) {
    FSTTargetID targetID = target.intValue;

    FSTQueryData *queryData = self.listenTargets[target];
    FSTQuery *query = queryData.query;
    if (!queryData) {
      // A watched target might have been removed already.
      return;

    } else if ([query isDocumentQuery]) {
      if (filter.count == 0) {
        // The existence filter told us the document does not exist.
        // We need to deduce that this document does not exist and apply a deleted document to our
        // updates. Without applying a deleted document there might be another query that will
        // raise this document as part of a snapshot until it is resolved, essentially exposing
        // inconsistency between queries
        const DocumentKey key{query.path};
        FSTDeletedDocument *deletedDoc =
            [FSTDeletedDocument documentWithKey:key version:snapshotVersion];
        [remoteEvent addDocumentUpdate:deletedDoc];
      } else {
        FSTAssert(filter.count == 1, @"Single document existence filter with count: %" PRId32,
                  filter.count);
      }

    } else {
      // Not a document query.
      DocumentKeySet trackedRemote = [self.localStore remoteDocumentKeysForTarget:targetID];
      FSTTargetMapping *mapping = remoteEvent.targetChanges[target].mapping;
      if (mapping) {
        if ([mapping isKindOfClass:[FSTUpdateMapping class]]) {
          FSTUpdateMapping *update = (FSTUpdateMapping *)mapping;
          trackedRemote = [update applyTo:trackedRemote];
        } else {
          FSTAssert([mapping isKindOfClass:[FSTResetMapping class]],
                    @"Expected either reset or update mapping but got something else %@", mapping);
          trackedRemote = ((FSTResetMapping *)mapping).documents;
        }
      }

      if (trackedRemote.size() != static_cast<size_t>(filter.count)) {
        FSTLog(@"Existence filter mismatch, resetting mapping");

        // Make sure the mismatch is exposed in the remote event
        [remoteEvent handleExistenceFilterMismatchForTargetID:target];

        // Clear the resume token for the query, since we're in a known mismatch state.
        queryData = [[FSTQueryData alloc] initWithQuery:query
                                               targetID:targetID
                                   listenSequenceNumber:queryData.sequenceNumber
                                                purpose:queryData.purpose];
        self.listenTargets[target] = queryData;

        // Cause a hard reset by unwatching and rewatching immediately, but deliberately don't
        // send a resume token so that we get a full update.
        [self sendUnwatchRequestForTargetID:@(targetID)];

        // Mark the query we send as being on behalf of an existence filter mismatch, but don't
        // actually retain that in listenTargets. This ensures that we flag the first re-listen
        // this way without impacting future listens of this target (that might happen e.g. on
        // reconnect).
        FSTQueryData *requestQueryData =
            [[FSTQueryData alloc] initWithQuery:query
                                       targetID:targetID
                           listenSequenceNumber:queryData.sequenceNumber
                                        purpose:FSTQueryPurposeExistenceFilterMismatch];
        [self sendWatchRequestWithQueryData:requestQueryData];
      }
    }
  }];

  // Update in-memory resume tokens. FSTLocalStore will update the persistent view of these when
  // applying the completed FSTRemoteEvent.
  [remoteEvent.targetChanges enumerateKeysAndObjectsUsingBlock:^(
                                 FSTBoxedTargetID *target, FSTTargetChange *change, BOOL *stop) {
    NSData *resumeToken = change.resumeToken;
    if (resumeToken.length > 0) {
      FSTQueryData *queryData = self->_listenTargets[target];
      // A watched target might have been removed already.
      if (queryData) {
        self->_listenTargets[target] =
            [queryData queryDataByReplacingSnapshotVersion:change.snapshotVersion
                                               resumeToken:resumeToken
                                            sequenceNumber:queryData.sequenceNumber];
      }
    }
  }];

  // Finally handle remote event
  [self.syncEngine applyRemoteEvent:remoteEvent];
}

/** Process a target error and passes the error along to SyncEngine. */
- (void)processTargetErrorForWatchChange:(FSTWatchTargetChange *)change {
  FSTAssert(change.cause, @"Handling target error without a cause");
  // Ignore targets that have been removed already.
  for (FSTBoxedTargetID *targetID in change.targetIDs) {
    if (self.listenTargets[targetID]) {
      [self.listenTargets removeObjectForKey:targetID];
      [self.syncEngine rejectListenWithTargetID:[targetID intValue] error:change.cause];
    }
  }
}

#pragma mark Write Stream

/**
 * Returns YES if the network is enabled, the write stream has not yet been started and there are
 * pending writes.
 */
- (BOOL)shouldStartWriteStream {
  return [self isNetworkEnabled] && ![self.writeStream isStarted] && self.pendingWrites.count > 0;
}

- (void)startWriteStream {
  FSTAssert([self shouldStartWriteStream],
            @"startWriteStream: called when shouldStartWriteStream: is false.");

  [self.writeStream startWithDelegate:self];
}

- (void)cleanUpWriteStreamState {
  self.lastBatchSeen = kFSTBatchIDUnknown;
  FSTLog(@"Stopping write stream with %lu pending writes",
         (unsigned long)[self.pendingWrites count]);
  [self.pendingWrites removeAllObjects];
}

- (void)fillWritePipeline {
  if ([self isNetworkEnabled]) {
    while ([self canWriteMutations]) {
      FSTMutationBatch *batch = [self.localStore nextMutationBatchAfterBatchID:self.lastBatchSeen];
      if (!batch) {
        break;
      }
      [self commitBatch:batch];
    }

    if ([self.pendingWrites count] == 0) {
      [self.writeStream markIdle];
    }
  }
}

/**
 * Returns YES if the backend can accept additional write requests.
 *
 * When sending mutations to the write stream (e.g. in -fillWritePipeline), call this method first
 * to check if more mutations can be sent.
 *
 * Currently the only thing that can prevent the backend from accepting write requests is if
 * there are too many requests already outstanding. As writes complete the backend will be able
 * to accept more.
 */
- (BOOL)canWriteMutations {
  return [self isNetworkEnabled] && self.pendingWrites.count < kMaxPendingWrites;
}

/** Given mutations to commit, actually commits them to the backend. */
- (void)commitBatch:(FSTMutationBatch *)batch {
  FSTAssert([self canWriteMutations], @"commitBatch called when mutations can't be written");
  self.lastBatchSeen = batch.batchID;

  [self.pendingWrites addObject:batch];

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

  // Drain any pending writes.
  //
  // Note that at this point pendingWrites contains mutations that have already been accepted by
  // fillWritePipeline/commitBatch. If the pipeline is full, canWriteMutations will be NO, despite
  // the fact that we actually need to send mutations over.
  //
  // This also means that this method indirectly respects the limits imposed by canWriteMutations
  // since writes can't be added to the pendingWrites array when canWriteMutations is NO. If the
  // limits imposed by canWriteMutations actually protect us from DOSing ourselves then those limits
  // won't be exceeded here and we'll continue to make progress.
  for (FSTMutationBatch *write in self.pendingWrites) {
    [self.writeStream writeMutations:write.mutations];
  }
}

/** Handles a successful StreamingWriteResponse from the server that contains a mutation result. */
- (void)writeStreamDidReceiveResponseWithVersion:(const SnapshotVersion &)commitVersion
                                 mutationResults:(NSArray<FSTMutationResult *> *)results {
  // This is a response to a write containing mutations and should be correlated to the first
  // pending write.
  NSMutableArray *pendingWrites = self.pendingWrites;
  FSTMutationBatch *batch = pendingWrites[0];
  [pendingWrites removeObjectAtIndex:0];

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
  FSTAssert([self isNetworkEnabled],
            @"writeStreamDidClose: should only be called when the network is enabled");

  // If the write stream closed due to an error, invoke the error callbacks if there are pending
  // writes.
  if (error != nil && self.pendingWrites.count > 0) {
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
    FSTLog(@"FSTRemoteStore %p error before completed handshake; resetting stream token %@: %@",
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
  FSTMutationBatch *batch = self.pendingWrites[0];
  [self.pendingWrites removeObjectAtIndex:0];

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
