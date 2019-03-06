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

#import <Foundation/Foundation.h>

#include "Firestore/core/src/firebase/firestore/local/mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"

@class FSTMaybeDocument;
@class FSTQuery;

NS_ASSUME_NONNULL_BEGIN

/**
 * A readonly view of the local state of all documents we're tracking (i.e. we have a cached
 * version in remoteDocumentCache or local mutations for the document). The view is computed by
 * applying the mutations in the FSTMutationQueue to the FSTRemoteDocumentCache.
 */
@interface FSTLocalDocumentsView : NSObject

+ (instancetype)viewWithRemoteDocumentCache:
                    (firebase::firestore::local::RemoteDocumentCache *)remoteDocumentCache
                              mutationQueue:
                                  (firebase::firestore::local::MutationQueue *)mutationQueue;

- (instancetype)init __attribute__((unavailable("Use a static constructor")));

/**
 * Get the local view of the document identified by `key`.
 *
 * @return Local view of the document or nil if we don't have any cached state for it.
 */
- (nullable FSTMaybeDocument *)documentForKey:(const firebase::firestore::model::DocumentKey &)key;

/**
 * Gets the local view of the documents identified by `keys`.
 *
 * If we don't have cached state for a document in `keys`, a FSTDeletedDocument will be stored
 * for that key in the resulting set.
 */
- (firebase::firestore::model::MaybeDocumentMap)documentsForKeys:
    (const firebase::firestore::model::DocumentKeySet &)keys;

/**
 * Similar to `documentsForKeys`, but creates the local view from the given
 * `baseDocs` without retrieving documents from the local store.
 */
- (firebase::firestore::model::MaybeDocumentMap)localViewsForDocuments:
    (const firebase::firestore::model::MaybeDocumentMap &)baseDocs;

/** Performs a query against the local view of all documents. */
- (firebase::firestore::model::DocumentMap)documentsMatchingQuery:(FSTQuery *)query;

@end

NS_ASSUME_NONNULL_END
