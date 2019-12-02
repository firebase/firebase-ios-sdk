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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LOCAL_DOCUMENTS_VIEW_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LOCAL_DOCUMENTS_VIEW_H_

#include <vector>

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/index_manager.h"
#include "Firestore/core/src/firebase/firestore/local/mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"

namespace firebase {
namespace firestore {
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
                     IndexManager* index_manager)
      : remote_document_cache_{remote_document_cache},
        mutation_queue_{mutation_queue},
        index_manager_{index_manager} {
  }

  virtual ~LocalDocumentsView() = default;

  /**
   * Gets the local view of the document identified by `key`.
   *
   * @return Local view of the document or nil if we don't have any cached state
   * for it.
   */
  absl::optional<model::MaybeDocument> GetDocument(
      const model::DocumentKey& key);

  /**
   * Gets the local view of the documents identified by `keys`.
   *
   * If we don't have cached state for a document in `keys`, a DeletedDocument
   * will be stored for that key in the resulting set.
   */
  model::MaybeDocumentMap GetDocuments(const model::DocumentKeySet& keys);

  /**
   * Similar to `GetDocuments`, but creates the local view from the given
   * `base_docs` without retrieving documents from the local store.
   */
  model::MaybeDocumentMap GetLocalViewOfDocuments(
      const model::OptionalMaybeDocumentMap& base_docs);

  /**
   * Performs a query against the local view of all documents.
   *
   * @param query The query to match documents against.
   * @param since_read_time If not set to SnapshotVersion::None(), return only
   *     documents that have been read since this snapshot version (exclusive).
   */
  // Virtual for testing.
  virtual model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query, const model::SnapshotVersion& since_read_time);

 private:
  /** Internal version of GetDocument that allows re-using batches. */
  absl::optional<model::MaybeDocument> GetDocument(
      const model::DocumentKey& key,
      const std::vector<model::MutationBatch>& batches);

  /**
   * Returns the view of the given `docs` as they would appear after applying
   * all mutations in the given `batches`.
   */
  model::OptionalMaybeDocumentMap ApplyLocalMutationsToDocuments(
      const model::OptionalMaybeDocumentMap& docs,
      const std::vector<model::MutationBatch>& batches);

  /** Performs a simple document lookup for the given path. */
  model::DocumentMap GetDocumentsMatchingDocumentQuery(
      const model::ResourcePath& doc_path);

  model::DocumentMap GetDocumentsMatchingCollectionGroupQuery(
      const core::Query& query, const model::SnapshotVersion& since_read_time);

  /** Queries the remote documents and overlays mutations. */
  model::DocumentMap GetDocumentsMatchingCollectionQuery(
      const core::Query& query, const model::SnapshotVersion& since_read_time);

  /**
   * It is possible that a `PatchMutation` can make a document match a query,
   * even if the version in the `RemoteDocumentCache` is not a match yet
   * (waiting for server to ack). To handle this, we find all document keys
   * affected by the `PatchMutation`s that are not in `existing_docs` yet, and
   * back fill them via `remote_document_cache_->GetAll`, otherwise those
   * `PatchMutation`s will be ignored because no base document can be found, and
   * lead to missing results for the query.
   */
  model::DocumentMap AddMissingBaseDocuments(
      const std::vector<model::MutationBatch>& matching_batches,
      model::DocumentMap existing_docs);

  RemoteDocumentCache* remote_document_cache_;
  MutationQueue* mutation_queue_;
  IndexManager* index_manager_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LOCAL_DOCUMENTS_VIEW_H_
