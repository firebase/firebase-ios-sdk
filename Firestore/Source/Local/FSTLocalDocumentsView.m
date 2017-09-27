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

#import "FSTLocalDocumentsView.h"

#import "FSTAssert.h"
#import "FSTDocument.h"
#import "FSTDocumentDictionary.h"
#import "FSTDocumentKey.h"
#import "FSTMutation.h"
#import "FSTMutationBatch.h"
#import "FSTMutationQueue.h"
#import "FSTQuery.h"
#import "FSTRemoteDocumentCache.h"
#import "FSTSnapshotVersion.h"

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

- (FSTMaybeDocumentDictionary *)documentsForKeys:(FSTDocumentKeySet *)keys {
  FSTMaybeDocumentDictionary *results = [FSTMaybeDocumentDictionary maybeDocumentDictionary];
  for (FSTDocumentKey *key in keys.objectEnumerator) {
    // TODO(mikelehen): PERF: Consider fetching all remote documents at once rather than one-by-one.
    FSTMaybeDocument *maybeDoc = [self documentForKey:key];
    // TODO(http://b/32275378): Don't conflate missing / deleted.
    if (!maybeDoc) {
      maybeDoc = [FSTDeletedDocument documentWithKey:key version:[FSTSnapshotVersion noVersion]];
    }
    results = [results dictionaryBySettingObject:maybeDoc forKey:key];
  }
  return results;
}

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query {
  if ([FSTDocumentKey isDocumentKey:query.path]) {
    return [self documentsMatchingDocumentQuery:query.path];
  } else {
    return [self documentsMatchingCollectionQuery:query];
  }
}

- (FSTDocumentDictionary *)documentsMatchingDocumentQuery:(FSTResourcePath *)docPath {
  FSTDocumentDictionary *result = [FSTDocumentDictionary documentDictionary];
  // Just do a simple document lookup.
  FSTMaybeDocument *doc = [self documentForKey:[FSTDocumentKey keyWithPath:docPath]];
  if ([doc isKindOfClass:[FSTDocument class]]) {
    result = [result dictionaryBySettingObject:(FSTDocument *)doc forKey:doc.key];
  }
  return result;
}

- (FSTDocumentDictionary *)documentsMatchingCollectionQuery:(FSTQuery *)query {
  // Query the remote documents and overlay mutations.
  // TODO(mikelehen): There may be significant overlap between the mutations affecting these
  // remote documents and the allMutationBatchesAffectingQuery mutations. Consider optimizing.
  __block FSTDocumentDictionary *results = [self.remoteDocumentCache documentsMatchingQuery:query];
  results = [self localDocuments:results];

  // Now use the mutation queue to discover any other documents that may match the query after
  // applying mutations.
  FSTDocumentKeySet *matchingKeys = [FSTDocumentKeySet keySet];
  NSArray<FSTMutationBatch *> *matchingMutationBatches =
      [self.mutationQueue allMutationBatchesAffectingQuery:query];
  for (FSTMutationBatch *batch in matchingMutationBatches) {
    for (FSTMutation *mutation in batch.mutations) {
      // TODO(mikelehen): PERF: Check if this mutation actually affects the query to reduce work.

      // If the key is already in the results, we can skip it.
      if (![results containsKey:mutation.key]) {
        matchingKeys = [matchingKeys setByAddingObject:mutation.key];
      }
    }
  }

  // Now add in results for the matchingKeys.
  for (FSTDocumentKey *key in matchingKeys.objectEnumerator) {
    FSTMaybeDocument *doc = [self documentForKey:key];
    if ([doc isKindOfClass:[FSTDocument class]]) {
      results = [results dictionaryBySettingObject:(FSTDocument *)doc forKey:key];
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
- (FSTDocumentDictionary *)localDocuments:(FSTDocumentDictionary *)documents {
  __block FSTDocumentDictionary *result = documents;
  [documents enumerateKeysAndObjectsUsingBlock:^(FSTDocumentKey *key, FSTDocument *remoteDocument,
                                                 BOOL *stop) {
    FSTMaybeDocument *mutatedDoc = [self localDocument:remoteDocument key:key];
    if ([mutatedDoc isKindOfClass:[FSTDeletedDocument class]]) {
      result = [documents dictionaryByRemovingObjectForKey:key];
    } else if ([mutatedDoc isKindOfClass:[FSTDocument class]]) {
      result = [documents dictionaryBySettingObject:(FSTDocument *)mutatedDoc forKey:key];
    } else {
      FSTFail(@"Unknown document: %@", mutatedDoc);
    }
  }];
  return result;
}

@end

NS_ASSUME_NONNULL_END
