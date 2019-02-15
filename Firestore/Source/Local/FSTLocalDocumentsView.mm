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

#import "Firestore/Source/Local/FSTLocalDocumentsView.h"

#include <string>
#include <vector>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#include "Firestore/core/src/firebase/firestore/local/index_manager.h"
#include "Firestore/core/src/firebase/firestore/local/mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

using firebase::firestore::local::IndexManager;
using firebase::firestore::local::MutationQueue;
using firebase::firestore::local::RemoteDocumentCache;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::util::MakeString;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalDocumentsView ()
- (instancetype)initWithRemoteDocumentCache:(RemoteDocumentCache *)remoteDocumentCache
                              mutationQueue:(MutationQueue *)mutationQueue
                               indexManager:(IndexManager *)indexManager NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTLocalDocumentsView {
  RemoteDocumentCache *_remoteDocumentCache;
  MutationQueue *_mutationQueue;
  IndexManager *_indexManager;
}

+ (instancetype)viewWithRemoteDocumentCache:(RemoteDocumentCache *)remoteDocumentCache
                              mutationQueue:(MutationQueue *)mutationQueue
                               indexManager:(IndexManager *)indexManager {
  return [[FSTLocalDocumentsView alloc] initWithRemoteDocumentCache:remoteDocumentCache
                                                      mutationQueue:mutationQueue
                                                       indexManager:indexManager];
}

- (instancetype)initWithRemoteDocumentCache:(RemoteDocumentCache *)remoteDocumentCache
                              mutationQueue:(MutationQueue *)mutationQueue
                               indexManager:(IndexManager *)indexManager {
  if (self = [super init]) {
    _remoteDocumentCache = remoteDocumentCache;
    _mutationQueue = mutationQueue;
    _indexManager = indexManager;
  }
  return self;
}

- (nullable FSTMaybeDocument *)documentForKey:(const DocumentKey &)key {
  std::vector<FSTMutationBatch *> batches =
      _mutationQueue->AllMutationBatchesAffectingDocumentKey(key);
  return [self documentForKey:key inBatches:batches];
}

// Internal version of documentForKey: which allows reusing `batches`.
- (nullable FSTMaybeDocument *)documentForKey:(const DocumentKey &)key
                                    inBatches:(const std::vector<FSTMutationBatch *> &)batches {
  FSTMaybeDocument *_Nullable document = _remoteDocumentCache->Get(key);
  for (FSTMutationBatch *batch : batches) {
    document = [batch applyToLocalDocument:document documentKey:key];
  }

  return document;
}

// Returns the view of the given `docs` as they would appear after applying all
// mutations in the given `batches`.
- (MaybeDocumentMap)applyLocalMutationsToDocuments:(const MaybeDocumentMap &)docs
                                       fromBatches:
                                           (const std::vector<FSTMutationBatch *> &)batches {
  MaybeDocumentMap results;

  for (const auto &kv : docs) {
    const DocumentKey &key = kv.first;
    FSTMaybeDocument *localView = kv.second;
    for (FSTMutationBatch *batch : batches) {
      localView = [batch applyToLocalDocument:localView documentKey:key];
    }
    results = results.insert(key, localView);
  }
  return results;
}

- (MaybeDocumentMap)documentsForKeys:(const DocumentKeySet &)keys {
  MaybeDocumentMap docs = _remoteDocumentCache->GetAll(keys);
  return [self localViewsForDocuments:docs];
}

/**
 * Similar to `documentsForKeys`, but creates the local view from the given
 * `baseDocs` without retrieving documents from the local store.
 */
- (MaybeDocumentMap)localViewsForDocuments:(const MaybeDocumentMap &)baseDocs {
  MaybeDocumentMap results;

  DocumentKeySet allKeys;
  for (const auto &kv : baseDocs) {
    allKeys = allKeys.insert(kv.first);
  }
  std::vector<FSTMutationBatch *> batches =
      _mutationQueue->AllMutationBatchesAffectingDocumentKeys(allKeys);

  MaybeDocumentMap docs = [self applyLocalMutationsToDocuments:baseDocs fromBatches:batches];

  for (const auto &kv : docs) {
    const DocumentKey &key = kv.first;
    FSTMaybeDocument *maybeDoc = kv.second;

    // TODO(http://b/32275378): Don't conflate missing / deleted.
    if (!maybeDoc) {
      maybeDoc = [FSTDeletedDocument documentWithKey:key
                                             version:SnapshotVersion::None()
                               hasCommittedMutations:NO];
    }
    results = results.insert(key, maybeDoc);
  }

  return results;
}

- (DocumentMap)documentsMatchingQuery:(FSTQuery *)query {
  if ([query isDocumentQuery]) {
    return [self documentsMatchingDocumentQuery:query.path];
  } else if ([query isCollectionGroupQuery]) {
    return [self documentsMatchingCollectionGroupQuery:query];
  } else {
    return [self documentsMatchingCollectionQuery:query];
  }
}

- (DocumentMap)documentsMatchingDocumentQuery:(const ResourcePath &)docPath {
  DocumentMap result;
  // Just do a simple document lookup.
  FSTMaybeDocument *doc = [self documentForKey:DocumentKey{docPath}];
  if ([doc isKindOfClass:[FSTDocument class]]) {
    result = result.insert(doc.key, static_cast<FSTDocument *>(doc));
  }
  return result;
}

- (DocumentMap)documentsMatchingCollectionGroupQuery:(FSTQuery *)query {
  HARD_ASSERT(query.path.empty(),
              "Currently we only support collection group queries at the root.");

  std::string collection_id = MakeString(query.collectionGroup);
  std::vector<ResourcePath> parents = _indexManager->GetCollectionParents(collection_id);
  DocumentMap results;

  // Perform a collection query against each parent that contains the collection_id and
  // aggregate the results.
  for (const ResourcePath &parent : parents) {
    FSTQuery *collectionQuery = [query collectionQueryAtPath:parent.Append(collection_id)];
    DocumentMap collectionResults = [self documentsMatchingCollectionQuery:collectionQuery];
    for (const auto &kv : collectionResults.underlying_map()) {
      const DocumentKey &key = kv.first;
      FSTDocument *doc = static_cast<FSTDocument *>(kv.second);
      results = results.insert(key, doc);
    }
  }
  return results;
}

- (DocumentMap)documentsMatchingCollectionQuery:(FSTQuery *)query {
  DocumentMap results = _remoteDocumentCache->GetMatching(query);
  // Get locally persisted mutation batches.
  std::vector<FSTMutationBatch *> matchingBatches =
      _mutationQueue->AllMutationBatchesAffectingQuery(query);

  for (FSTMutationBatch *batch : matchingBatches) {
    for (FSTMutation *mutation : [batch mutations]) {
      // Only process documents belonging to the collection.
      if (!query.path.IsImmediateParentOf(mutation.key.path())) {
        continue;
      }

      const DocumentKey &key = mutation.key;
      // baseDoc may be nil for the documents that weren't yet written to the backend.
      FSTMaybeDocument *baseDoc = nil;
      auto found = results.underlying_map().find(key);
      if (found != results.underlying_map().end()) {
        baseDoc = found->second;
      }
      FSTMaybeDocument *mutatedDoc = [mutation applyToLocalDocument:baseDoc
                                                       baseDocument:baseDoc
                                                     localWriteTime:batch.localWriteTime];

      if ([mutatedDoc isKindOfClass:[FSTDocument class]]) {
        results = results.insert(key, static_cast<FSTDocument *>(mutatedDoc));
      } else {
        results = results.erase(key);
      }
    }
  }

  // Finally, filter out any documents that don't actually match the query. Note that the extra
  // reference here prevents ARC from deallocating the initial unfiltered results while we're
  // enumerating them.
  DocumentMap unfiltered = results;
  for (const auto &kv : unfiltered.underlying_map()) {
    const DocumentKey &key = kv.first;
    FSTDocument *doc = static_cast<FSTDocument *>(kv.second);
    if (![query matchesDocument:doc]) {
      results = results.erase(key);
    }
  }

  return results;
}

@end

NS_ASSUME_NONNULL_END
