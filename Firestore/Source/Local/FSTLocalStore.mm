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

#include <set>

#import "FIRTimestamp.h"
#import "Firestore/Source/Core/FSTListenSequence.h"
#import "Firestore/Source/Core/FSTQuery.h"
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
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTLogger.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

using firebase::firestore::auth::User;
using firebase::firestore::core::TargetIdGenerator;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentVersionMap;

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
                        initialUser:(const User &)initialUser {
  if (self = [super init]) {
    _persistence = persistence;
    _mutationQueue = [persistence mutationQueueForUser:initialUser];
    _remoteDocumentCache = [persistence remoteDocumentCache];
    _queryCache = [persistence queryCache];
    _localDocuments = [FSTLocalDocumentsView viewWithRemoteDocumentCache:_remoteDocumentCache
                                                           mutationQueue:_mutationQueue];
    _localViewReferences = [[FSTReferenceSet alloc] init];
    [_persistence.referenceDelegate addInMemoryPins:_localViewReferences];

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
  self.persistence.run("Start MutationQueue", [&]() {
    [self.mutationQueue start];

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
        [self.mutationQueue removeMutationBatches:batches];
      }
    }
  });
}

- (void)startQueryCache {
  [self.queryCache start];

  FSTTargetID targetID = [self.queryCache highestTargetID];
  _targetIDGenerator = TargetIdGenerator::LocalStoreTargetIdGenerator(targetID);
  FSTListenSequenceNumber sequenceNumber = [self.queryCache highestListenSequenceNumber];
  self.listenSequence = [[FSTListenSequence alloc] initStartingAfter:sequenceNumber];
}

- (FSTMaybeDocumentDictionary *)userDidChange:(const User &)user {
  // Swap out the mutation queue, grabbing the pending mutation batches before and after.
  NSArray<FSTMutationBatch *> *oldBatches = self.persistence.run(
      "OldBatches",
      [&]() -> NSArray<FSTMutationBatch *> * { return [self.mutationQueue allMutationBatches]; });

  [self.garbageCollector removeGarbageSource:self.mutationQueue];

  self.mutationQueue = [self.persistence mutationQueueForUser:user];
  [self.garbageCollector addGarbageSource:self.mutationQueue];

  [self startMutationQueue];

  return self.persistence.run("NewBatches", [&]() -> FSTMaybeDocumentDictionary * {
    NSArray<FSTMutationBatch *> *newBatches = [self.mutationQueue allMutationBatches];

    // Recreate our LocalDocumentsView using the new MutationQueue.
    self.localDocuments =
        [FSTLocalDocumentsView viewWithRemoteDocumentCache:self.remoteDocumentCache
                                             mutationQueue:self.mutationQueue];

    // Union the old/new changed keys.
    DocumentKeySet changedKeys;
    for (NSArray<FSTMutationBatch *> *batches in @[ oldBatches, newBatches ]) {
      for (FSTMutationBatch *batch in batches) {
        for (FSTMutation *mutation in batch.mutations) {
          changedKeys = changedKeys.insert(mutation.key);
        }
      }
    }

    // Return the set of all (potentially) changed documents as the result of the user change.
    return [self.localDocuments documentsForKeys:changedKeys];
  });
}

- (FSTLocalWriteResult *)locallyWriteMutations:(NSArray<FSTMutation *> *)mutations {
  return self.persistence.run("Locally write mutations", [&]() -> FSTLocalWriteResult * {
    FIRTimestamp *localWriteTime = [FIRTimestamp timestamp];
    FSTMutationBatch *batch =
        [self.mutationQueue addMutationBatchWithWriteTime:localWriteTime mutations:mutations];
    DocumentKeySet keys = [batch keys];
    FSTMaybeDocumentDictionary *changedDocuments = [self.localDocuments documentsForKeys:keys];
    return [FSTLocalWriteResult resultForBatchID:batch.batchID changes:changedDocuments];
  });
}

- (FSTMaybeDocumentDictionary *)acknowledgeBatchWithResult:(FSTMutationBatchResult *)batchResult {
  return self.persistence.run("Acknowledge batch", [&]() -> FSTMaybeDocumentDictionary * {
    id<FSTMutationQueue> mutationQueue = self.mutationQueue;

    [mutationQueue acknowledgeBatch:batchResult.batch streamToken:batchResult.streamToken];

    DocumentKeySet affected;
    if ([self shouldHoldBatchResultWithVersion:batchResult.commitVersion]) {
      [self.heldBatchResults addObject:batchResult];
    } else {
      affected = [self releaseBatchResults:@[ batchResult ]];
    }

    [self.mutationQueue performConsistencyCheck];

    return [self.localDocuments documentsForKeys:affected];
  });
}

- (FSTMaybeDocumentDictionary *)rejectBatchID:(FSTBatchID)batchID {
  return self.persistence.run("Reject batch", [&]() -> FSTMaybeDocumentDictionary * {
    FSTMutationBatch *toReject = [self.mutationQueue lookupMutationBatch:batchID];
    FSTAssert(toReject, @"Attempt to reject nonexistent batch!");

    FSTBatchID lastAcked = [self.mutationQueue highestAcknowledgedBatchID];
    FSTAssert(batchID > lastAcked, @"Acknowledged batches can't be rejected.");

    DocumentKeySet affected = [self removeMutationBatch:toReject];

    [self.mutationQueue performConsistencyCheck];

    return [self.localDocuments documentsForKeys:affected];
  });
}

- (nullable NSData *)lastStreamToken {
  return [self.mutationQueue lastStreamToken];
}

- (void)setLastStreamToken:(nullable NSData *)streamToken {
  self.persistence.run("Set stream token",
                       [&]() { [self.mutationQueue setLastStreamToken:streamToken]; });
}

- (const SnapshotVersion &)lastRemoteSnapshotVersion {
  return [self.queryCache lastRemoteSnapshotVersion];
}

- (FSTMaybeDocumentDictionary *)applyRemoteEvent:(FSTRemoteEvent *)remoteEvent {
  return self.persistence.run("Apply remote event", [&]() -> FSTMaybeDocumentDictionary * {
    // TODO(gsoltis): move the sequence number into the reference delegate.
    FSTListenSequenceNumber sequenceNumber = [self.listenSequence next];
    id<FSTQueryCache> queryCache = self.queryCache;

    [remoteEvent.targetChanges enumerateKeysAndObjectsUsingBlock:^(
                                   NSNumber *targetIDNumber, FSTTargetChange *change, BOOL *stop) {
      FSTTargetID targetID = targetIDNumber.intValue;

      // Do not ref/unref unassigned targetIDs - it may lead to leaks.
      FSTQueryData *queryData = self.targetIDs[targetIDNumber];
      if (!queryData) {
        return;
      }

      // Update the resume token if the change includes one. Don't clear any preexisting value.
      // Bump the sequence number as well, so that documents being removed now are ordered later
      // than documents that were previously removed from this target.
      NSData *resumeToken = change.resumeToken;
      if (resumeToken.length > 0) {
        queryData = [queryData queryDataByReplacingSnapshotVersion:change.snapshotVersion
                                                       resumeToken:resumeToken
                                                    sequenceNumber:sequenceNumber];
        self.targetIDs[targetIDNumber] = queryData;
        [self.queryCache updateQueryData:queryData];
      }

      FSTTargetMapping *mapping = change.mapping;
      if (mapping) {
        // First make sure that all references are deleted.
        if ([mapping isKindOfClass:[FSTResetMapping class]]) {
          FSTResetMapping *reset = (FSTResetMapping *)mapping;
          [queryCache removeMatchingKeysForTargetID:targetID];
          [queryCache addMatchingKeys:reset.documents forTargetID:targetID];

        } else if ([mapping isKindOfClass:[FSTUpdateMapping class]]) {
          FSTUpdateMapping *update = (FSTUpdateMapping *)mapping;
          [queryCache removeMatchingKeys:update.removedDocuments forTargetID:targetID];
          [queryCache addMatchingKeys:update.addedDocuments forTargetID:targetID];

        } else {
          FSTFail(@"Unknown mapping type: %@", mapping);
        }
      }
    }];

    // TODO(klimt): This could probably be an NSMutableDictionary.
    DocumentKeySet changedDocKeys;
    const DocumentKeySet &limboDocuments = remoteEvent.limboDocumentChanges;
    for (const auto &kv : remoteEvent.documentUpdates) {
      const DocumentKey &key = kv.first;
      FSTMaybeDocument *doc = kv.second;
      changedDocKeys = changedDocKeys.insert(key);
      FSTMaybeDocument *existingDoc = [self.remoteDocumentCache entryForKey:key];
      // Make sure we don't apply an old document version to the remote cache, though we
      // make an exception for SnapshotVersion::None() which can happen for manufactured
      // events (e.g. in the case of a limbo document resolution failing).
      if (!existingDoc || SnapshotVersion{doc.version} == SnapshotVersion::None() ||
          SnapshotVersion{doc.version} >= SnapshotVersion{existingDoc.version}) {
        [self.remoteDocumentCache addEntry:doc];
      } else {
        FSTLog(
            @"FSTLocalStore Ignoring outdated watch update for %s. "
             "Current version: %s  Watch version: %s",
            key.ToString().c_str(), existingDoc.version.timestamp().ToString().c_str(),
            doc.version.timestamp().ToString().c_str());
      }

      // The document might be garbage because it was unreferenced by everything.
      // Make sure to mark it as garbage if it is...
      [self.garbageCollector addPotentialGarbageKey:key];
      if (limboDocuments.contains(key)) {
        [self.persistence.referenceDelegate limboDocumentUpdated:key];
      }
    }

    // HACK: The only reason we allow omitting snapshot version is so we can synthesize remote
    // events when we get permission denied errors while trying to resolve the state of a locally
    // cached document that is in limbo.
    const SnapshotVersion &lastRemoteVersion = [self.queryCache lastRemoteSnapshotVersion];
    const SnapshotVersion &remoteVersion = remoteEvent.snapshotVersion;
    if (remoteVersion != SnapshotVersion::None()) {
      FSTAssert(remoteVersion >= lastRemoteVersion,
                @"Watch stream reverted to previous snapshot?? (%s < %s)",
                remoteVersion.timestamp().ToString().c_str(),
                lastRemoteVersion.timestamp().ToString().c_str());
      [self.queryCache setLastRemoteSnapshotVersion:remoteVersion];
    }

    DocumentKeySet releasedWriteKeys = [self releaseHeldBatchResults];

    // Union the two key sets.
    DocumentKeySet keysToRecalc = changedDocKeys;
    for (const DocumentKey &key : releasedWriteKeys) {
      keysToRecalc = keysToRecalc.insert(key);
    }

    return [self.localDocuments documentsForKeys:keysToRecalc];
  });
}

- (void)notifyLocalViewChanges:(NSArray<FSTLocalViewChanges *> *)viewChanges {
  self.persistence.run("NotifyLocalViewChanges", [&]() {
    FSTReferenceSet *localViewReferences = self.localViewReferences;
    for (FSTLocalViewChanges *view in viewChanges) {
      FSTQueryData *queryData = [self.queryCache queryDataForQuery:view.query];
      FSTAssert(queryData, @"Local view changes contain unallocated query.");
      FSTTargetID targetID = queryData.targetID;
      for (const DocumentKey &key : view.removedKeys) {
        [self->_persistence.referenceDelegate removeReference:key target:targetID];
      }
      [localViewReferences addReferencesToKeys:view.addedKeys forID:targetID];
      [localViewReferences removeReferencesToKeys:view.removedKeys forID:targetID];
    }
  });
}

- (nullable FSTMutationBatch *)nextMutationBatchAfterBatchID:(FSTBatchID)batchID {
  FSTMutationBatch *result =
      self.persistence.run("NextMutationBatchAfterBatchID", [&]() -> FSTMutationBatch * {
        return [self.mutationQueue nextMutationBatchAfterBatchID:batchID];
      });
  return result;
}

- (nullable FSTMaybeDocument *)readDocument:(const DocumentKey &)key {
  return self.persistence.run("ReadDocument", [&]() -> FSTMaybeDocument *_Nullable {
    return [self.localDocuments documentForKey:key];
  });
}

- (FSTQueryData *)allocateQuery:(FSTQuery *)query {
  FSTQueryData *queryData = self.persistence.run("Allocate query", [&]() -> FSTQueryData * {
    FSTQueryData *cached = [self.queryCache queryDataForQuery:query];
    // TODO(mcg): freshen last accessed date if cached exists?
    if (!cached) {
      cached = [[FSTQueryData alloc] initWithQuery:query
                                          targetID:_targetIDGenerator.NextId()
                              listenSequenceNumber:[self.listenSequence next]
                                           purpose:FSTQueryPurposeListen];
      [self.queryCache addQueryData:cached];
    }
    return cached;
  });
  // Sanity check to ensure that even when resuming a query it's not currently active.
  FSTBoxedTargetID *boxedTargetID = @(queryData.targetID);
  FSTAssert(!self.targetIDs[boxedTargetID], @"Tried to allocate an already allocated query: %@",
            query);
  self.targetIDs[boxedTargetID] = queryData;
  return queryData;
}

- (void)releaseQuery:(FSTQuery *)query {
  self.persistence.run("Release query", [&]() {
    FSTQueryData *queryData = [self.queryCache queryDataForQuery:query];
    FSTAssert(queryData, @"Tried to release nonexistent query: %@", query);

    [self.localViewReferences removeReferencesForID:queryData.targetID];
    if (self.garbageCollector.isEager) {
      [self.queryCache removeQueryData:queryData];
    }
    [self.persistence.referenceDelegate removeTarget:queryData];
    [self.targetIDs removeObjectForKey:@(queryData.targetID)];

    // If this was the last watch target, then we won't get any more watch snapshots, so we should
    // release any held batch results.
    if ([self.targetIDs count] == 0) {
      [self releaseHeldBatchResults];
    }
  });
}

- (FSTDocumentDictionary *)executeQuery:(FSTQuery *)query {
  return self.persistence.run("ExecuteQuery", [&]() -> FSTDocumentDictionary * {
    return [self.localDocuments documentsMatchingQuery:query];
  });
}

- (DocumentKeySet)remoteDocumentKeysForTarget:(FSTTargetID)targetID {
  return self.persistence.run("RemoteDocumentKeysForTarget", [&]() -> DocumentKeySet {
    return [self.queryCache matchingKeysForTargetID:targetID];
  });
}

- (void)collectGarbage {
  self.persistence.run("Garbage Collection", [&]() {
    // Call collectGarbage regardless of whether isGCEnabled so the referenceSet doesn't continue to
    // accumulate the garbage keys.
    std::set<DocumentKey> garbage = [self.garbageCollector collectGarbage];
    if (garbage.size() > 0) {
      for (const DocumentKey &key : garbage) {
        [self.remoteDocumentCache removeEntryForKey:key];
      }
    }
  });
}

/**
 * Releases all the held mutation batches up to the current remote version received, and
 * applies their mutations to the docs in the remote documents cache.
 *
 * @return the set of keys of docs that were modified by those writes.
 */
- (DocumentKeySet)releaseHeldBatchResults {
  NSMutableArray<FSTMutationBatchResult *> *toRelease = [NSMutableArray array];
  for (FSTMutationBatchResult *batchResult in self.heldBatchResults) {
    if (![self isRemoteUpToVersion:batchResult.commitVersion]) {
      break;
    }
    [toRelease addObject:batchResult];
  }

  if (toRelease.count == 0) {
    return DocumentKeySet{};
  } else {
    [self.heldBatchResults removeObjectsInRange:NSMakeRange(0, toRelease.count)];
    return [self releaseBatchResults:toRelease];
  }
}

- (BOOL)isRemoteUpToVersion:(const SnapshotVersion &)version {
  // If there are no watch targets, then we won't get remote snapshots, and are always "up-to-date."
  return version <= self.queryCache.lastRemoteSnapshotVersion || self.targetIDs.count == 0;
}

- (BOOL)shouldHoldBatchResultWithVersion:(const SnapshotVersion &)version {
  // Check if watcher isn't up to date or prior results are already held.
  return ![self isRemoteUpToVersion:version] || self.heldBatchResults.count > 0;
}

- (DocumentKeySet)releaseBatchResults:(NSArray<FSTMutationBatchResult *> *)batchResults {
  NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];
  for (FSTMutationBatchResult *batchResult in batchResults) {
    [self applyBatchResult:batchResult];
    [batches addObject:batchResult.batch];
  }

  return [self removeMutationBatches:batches];
}

- (DocumentKeySet)removeMutationBatch:(FSTMutationBatch *)batch {
  return [self removeMutationBatches:@[ batch ]];
}

/** Removes all the mutation batches named in the given array. */
- (DocumentKeySet)removeMutationBatches:(NSArray<FSTMutationBatch *> *)batches {
  DocumentKeySet affectedDocs;
  for (FSTMutationBatch *batch in batches) {
    for (FSTMutation *mutation in batch.mutations) {
      const DocumentKey &key = mutation.key;
      affectedDocs = affectedDocs.insert(key);
    }
  }

  [self.mutationQueue removeMutationBatches:batches];
  return affectedDocs;
}

- (void)applyBatchResult:(FSTMutationBatchResult *)batchResult {
  FSTMutationBatch *batch = batchResult.batch;
  DocumentKeySet docKeys = batch.keys;
  const DocumentVersionMap &versions = batchResult.docVersions;
  for (const DocumentKey &docKey : docKeys) {
    FSTMaybeDocument *_Nullable remoteDoc = [self.remoteDocumentCache entryForKey:docKey];
    FSTMaybeDocument *_Nullable doc = remoteDoc;

    auto ackVersionIter = versions.find(docKey);
    FSTAssert(ackVersionIter != versions.end(),
              @"docVersions should contain every doc in the write.");
    const SnapshotVersion &ackVersion = ackVersionIter->second;
    if (!doc || doc.version < ackVersion) {
      doc = [batch applyTo:doc documentKey:docKey mutationBatchResult:batchResult];
      if (!doc) {
        FSTAssert(!remoteDoc, @"Mutation batch %@ applied to document %@ resulted in nil.", batch,
                  remoteDoc);
      } else {
        [self.remoteDocumentCache addEntry:doc];
      }
    }
  }
}

@end

NS_ASSUME_NONNULL_END
