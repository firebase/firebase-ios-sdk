/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_LOCAL_QUERY_ENGINE_H_
#define FIRESTORE_CORE_SRC_LOCAL_QUERY_ENGINE_H_

#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {

namespace core {
class Query;
enum class LimitType;
}  // namespace core

namespace local {

class LocalDocumentsView;
class IndexManager;

/**
 * Firestore queries can be executed in three modes. The Query Engine determines
 * what mode to use based on what data is persisted. The mode only determines
 * the runtime complexity of the query - the result set is equivalent across all
 * implementations.
 *
 * The Query engine will use indexed-based execution if a user has configured
 * any index that can be used to execute query (via SetIndexConfiguration in
 * Firestore/core/src/api/firestore.cc). Otherwise, the engine will try to
 * optimize the query by re-using a previously persisted query result. If that
 * is not possible, the query will be executed via a full collection scan.
 *
 * Index-based execution is the default when available. The query engine
 * supports partial indexed execution and merges the result from the index
 * lookup with documents that have not yet been indexed. The index evaluation
 * matches the backend's format and as such, the SDK can use indexing for all
 * queries that the backend supports.
 *
 * If no index exists, the query engine tries to take advantage of the target
 * document mapping in the TargetCache. These mappings exists for all queries
 * that have been synced with the backend at least once and allow the query
 * engine to only read documents that previously matched a query plus any
 * documents that were edited after the query was last listened to.
 *
 * For queries that have never been CURRENT or free of limbo documents, this
 * specific optimization is not guaranteed to produce the same results as full
 * collection scans. So in these cases, query processing falls back to full
 * scans.
 */
class QueryEngine {
 public:
  virtual ~QueryEngine() = default;

  /**
   * Sets the document view and index manager to query against.
   *
   * The caller owns the LocalDocumentView and IndexManager,
   * and must ensure that both of them outlives the QueryEngine.
   */
  virtual void Initialize(LocalDocumentsView* local_documents);

  const model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::SnapshotVersion& last_limbo_free_snapshot_version,
      const model::DocumentKeySet& remote_keys) const;

 private:
  /**
   * Performs an indexed query that evaluates the query based on a collection's
   * persisted index values. Returns nullopt if an index is not available.
   */
  absl::optional<model::DocumentMap> PerformQueryUsingIndex(
      const core::Query& query) const;

  /**
   * Performs a query based on the target's persisted query mapping. Returns
   * nullopt if the mapping is not available or cannot be used.
   */
  absl::optional<model::DocumentMap> PerformQueryUsingRemoteKeys(
      const core::Query& query,
      const model::DocumentKeySet& remote_keys,
      const model::SnapshotVersion& last_limbo_free_snapshot_version) const;

  /** Applies the query filter and sorting to the provided documents. */
  model::DocumentSet ApplyQuery(const core::Query& query,
                                const model::DocumentMap& documents) const;

  /**
   * Determines if a limit query needs to be refilled from cache, making it
   * ineligible for index-free execution.
   *
   * @param query The query for refill calculation.
   * @param sorted_previous_results The documents that matched the query when it
   *     was last synchronized, sorted by the query's comparator.
   * @param remote_keys The document keys that matched the query at the last
   *     snapshot.
   * @param limbo_free_snapshot_version The version of the snapshot when the
   *     query was last synchronized.
   */
  bool NeedsRefill(
      const core::Query& query,
      const model::DocumentSet& sorted_previous_results,
      const model::DocumentKeySet& remote_keys,
      const model::SnapshotVersion& limbo_free_snapshot_version) const;

  const model::DocumentMap ExecuteFullCollectionScan(
      const core::Query& query) const;

  /**
   * Combines the results from an indexed execution with the remaining documents
   * that have not yet been indexed.
   */
  const model::DocumentMap AppendRemainingResults(
      const model::DocumentSet& indexedResults,
      const core::Query& query,
      const model::IndexOffset& offset) const;

  LocalDocumentsView* local_documents_view_ = nullptr;

  IndexManager* index_manager_ = nullptr;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_QUERY_ENGINE_H_
