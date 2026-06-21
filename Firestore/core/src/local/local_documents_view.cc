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

#include "Firestore/core/src/local/local_documents_view.h"

#include <algorithm>
#include <functional>  // Added for std::function
#include <map>
#include <memory>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/core/pipeline_util.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/immutable/sorted_set.h"
#include "Firestore/core/src/local/local_write_result.h"
#include "Firestore/core/src/local/mutation_queue.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/src/model/overlayed_document.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/util/exception.h"  // Added for ThrowInvalidArgument
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace local {

using api::RealtimePipeline;  // Added
using core::Query;
using core::QueryOrPipeline;  // Added
using model::BatchId;
using model::Document;
using model::DocumentKey;
using model::DocumentKeyHash;
using model::DocumentKeySet;
using model::DocumentMap;
using model::FieldMask;
using model::IndexOffset;
using model::MutableDocument;
using model::MutableDocumentMap;
using model::Mutation;
using model::MutationBatch;
using model::MutationByDocumentKeyMap;
using model::Overlay;
using model::OverlayByDocumentKeyMap;
using model::ResourcePath;
using model::SnapshotVersion;

Document LocalDocumentsView::GetDocument(
    const DocumentKey& key, const std::vector<MutationBatch>& batches) {
  MutableDocument document = remote_document_cache_->Get(key);
  for (const MutationBatch& batch : batches) {
    batch.ApplyToLocalDocument(document);
  }
  return Document{std::move(document)};
}

// Main entry point for matching documents, handles both Query and Pipeline.
DocumentMap LocalDocumentsView::GetDocumentsMatchingQuery(
    const QueryOrPipeline& query_or_pipeline,
    const model::IndexOffset& offset,
    absl::optional<QueryContext>& context) {
  if (query_or_pipeline.IsPipeline()) {
    return GetDocumentsMatchingPipeline(query_or_pipeline, offset, context);
  } else {
    // Handle standard queries
    const Query& query = query_or_pipeline.query();
    if (query.IsDocumentQuery()) {
      return GetDocumentsMatchingDocumentQuery(query.path());
    } else if (query.IsCollectionGroupQuery()) {
      return GetDocumentsMatchingCollectionGroupQuery(query, offset, context);
    } else {
      return GetDocumentsMatchingCollectionQuery(query, offset, context);
    }
  }
}

// Overload without QueryContext (calls the main one with QueryOrPipeline)
// This definition now matches the remaining declaration in the header.
DocumentMap LocalDocumentsView::GetDocumentsMatchingQuery(
    const QueryOrPipeline& query, const model::IndexOffset& offset) {
  absl::optional<QueryContext> null_context;
  // Wrap Query in QueryOrPipeline for the call
  return GetDocumentsMatchingQuery(query, offset, null_context);
}

DocumentMap LocalDocumentsView::GetDocumentsMatchingDocumentQuery(
    const ResourcePath& doc_path) {
  DocumentMap result;
  // Just do a simple document lookup.
  Document doc = GetDocument(DocumentKey{doc_path});
  if (doc->is_found_document()) {
    result = result.insert(doc->key(), doc);
  }
  return result;
}

model::DocumentMap LocalDocumentsView::GetDocumentsMatchingCollectionGroupQuery(
    const Query& query,
    const IndexOffset& offset,
    absl::optional<QueryContext>& context) {
  HARD_ASSERT(
      query.path().empty(),
      "Currently we only support collection group queries at the root.");

  const std::string& collection_id = *query.collection_group();
  std::vector<ResourcePath> parents =
      index_manager_->GetCollectionParents(collection_id);
  DocumentMap results;

  // Perform a collection query against each parent that contains the
  // collection_id and aggregate the results.
  for (const ResourcePath& parent : parents) {
    Query collection_query =
        query.AsCollectionQueryAtPath(parent.Append(collection_id));
    DocumentMap collection_results =
        GetDocumentsMatchingCollectionQuery(collection_query, offset, context);
    for (const auto& kv : collection_results) {
      const DocumentKey& key = kv.first;
      results = results.insert(key, Document(kv.second));
    }
  }
  return results;
}

LocalWriteResult LocalDocumentsView::GetNextDocuments(
    const std::string& collection_group,
    const IndexOffset& offset,
    size_t count) const {
  auto docs = remote_document_cache_->GetAll(collection_group, offset, count);
  auto overlays = count - docs.size() > 0
                      ? document_overlay_cache_->GetOverlays(
                            collection_group, offset.largest_batch_id(),
                            count - docs.size())
                      : OverlayByDocumentKeyMap();

  int largest_batch_id = IndexOffset::InitialLargestBatchId();
  for (const auto& entry : overlays) {
    if (docs.find(entry.first) == docs.end()) {
      docs =
          docs.insert(entry.first, GetBaseDocument(entry.first, entry.second));
    }
    // The callsite will use the largest batch ID together with the latest read
    // time to create a new index offset. Since we only process batch IDs if all
    // remote documents have been read, no overlay will increase the overall
    // read time. This is why we only need to special case the batch id.
    largest_batch_id =
        std::max(largest_batch_id, entry.second.largest_batch_id());
  }

  PopulateOverlays(overlays, DocumentKeySet::FromKeysOf(docs));
  auto local_docs = ComputeViews(docs, std::move(overlays), DocumentKeySet{});
  return LocalWriteResult::FromOverlayedDocuments(largest_batch_id,
                                                  std::move(local_docs));
}

DocumentMap LocalDocumentsView::GetDocumentsMatchingCollectionQuery(
    const Query& query,
    const IndexOffset& offset,
    absl::optional<QueryContext>& context) {
  // Get locally mutated documents
  OverlayByDocumentKeyMap overlays = document_overlay_cache_->GetOverlays(
      query.path(), offset.largest_batch_id());
  MutableDocumentMap remote_documents =
      remote_document_cache_->GetDocumentsMatchingQuery(
          QueryOrPipeline(query), offset, context, absl::nullopt, overlays);

  return RetrieveMatchingLocalDocuments(
      std::move(overlays), std::move(remote_documents),
      [&query](const Document& doc) { return query.Matches(doc); });
}

Document LocalDocumentsView::GetDocument(const DocumentKey& key) {
  absl::optional<Overlay> overlay = document_overlay_cache_->GetOverlay(key);
  MutableDocument document = GetBaseDocument(key, overlay);
  if (overlay.has_value()) {
    overlay.value().mutation().ApplyToLocalView(document, FieldMask(),
                                                Timestamp::Now());
  }
  return document;
}

DocumentMap LocalDocumentsView::GetDocuments(const DocumentKeySet& keys) {
  MutableDocumentMap docs = remote_document_cache_->GetAll(keys);
  return GetLocalViewOfDocuments(docs, DocumentKeySet{});
}

DocumentMap LocalDocumentsView::GetLocalViewOfDocuments(
    const MutableDocumentMap& base_docs,
    const DocumentKeySet& existence_state_changed) {
  OverlayByDocumentKeyMap overlays;
  PopulateOverlays(overlays, DocumentKeySet::FromKeysOf(base_docs));
  auto overlayed_documents =
      ComputeViews(base_docs, std::move(overlays), existence_state_changed);

  DocumentMap result;
  for (auto& entry : overlayed_documents) {
    result = result.insert(entry.first, std::move(entry.second).document());
  }
  return result;
}

model::OverlayedDocumentMap LocalDocumentsView::GetOverlayedDocuments(
    const MutableDocumentMap& docs) {
  OverlayByDocumentKeyMap overlays;
  PopulateOverlays(overlays, model::DocumentKeySet::FromKeysOf(docs));
  return ComputeViews(docs, std::move(overlays), DocumentKeySet{});
}

void LocalDocumentsView::PopulateOverlays(
    OverlayByDocumentKeyMap& overlays,
    const model::DocumentKeySet& keys) const {
  std::set<DocumentKey> missing_overlays;
  for (const DocumentKey& key : keys) {
    if (overlays.find(key) == overlays.end()) {
      missing_overlays.insert(key);
    }
  }
  document_overlay_cache_->GetOverlays(overlays, missing_overlays);
}

model::OverlayedDocumentMap LocalDocumentsView::ComputeViews(
    MutableDocumentMap docs,
    OverlayByDocumentKeyMap&& overlays,
    const DocumentKeySet& existence_state_changed) const {
  model::MutableDocumentPtrMap recalculate_documents;
  model::FieldMaskMap mutated_fields;
  for (const auto& docs_entry : docs) {
    auto* doc = const_cast<MutableDocument*>(&(docs_entry.second));
    auto overlay_it = overlays.find(doc->key());
    // Recalculate an overlay if the document's existence state is changed due
    // to a remote event *and* the overlay is a PatchMutation. This is because
    // document existence state can change if some patch mutation's
    // preconditions are met. NOTE: we recalculate when `overlay` is null as
    // well, because there might be a patch mutation whose precondition does not
    // match before the change (hence overlay==null), but would now match.
    if (existence_state_changed.contains(doc->key()) &&
        (overlay_it == overlays.end() ||
         overlay_it->second.mutation().type() == Mutation::Type::Patch)) {
      recalculate_documents[doc->key()] = doc;
    } else if (overlay_it != overlays.end()) {
      mutated_fields.insert(
          {doc->key(), overlay_it->second.mutation().field_mask()});
      overlay_it->second.mutation().ApplyToLocalView(*doc, absl::nullopt,
                                                     Timestamp::Now());
    } else {  // No overlay for this document
      // Using empty mask to indicate there is no overlay for the document.
      mutated_fields.emplace(doc->key(), FieldMask{});
    }
  }

  auto recalculate_fields =
      RecalculateAndSaveOverlays(std::move(recalculate_documents));
  mutated_fields.insert(recalculate_fields.begin(), recalculate_fields.end());

  model::OverlayedDocumentMap results;
  for (const auto& entry : docs) {
    results.insert(
        {entry.first, model::OverlayedDocument(entry.second,
                                               {mutated_fields[entry.first]})});
  }

  return results;
}

void LocalDocumentsView::RecalculateAndSaveOverlays(
    const DocumentKeySet& keys) const {
  model::MutableDocumentPtrMap docs;
  auto remote_docs = remote_document_cache_->GetAll(keys);
  for (const auto& entry : remote_docs) {
    docs[entry.first] = const_cast<MutableDocument*>(&(entry.second));
  }
  RecalculateAndSaveOverlays(std::move(docs));
}

model::FieldMaskMap LocalDocumentsView::RecalculateAndSaveOverlays(
    model::MutableDocumentPtrMap&& docs) const {
  DocumentKeySet keys;
  for (const auto& doc : docs) {
    keys = keys.insert(doc.first);
  }
  std::vector<MutationBatch> batches =
      mutation_queue_->AllMutationBatchesAffectingDocumentKeys(std::move(keys));

  model::FieldMaskMap masks;
  // A reverse lookup map from batch id to the documents within that batch,
  // ordered by batch id (note that std::map is ordered).
  std::map<BatchId, DocumentKeySet> documents_by_batch_id;

  // Apply mutations from mutation queue to the documents, collecting batch id
  // and field masks along the way.
  for (const MutationBatch& batch : batches) {
    for (const DocumentKey& key : batch.keys()) {
      auto base_doc_it = docs.find(key);
      if (base_doc_it == docs.end()) {
        // If this batch has documents not included in passed in `docs`, skip
        // them.
        continue;
      }
      MutableDocument* base_doc = base_doc_it->second;

      absl::optional<FieldMask> mask = FieldMask();
      auto mask_it = masks.find(key);
      if (mask_it != masks.end()) {
        mask = mask_it->second;
      }
      mask = batch.ApplyToLocalView(*base_doc, std::move(mask));
      masks[key] = mask;
      BatchId batch_id = batch.batch_id();
      DocumentKeySet& documents = documents_by_batch_id[batch_id];
      documents = documents.insert(key);
    }
  }

  DocumentKeySet processed;
  // Iterate in descending order of batch ids, skip documents that are already
  // saved.
  for (auto it = documents_by_batch_id.rbegin();
       it != documents_by_batch_id.rend(); ++it) {
    MutationByDocumentKeyMap overlays;
    for (const DocumentKey& key : it->second) {
      if (!processed.contains(key)) {
        auto docs_it = docs.find(key);
        HARD_ASSERT(docs_it != docs.end());
        absl::optional<Mutation> mutation =
            Mutation::CalculateOverlayMutation(*docs_it->second, masks[key]);
        if (mutation.has_value()) {
          overlays[key] = std::move(mutation).value();
        }
        processed = processed.insert(key);
      }
    }
    document_overlay_cache_->SaveOverlays(it->first, overlays);
  }

  return masks;
}

MutableDocument LocalDocumentsView::GetBaseDocument(
    const DocumentKey& key, const absl::optional<Overlay>& overlay) const {
  return (!overlay.has_value() ||
          overlay.value().mutation().type() == Mutation::Type::Patch)
             ? remote_document_cache_->Get(key)
             : MutableDocument::InvalidDocument(key);
}

// Helper function to apply overlays and filter documents.
DocumentMap LocalDocumentsView::RetrieveMatchingLocalDocuments(
    OverlayByDocumentKeyMap overlays,
    MutableDocumentMap remote_documents,
    const std::function<bool(const model::Document&)>& matcher) {
  // As documents might match the query because of their overlay we need to
  // include documents for all overlays in the initial document set.
  for (const auto& entry : overlays) {
    const DocumentKey& key = entry.first;
    if (remote_documents.find(key) == remote_documents.end()) {
      remote_documents =
          remote_documents.insert(key, MutableDocument::InvalidDocument(key));
    }
  }

  DocumentMap results;
  for (const auto& entry : remote_documents) {
    const DocumentKey& key = entry.first;
    MutableDocument doc = entry.second;  // Make a copy to modify

    auto overlay_it = overlays.find(key);
    if (overlay_it != overlays.end()) {
      // Apply the overlay mutation
      overlay_it->second.mutation().ApplyToLocalView(doc, FieldMask(),
                                                     Timestamp::Now());
    }

    // Finally, insert the documents that match the filter
    if (matcher(doc)) {
      results = results.insert(key, std::move(doc));
    }
  }

  return results;
}

// Handles querying the local view for pipelines.
DocumentMap LocalDocumentsView::GetDocumentsMatchingPipeline(
    const QueryOrPipeline& query_or_pipeline,
    const IndexOffset& offset,
    absl::optional<QueryContext>& context) {
  const auto& pipeline = query_or_pipeline.pipeline();

  if (core::GetPipelineSourceType(pipeline) ==
      core::PipelineSourceType::kCollectionGroup) {
    auto collection_id = core::GetPipelineCollectionGroup(pipeline);
    HARD_ASSERT(
        collection_id.has_value(),
        "Pipeline source type is kCollectionGroup but first stage is not "
        "a CollectionGroupSource.");

    DocumentMap results;
    std::vector<ResourcePath> parents =
        index_manager_->GetCollectionParents(collection_id.value());

    for (const ResourcePath& parent : parents) {
      RealtimePipeline collection_pipeline = core::AsCollectionPipelineAtPath(
          pipeline, parent.Append(collection_id.value()));
      DocumentMap collection_results = GetDocumentsMatchingPipeline(
          QueryOrPipeline(collection_pipeline), offset, context);
      for (const auto& kv : collection_results) {
        results = results.insert(kv.first, kv.second);
      }
    }
    return results;
  } else {
    // Non-collection-group pipelines:
    OverlayByDocumentKeyMap overlays = GetOverlaysForPipeline(
        QueryOrPipeline(pipeline), offset.largest_batch_id());

    MutableDocumentMap remote_documents;
    switch (core::GetPipelineSourceType(pipeline)) {
      case core::PipelineSourceType::kCollection: {
        remote_documents = remote_document_cache_->GetDocumentsMatchingQuery(
            query_or_pipeline, offset, context, absl::nullopt, overlays);
        break;
      }
      case core::PipelineSourceType::kDocuments: {
        const auto keys =
            core::GetPipelineDocuments(query_or_pipeline.pipeline());
        DocumentKeySet key_set;
        for (const auto& key : keys.value()) {
          key_set = key_set.insert(DocumentKey::FromPathString(key));
        }

        remote_documents = remote_document_cache_->GetAll(key_set);
        break;
      }
      default:
        util::ThrowInvalidArgument(
            "Invalid pipeline source to execute offline: %s",
            query_or_pipeline.ToString());  // Assuming ToString exists
    }

    return RetrieveMatchingLocalDocuments(
        std::move(overlays), std::move(remote_documents),
        [&query_or_pipeline](const model::Document& doc) {
          return query_or_pipeline.Matches(doc);
        });
  }
}

OverlayByDocumentKeyMap LocalDocumentsView::GetOverlaysForPipeline(
    const QueryOrPipeline& query_or_pipeline, BatchId largest_batch_id) {
  const auto& pipeline = query_or_pipeline.pipeline();
  switch (core::GetPipelineSourceType(pipeline)) {
    case core::PipelineSourceType::kCollection: {
      auto collection = core::GetPipelineCollection(pipeline);
      HARD_ASSERT(collection.has_value(),
                  "Pipeline source type is kCollection but collection source "
                  "is missing");

      return document_overlay_cache_->GetOverlays(
          ResourcePath::FromString(collection.value()), largest_batch_id);
    }
    case core::PipelineSourceType::kDocuments: {
      auto documents = core::GetPipelineDocuments(pipeline);
      HARD_ASSERT(documents.has_value(),
                  "Pipeline source type is kDocuments but documents source "
                  "is missing");

      std::set<DocumentKey> key_set;
      for (const auto& key_string : documents.value()) {
        key_set.insert(DocumentKey::FromPathString(key_string));
      }

      OverlayByDocumentKeyMap results;
      document_overlay_cache_->GetOverlays(results, key_set);

      return results;
    }
    default: {
      HARD_FAIL(
          "GetOverlaysForPipeline: Unrecognized pipeline source type for "
          "pipeline %s}",
          query_or_pipeline.ToString());
    }
  }
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
