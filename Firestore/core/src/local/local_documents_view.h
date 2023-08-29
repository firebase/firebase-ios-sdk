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

#include <string>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/immutable/sorted_set.h"
#include "Firestore/core/src/local/document_overlay_cache.h"
#include "Firestore/core/src/local/index_manager.h"
#include "Firestore/core/src/local/mutation_queue.h"
#include "Firestore/core/src/local/query_context.h"
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

class LocalWriteResult;
class QueryContext;

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
   * If we don't have cached state for a document in `keys`, a NoDocument
   * will be stored for that key in the resulting set.
   */
  model::DocumentMap GetDocuments(const model::DocumentKeySet& keys);

  /**
   * Given a collection group, returns the next documents that follow the
   * provided offset, along with an updated batch ID.
   *
   * The documents returned by this method are ordered by remote version from
   * the provided offset. If there are no more remote documents after the
   * provided offset, documents with mutations in order of batch id from the
   * offset are returned. Since all documents in a batch are returned together,
   * the total number of documents returned can exceed count.
   *
   * @param collection_group The collection group for the documents.
   * @param offset The offset to index into.
   * @param count The number of documents to return
   * @return A LocalWriteResult with the documents that follow the provided
   * offset and the last processed batch id.
   */
  local::LocalWriteResult GetNextDocuments(const std::string& collection_group,
                                           const model::IndexOffset& offset,
                                           int count) const;

  /**
   * Similar to `GetDocuments`, but creates the local view from the given
   * `base_docs` without retrieving documents from the local store.
   *
   * @param base_docs The documents to apply local mutations to get the local
   * views.
   * @param existence_state_changed The set of document keys whose existence
   * state is changed. This is useful to determine if some documents overlay
   * needs to be recalculated.
   */
  model::DocumentMap GetLocalViewOfDocuments(
      const model::MutableDocumentMap& base_docs,
      const model::DocumentKeySet& existence_state_changed);

  /**
   * Gets the overlayed documents for the given document map, which will include
   * the local view of those documents and a `FieldMask` indicating which fields
   * are mutated locally, or `absl::nullopt` if overlay is a Set or Delete
   * mutation.
   *
   * @param docs The documents to apply local mutations to get the local views.
   */
  model::OverlayedDocumentMap GetOverlayedDocuments(
      const model::MutableDocumentMap& docs);

  /**
   * Recalculates overlays by reading the documents from remote document cache
   * first, and save them after they are calculated.
   */
  void RecalculateAndSaveOverlays(const model::DocumentKeySet& keys) const;

  /**
   * Performs a query against the local view of all documents.
   *
   * @param query The query to match documents against.
   * @param offset Read time and document key to start scanning by (exclusive).
   */
  // Virtual for testing.
  virtual model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query, const model::IndexOffset& offset);

  /**
   * Performs a query against the local view of all documents.
   *
   * @param query The query to match documents against.
   * @param offset Read time and document key to start scanning by (exclusive).
   * @param context A optional tracker to keep a record of important details
   * during database local query execution.
   */
  // Virtual for testing.
  virtual model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::IndexOffset& offset,
      absl::optional<QueryContext>& context);

 private:
  friend class QueryEngine;

  friend class CountingQueryEngine;  // For testing

  /** Internal version of GetDocument that allows re-using batches. */
  model::Document GetDocument(const model::DocumentKey& key,
                              const std::vector<model::MutationBatch>& batches);

  /** Performs a simple document lookup for the given path. */
  model::DocumentMap GetDocumentsMatchingDocumentQuery(
      const model::ResourcePath& doc_path);

  model::DocumentMap GetDocumentsMatchingCollectionGroupQuery(
      const core::Query& query,
      const model::IndexOffset& offset,
      absl::optional<QueryContext>& context);

  /** Queries the remote documents and overlays mutations. */
  model::DocumentMap GetDocumentsMatchingCollectionQuery(
      const core::Query& query,
      const model::IndexOffset& offset,
      absl::optional<QueryContext>& context);

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
  void PopulateOverlays(model::OverlayByDocumentKeyMap& overlays,
                        const model::DocumentKeySet& keys) const;

  /* Computes the local view for doc */
  model::OverlayedDocumentMap ComputeViews(
      model::MutableDocumentMap docs,
      model::OverlayByDocumentKeyMap&& overlays,
      const model::DocumentKeySet& existence_state_changed) const;

  model::FieldMaskMap RecalculateAndSaveOverlays(
      model::MutableDocumentPtrMap&& docs) const;

  RemoteDocumentCache* remote_document_cache_;
  MutationQueue* mutation_queue_;
  DocumentOverlayCache* document_overlay_cache_;
  IndexManager* index_manager_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_LOCAL_DOCUMENTS_VIEW_H_
