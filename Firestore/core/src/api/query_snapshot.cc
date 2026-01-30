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

#include "Firestore/core/src/api/query_snapshot.h"

#include <utility>
#include <vector>

#include "Firestore/core/src/api/document_change.h"
#include "Firestore/core/src/api/document_snapshot.h"
#include "Firestore/core/src/api/query_core.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace api {

using api::Firestore;
using core::DocumentViewChange;
using core::ViewSnapshot;
using model::Document;
using model::DocumentComparator;
using model::DocumentSet;
using util::ThrowInvalidArgument;

QuerySnapshot::QuerySnapshot(std::shared_ptr<Firestore> firestore,
                             core::Query query,
                             core::ViewSnapshot&& snapshot,
                             SnapshotMetadata metadata)
    : firestore_(std::move(firestore)),
      internal_query_(std::move(query)),
      snapshot_(std::move(snapshot)),
      metadata_(std::move(metadata)) {
}

Query QuerySnapshot::query() const {
  return Query(internal_query_, firestore_);
}

const core::Query& QuerySnapshot::internal_query() const {
  return internal_query_;
}

bool operator==(const QuerySnapshot& lhs, const QuerySnapshot& rhs) {
  return lhs.firestore_ == rhs.firestore_ &&
         lhs.internal_query_ == rhs.internal_query_ &&
         lhs.snapshot_ == rhs.snapshot_ && lhs.metadata_ == rhs.metadata_;
}

size_t QuerySnapshot::Hash() const {
  return util::Hash(firestore_.get(), internal_query_, snapshot_, metadata_);
}

void QuerySnapshot::ForEachDocument(
    const std::function<void(DocumentSnapshot)>& callback) const {
  DocumentSet document_set = snapshot_.documents();
  bool from_cache = metadata_.from_cache();

  for (const Document& document : document_set) {
    bool has_pending_writes =
        snapshot_.mutated_keys().contains(document->key());
    auto snap = DocumentSnapshot::FromDocument(
        firestore_, document, SnapshotMetadata(has_pending_writes, from_cache));
    callback(std::move(snap));
  }
}

void QuerySnapshot::ForEachChange(
    bool include_metadata_changes,
    const std::function<void(DocumentChange)>& callback) const {
  auto factory = [this](const Document& doc,
                        SnapshotMetadata meta) -> DocumentSnapshot {
    return DocumentSnapshot::FromDocument(this->firestore_, doc,
                                          std::move(meta));
  };

  std::vector<DocumentChange> changes =
      GenerateChangesFromSnapshot<DocumentChange, DocumentSnapshot>(
          this->snapshot_, include_metadata_changes, factory);
  for (auto& change : changes) {
    callback(change);
  }
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
