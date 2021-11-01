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

#include "Firestore/core/src/api/document_snapshot.h"

#include <utility>

#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/util/hashing.h"

namespace firebase {
namespace firestore {
namespace api {

using model::Document;
using model::DocumentKey;
using model::FieldPath;
using model::ObjectValue;

DocumentSnapshot DocumentSnapshot::FromDocument(
    std::shared_ptr<Firestore> firestore,
    model::Document document,
    SnapshotMetadata metadata) {
  return DocumentSnapshot{std::move(firestore), document->key(),
                          optional<model::Document>(document),
                          std::move(metadata)};
}

DocumentSnapshot DocumentSnapshot::FromNoDocument(
    std::shared_ptr<Firestore> firestore,
    model::DocumentKey key,
    SnapshotMetadata metadata) {
  return DocumentSnapshot{std::move(firestore), std::move(key),
                          optional<model::Document>(), std::move(metadata)};
}

DocumentSnapshot::DocumentSnapshot(std::shared_ptr<Firestore> firestore,
                                   model::DocumentKey document_key,
                                   optional<Document> document,
                                   SnapshotMetadata metadata)
    : firestore_{std::move(firestore)},
      internal_key_{std::move(document_key)},
      internal_document_{std::move(document)},
      metadata_{std::move(metadata)} {
}

size_t DocumentSnapshot::Hash() const {
  return util::Hash(firestore_.get(), internal_key_, internal_document_,
                    metadata_);
}

bool DocumentSnapshot::exists() const {
  return internal_document_.has_value();
}

const optional<Document>& DocumentSnapshot::internal_document() const {
  return internal_document_;
}

DocumentReference DocumentSnapshot::CreateReference() const {
  return DocumentReference{internal_key_, firestore_};
}

const std::string& DocumentSnapshot::document_id() const {
  return internal_key_.path().last_segment();
}

optional<google_firestore_v1_Value> DocumentSnapshot::GetValue(
    const FieldPath& field_path) const {
  if (internal_document_) {
    auto value = (*internal_document_)->field(field_path);
    if (value) {
      return optional<google_firestore_v1_Value>(value.value());
    }
  }
  return optional<google_firestore_v1_Value>();
}

bool operator==(const DocumentSnapshot& lhs, const DocumentSnapshot& rhs) {
  return lhs.firestore_ == rhs.firestore_ &&
         lhs.internal_key_ == rhs.internal_key_ &&
         lhs.exists() == rhs.exists() &&
         (lhs.exists() ? lhs.internal_document_->get().data() ==
                             rhs.internal_document_->get().data()
                       : true) &&
         lhs.metadata_ == rhs.metadata_;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
