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

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalDocumentsView ()
- (instancetype)initWithRemoteDocumentCache:(id<FSTRemoteDocumentCache>)remoteDocumentCache
                              mutationQueue:(id<FSTMutationQueue>)mutationQueue
    NS_DESIGNATED_INITIALIZER;
@property(nonatomic, strong, readonly) id<FSTRemoteDocumentCache> remoteDocumentCache;
@property(nonatomic, strong, readonly) id<FSTMutationQueue> mutationQueue;
@end

@implementation FSTLocalDocumentsView

+ (instancetype)viewWithRemoteDocumentCache:(id<FSTRemoteDocumentCache>)remoteDocumentCache
                              mutationQueue:(id<FSTMutationQueue>)mutationQueue {
  return [[FSTLocalDocumentsView alloc] initWithRemoteDocumentCache:remoteDocumentCache
                                                      mutationQueue:mutationQueue];
}

- (instancetype)initWithRemoteDocumentCache:(id<FSTRemoteDocumentCache>)remoteDocumentCache
                              mutationQueue:(id<FSTMutationQueue>)mutationQueue {
  if (self = [super init]) {
    _remoteDocumentCache = remoteDocumentCache;
    _mutationQueue = mutationQueue;
  }
  return self;
}

- (nullable FSTMaybeDocument *)documentForKey:(const DocumentKey &)key {
  NSArray<FSTMutationBatch *> *batches =
      [self.mutationQueue allMutationBatchesAffectingDocumentKey:key];
  return [self documentForKey:key inBatches:batches];
}

// Internal version of documentForKey: which allows reusing `batches`.
- (nullable FSTMaybeDocument *)documentForKey:(const DocumentKey &)key
                                    inBatches:(NSArray<FSTMutationBatch *> *)batches {
  FSTMaybeDocument *_Nullable document = [self.remoteDocumentCache entryForKey:key];
  for (FSTMutationBatch *batch in batches) {
    document = [batch applyToLocalDocument:document documentKey:key];
  }

  return document;
}

// Returns the view of the given `docs` as they would appear after applying all
// mutations in the given `batches`.
- (MaybeDocumentMap)applyLocalMutationsToDocuments:(const MaybeDocumentMap &)docs
                                       fromBatches:(NSArray<FSTMutationBatch *> *)batches {
  MaybeDocumentMap results;

  for (const auto &kv : docs) {
    const DocumentKey &key = kv.first;
    FSTMaybeDocument *localView = kv.second;
    for (FSTMutationBatch *batch in batches) {
      localView = [batch applyToLocalDocument:localView documentKey:key];
    }
    results = results.insert(key, localView);
  }
  return results;
}

- (MaybeDocumentMap)documentsForKeys:(const DocumentKeySet &)keys {
  MaybeDocumentMap docs = [self.remoteDocumentCache entriesForKeys:keys];
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
  NSArray<FSTMutationBatch *> *batches =
      [self.mutationQueue allMutationBatchesAffectingDocumentKeys:allKeys];

  MaybeDocumentMap docs = [self applyLocalMutationsToDocuments:baseDocs fromBatches: batches];

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

- (MaybeDocumentMap)documentsMatchingQuery:(FSTQuery *)query {
  if (DocumentKey::IsDocumentKey(query.path)) {
    return [self documentsMatchingDocumentQuery:query.path];
  } else {
    return [self documentsMatchingCollectionQuery:query];
  }
}

- (MaybeDocumentMap)documentsMatchingDocumentQuery:(const ResourcePath &)docPath {
  MaybeDocumentMap result;
  // Just do a simple document lookup.
  FSTMaybeDocument *doc = [self documentForKey:DocumentKey{docPath}];
  if ([doc isKindOfClass:[FSTDocument class]]) {
    result = result.insert(doc.key, static_cast<FSTDocument *>(doc));
  }
  return result;
}

- (MaybeDocumentMap)documentsMatchingCollectionQuery:(FSTQuery *)query {
  MaybeDocumentMap results = [self.remoteDocumentCache documentsMatchingQuery:query];
  // Get locally persisted mutation batches.
  NSArray<FSTMutationBatch *> *matchingBatches =
      [self.mutationQueue allMutationBatchesAffectingQuery:query];

  for (FSTMutationBatch *batch in matchingBatches) {
    for (FSTMutation *mutation in batch.mutations) {
      // Only process documents belonging to the collection.
      if (!query.path.IsImmediateParentOf(mutation.key.path())) {
        continue;
      }

      const DocumentKey &key = mutation.key;
      // baseDoc may be nil for the documents that weren't yet written to the backend.
      FSTMaybeDocument *baseDoc = nil;
      auto found = results.find(key);
      if (found != results.end()) {
        baseDoc = found->second;
        }
      FSTMaybeDocument *mutatedDoc = [mutation applyToLocalDocument:baseDoc
                                                       baseDocument:baseDoc
                                                     localWriteTime:batch.localWriteTime];

      if ([mutatedDoc isKindOfClass:[FSTDocument class]]) {
        results = results.insert(key, mutatedDoc);
      } else {
        results = results.erase(key);
      }
    }
  }

  // Finally, filter out any documents that don't actually match the query. Note that the extra
  // reference here prevents ARC from deallocating the initial unfiltered results while we're
  // enumerating them.
  MaybeDocumentMap unfiltered = results;
  for (const auto &kv : unfiltered) {
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
