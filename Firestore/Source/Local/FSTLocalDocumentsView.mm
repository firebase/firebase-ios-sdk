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
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::DocumentKeySet;

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
    document = [batch applyTo:document documentKey:key];
  }

  return document;
}

- (FSTMaybeDocumentDictionary *)documentsForKeys:(const DocumentKeySet &)keys {
  FSTMaybeDocumentDictionary *results = [FSTMaybeDocumentDictionary maybeDocumentDictionary];
  NSArray<FSTMutationBatch *> *batches =
      [self.mutationQueue allMutationBatchesAffectingDocumentKeys:keys];
  for (const DocumentKey &key : keys) {
    // TODO(mikelehen): PERF: Consider fetching all remote documents at once rather than one-by-one.
    FSTMaybeDocument *maybeDoc = [self documentForKey:key inBatches:batches];
    // TODO(http://b/32275378): Don't conflate missing / deleted.
    if (!maybeDoc) {
      maybeDoc = [FSTDeletedDocument documentWithKey:key version:SnapshotVersion::None()];
    }
    results = [results dictionaryBySettingObject:maybeDoc forKey:key];
  }

  return results;
}

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query {
  if (DocumentKey::IsDocumentKey(query.path)) {
    return [self documentsMatchingDocumentQuery:query.path];
  } else {
    return [self documentsMatchingCollectionQuery:query];
  }
}

- (FSTDocumentDictionary *)documentsMatchingDocumentQuery:(const ResourcePath &)docPath {
  FSTDocumentDictionary *result = [FSTDocumentDictionary documentDictionary];
  // Just do a simple document lookup.
  FSTMaybeDocument *doc = [self documentForKey:DocumentKey{docPath}];
  if ([doc isKindOfClass:[FSTDocument class]]) {
    result = [result dictionaryBySettingObject:(FSTDocument *)doc forKey:doc.key];
  }
  return result;
}

- (FSTDocumentDictionary *)documentsMatchingCollectionQuery:(FSTQuery *)query {
  __block FSTDocumentDictionary *results = [self.remoteDocumentCache documentsMatchingQuery:query];
  // Get locally persisted mutation batches.
  NSArray<FSTMutationBatch *> *matchingBatches =
      [self.mutationQueue allMutationBatchesAffectingQuery:query];

  for (FSTMutationBatch *batch in matchingBatches) {
    for (FSTMutation *mutation in batch.mutations) {
      // Only process documents belonging to the collection.
      if (!query.path.IsImmediateParentOf(mutation.key.path())) {
        continue;
      }

      FSTDocumentKey *key = static_cast<FSTDocumentKey *>(mutation.key);
      // baseDoc may be nil for the documents that weren't yet written to the backend.
      FSTMaybeDocument *baseDoc = results[key];
      FSTMaybeDocument *mutatedDoc =
          [mutation applyTo:baseDoc baseDocument:baseDoc localWriteTime:batch.localWriteTime];

      if (!mutatedDoc || [mutatedDoc isKindOfClass:[FSTDeletedDocument class]]) {
        results = [results dictionaryByRemovingObjectForKey:key];
      } else if ([mutatedDoc isKindOfClass:[FSTDocument class]]) {
        results = [results dictionaryBySettingObject:(FSTDocument *)mutatedDoc forKey:key];
      } else {
        HARD_FAIL("Unknown document: %s", mutatedDoc);
      }
    }
  }

  // Finally, filter out any documents that don't actually match the query. Note that the extra
  // reference here prevents ARC from deallocating the initial unfiltered results while we're
  // enumerating them.
  FSTDocumentDictionary *unfiltered = results;
  [unfiltered
      enumerateKeysAndObjectsUsingBlock:^(FSTDocumentKey *key, FSTDocument *doc, BOOL *stop) {
        if (![query matchesDocument:doc]) {
          results = [results dictionaryByRemovingObjectForKey:key];
        }
      }];

  return results;
}

@end

NS_ASSUME_NONNULL_END
