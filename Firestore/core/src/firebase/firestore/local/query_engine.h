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

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/local_documents_view.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

namespace firebase {
namespace firestore {
namespace local {

/**
 * Represents a query engine capable of performing queries over the local
 * document cache. You must call setLocalDocumentsView() before using.
 */
class QueryEngine {
 public:
  virtual ~QueryEngine() {
  }

  /** Sets the document view to query against. */
  virtual void SetLocalDocumentsView(LocalDocumentsView* local_documents) = 0;

  /** Returns all local documents matching the specified query. */
  virtual model::DocumentMap GetDocumentsMatchingQuery(
      core::Query query,
      model::SnapshotVersion last_limbo_free_snapshot_version,
      model::DocumentKeySet remote_keys) const = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_ENGINE_H_
