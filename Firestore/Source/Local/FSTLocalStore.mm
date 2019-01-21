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
#include <utility>

#import "FIRTimestamp.h"
#import "Firestore/Source/Core/FSTListenSequence.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Source/Local/FSTLocalDocumentsView.h"
#import "Firestore/Source/Local/FSTLocalViewChanges.h"
#import "Firestore/Source/Local/FSTLocalWriteResult.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"
#include "Firestore/core/src/firebase/firestore/immutable/sorted_set.h"
#include "Firestore/core/src/firebase/firestore/local/query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

using firebase::firestore::auth::User;
using firebase::firestore::core::TargetIdGenerator;
using firebase::firestore::local::LruResults;
using firebase::firestore::local::QueryCache;
using firebase::firestore::local::ReferenceSet;
using firebase::firestore::local::RemoteDocumentCache;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::DocumentVersionMap;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

/**
 * The maximum time to leave a resume token buffered without writing it out. This value is
 * arbitrary: it's long enough to avoid several writes (possibly indefinitely if updates come more
 * frequently than this) but short enough that restarting after crashing will still have a pretty
 * recent resume token.
 */
static const int64_t kResumeTokenMaxAgeSeconds = 5 * 60;  // 5 minutes

@interface FSTLocalStore ()

/** Manages our in-memory or durable persistence. */
@property(nonatomic, strong, readonly) id<FSTPersistence> persistence;

/** The set of all mutations that have been sent but not yet been applied to the backend. */
@property(nonatomic, strong) id<FSTMutationQueue> mutationQueue;

/** The "local" view of all documents (layering mutationQueue on top of remoteDocumentCache). */
@property(nonatomic, strong) FSTLocalDocumentsView *localDocuments;

/** Maps a query to the data about that query. */
@property(nonatomic) QueryCache *queryCache;

/** Maps a targetID to data about its query. */
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, FSTQueryData *> *targetIDs;

@end

@implementation FSTLocalStore {
  /** Used to generate targetIDs for queries tracked locally. */
  TargetIdGenerator _targetIDGenerator;
  /** The set of all cached remote documents. */
  RemoteDocumentCache *_remoteDocumentCache;
  QueryCache *_queryCache;

  /** The set of document references maintained by any local views. */
  ReferenceSet _localViewReferences;
}

- (instancetype)initWithPersistence:(id<FSTPersistence>)persistence
                        initialUser:(const User &)initialUser {
  if (self = [super init]) {
    _persistence = persistence;
    _mutationQueue = [persistence mutationQueueForUser:initialUser];
    _remoteDocumentCache = [persistence remoteDocumentCache];
    _queryCache = [persistence queryCache];
    _localDocuments = [FSTLocalDocumentsView viewWithRemoteDocumentCache:_remoteDocumentCache
                                                           mutationQueue:_mutationQueue];
    [_persistence.referenceDelegate addInMemoryPins:&_localViewReferences];

    _targetIDs = [NSMutableDictionary dictionary];

    _targetIDGenerator = TargetIdGenerator::QueryCacheTargetIdGenerator(0);
  }
  return self;
}

- (void)start {
  [self startMutationQueue];
  TargetId targetID = _queryCache->highest_target_id();
  _targetIDGenerator = TargetIdGenerator::QueryCacheTargetIdGenerator(targetID);
}

- (void)startMutationQueue {
  self.persistence.run("Start MutationQueue", [&]() { [self.mutationQueue start]; });
}

- (MaybeDocumentMap)userDidChange:(const User &)user {
  // Swap out the mutation queue, grabbing the pending mutation batches before and after.
  NSArray<FSTMutationBatch *> *oldBatches = self.persistence.run(
      "OldBatches",
      [&]() -> NSArray<FSTMutationBatch *> * { return [self.mutationQueue allMutationBatches]; });

  self.mutationQueue = [self.persistence mutationQueueForUser:user];

  [self startMutationQueue];

  return self.persistence.run("NewBatches", [&]() -> MaybeDocumentMap {
    NSArray<FSTMutationBatch *> *newBatches = [self.mutationQueue allMutationBatches];

    // Recreate our LocalDocumentsView using the new MutationQueue.
    self.localDocuments = [FSTLocalDocumentsView viewWithRemoteDocumentCache:_remoteDocumentCache
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
    FSTMutationBatch *batch = [self.mutationQueue addMutationBatchWithWriteTime:localWriteTime
                                                                      mutations:mutations];
    DocumentKeySet keys = [batch keys];
    MaybeDocumentMap changedDocuments = [self.localDocuments documentsForKeys:keys];
    return [FSTLocalWriteResult resultForBatchID:batch.batchID changes:std::move(changedDocuments)];
  });
}

- (MaybeDocumentMap)acknowledgeBatchWithResult:(FSTMutationBatchResult *)batchResult {
  return self.persistence.run("Acknowledge batch", [&]() -> MaybeDocumentMap {
    id<FSTMutationQueue> mutationQueue = self.mutationQueue;

    FSTMutationBatch *batch = batchResult.batch;
    [mutationQueue acknowledgeBatch:batch streamToken:batchResult.streamToken];
    [self applyBatchResult:batchResult];
    [self.mutationQueue performConsistencyCheck];

    return [self.localDocuments documentsForKeys:batch.keys];
  });
}

- (MaybeDocumentMap)rejectBatchID:(BatchId)batchID {
  return self.persistence.run("Reject batch", [&]() -> MaybeDocumentMap {
    FSTMutationBatch *toReject = [self.mutationQueue lookupMutationBatch:batchID];
    HARD_ASSERT(toReject, "Attempt to reject nonexistent batch!");

    [self.mutationQueue removeMutationBatch:toReject];
    [self.mutationQueue performConsistencyCheck];

    return [self.localDocuments documentsForKeys:toReject.keys];
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
  return self.queryCache->GetLastRemoteSnapshotVersion();
}

- (MaybeDocumentMap)applyRemoteEvent:(FSTRemoteEvent *)remoteEvent {
  return self.persistence.run("Apply remote event", [&]() -> MaybeDocumentMap {
    // TODO(gsoltis): move the sequence number into the reference delegate.
    ListenSequenceNumber sequenceNumber = self.persistence.currentSequenceNumber;

    DocumentKeySet authoritativeUpdates;
    for (const auto &entry : remoteEvent.targetChanges) {
      TargetId targetID = entry.first;
      FSTBoxedTargetID *boxedTargetID = @(targetID);
      FSTTargetChange *change = entry.second;

      // Do not ref/unref unassigned targetIDs - it may lead to leaks.
      FSTQueryData *queryData = self.targetIDs[boxedTargetID];
      if (!queryData) {
        continue;
      }

      // When a global snapshot contains updates (either add or modify) we can completely trust
      // these updates as authoritative and blindly apply them to our cache (as a defensive measure
      // to promote self-healing in the unfortunate case that our cache is ever somehow corrupted /
      // out-of-sync).
      //
      // If the document is only updated while removing it from a target then watch isn't obligated
      // to send the absolute latest version: it can send the first version that caused the document
      // not to match.
      for (const DocumentKey &key : change.addedDocuments) {
        authoritativeUpdates = authoritativeUpdates.insert(key);
      }
      for (const DocumentKey &key : change.modifiedDocuments) {
        authoritativeUpdates = authoritativeUpdates.insert(key);
      }

      _queryCache->RemoveMatchingKeys(change.removedDocuments, targetID);
      _queryCache->AddMatchingKeys(change.addedDocuments, targetID);

      // Update the resume token if the change includes one. Don't clear any preexisting value.
      // Bump the sequence number as well, so that documents being removed now are ordered later
      // than documents that were previously removed from this target.
      NSData *resumeToken = change.resumeToken;
      if (resumeToken.length > 0) {
        FSTQueryData *oldQueryData = queryData;
        queryData = [queryData queryDataByReplacingSnapshotVersion:remoteEvent.snapshotVersion
                                                       resumeToken:resumeToken
                                                    sequenceNumber:sequenceNumber];
        self.targetIDs[boxedTargetID] = queryData;

        if ([self shouldPersistQueryData:queryData oldQueryData:oldQueryData change:change]) {
          _queryCache->UpdateTarget(queryData);
        }
      }
    }

    MaybeDocumentMap changedDocs;
    const DocumentKeySet &limboDocuments = remoteEvent.limboDocumentChanges;
    DocumentKeySet updatedKeys;
    for (const auto &kv : remoteEvent.documentUpdates) {
      updatedKeys = updatedKeys.insert(kv.first);
    }
    // Each loop iteration only affects its "own" doc, so it's safe to get all the remote
    // documents in advance in a single call.
    MaybeDocumentMap existingDocs = _remoteDocumentCache->GetAll(updatedKeys);

    for (const auto &kv : remoteEvent.documentUpdates) {
      const DocumentKey &key = kv.first;
      FSTMaybeDocument *doc = kv.second;
      FSTMaybeDocument *existingDoc = nil;
      auto foundExisting = existingDocs.find(key);
      if (foundExisting != existingDocs.end()) {
        existingDoc = foundExisting->second;
      }

      // If a document update isn't authoritative, make sure we don't apply an old document version
      // to the remote cache. We make an exception for SnapshotVersion.MIN which can happen for
      // manufactured events (e.g. in the case of a limbo document resolution failing).
      if (!existingDoc || doc.version == SnapshotVersion::None() ||
          (authoritativeUpdates.contains(doc.key) && !existingDoc.hasPendingWrites) ||
          doc.version >= existingDoc.version) {
        _remoteDocumentCache->Add(doc);
        changedDocs = changedDocs.insert(key, doc);
      } else {
        LOG_DEBUG("FSTLocalStore Ignoring outdated watch update for %s. "
                  "Current version: %s  Watch version: %s",
                  key.ToString(), existingDoc.version.timestamp().ToString(),
                  doc.version.timestamp().ToString());
      }

      // If this was a limbo resolution, make sure we mark when it was accessed.
      if (limboDocuments.contains(key)) {
        [self.persistence.referenceDelegate limboDocumentUpdated:key];
      }
    }

    // HACK: The only reason we allow omitting snapshot version is so we can synthesize remote
    // events when we get permission denied errors while trying to resolve the state of a locally
    // cached document that is in limbo.
    const SnapshotVersion &lastRemoteVersion = _queryCache->GetLastRemoteSnapshotVersion();
    const SnapshotVersion &remoteVersion = remoteEvent.snapshotVersion;
    if (remoteVersion != SnapshotVersion::None()) {
      HARD_ASSERT(remoteVersion >= lastRemoteVersion,
                  "Watch stream reverted to previous snapshot?? (%s < %s)",
                  remoteVersion.timestamp().ToString(), lastRemoteVersion.timestamp().ToString());
      _queryCache->SetLastRemoteSnapshotVersion(remoteVersion);
    }

    return [self.localDocuments localViewsForDocuments:changedDocs];
  });
}

/**
 * Returns YES if the newQueryData should be persisted during an update of an active target.
 * QueryData should always be persisted when a target is being released and should not call this
 * function.
 *
 * While the target is active, QueryData updates can be omitted when nothing about the target has
 * changed except metadata like the resume token or snapshot version. Occasionally it's worth the
 * extra write to prevent these values from getting too stale after a crash, but this doesn't have
 * to be too frequent.
 */
- (BOOL)shouldPersistQueryData:(FSTQueryData *)newQueryData
                  oldQueryData:(FSTQueryData *)oldQueryData
                        change:(FSTTargetChange *)change {
  // Avoid clearing any existing value
  if (newQueryData.resumeToken.length == 0) return NO;

  // Any resume token is interesting if there isn't one already.
  if (oldQueryData.resumeToken.length == 0) return YES;

  // Don't allow resume token changes to be buffered indefinitely. This allows us to be reasonably
  // up-to-date after a crash and avoids needing to loop over all active queries on shutdown.
  // Especially in the browser we may not get time to do anything interesting while the current
  // tab is closing.
  int64_t newSeconds = newQueryData.snapshotVersion.timestamp().seconds();
  int64_t oldSeconds = oldQueryData.snapshotVersion.timestamp().seconds();
  int64_t timeDelta = newSeconds - oldSeconds;
  if (timeDelta >= kResumeTokenMaxAgeSeconds) return YES;

  // Otherwise if the only thing that has changed about a target is its resume token then it's not
  // worth persisting. Note that the RemoteStore keeps an in-memory view of the currently active
  // targets which includes the current resume token, so stream failure or user changes will still
  // use an up-to-date resume token regardless of what we do here.
  size_t changes = change.addedDocuments.size() + change.modifiedDocuments.size() +
                   change.removedDocuments.size();
  return changes > 0;
}

- (void)notifyLocalViewChanges:(NSArray<FSTLocalViewChanges *> *)viewChanges {
  self.persistence.run("NotifyLocalViewChanges", [&]() {
    for (FSTLocalViewChanges *viewChange in viewChanges) {
      for (const DocumentKey &key : viewChange.removedKeys) {
        [self->_persistence.referenceDelegate removeReference:key];
      }
      _localViewReferences.AddReferences(viewChange.addedKeys, viewChange.targetID);
      _localViewReferences.AddReferences(viewChange.removedKeys, viewChange.targetID);
    }
  });
}

- (nullable FSTMutationBatch *)nextMutationBatchAfterBatchID:(BatchId)batchID {
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
    FSTQueryData *cached = _queryCache->GetTarget(query);
    // TODO(mcg): freshen last accessed date if cached exists?
    if (!cached) {
      cached = [[FSTQueryData alloc] initWithQuery:query
                                          targetID:_targetIDGenerator.NextId()
                              listenSequenceNumber:self.persistence.currentSequenceNumber
                                           purpose:FSTQueryPurposeListen];
      _queryCache->AddTarget(cached);
    }
    return cached;
  });
  // Sanity check to ensure that even when resuming a query it's not currently active.
  FSTBoxedTargetID *boxedTargetID = @(queryData.targetID);
  HARD_ASSERT(!self.targetIDs[boxedTargetID], "Tried to allocate an already allocated query: %s",
              query);
  self.targetIDs[boxedTargetID] = queryData;
  return queryData;
}

- (void)releaseQuery:(FSTQuery *)query {
  self.persistence.run("Release query", [&]() {
    FSTQueryData *queryData = _queryCache->GetTarget(query);
    HARD_ASSERT(queryData, "Tried to release nonexistent query: %s", query);

    TargetId targetID = queryData.targetID;
    FSTBoxedTargetID *boxedTargetID = @(targetID);

    FSTQueryData *cachedQueryData = self.targetIDs[boxedTargetID];
    if (cachedQueryData.snapshotVersion > queryData.snapshotVersion) {
      // If we've been avoiding persisting the resumeToken (see shouldPersistQueryData for
      // conditions and rationale) we need to persist the token now because there will no
      // longer be an in-memory version to fall back on.
      queryData = cachedQueryData;
      _queryCache->UpdateTarget(queryData);
    }

    // References for documents sent via Watch are automatically removed when we delete a
    // query's target data from the reference delegate. Since this does not remove references
    // for locally mutated documents, we have to remove the target associations for these
    // documents manually.
    DocumentKeySet removed = _localViewReferences.RemoveReferences(targetID);
    for (const DocumentKey &key : removed) {
      [self.persistence.referenceDelegate removeReference:key];
    }
    [self.targetIDs removeObjectForKey:boxedTargetID];
    [self.persistence.referenceDelegate removeTarget:queryData];
  });
}

- (DocumentMap)executeQuery:(FSTQuery *)query {
  return self.persistence.run("ExecuteQuery", [&]() -> DocumentMap {
    return [self.localDocuments documentsMatchingQuery:query];
  });
}

- (DocumentKeySet)remoteDocumentKeysForTarget:(TargetId)targetID {
  return self.persistence.run("RemoteDocumentKeysForTarget", [&]() -> DocumentKeySet {
    return _queryCache->GetMatchingKeys(targetID);
  });
}

- (void)applyBatchResult:(FSTMutationBatchResult *)batchResult {
  FSTMutationBatch *batch = batchResult.batch;
  DocumentKeySet docKeys = batch.keys;
  const DocumentVersionMap &versions = batchResult.docVersions;
  for (const DocumentKey &docKey : docKeys) {
    FSTMaybeDocument *_Nullable remoteDoc = _remoteDocumentCache->Get(docKey);
    FSTMaybeDocument *_Nullable doc = remoteDoc;

    auto ackVersionIter = versions.find(docKey);
    HARD_ASSERT(ackVersionIter != versions.end(),
                "docVersions should contain every doc in the write.");
    const SnapshotVersion &ackVersion = ackVersionIter->second;
    if (!doc || doc.version < ackVersion) {
      doc = [batch applyToRemoteDocument:doc documentKey:docKey mutationBatchResult:batchResult];
      if (!doc) {
        HARD_ASSERT(!remoteDoc, "Mutation batch %s applied to document %s resulted in nil.", batch,
                    remoteDoc);
      } else {
        _remoteDocumentCache->Add(doc);
      }
    }
  }

  [self.mutationQueue removeMutationBatch:batch];
}

- (LruResults)collectGarbage:(FSTLRUGarbageCollector *)garbageCollector {
  return self.persistence.run("Collect garbage", [&]() -> LruResults {
    return [garbageCollector collectWithLiveTargets:_targetIDs];
  });
}

@end

NS_ASSUME_NONNULL_END
