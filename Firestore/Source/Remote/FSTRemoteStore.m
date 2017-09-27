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

#import "FSTRemoteStore.h"

#import "FSTAssert.h"
#import "FSTDatastore.h"
#import "FSTDocument.h"
#import "FSTDocumentKey.h"
#import "FSTExistenceFilter.h"
#import "FSTLocalStore.h"
#import "FSTLogger.h"
#import "FSTMutation.h"
#import "FSTMutationBatch.h"
#import "FSTQuery.h"
#import "FSTQueryData.h"
#import "FSTRemoteEvent.h"
#import "FSTSnapshotVersion.h"
#import "FSTTransaction.h"
#import "FSTWatchChange.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The maximum number of pending writes to allow.
 * TODO(bjornick): Negotiate this value with the backend.
 */
static const NSUInteger kMaxPendingWrites = 10;

#pragma mark - FSTRemoteStore

@interface FSTRemoteStore () <FSTWatchStreamDelegate, FSTWriteStreamDelegate>

- (instancetype)initWithLocalStore:(FSTLocalStore *)localStore
                         datastore:(FSTDatastore *)datastore NS_DESIGNATED_INITIALIZER;

/**
 * The local store, used to fill the write pipeline with outbound mutations and resolve existence
 * filter mismatches. Immutable after initialization.
 */
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;

/** The client-side proxy for interacting with the backend. Immutable after initialization. */
@property(nonatomic, strong, readonly) FSTDatastore *datastore;

#pragma mark Watch Stream
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

/**
 * The online state of the watch stream. The state is set to healthy if and only if there are
 * messages received by the backend.
 */
@property(nonatomic, assign) FSTOnlineState watchStreamOnlineState;

#pragma mark Write Stream
@property(nonatomic, strong, nullable) FSTWriteStream *writeStream;

/**
 * The approximate time the StreamingWrite stream was opened. Used to estimate if stream was
 * closed due to an auth expiration (a recoverable error) or some other more permanent error.
 */
@property(nonatomic, strong, nullable) NSDate *writeStreamOpenTime;

/**
 * A FIFO queue of in-flight writes. This is in-flight from the point of view of the caller of
 * writeMutations, not from the point of view from the Datastore itself. In particular, these
 * requests may not have been sent to the Datastore server if the write stream is not yet running.
 */
@property(nonatomic, strong, readonly) NSMutableArray<FSTMutationBatch *> *pendingWrites;
@end

@implementation FSTRemoteStore

+ (instancetype)remoteStoreWithLocalStore:(FSTLocalStore *)localStore
                                datastore:(FSTDatastore *)datastore {
  return [[FSTRemoteStore alloc] initWithLocalStore:localStore datastore:datastore];
}

- (instancetype)initWithLocalStore:(FSTLocalStore *)localStore datastore:(FSTDatastore *)datastore {
  if (self = [super init]) {
    _localStore = localStore;
    _datastore = datastore;
    _listenTargets = [NSMutableDictionary dictionary];
    _pendingTargetResponses = [NSMutableDictionary dictionary];
    _accumulatedChanges = [NSMutableArray array];

    _lastBatchSeen = kFSTBatchIDUnknown;
    _watchStreamOnlineState = FSTOnlineStateUnknown;
    _pendingWrites = [NSMutableArray array];
  }
  return self;
}

- (void)start {
  [self setupStreams];

  // Resume any writes
  [self fillWritePipeline];
}

- (void)updateAndNotifyAboutOnlineState:(FSTOnlineState)watchStreamOnlineState {
  BOOL didChange = (watchStreamOnlineState != self.watchStreamOnlineState);
  self.watchStreamOnlineState = watchStreamOnlineState;
  if (didChange) {
    [self.onlineStateDelegate watchStreamDidChangeOnlineState:watchStreamOnlineState];
  }
}

- (void)setupStreams {
  self.watchStream = [self.datastore createWatchStreamWithDelegate:self];
  self.writeStream = [self.datastore createWriteStreamWithDelegate:self];

  // Load any saved stream token from persistent storage
  self.writeStream.lastStreamToken = [self.localStore lastStreamToken];
}

#pragma mark Shutdown

- (void)shutdown {
  FSTLog(@"FSTRemoteStore %p shutting down", (__bridge void *)self);

  self.watchStreamOnlineState = FSTOnlineStateUnknown;
  [self cleanupWatchStreamState];
  [self.watchStream stop];
  [self.writeStream stop];
}

- (void)userDidChange:(FSTUser *)user {
  FSTLog(@"FSTRemoteStore %p changing users: %@", (__bridge void *)self, user);

  // Clear pending writes because those are per-user. Watched targets persist across users so
  // don't clear those.
  _lastBatchSeen = kFSTBatchIDUnknown;
  [self.pendingWrites removeAllObjects];

  // Stop the streams. They promise not to call us back.
  [self.watchStream stop];
  [self.writeStream stop];

  [self cleanupWatchStreamState];

  // Create new streams (but note they're not started yet).
  [self setupStreams];

  // If there are any watchedTargets properly handle the stream restart now that FSTRemoteStore
  // is ready to handle them.
  if ([self shouldStartWatchStream]) {
    [self.watchStream start];
  }

  // Resume any writes
  [self fillWritePipeline];

  // User change moves us back to the unknown state because we might not
  // want to re-open the stream
  [self updateAndNotifyAboutOnlineState:FSTOnlineStateUnknown];
}

#pragma mark Watch Stream

- (void)listenToTargetWithQueryData:(FSTQueryData *)queryData {
  NSNumber *targetKey = @(queryData.targetID);
  FSTAssert(!self.listenTargets[targetKey], @"listenToQuery called with duplicate target id: %@",
            targetKey);

  self.listenTargets[targetKey] = queryData;
  if ([self.watchStream isOpen]) {
    [self sendWatchRequestWithQueryData:queryData];
  } else if (![self.watchStream isStarted]) {
    [self.watchStream start];
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
  if ([self.watchStream isOpen]) {
    [self sendUnwatchRequestForTargetID:targetKey];
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
 * Returns whether the watch stream should be started because there are active targets trying to
 * be listened to.
 */
- (BOOL)shouldStartWatchStream {
  return self.listenTargets.count > 0;
}

- (void)cleanupWatchStreamState {
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
             snapshotVersion:(FSTSnapshotVersion *)snapshotVersion {
  // Mark the connection as healthy because we got a message from the server.
  [self updateAndNotifyAboutOnlineState:FSTOnlineStateHealthy];

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
    FSTAssert(snapshotVersion, @"snapshotVersion must not be nil.");
    if ([snapshotVersion isEqual:[FSTSnapshotVersion noVersion]] ||
        [snapshotVersion compare:[self.localStore lastRemoteSnapshotVersion]] ==
            NSOrderedAscending) {
      return;
    }

    // Create a batch, giving it the accumulatedChanges array.
    NSArray<FSTWatchChange *> *changes = self.accumulatedChanges;
    self.accumulatedChanges = [NSMutableArray array];

    [self processBatchedWatchChanges:changes snapshotVersion:snapshotVersion];
  }
}

- (void)watchStreamDidClose:(NSError *_Nullable)error {
  [self cleanupWatchStreamState];

  // If there was an error, retry the connection.
  if ([self shouldStartWatchStream]) {
    // If the connection fails before the stream has become healthy, consider the online state
    // failed. Otherwise consider the online state unknown and the next connection attempt will
    // resolve the online state. For example, if a healthy stream is closed due to an expired token
    // we want to have one more try at reconnecting before we consider the connection unhealthy.
    if (self.watchStreamOnlineState == FSTOnlineStateHealthy) {
      [self updateAndNotifyAboutOnlineState:FSTOnlineStateUnknown];
    } else {
      [self updateAndNotifyAboutOnlineState:FSTOnlineStateFailed];
    }
    [self.watchStream start];
  } else {
    // No need to restart watch stream because there are no active targets. The online state is set
    // to unknown because there is no active attempt at establishing a connection.
    [self updateAndNotifyAboutOnlineState:FSTOnlineStateUnknown];
  }
}

/**
 * Takes a batch of changes from the Datastore, repackages them as a RemoteEvent, and passes that
 * on to the SyncEngine.
 */
- (void)processBatchedWatchChanges:(NSArray<FSTWatchChange *> *)changes
                   snapshotVersion:(FSTSnapshotVersion *)snapshotVersion {
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
        FSTDocumentKey *key = [FSTDocumentKey keyWithPath:query.path];
        FSTDeletedDocument *deletedDoc =
            [FSTDeletedDocument documentWithKey:key version:snapshotVersion];
        [remoteEvent addDocumentUpdate:deletedDoc];
      } else {
        FSTAssert(filter.count == 1, @"Single document existence filter with count: %" PRId32,
                  filter.count);
      }

    } else {
      // Not a document query.
      FSTDocumentKeySet *trackedRemote = [self.localStore remoteDocumentKeysForTarget:targetID];
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

      if (trackedRemote.count != (NSUInteger)filter.count) {
        FSTLog(@"Existence filter mismatch, resetting mapping");

        // Make sure the mismatch is exposed in the remote event
        [remoteEvent handleExistenceFilterMismatchForTargetID:target];

        // Clear the resume token for the query, since we're in a known mismatch state.
        queryData =
            [[FSTQueryData alloc] initWithQuery:query targetID:targetID purpose:queryData.purpose];
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
      FSTQueryData *queryData = _listenTargets[target];
      // A watched target might have been removed already.
      if (queryData) {
        _listenTargets[target] =
            [queryData queryDataByReplacingSnapshotVersion:change.snapshotVersion
                                               resumeToken:resumeToken];
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
      [self.syncEngine rejectListenWithTargetID:targetID error:change.cause];
    }
  }
}

#pragma mark Write Stream

- (void)fillWritePipeline {
  while ([self canWriteMutations]) {
    FSTMutationBatch *batch = [self.localStore nextMutationBatchAfterBatchID:self.lastBatchSeen];
    if (!batch) {
      break;
    }
    [self commitBatch:batch];
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
  return self.pendingWrites.count < kMaxPendingWrites;
}

/** Given mutations to commit, actually commits them to the backend. */
- (void)commitBatch:(FSTMutationBatch *)batch {
  FSTAssert([self canWriteMutations], @"commitBatch called when mutations can't be written");
  self.lastBatchSeen = batch.batchID;

  if (!self.writeStream.isStarted) {
    [self.writeStream start];
  }

  [self.pendingWrites addObject:batch];

  if (self.writeStream.handshakeComplete) {
    [self.writeStream writeMutations:batch.mutations];
  }
}

- (void)writeStreamDidOpen {
  self.writeStreamOpenTime = [NSDate date];

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
- (void)writeStreamDidReceiveResponseWithVersion:(FSTSnapshotVersion *)commitVersion
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
- (void)writeStreamDidClose:(NSError *_Nullable)error {
  NSMutableArray *pendingWrites = self.pendingWrites;
  // Ignore close if there are no pending writes.
  if (pendingWrites.count == 0) {
    return;
  }

  FSTAssert(error, @"There are pending writes, but the write stream closed without an error.");
  if ([FSTDatastore isPermanentWriteError:error]) {
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
  if (pendingWrites.count > 0 && !self.writeStream.isStarted) {
    [self.writeStream start];
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
