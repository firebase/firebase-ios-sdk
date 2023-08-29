/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_SRC_LOCAL_REMOTE_DOCUMENT_CACHE_H_
#define FIRESTORE_CORE_SRC_LOCAL_REMOTE_DOCUMENT_CACHE_H_

#include <string>

#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/overlay.h"

namespace firebase {
namespace firestore {

namespace core {
class Query;
}  // namespace core

namespace local {

class IndexManager;
class QueryContext;

/**
 * Represents cached documents received from the remote backend.
 *
 * The cache is keyed by DocumentKey and entries in the cache are MaybeDocument
 * instances, meaning we can cache both Document instances (an actual document
 * with data) as well as DeletedDocument instances (indicating that the document
 * is known to not exist).
 */
class RemoteDocumentCache {
 public:
  virtual ~RemoteDocumentCache() = default;

  /**
   * Adds or replaces an entry in the cache.
   *
   * The cache key is extracted from `document.key`. If there is already a cache
   * entry for the key, it will be replaced.
   *
   * @param document A Document or DeletedDocument to put in the cache.
   * @param read_time The time at which the document was read or committed.
   */
  virtual void Add(const model::MutableDocument& document,
                   const model::SnapshotVersion& read_time) = 0;

  /** Removes the cached entry for the given key (no-op if no entry exists). */
  virtual void Remove(const model::DocumentKey& key) = 0;

  /**
   * Looks up an entry in the cache.
   *
   * @param key The key of the entry to look up.
   * @return The cached Document or DeletedDocument entry, or nullopt if we
   * have nothing cached.
   */
  virtual model::MutableDocument Get(const model::DocumentKey& key) const = 0;

  /**
   * Looks up a set of entries in the cache.
   *
   * @param keys The keys of the entries to look up.
   * @return The cached Document or NoDocument entries indexed by key. If an
   * entry is not cached, the corresponding key will be mapped to a null value.
   */
  virtual model::MutableDocumentMap GetAll(
      const model::DocumentKeySet& keys) const = 0;

  /**
   * Looks up the next "limit" number of documents for a collection group based
   * on the provided offset. The ordering is based on the document's read time
   * and key.
   *
   * @param collection_group The collection group to scan.
   * @param offset The offset to start the scan at.
   * @param limit The maximum number of results to return.
   * @return A newly created map with next set of documents.
   */
  virtual model::MutableDocumentMap GetAll(const std::string& collection_group,
                                           const model::IndexOffset& offset,
                                           size_t limit) const = 0;

  /**
   * Executes a query against the cached Document entries
   *
   * Implementations may return extra documents if convenient. The results
   * should be re-filtered by the consumer before presenting them to the user.
   *
   * Cached DeletedDocument entries have no bearing on query results.
   *
   * @param query The query to match documents against.
   * @param offset The read time and document key to start scanning at
   * (exclusive).
   * @param limit The maximum number of results to return.
   * If the limit is not defined, returns all matching documents.
   * @param mutated_docs The documents with local mutations, they are read
   * regardless if the remote version matches the given query.
   * @return The set of matching documents.
   */
  virtual model::MutableDocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::IndexOffset& offset,
      absl::optional<size_t> limit = absl::nullopt,
      const model::OverlayByDocumentKeyMap& mutated_docs = {}) const = 0;

  /**
   * Executes a query against the cached Document entries
   *
   * Implementations may return extra documents if convenient. The results
   * should be re-filtered by the consumer before presenting them to the user.
   *
   * Cached DeletedDocument entries have no bearing on query results.
   *
   * @param query The query to match documents against.
   * @param offset The read time and document key to start scanning at
   * (exclusive).
   * @param context A optional tracker to keep a record of important details
   * during database local query execution.
   * @param limit The maximum number of results to return.
   * If the limit is not defined, returns all matching documents.
   * @param mutated_docs The documents with local mutations, they are read
   * regardless if the remote version matches the given query.
   * @return The set of matching documents.
   */
  virtual model::MutableDocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::IndexOffset& offset,
      absl::optional<QueryContext>& context,
      absl::optional<size_t> limit = absl::nullopt,
      const model::OverlayByDocumentKeyMap& mutated_docs = {}) const = 0;

  /**
   * Sets the index manager used by remote document cache.
   *
   * @param manager A pointer to an `IndexManager` owned by `Persistence`.
   */
  virtual void SetIndexManager(IndexManager* manager) = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_REMOTE_DOCUMENT_CACHE_H_
