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
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/model/document_dictionary.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

using firebase::firestore::model::DocumentDictionary;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::MaybeDocumentDictionary;
using firebase::firestore::model::ResourcePath;

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

- (nullable FSTMaybeDocument *)documentForKey:(FSTDocumentKey *)key {
  FSTMaybeDocument *_Nullable remoteDoc = [self.remoteDocumentCache entryForKey:key];
  return [self localDocument:remoteDoc key:key];
}

- (MaybeDocumentDictionary)documentsForKeys:(const DocumentKeySet &)keys {
  MaybeDocumentDictionary results{};
  for (const auto &key : keys) {
    // TODO(mikelehen): PERF: Consider fetching all remote documents at once rather than one-by-one.
    FSTMaybeDocument *maybeDoc = [self documentForKey:key];
    // TODO(http://b/32275378): Don't conflate missing / deleted.
    if (!maybeDoc) {
      maybeDoc = [FSTDeletedDocument documentWithKey:key version:[FSTSnapshotVersion noVersion]];
    }
    results[key] = maybeDoc;
  }
  return results;
}

- (DocumentDictionary)documentsMatchingQuery:(FSTQuery *)query {
  if ([FSTDocumentKey isDocumentKey:query.path]) {
    return [self documentsMatchingDocumentQuery:query.path];
  } else {
    return [self documentsMatchingCollectionQuery:query];
  }
}

- (DocumentDictionary)documentsMatchingDocumentQuery:(const ResourcePath &)docPath {
  DocumentDictionary result{};
  // Just do a simple document lookup.
  FSTMaybeDocument *doc = [self documentForKey:[FSTDocumentKey keyWithPath:docPath]];
  if ([doc isKindOfClass:[FSTDocument class]]) {
    result[doc.key] = (FSTDocument *)doc;
  }
  return result;
}

- (DocumentDictionary)documentsMatchingCollectionQuery:(FSTQuery *)query {
  // Query the remote documents and overlay mutations.
  // TODO(mikelehen): There may be significant overlap between the mutations affecting these
  // remote documents and the allMutationBatchesAffectingQuery mutations. Consider optimizing.
  DocumentDictionary results = [self.remoteDocumentCache documentsMatchingQuery:query];
  results = [self localDocuments:results];

  // Now use the mutation queue to discover any other documents that may match the query after
  // applying mutations.
  DocumentKeySet matchingKeys{};
  NSArray<FSTMutationBatch *> *matchingMutationBatches =
      [self.mutationQueue allMutationBatchesAffectingQuery:query];
  for (FSTMutationBatch *batch in matchingMutationBatches) {
    for (FSTMutation *mutation in batch.mutations) {
      // TODO(mikelehen): PERF: Check if this mutation actually affects the query to reduce work.

      // If the key is already in the results, we can skip it.
      if (results.find(mutation.key) == results.end()) {
        matchingKeys.insert(mutation.key);
      }
    }
  }

  // Now add in results for the matchingKeys.
  for (const auto &key : matchingKeys) {
    FSTMaybeDocument *doc = [self documentForKey:key];
    if ([doc isKindOfClass:[FSTDocument class]]) {
      results[key] = (FSTDocument *)doc;
    }
  }

  // Finally, filter out any documents that don't actually match the query. Note that the extra
  // reference here prevents ARC from deallocating the initial unfiltered results while we're
  // enumerating them.
  for (auto iter = results.begin(); iter != results.end();) {
    if (![query matchesDocument:iter->second]) {
      iter = results.erase(iter);
    } else {
      ++iter;
    }
  };

  return results;
}

/**
 * Takes a remote document and applies local mutations to generate the local view of the
 * document.
 *
 * @param document The base remote document to apply mutations to.
 * @param documentKey The key of the document (necessary when remoteDocument is nil).
 */
- (nullable FSTMaybeDocument *)localDocument:(nullable FSTMaybeDocument *)document
                                         key:(FSTDocumentKey *)documentKey {
  NSArray<FSTMutationBatch *> *batches =
      [self.mutationQueue allMutationBatchesAffectingDocumentKey:documentKey];
  for (FSTMutationBatch *batch in batches) {
    document = [batch applyTo:document documentKey:documentKey];
  }

  return document;
}

/**
 * Takes a set of remote documents and applies local mutations to generate the local view of
 * the documents.
 *
 * @param documents The base remote documents to apply mutations to.
 * @return The local view of the documents.
 */
- (DocumentDictionary)localDocuments:(const DocumentDictionary &)documents {
  DocumentDictionary result = documents;
  for (auto iter = result.begin(); iter != result.end();) {
    FSTMaybeDocument *mutatedDoc = [self localDocument:iter->second key:iter->first];
    if ([mutatedDoc isKindOfClass:[FSTDeletedDocument class]]) {
      iter = result.erase(iter);
    } else if ([mutatedDoc isKindOfClass:[FSTDocument class]]) {
      result[iter->first] = (FSTDocument *)mutatedDoc;
      ++iter;
    } else {
      FSTFail(@"Unknown document: %@", mutatedDoc);
    }
  };
  return result;
}

@end

NS_ASSUME_NONNULL_END
