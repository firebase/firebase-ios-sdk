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

#include "Firestore/core/src/local/query_engine.h"

#include <utility>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/local/local_documents_view.h"
#include "Firestore/core/src/local/query_context.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/util/log.h"

namespace firebase {
namespace firestore {
namespace local {

namespace {

static const int kDefaultIndexAutoCreationMinCollectionSize = 100;

/**
 * This cost represents the evaluation result of (([index, docKey] + [docKey,
 * docContent]) per document in the result set) / ([docKey, docContent] per
 * documents in full collection scan) coming from experiment
 * https://github.com/firebase/firebase-ios-sdk/pull/11716.
 */

static const double KDefaultRelativeIndexReadCostPerDocument = 3.4;
}  // namespace

using core::LimitType;
using core::Query;
using model::Document;
using model::DocumentKeySet;
using model::DocumentMap;
using model::DocumentSet;
using model::MutableDocument;
using model::SnapshotVersion;

void QueryEngine::Initialize(LocalDocumentsView* local_documents) {
  local_documents_view_ = local_documents;
  index_manager_ = local_documents->index_manager();
  index_auto_creation_min_collection_size_ =
      kDefaultIndexAutoCreationMinCollectionSize;
  relative_index_read_cost_per_document_ =
      KDefaultRelativeIndexReadCostPerDocument;
}

const DocumentMap QueryEngine::GetDocumentsMatchingQuery(
    const core::QueryOrPipeline& query_or_pipeline,
    const SnapshotVersion& last_limbo_free_snapshot_version,
    const DocumentKeySet& remote_keys) const {
  HARD_ASSERT(local_documents_view_ && index_manager_,
              "Initialize() not called");

  const absl::optional<DocumentMap> index_result =
      PerformQueryUsingIndex(query_or_pipeline);
  if (index_result.has_value()) {
    return index_result.value();
  }

  const absl::optional<DocumentMap> key_result = PerformQueryUsingRemoteKeys(
      query_or_pipeline, remote_keys, last_limbo_free_snapshot_version);
  if (key_result.has_value()) {
    return key_result.value();
  }

  absl::optional<QueryContext> context = QueryContext();
  auto full_scan_result = ExecuteFullCollectionScan(query_or_pipeline, context);
  if (index_auto_creation_enabled_) {
    CreateCacheIndexes(query_or_pipeline, context.value(),
                       full_scan_result.size());
  }
  return full_scan_result;
}

void QueryEngine::CreateCacheIndexes(const core::QueryOrPipeline& query,
                                     const QueryContext& context,
                                     size_t result_size) const {
  if (query.IsPipeline()) {
    LOG_DEBUG("SDK will skip creating cache indexes for pipelines.");
    return;
  }

  if (context.GetDocumentReadCount() <
      index_auto_creation_min_collection_size_) {
    LOG_DEBUG(
        "SDK will not create cache indexes for query: %s, since it only "
        "creates cache indexes for collection contains more than or equal to "
        "%s documents.",
        query.ToString(), index_auto_creation_min_collection_size_);
    return;
  }

  LOG_DEBUG(
      "Query: %s, scans %s local documents and returns %s documents as "
      "results.",
      query.ToString(), context.GetDocumentReadCount(), result_size);

  if (context.GetDocumentReadCount() >
      relative_index_read_cost_per_document_ * result_size) {
    index_manager_->CreateTargetIndexes(query.query().ToTarget());
    LOG_DEBUG(
        "The SDK decides to create cache indexes for query: %s, as using cache "
        "indexes may help improve performance.",
        query.ToString());
  }
}

void QueryEngine::SetIndexAutoCreationEnabled(bool is_enabled) {
  index_auto_creation_enabled_ = is_enabled;
}

absl::optional<DocumentMap> QueryEngine::PerformQueryUsingIndex(
    const core::QueryOrPipeline& query_or_pipeline) const {
  if (query_or_pipeline.IsPipeline()) {
    LOG_DEBUG("Skipping using indexes for pipelines.");
    return absl::nullopt;
  }

  const auto& query = query_or_pipeline.query();
  if (query.MatchesAllDocuments()) {
    // Don't use indexes for queries that can be executed by scanning the
    // collection.
    return absl::nullopt;
  }

  const core::Target& target = query.ToTarget();
  const IndexManager::IndexType index_type =
      index_manager_->GetIndexType(target);

  if (index_type == IndexManager::IndexType::NONE) {
    // The target cannot be served from any index.
    return absl::nullopt;
  }

  if (query.has_limit() && index_type == IndexManager::IndexType::PARTIAL) {
    // We cannot apply a limit for targets that are served using a partial
    // index. If a partial index will be used to serve the target, the query may
    // return a superset of documents that match the target (e.g. if the index
    // doesn't include all the target's filters), or may return the correct set
    // of documents in the wrong order (e.g. if the index doesn't include a
    // segment for one of the orderBys). Therefore a limit should not be applied
    // in such cases.
    const Query query_with_limit =
        query.WithLimitToFirst(core::Target::kNoLimit);
    return PerformQueryUsingIndex(core::QueryOrPipeline(query_with_limit));
  }

  auto keys = index_manager_->GetDocumentsMatchingTarget(target);
  HARD_ASSERT(
      keys.has_value(),
      "index manager must return results for partial and full indexes.");

  DocumentKeySet remote_keys;
  for (auto key : keys.value()) {
    remote_keys = remote_keys.insert(key);
  }

  DocumentMap indexedDocuments =
      local_documents_view_->GetDocuments(remote_keys);
  model::IndexOffset offset = index_manager_->GetMinOffset(target);

  DocumentSet previous_results =
      ApplyQuery(query_or_pipeline, indexedDocuments);
  if (NeedsRefill(query_or_pipeline, previous_results, remote_keys,
                  offset.read_time())) {
    // A limit query whose boundaries change due to local edits can be re-run
    // against the cache by excluding the limit. This ensures that all documents
    // that match the query's filters are included in the result set. The SDK
    // can then apply the limit once all local edits are incorporated.
    const Query query_with_limit =
        query.WithLimitToFirst(core::Target::kNoLimit);
    return PerformQueryUsingIndex(core::QueryOrPipeline(query_with_limit));
  }

  // Retrieve all results for documents that were updated since the last
  // remote snapshot that did not contain any Limbo documents.
  return AppendRemainingResults(previous_results, query_or_pipeline, offset);
}

absl::optional<DocumentMap> QueryEngine::PerformQueryUsingRemoteKeys(
    const core::QueryOrPipeline& query,
    const DocumentKeySet& remote_keys,
    const SnapshotVersion& last_limbo_free_snapshot_version) const {
  // Queries that match all documents don't benefit from using key-based
  // lookups. It is more efficient to scan all documents in a collection, rather
  // than to perform individual lookups.
  if (query.MatchesAllDocuments()) {
    return absl::nullopt;
  }

  // Queries that have never seen a snapshot without limbo free documents should
  // also be run as a full collection scan.
  if (last_limbo_free_snapshot_version == SnapshotVersion::None()) {
    return absl::nullopt;
  }

  DocumentMap documents = local_documents_view_->GetDocuments(remote_keys);
  DocumentSet previous_results = ApplyQuery(query, documents);

  if ((query.has_limit()) && NeedsRefill(query, previous_results, remote_keys,
                                         last_limbo_free_snapshot_version)) {
    return absl::nullopt;
  }

  LOG_DEBUG("Re-using previous result from %s to execute query: %s",
            last_limbo_free_snapshot_version.ToString(), query.ToString());

  // Retrieve all results for documents that were updated since the last
  // remote snapshot that did not contain any Limbo documents.
  return AppendRemainingResults(
      previous_results, query,
      model::IndexOffset::CreateSuccessor(last_limbo_free_snapshot_version));
}

DocumentSet QueryEngine::ApplyQuery(const core::QueryOrPipeline& query,
                                    const DocumentMap& documents) const {
  // Sort the documents and re-apply the query filter since previously matching
  // documents do not necessarily still match the query.
  DocumentSet query_results(query.Comparator());

  for (const auto& document_entry : documents) {
    const Document& doc = document_entry.second;
    if (doc->is_found_document()) {
      if (query.Matches(doc)) {
        query_results = query_results.insert(doc);
      }
    }
  }
  return query_results;
}

bool QueryEngine::NeedsRefill(
    const core::QueryOrPipeline& query_or_pipeline,
    const DocumentSet& sorted_previous_results,
    const DocumentKeySet& remote_keys,
    const SnapshotVersion& limbo_free_snapshot_version) const {
  // TODO(pipeline): For pipelines it is simple for now, we refill for all
  // limit/offset. we should implement a similar approach for query at some
  // point.
  if (query_or_pipeline.IsPipeline()) {
    return query_or_pipeline.has_limit();
  }

  const auto& query = query_or_pipeline.query();
  if (!query.has_limit()) {
    // Queries without limits do not need to be refilled.
    return false;
  }

  // The query needs to be refilled if a previously matching document no longer
  // matches.
  if (remote_keys.size() != sorted_previous_results.size()) {
    return true;
  }

  // Limit queries are not eligible for index-free query execution if there is a
  // potential that an older document from cache now sorts before a document
  // that was previously part of the limit.
  // This, however, can only happen if the document at the edge of the limit
  // goes out of limit. If a document that is not the limit boundary sorts
  // differently, the boundary of the limit itself did not change and documents
  // from cache will continue to be "rejected" by this boundary. Therefore, we
  // can ignore any modifications that don't affect the last document.
  absl::optional<Document> document_at_limit_edge =
      (query.limit_type() == LimitType::First)
          ? sorted_previous_results.GetLastDocument()
          : sorted_previous_results.GetFirstDocument();
  if (!document_at_limit_edge) {
    // We don't need to refill the query if there were already no documents.
    return false;
  }
  return (*document_at_limit_edge)->has_pending_writes() ||
         (*document_at_limit_edge)->version() > limbo_free_snapshot_version;
}

const DocumentMap QueryEngine::ExecuteFullCollectionScan(
    const core::QueryOrPipeline& query,
    absl::optional<QueryContext>& context) const {
  LOG_DEBUG("Using full collection scan to execute query: %s",
            query.ToString());
  return local_documents_view_->GetDocumentsMatchingQuery(
      query, model::IndexOffset::None(), context);
}

const DocumentMap QueryEngine::AppendRemainingResults(
    const DocumentSet& indexed_results,
    const core::QueryOrPipeline& query,
    const model::IndexOffset& offset) const {
  // Retrieve all results for documents that were updated since the offset.
  DocumentMap remaining_results =
      local_documents_view_->GetDocumentsMatchingQuery(query, offset);

  // We merge `previous_results` into `update_results`, since `update_results`
  // is already a DocumentMap. If a document is contained in both lists, then
  // its contents are the same.
  for (const Document& entry : indexed_results) {
    remaining_results = remaining_results.insert(entry->key(), entry);
  }
  return remaining_results;
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
