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

#include "Firestore/core/src/firebase/firestore/local/simple_query_engine.h"

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/local_documents_view.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

namespace firebase {
namespace firestore {
namespace local {

using model::SnapshotVersion;

model::DocumentMap SimpleQueryEngine::GetDocumentsMatchingQuery(
    const core::Query& query,
    const SnapshotVersion& last_limbo_free_snapshot_version,
    const model::DocumentKeySet& remote_keys) {
  HARD_ASSERT(local_documents_view_, "SetLocalDocumentsView() not called");

  return local_documents_view_->GetDocumentsMatchingQuery(
      query, SnapshotVersion::None());
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
