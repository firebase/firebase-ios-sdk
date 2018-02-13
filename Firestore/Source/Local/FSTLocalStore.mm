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

#import "Firestore/Source/Local/FSTLocalStore.h"

#import "Firestore/Source/Auth/FSTUser.h"
#import "Firestore/Source/Core/FSTListenSequence.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Core/FSTTimestamp.h"
#import "Firestore/Source/Local/FSTGarbageCollector.h"
#import "Firestore/Source/Local/FSTLocalDocumentsView.h"
#import "Firestore/Source/Local/FSTLocalViewChanges.h"
#import "Firestore/Source/Local/FSTLocalWriteResult.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"
#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Local/FSTRemoteDocumentChangeBuffer.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTLogger.h"

#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"

using firebase::firestore::core::TargetIdGenerator;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalStore ()

/** Manages our in-memory or durable persistence. */
@property(nonatomic, strong, readonly) id<FSTPersistence> persistence;

/** The set of all mutations that have been sent but not yet been applied to the backend. */
@property(nonatomic, strong) id<FSTMutationQueue> mutationQueue;

/** The set of all cached remote documents. */
@property(nonatomic, strong) id<FSTRemoteDocumentCache> remoteDocumentCache;

/** The "local" view of all documents (layering mutationQueue on top of remoteDocumentCache). */
@property(nonatomic, strong) FSTLocalDocumentsView *localDocuments;

/** The set of document references maintained by any local views. */
@property(nonatomic, strong) FSTReferenceSet *localViewReferences;

/**
 * The garbage collector collects documents that should no longer be cached (e.g. if they are no
 * longer retained by the above reference sets and the garbage collector is performing eager
 * collection).
 */
@property(nonatomic, strong) id<FSTGarbageCollector> garbageCollector;

/** Maps a query to the data about that query. */
@property(nonatomic, strong) id<FSTQueryCache> queryCache;

/** Maps a targetID to data about its query. */
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, FSTQueryData *> *targetIDs;

@property(nonatomic, strong) FSTListenSequence *listenSequence;

/**
 * A heldBatchResult is a mutation batch result (from a write acknowledgement) that arrived before
 * the watch stream got notified of a snapshot that includes the write.  So we "hold" it until
 * the watch stream catches up. It ensures that the local write remains visible (latency
 * compensation) and doesn't temporarily appear reverted because the watch stream is slower than
 * the write stream and so wasn't reflecting it.
 *
 * NOTE: Eventually we want to move this functionality into the remote store.
 */
@property(nonatomic, strong) NSMutableArray<FSTMutationBatchResult *> *heldBatchResults;

@end

@implementation FSTLocalStore {
  /** Used to generate targetIDs for queries tracked locally. */
  TargetIdGenerator _targetIDGenerator;
}

- (instancetype)initWithPersistence:(id<FSTPersistence>)persistence
                   garbageCollector:(id<FSTGarbageCollector>)garbageCollector
                        initialUser:(FSTUser *)initialUser {
  if (self = [super init]) {
    _persistence = persistence;
    _mutationQueue = [persistence mutationQueueForUser:initialUser];
    _remoteDocumentCache = [persistence remoteDocumentCache];
    _queryCache = [persistence queryCache];
    _localDocuments = [FSTLocalDocumentsView viewWithRemoteDocumentCache:_remoteDocumentCache
                                                           mutationQueue:_mutationQueue];
    _localViewReferences = [[FSTReferenceSet alloc] init];

    _garbageCollector = garbageCollector;
    [_garbageCollector addGarbageSource:_queryCache];
    [_garbageCollector addGarbageSource:_localViewReferences];
    [_garbageCollector addGarbageSource:_mutationQueue];

    _targetIDs = [NSMutableDictionary dictionary];
    _heldBatchResults = [NSMutableArray array];

    _targetIDGenerator = TargetIdGenerator::LocalStoreTargetIdGenerator(0);
  }
  return self;
}

- (void)start {
  [self startMutationQueue];
  [self startQueryCache];
}

- (void)startMutationQueue {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Start MutationQueue"];
  [self.mutationQueue startWithGroup:group];

  // If we have any leftover mutation batch results from a prior run, just drop them.
  // TODO(http://b/33446471): We probably need to repopulate heldBatchResults or similar instead,
  // but that is not straightforward since we're not persisting the write ack versions.
  [self.heldBatchResults removeAllObjects];

  // TODO(mikelehen): This is the only usage of getAllMutationBatchesThroughBatchId:. Consider
  // removing it in favor of a getAcknowledgedBatches method.
  FSTBatchID highestAck = [self.mutationQueue highestAcknowledgedBatchID];
  if (highestAck != kFSTBatchIDUnknown) {
    NSArray<FSTMutationBatch *> *batches =
        [self.mutationQueue allMutationBatchesThroughBatchID:highestAck];
    if (batches.count > 0) {
      // NOTE: This could be more efficient if we had a removeBatchesThroughBatchID, but this set
      // should be very small and this code should go away eventually.
      [self.mutationQueue removeMutationBatches:batches group:group];
    }
  }
  [self.persistence commitGroup:group];
}

- (void)startQueryCache {
  [self.queryCache start];

  FSTTargetID targetID = [self.queryCache highestTargetID];
  _targetIDGenerator = TargetIdGenerator::LocalStoreTargetIdGenerator(targetID);
  FSTListenSequenceNumber sequenceNumber = [self.queryCache highestListenSequenceNumber];
  self.listenSequence = [[FSTListenSequence alloc] initStartingAfter:sequenceNumber];
}

- (void)shutdown {
  [self.mutationQueue shutdown];
  [self.remoteDocumentCache shutdown];
  [self.queryCache shutdown];
}

- (FSTMaybeDocumentDictionary *)userDidChange:(FSTUser *)user {
  // Swap out the mutation queue, grabbing the pending mutation batches before and after.
  NSArray<FSTMutationBatch *> *oldBatches = [self.mutationQueue allMutationBatches];

  [self.mutationQueue shutdown];
  [self.garbageCollector removeGarbageSource:self.mutationQueue];

  self.mutationQueue = [self.persistence mutationQueueForUser:user];
  [self.garbageCollector addGarbageSource:self.mutationQueue];

  [self startMutationQueue];

  NSArray<FSTMutationBatch *> *newBatches = [self.mutationQueue allMutationBatches];

  // Recreate our LocalDocumentsView using the new MutationQueue.
  self.localDocuments = [FSTLocalDocumentsView viewWithRemoteDocumentCache:self.remoteDocumentCache
                                                             mutationQueue:self.mutationQueue];

  // Union the old/new changed keys.
  FSTDocumentKeySet *changedKeys = [FSTDocumentKeySet keySet];
  for (NSArray<FSTMutationBatch *> *batches in @[ oldBatches, newBatches ]) {
    for (FSTMutationBatch *batch in batches) {
      for (FSTMutation *mutation in batch.mutations) {
        changedKeys = [changedKeys setByAddingObject:mutation.key];
      }
    }
  }

  // Return the set of all (potentially) changed documents as the result of the user change.
  return [self.localDocuments documentsForKeys:changedKeys];
}

- (FSTLocalWriteResult *)locallyWriteMutations:(NSArray<FSTMutation *> *)mutations {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Locally write mutations"];
  FSTTimestamp *localWriteTime = [FSTTimestamp timestamp];
  FSTMutationBatch *batch = [self.mutationQueue addMutationBatchWithWriteTime:localWriteTime
                                                                    mutations:mutations
                                                                        group:group];
  [self.persistence commitGroup:group];

  FSTDocumentKeySet *keys = [batch keys];
  FSTMaybeDocumentDictionary *changedDocuments = [self.localDocuments documentsForKeys:keys];
  return [FSTLocalWriteResult resultForBatchID:batch.batchID changes:changedDocuments];
}

- (FSTMaybeDocumentDictionary *)acknowledgeBatchWithResult:(FSTMutationBatchResult *)batchResult {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Acknowledge batch"];
  id<FSTMutationQueue> mutationQueue = self.mutationQueue;

  [mutationQueue acknowledgeBatch:batchResult.batch
                      streamToken:batchResult.streamToken
                            group:group];

  FSTDocumentKeySet *affected;
  if ([self shouldHoldBatchResultWithVersion:batchResult.commitVersion]) {
    [self.heldBatchResults addObject:batchResult];
    affected = [FSTDocumentKeySet keySet];
  } else {
    FSTRemoteDocumentChangeBuffer *remoteDocuments =
        [FSTRemoteDocumentChangeBuffer changeBufferWithCache:self.remoteDocumentCache];

    affected =
        [self releaseBatchResults:@[ batchResult ] group:group remoteDocuments:remoteDocuments];

    [remoteDocuments applyToWriteGroup:group];
  }

  [self.persistence commitGroup:group];
  [self.mutationQueue performConsistencyCheck];

  return [self.localDocuments documentsForKeys:affected];
}

- (FSTMaybeDocumentDictionary *)rejectBatchID:(FSTBatchID)batchID {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Reject batch"];

  FSTMutationBatch *toReject = [self.mutationQueue lookupMutationBatch:batchID];
  FSTAssert(toReject, @"Attempt to reject nonexistent batch!");

  FSTBatchID lastAcked = [self.mutationQueue highestAcknowledgedBatchID];
  FSTAssert(batchID > lastAcked, @"Acknowledged batches can't be rejected.");

  FSTDocumentKeySet *affected = [self removeMutationBatch:toReject group:group];

  [self.persistence commitGroup:group];
  [self.mutationQueue performConsistencyCheck];

  return [self.localDocuments documentsForKeys:affected];
}

- (nullable NSData *)lastStreamToken {
  return [self.mutationQueue lastStreamToken];
}

- (void)setLastStreamToken:(nullable NSData *)streamToken {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Set stream token"];

  [self.mutationQueue setLastStreamToken:streamToken group:group];
  [self.persistence commitGroup:group];
}

- (FSTSnapshotVersion *)lastRemoteSnapshotVersion {
  return [self.queryCache lastRemoteSnapshotVersion];
}

- (FSTMaybeDocumentDictionary *)applyRemoteEvent:(FSTRemoteEvent *)remoteEvent {
  id<FSTQueryCache> queryCache = self.queryCache;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Apply remote event"];
  FSTRemoteDocumentChangeBuffer *remoteDocuments =
      [FSTRemoteDocumentChangeBuffer changeBufferWithCache:self.remoteDocumentCache];

  [remoteEvent.targetChanges enumerateKeysAndObjectsUsingBlock:^(
                                 NSNumber *targetIDNumber, FSTTargetChange *change, BOOL *stop) {
    FSTTargetID targetID = targetIDNumber.intValue;

    // Do not ref/unref unassigned targetIDs - it may lead to leaks.
    FSTQueryData *queryData = self.targetIDs[targetIDNumber];
    if (!queryData) {
      return;
    }

    FSTTargetMapping *mapping = change.mapping;
    if (mapping) {
      // First make sure that all references are deleted.
      if ([mapping isKindOfClass:[FSTResetMapping class]]) {
        FSTResetMapping *reset = (FSTResetMapping *)mapping;
        [queryCache removeMatchingKeysForTargetID:targetID group:group];
        [queryCache addMatchingKeys:reset.documents forTargetID:targetID group:group];

      } else if ([mapping isKindOfClass:[FSTUpdateMapping class]]) {
        FSTUpdateMapping *update = (FSTUpdateMapping *)mapping;
        [queryCache removeMatchingKeys:update.removedDocuments forTargetID:targetID group:group];
        [queryCache addMatchingKeys:update.addedDocuments forTargetID:targetID group:group];

      } else {
        FSTFail(@"Unknown mapping type: %@", mapping);
      }
    }

    // Update the resume token if the change includes one. Don't clear any preexisting value.
    NSData *resumeToken = change.resumeToken;
    if (resumeToken.length > 0) {
      queryData = [queryData queryDataByReplacingSnapshotVersion:change.snapshotVersion
                                                     resumeToken:resumeToken];
      self.targetIDs[targetIDNumber] = queryData;
      [self.queryCache updateQueryData:queryData group:group];
    }
  }];

  // TODO(klimt): This could probably be an NSMutableDictionary.
  __block FSTDocumentKeySet *changedDocKeys = [FSTDocumentKeySet keySet];
  [remoteEvent.documentUpdates
      enumerateKeysAndObjectsUsingBlock:^(FSTDocumentKey *key, FSTMaybeDocument *doc, BOOL *stop) {
        changedDocKeys = [changedDocKeys setByAddingObject:key];
        FSTMaybeDocument *existingDoc = [remoteDocuments entryForKey:key];
        // Make sure we don't apply an old document version to the remote cache, though we
        // make an exception for [SnapshotVersion noVersion] which can happen for manufactured
        // events (e.g. in the case of a limbo document resolution failing).
        if (!existingDoc || [doc.version isEqual:[FSTSnapshotVersion noVersion]] ||
            [doc.version compare:existingDoc.version] != NSOrderedAscending) {
          [remoteDocuments addEntry:doc];
        } else {
          FSTLog(
              @"FSTLocalStore Ignoring outdated watch update for %@. "
               "Current version: %@  Watch version: %@",
              key, existingDoc.version, doc.version);
        }

        // The document might be garbage because it was unreferenced by everything.
        // Make sure to mark it as garbage if it is...
        [self.garbageCollector addPotentialGarbageKey:key];
      }];

  // HACK: The only reason we allow omitting snapshot version is so we can synthesize remote events
  // when we get permission denied errors while trying to resolve the state of a locally cached
  // document that is in limbo.
  FSTSnapshotVersion *lastRemoteVersion = [self.queryCache lastRemoteSnapshotVersion];
  FSTSnapshotVersion *remoteVersion = remoteEvent.snapshotVersion;
  if (![remoteVersion isEqual:[FSTSnapshotVersion noVersion]]) {
    FSTAssert([remoteVersion compare:lastRemoteVersion] != NSOrderedAscending,
              @"Watch stream reverted to previous snapshot?? (%@ < %@)", remoteVersion,
              lastRemoteVersion);
    [self.queryCache setLastRemoteSnapshotVersion:remoteVersion group:group];
  }

  FSTDocumentKeySet *releasedWriteKeys =
      [self releaseHeldBatchResultsWithGroup:group remoteDocuments:remoteDocuments];

  [remoteDocuments applyToWriteGroup:group];

  [self.persistence commitGroup:group];

  // Union the two key sets.
  __block FSTDocumentKeySet *keysToRecalc = changedDocKeys;
  [releasedWriteKeys enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
    keysToRecalc = [keysToRecalc setByAddingObject:key];
  }];

  return [self.localDocuments documentsForKeys:keysToRecalc];
}

- (void)notifyLocalViewChanges:(NSArray<FSTLocalViewChanges *> *)viewChanges {
  FSTReferenceSet *localViewReferences = self.localViewReferences;
  for (FSTLocalViewChanges *view in viewChanges) {
    FSTQueryData *queryData = [self.queryCache queryDataForQuery:view.query];
    FSTAssert(queryData, @"Local view changes contain unallocated query.");
    FSTTargetID targetID = queryData.targetID;
    [localViewReferences addReferencesToKeys:view.addedKeys forID:targetID];
    [localViewReferences removeReferencesToKeys:view.removedKeys forID:targetID];
  }
}

- (nullable FSTMutationBatch *)nextMutationBatchAfterBatchID:(FSTBatchID)batchID {
  return [self.mutationQueue nextMutationBatchAfterBatchID:batchID];
}

- (nullable FSTMaybeDocument *)readDocument:(FSTDocumentKey *)key {
  return [self.localDocuments documentForKey:key];
}

- (FSTQueryData *)allocateQuery:(FSTQuery *)query {
  FSTQueryData *cached = [self.queryCache queryDataForQuery:query];
  FSTTargetID targetID;
  FSTListenSequenceNumber sequenceNumber = [self.listenSequence next];
  if (cached) {
    // This query has been listened to previously, so reuse the previous targetID.
    // TODO(mcg): freshen last accessed date?
    targetID = cached.targetID;
  } else {
    FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Allocate query"];

    targetID = _targetIDGenerator.NextId();
    cached = [[FSTQueryData alloc] initWithQuery:query
                                        targetID:targetID
                            listenSequenceNumber:sequenceNumber
                                         purpose:FSTQueryPurposeListen];
    [self.queryCache addQueryData:cached group:group];

    [self.persistence commitGroup:group];
  }

  // Sanity check to ensure that even when resuming a query it's not currently active.
  FSTBoxedTargetID *boxedTargetID = @(targetID);
  FSTAssert(!self.targetIDs[boxedTargetID], @"Tried to allocate an already allocated query: %@",
            query);
  self.targetIDs[boxedTargetID] = cached;
  return cached;
}

- (void)releaseQuery:(FSTQuery *)query {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Release query"];

  FSTQueryData *queryData = [self.queryCache queryDataForQuery:query];
  FSTAssert(queryData, @"Tried to release nonexistent query: %@", query);

  [self.localViewReferences removeReferencesForID:queryData.targetID];
  if (self.garbageCollector.isEager) {
    [self.queryCache removeQueryData:queryData group:group];
  }
  [self.targetIDs removeObjectForKey:@(queryData.targetID)];

  // If this was the last watch target, then we won't get any more watch snapshots, so we should
  // release any held batch results.
  if ([self.targetIDs count] == 0) {
    FSTRemoteDocumentChangeBuffer *remoteDocuments =
        [FSTRemoteDocumentChangeBuffer changeBufferWithCache:self.remoteDocumentCache];

    [self releaseHeldBatchResultsWithGroup:group remoteDocuments:remoteDocuments];

    [remoteDocuments applyToWriteGroup:group];
  }

  [self.persistence commitGroup:group];
}

- (FSTDocumentDictionary *)executeQuery:(FSTQuery *)query {
  return [self.localDocuments documentsMatchingQuery:query];
}

- (FSTDocumentKeySet *)remoteDocumentKeysForTarget:(FSTTargetID)targetID {
  return [self.queryCache matchingKeysForTargetID:targetID];
}

- (void)collectGarbage {
  // Call collectGarbage regardless of whether isGCEnabled so the referenceSet doesn't continue to
  // accumulate the garbage keys.
  NSSet<FSTDocumentKey *> *garbage = [self.garbageCollector collectGarbage];
  if (garbage.count > 0) {
    FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Garbage Collection"];
    for (FSTDocumentKey *key in garbage) {
      [self.remoteDocumentCache removeEntryForKey:key group:group];
    }
    [self.persistence commitGroup:group];
  }
}

/**
 * Releases all the held mutation batches up to the current remote version received, and
 * applies their mutations to the docs in the remote documents cache.
 *
 * @return the set of keys of docs that were modified by those writes.
 */
- (FSTDocumentKeySet *)releaseHeldBatchResultsWithGroup:(FSTWriteGroup *)group
                                        remoteDocuments:
                                            (FSTRemoteDocumentChangeBuffer *)remoteDocuments {
  NSMutableArray<FSTMutationBatchResult *> *toRelease = [NSMutableArray array];
  for (FSTMutationBatchResult *batchResult in self.heldBatchResults) {
    if (![self isRemoteUpToVersion:batchResult.commitVersion]) {
      break;
    }
    [toRelease addObject:batchResult];
  }

  if (toRelease.count == 0) {
    return [FSTDocumentKeySet keySet];
  } else {
    [self.heldBatchResults removeObjectsInRange:NSMakeRange(0, toRelease.count)];
    return [self releaseBatchResults:toRelease group:group remoteDocuments:remoteDocuments];
  }
}

- (BOOL)isRemoteUpToVersion:(FSTSnapshotVersion *)version {
  // If there are no watch targets, then we won't get remote snapshots, and are always "up-to-date."
  return [version compare:self.queryCache.lastRemoteSnapshotVersion] != NSOrderedDescending ||
         self.targetIDs.count == 0;
}

- (BOOL)shouldHoldBatchResultWithVersion:(FSTSnapshotVersion *)version {
  // Check if watcher isn't up to date or prior results are already held.
  return ![self isRemoteUpToVersion:version] || self.heldBatchResults.count > 0;
}

- (FSTDocumentKeySet *)releaseBatchResults:(NSArray<FSTMutationBatchResult *> *)batchResults
                                     group:(FSTWriteGroup *)group
                           remoteDocuments:(FSTRemoteDocumentChangeBuffer *)remoteDocuments {
  NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];
  for (FSTMutationBatchResult *batchResult in batchResults) {
    [self applyBatchResult:batchResult toRemoteDocuments:remoteDocuments];
    [batches addObject:batchResult.batch];
  }

  return [self removeMutationBatches:batches group:group];
}

- (FSTDocumentKeySet *)removeMutationBatch:(FSTMutationBatch *)batch group:(FSTWriteGroup *)group {
  return [self removeMutationBatches:@[ batch ] group:group];
}

/** Removes all the mutation batches named in the given array. */
- (FSTDocumentKeySet *)removeMutationBatches:(NSArray<FSTMutationBatch *> *)batches
                                       group:(FSTWriteGroup *)group {
  // TODO(klimt): Could this be an NSMutableDictionary?
  __block FSTDocumentKeySet *affectedDocs = [FSTDocumentKeySet keySet];

  for (FSTMutationBatch *batch in batches) {
    for (FSTMutation *mutation in batch.mutations) {
      FSTDocumentKey *key = mutation.key;
      affectedDocs = [affectedDocs setByAddingObject:key];
    }
  }

  [self.mutationQueue removeMutationBatches:batches group:group];

  return affectedDocs;
}

- (void)applyBatchResult:(FSTMutationBatchResult *)batchResult
       toRemoteDocuments:(FSTRemoteDocumentChangeBuffer *)remoteDocuments {
  FSTMutationBatch *batch = batchResult.batch;
  FSTDocumentKeySet *docKeys = batch.keys;
  [docKeys enumerateObjectsUsingBlock:^(FSTDocumentKey *docKey, BOOL *stop) {
    FSTMaybeDocument *_Nullable remoteDoc = [remoteDocuments entryForKey:docKey];
    FSTMaybeDocument *_Nullable doc = remoteDoc;
    FSTSnapshotVersion *ackVersion = batchResult.docVersions[docKey];
    FSTAssert(ackVersion, @"docVersions should contain every doc in the write.");
    if (!doc || [doc.version compare:ackVersion] == NSOrderedAscending) {
      doc = [batch applyTo:doc documentKey:docKey mutationBatchResult:batchResult];
      if (!doc) {
        FSTAssert(!remoteDoc, @"Mutation batch %@ applied to document %@ resulted in nil.", batch,
                  remoteDoc);
      } else {
        [remoteDocuments addEntry:doc];
      }
    }
  }];
}

@end

NS_ASSUME_NONNULL_END
