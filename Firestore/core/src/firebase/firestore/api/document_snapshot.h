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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_DOCUMENT_SNAPSHOT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_DOCUMENT_SNAPSHOT_H_

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/api/snapshot_metadata.h"
#include "Firestore/core/src/firebase/firestore/core/event_listener.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/objc/objc_class.h"
#include "absl/types/optional.h"

NS_ASSUME_NONNULL_BEGIN

OBJC_CLASS(FSTDocument);
OBJC_CLASS(FSTObjectValue);

namespace firebase {
namespace firestore {
namespace api {

class DocumentReference;
class Firestore;

class DocumentSnapshot {
 public:
  using Listener = std::unique_ptr<core::EventListener<DocumentSnapshot>>;

  DocumentSnapshot() = default;

  DocumentSnapshot(std::shared_ptr<Firestore> firestore,
                   model::DocumentKey document_key,
                   FSTDocument* _Nullable document,
                   SnapshotMetadata metadata);

  DocumentSnapshot(std::shared_ptr<Firestore> firestore,
                   model::DocumentKey document_key,
                   FSTDocument* _Nullable document,
                   bool from_cache,
                   bool has_pending_writes);

  size_t Hash() const;

  bool exists() const;
  FSTDocument* internal_document() const;
  const std::string& document_id() const;

  const SnapshotMetadata& metadata() const {
    return metadata_;
  }

  DocumentReference CreateReference() const;

  absl::optional<model::ObjectValue> GetData() const;
  absl::optional<model::FieldValue> GetValue(
      const model::FieldPath& field_path) const;

  const std::shared_ptr<Firestore>& firestore() const {
    return firestore_;
  }

  friend bool operator==(const DocumentSnapshot& lhs,
                         const DocumentSnapshot& rhs);

 private:
  std::shared_ptr<Firestore> firestore_;
  model::DocumentKey internal_key_;
  objc::Handle<FSTDocument> internal_document_;
  SnapshotMetadata metadata_;
};

inline bool operator!=(const DocumentSnapshot& lhs,
                       const DocumentSnapshot& rhs) {
  return !(lhs == rhs);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_DOCUMENT_SNAPSHOT_H_
