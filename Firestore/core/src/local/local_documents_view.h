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

#ifndef FIRESTORE_CORE_SRC_LOCAL_LOCAL_DOCUMENTS_VIEW_H_
#define FIRESTORE_CORE_SRC_LOCAL_LOCAL_DOCUMENTS_VIEW_H_

#include <unordered_map>
#include <vector>

#include "Firestore/core/src/immutable/sorted_set.h"
#include "Firestore/core/src/local/document_overlay_cache.h"
#include "Firestore/core/src/local/index_manager.h"
#include "Firestore/core/src/local/mutation_queue.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/overlayed_document.h"
#include "Firestore/core/src/util/range.h"

namespace firebase {
namespace firestore {

namespace core {
class Query;
}  // namespace core

namespace local {

/**
 * A readonly view of the local state of all documents we're tracking (i.e. we
 * have a cached version in the RemoteDocumentCache or local mutations for the
 * document). The view is computed by applying the mutations in the
 * MutationQueue to the RemoteDocumentCache.
 */
class LocalDocumentsView {
 public:
  LocalDocumentsView(RemoteDocumentCache* remote_document_cache,
                     MutationQueue* mutation_queue,
                     DocumentOverlayCache* document_overlay_cache,
                     IndexManager* index_manager)
      : remote_document_cache_{remote_document_cache},
        mutation_queue_{mutation_queue},
        document_overlay_cache_{document_overlay_cache},
        index_manager_{index_manager} {
  }

  virtual ~LocalDocumentsView() = default;

  /**
   * Gets the local view of the document identified by `key`.
   *
   * @return Local view of the document or an invalid document if we don't have
   * any cached state for it.
   */
  model::Document GetDocument(const model::DocumentKey& key);

  /**
   * Gets the local view of the documents identified by `keys`.
   *
   * TODO(dconeybe) Verify that "DeletedDocument" is correct in the
   * paragraph below; in Android javadocs, it says "NoDocument".
   *
   * If we don't have cached state for a document in `keys`, a DeletedDocument
   * will be stored for that key in the resulting set.
   */
  model::DocumentMap GetDocuments(const model::DocumentKeySet& keys);

  /**
   * Similar to `GetDocuments`, but creates the local view from the given
   * `base_docs` without retrieving documents from the local store.
   *
   * @param docs The documents to apply local mutations to get the local views.
   * @param existence_state_changed The set of document keys whose existence
   * state is changed. This is useful to determine if some documents overlay
   * needs to be recalculated.
   */
  model::DocumentMap GetLocalViewOfDocuments(
      const model::MutableDocumentMap& docs,
      const model::DocumentKeySet& existence_state_changed);

  model::OverlayedDocumentMap GetOverlayedDocuments(
      const model::MutableDocumentMap& docs);

  void RecalculateAndSaveOverlays(model::DocumentKeySet keys);

  /**
   * Performs a query against the local view of all documents.
   *
   * @param query The query to match documents against.
   * @param since_read_time If not set to SnapshotVersion::None(), return only
   *     documents that have been read since this snapshot version (exclusive).
   */
  // Virtual for testing.
  virtual model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query, const model::IndexOffset& offset);

 private:
  friend class CountingQueryEngine;  // For testing

  /** Internal version of GetDocument that allows re-using batches. */
  model::Document GetDocument(const model::DocumentKey& key,
                              const std::vector<model::MutationBatch>& batches);

  /**
   * Returns the view of the given `docs` as they would appear after applying
   * all mutations in the given `batches`.
   */
  static model::DocumentMap ApplyLocalMutationsToDocuments(
      model::MutableDocumentMap& docs,
      const std::vector<model::MutationBatch>& batches);

  /** Performs a simple document lookup for the given path. */
  model::DocumentMap GetDocumentsMatchingDocumentQuery(
      const model::ResourcePath& doc_path);

  model::DocumentMap GetDocumentsMatchingCollectionGroupQuery(
      const core::Query& query, const model::IndexOffset& offset);

  /** Queries the remote documents and overlays mutations. */
  model::DocumentMap GetDocumentsMatchingCollectionQuery(
      const core::Query& query, const model::IndexOffset& offset);

  RemoteDocumentCache* remote_document_cache() {
    return remote_document_cache_;
  }

  MutationQueue* mutation_queue() {
    return mutation_queue_;
  }

  DocumentOverlayCache* document_overlay_cache() {
    return document_overlay_cache_;
  }

  IndexManager* index_manager() {
    return index_manager_;
  }

 private:
  /** Returns a base document that can be used to apply `overlay`. */
  model::MutableDocument GetBaseDocument(
      const model::DocumentKey& key,
      const absl::optional<model::Overlay>& overlay) const;

  /**
   * Fetches the overlays for `keys` and adds them to provided overlay map if
   * the map does not already contain an entry for the given key.
   */
  void PopulateOverlays(DocumentOverlayCache::OverlayByDocumentKeyMap& overlays,
                        const model::DocumentKeySet& keys) const;

  /* Computes the local view for doc */
  model::OverlayedDocumentMap ComputeViews(
      model::MutableDocumentMap docs,
      DocumentOverlayCache::OverlayByDocumentKeyMap&& overlays,
      const model::DocumentKeySet& existence_state_changed);

  std::unordered_map<model::DocumentKey,
                     absl::optional<model::FieldMask>,
                     model::DocumentKeyHash>
  RecalculateAndSaveOverlays(std::unordered_map<model::DocumentKey,
                                                model::MutableDocument*,
                                                model::DocumentKeyHash> docs);

  RemoteDocumentCache* remote_document_cache_;
  MutationQueue* mutation_queue_;
  DocumentOverlayCache* document_overlay_cache_;
  IndexManager* index_manager_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_LOCAL_DOCUMENTS_VIEW_H_
