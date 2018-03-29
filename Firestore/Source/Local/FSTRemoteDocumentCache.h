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

#import "Firestore/Source/Model/FSTDocumentDictionary.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FSTMaybeDocument;
@class FSTQuery;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents cached documents received from the remote backend.
 *
 * The cache is keyed by FSTDocumentKey and entries in the cache are FSTMaybeDocument instances,
 * meaning we can cache both FSTDocument instances (an actual document with data) as well as
 * FSTDeletedDocument instances (indicating that the document is known to not exist).
 */
@protocol FSTRemoteDocumentCache <NSObject>

/**
 * Adds or replaces an entry in the cache.
 *
 * The cache key is extracted from `maybeDocument.key`. If there is already a cache entry for
 * the key, it will be replaced.
 *
 * @param maybeDocument A FSTDocument or FSTDeletedDocument to put in the cache.
 */
- (void)addEntry:(FSTMaybeDocument *)maybeDocument;

/** Removes the cached entry for the given key (no-op if no entry exists). */
- (void)removeEntryForKey:(const firebase::firestore::model::DocumentKey &)documentKey;

/**
 * Looks up an entry in the cache.
 *
 * @param documentKey The key of the entry to look up.
 * @return The cached FSTDocument or FSTDeletedDocument entry, or nil if we have nothing cached.
 */
- (nullable FSTMaybeDocument *)entryForKey:
    (const firebase::firestore::model::DocumentKey &)documentKey;

/**
 * Executes a query against the cached FSTDocument entries
 *
 * Implementations may return extra documents if convenient. The results should be re-filtered
 * by the consumer before presenting them to the user.
 *
 * Cached FSTDeletedDocument entries have no bearing on query results.
 *
 * @param query The query to match documents against.
 * @return The set of matching documents.
 */
- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query;

@end

NS_ASSUME_NONNULL_END
