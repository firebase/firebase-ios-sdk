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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_ENGINE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_ENGINE_H_

#include "Firestore/core/src/firebase/firestore/model/model_fwd.h"

namespace firebase {
namespace firestore {

namespace core {
class Query;
}  // namespace core

namespace local {

class LocalDocumentsView;

/**
 * Represents a query engine capable of performing queries over the local
 * document cache. You must call `SetLocalDocumentsView()` before using.
 */
class QueryEngine {
 public:
  enum Type { Simple, IndexFree };

  virtual ~QueryEngine() = default;

  /**
   * Sets the document view to query against.
   *
   * The caller owns the LocalDocumentView and must ensure that it outlives the
   * QueryEngine.
   */
  virtual void SetLocalDocumentsView(LocalDocumentsView* local_documents) = 0;

  /** Returns all local documents matching the specified query. */
  virtual model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::SnapshotVersion& last_limbo_free_snapshot_version,
      const model::DocumentKeySet& remote_keys) = 0;

  /** Returns the underlying algorithm used by the query engine. */
  virtual Type type() const = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_ENGINE_H_
