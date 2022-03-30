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

#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/mutation_queue.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::BatchId;
using model::Document;
using model::DocumentKey;
using model::DocumentKeyHash;
using model::DocumentKeySet;
using model::DocumentMap;
using model::FieldMask;
using model::MutableDocument;
using model::MutableDocumentMap;
using model::Mutation;
using model::MutationBatch;
using model::Overlay;
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

DocumentMap LocalDocumentsView::ApplyLocalMutationsToDocuments(
    MutableDocumentMap& docs, const std::vector<MutationBatch>& batches) {
  DocumentMap results;
  for (const auto& kv : docs) {
    MutableDocument local_view = kv.second;
    for (const MutationBatch& batch : batches) {
      batch.ApplyToLocalDocument(local_view);
    }
    results = results.insert(kv.first, std::move(local_view));
  }
  return results;
}

DocumentMap LocalDocumentsView::GetDocumentsMatchingQuery(
    const Query& query, const model::SnapshotVersion& since_read_time) {
  if (query.IsDocumentQuery()) {
    return GetDocumentsMatchingDocumentQuery(query.path());
  } else if (query.IsCollectionGroupQuery()) {
    return GetDocumentsMatchingCollectionGroupQuery(query, since_read_time);
  } else {
    return GetDocumentsMatchingCollectionQuery(query, since_read_time);
  }
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
    const Query& query, const SnapshotVersion& since_read_time) {
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
        GetDocumentsMatchingCollectionQuery(collection_query, since_read_time);
    for (const auto& kv : collection_results) {
      const DocumentKey& key = kv.first;
      results = results.insert(key, Document(kv.second));
    }
  }
  return results;
}

DocumentMap LocalDocumentsView::GetDocumentsMatchingCollectionQuery(
    const Query& query, const SnapshotVersion& since_read_time) {
  MutableDocumentMap remote_documents =
      remote_document_cache_->GetMatching(query, since_read_time);
  // Get locally persisted mutation batches.
  std::vector<MutationBatch> matching_batches =
      mutation_queue_->AllMutationBatchesAffectingQuery(query);

  remote_documents =
      AddMissingBaseDocuments(matching_batches, std::move(remote_documents));

  for (const MutationBatch& batch : matching_batches) {
    for (const Mutation& mutation : batch.mutations()) {
      // Only process documents belonging to the collection.
      if (!query.path().IsImmediateParentOf(mutation.key().path())) {
        continue;
      }

      const DocumentKey& key = mutation.key();
      // base_doc may be unset for the documents that weren't yet written to
      // the backend.
      absl::optional<MutableDocument> document = remote_documents.get(key);
      if (!document) {
        // Create invalid document to apply mutations on top of
        document = MutableDocument::InvalidDocument(key);
      }

      // TODO(dconeybe) Replace absl::nullopt with a FieldMask?
      // TODO(Overlay): Here we should be reading overlay mutation and apply that instead.
      mutation.ApplyToLocalView(*document, absl::nullopt, batch.local_write_time());
      remote_documents = remote_documents.insert(key, *document);
    }
  }

  // Finally, filter out any documents that don't actually match the query. Note
  // that the extra reference here prevents DocumentMap's destructor from
  // deallocating the initial unfiltered results while we're iterating over
  // them.
  DocumentMap results;
  for (const auto& kv : remote_documents) {
    const DocumentKey& key = kv.first;
    if (query.Matches(kv.second)) {
      results = results.insert(key, kv.second);
    }
  }

  return results;
}

MutableDocumentMap LocalDocumentsView::AddMissingBaseDocuments(
    const std::vector<MutationBatch>& matching_batches,
    MutableDocumentMap existing_docs) {
  DocumentKeySet missing_doc_keys;
  for (const MutationBatch& batch : matching_batches) {
    for (const Mutation& mutation : batch.mutations()) {
      const DocumentKey& key = mutation.key();
      if (mutation.type() == Mutation::Type::Patch &&
          !existing_docs.contains(key)) {
        missing_doc_keys = missing_doc_keys.insert(key);
      }
    }
  }

  MutableDocumentMap merged_docs = existing_docs;
  MutableDocumentMap missing_docs =
      remote_document_cache_->GetAll(missing_doc_keys);
  for (const auto& kv : missing_docs) {
    const MutableDocument document = kv.second;
    if (document.is_found_document()) {
      existing_docs = existing_docs.insert(kv.first, document);
    }
  }

  return existing_docs;
}

////////////////////////

Document LocalDocumentsView::GetDocument(const DocumentKey& key) {
  absl::optional<Overlay> overlay = document_overlay_cache_->GetOverlay(key);
  MutableDocument document = GetBaseDocument(key, overlay);
  if (overlay.has_value()) {
    overlay.value().mutation().ApplyToLocalView(document, absl::nullopt, Timestamp::Now());
  }
  return document;
}

DocumentMap LocalDocumentsView::GetDocuments(const DocumentKeySet& keys) {
  MutableDocumentMap docs = remote_document_cache_->GetAll(keys);
  return GetLocalViewOfDocuments(docs, DocumentKeySet{});
}

DocumentMap LocalDocumentsView::GetLocalViewOfDocuments(const MutableDocumentMap& docs, const DocumentKeySet& existence_state_changed) {
  DocumentOverlayCache::OverlayByDocumentKeyMap overlays;
  PopulateOverlays(overlays, DocumentKeySet::FromKeysOf(docs));
  return ComputeViews(docs, std::move(overlays), existence_state_changed);
}

void LocalDocumentsView::PopulateOverlays(DocumentOverlayCache::OverlayByDocumentKeyMap& overlays, const model::DocumentKeySet& keys) const {
  DocumentKeySet missing_overlays;
  for (const DocumentKey& key : keys) {
    if (overlays.find(key) == overlays.end()) {
      missing_overlays = missing_overlays.insert(key);
    }
  }
  document_overlay_cache_->GetOverlays(overlays, missing_overlays);
}

DocumentMap LocalDocumentsView::ComputeViews(MutableDocumentMap docs, DocumentOverlayCache::OverlayByDocumentKeyMap&& overlays, const DocumentKeySet& existence_state_changed) {
  DocumentMap results;
  MutableDocumentMap recalculate_documents;
  for (const auto& docs_entry : docs) {
    const MutableDocument& doc = docs_entry.second;
    auto overlay_it = overlays.find(doc.key());
    // Recalculate an overlay if the document's existence state is changed due
    // to a remote event *and* the overlay is a PatchMutation. This is because
    // document existence state can change if some patch mutation's
    // preconditions are met. NOTE: we recalculate when `overlay` is null as
    // well, because there might be a patch mutation whose precondition does not
    // match before the change (hence overlay==null), but would now match.
    if (existence_state_changed.contains(doc.key()) && (overlay_it == overlays.end() || overlay_it->second.mutation().type() == Mutation::Type::Patch)) {
      recalculate_documents = recalculate_documents.insert(doc.key(), doc);
    } else if (overlay_it != overlays.end()) {
      MutableDocument doc_updated = doc;
      overlay_it->second.mutation().ApplyToLocalView(doc_updated, absl::nullopt, Timestamp::Now());
      docs = docs.insert(docs_entry.first, doc_updated);
    }
  }

  recalculate_documents = RecalculateAndSaveOverlays(recalculate_documents);

  for (const auto& entry : docs) {
    results = results.insert(entry.first, entry.second);
  }
  for (const auto& entry : recalculate_documents) {
    results = results.insert(entry.first, entry.second);
  }

  return results;
}

MutableDocumentMap LocalDocumentsView::RecalculateAndSaveOverlays(MutableDocumentMap docs) {
  std::vector<MutationBatch> batches = mutation_queue_->AllMutationBatchesAffectingDocumentKeys(DocumentKeySet::FromKeysOf(docs));

  std::unordered_map<DocumentKey, FieldMask, DocumentKeyHash> masks;
  // A reverse lookup map from batch id to the documents within that batch,
  // ordered by batch id (note that std::map is ordered).
  std::map<BatchId, DocumentKeySet> documents_by_batch_id;

  // Apply mutations from mutation queue to the documents, collecting batch id
  // and field masks along the way.
  for (const MutationBatch& batch : batches) {
    for (const DocumentKey& key : batch.keys()) {
      auto base_doc_it = docs.find(key);
      if (base_doc_it == docs.end()) {
        continue;
      }
      MutableDocument base_doc = base_doc_it->second;

      FieldMask mask;
      auto mask_it = masks.find(key);
      if (mask_it != masks.end()) {
        mask = mask_it->second;
      }
      mask = batch.ApplyToLocalView(base_doc, mask).value();
      docs = docs.insert(key, base_doc);
      masks[key] = mask;
      BatchId batch_id = batch.batch_id();
      DocumentKeySet& documents = documents_by_batch_id[batch_id];
      documents = documents.insert(key);
    }
  }

  DocumentKeySet processed;
  // Iterate in descending order of batch ids, skip documents that are already saved.
  for (auto it = documents_by_batch_id.rbegin(); it != documents_by_batch_id.rend(); ++it) {
    DocumentOverlayCache::MutationByDocumentKeyMap overlays;
    for (const DocumentKey& key : it->second) {
      if (! processed.contains(key)) {
        auto docs_it = docs.find(key);
        HARD_ASSERT(docs_it != docs.end());
        absl::optional<Mutation> mutation = Mutation::CalculateOverlayMutation(docs_it->second, masks[key]);
        if (mutation.has_value()) {
          overlays[key] = std::move(mutation).value();
        }
        processed = processed.insert(key);
      }
    }
    document_overlay_cache_->SaveOverlays(it->first, overlays);
  }

  return docs;
}

MutableDocument LocalDocumentsView::GetBaseDocument(const DocumentKey& key, const absl::optional<Overlay>& overlay) const {
  return (!overlay.has_value() || overlay.value().mutation().type() == Mutation::Type::Patch)
             ? remote_document_cache_->Get(key)
             : MutableDocument::InvalidDocument(key);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
