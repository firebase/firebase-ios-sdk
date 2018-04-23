/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_TESTUTIL_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_TESTUTIL_H_

#include <algorithm>
#include <chrono>  // NOLINT(build/c++11)
#include <cstdint>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/mutations.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "absl/memory/memory.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace testutil {

// Below are convenience methods for creating instances for tests.

inline model::DocumentKey Key(absl::string_view path) {
  return model::DocumentKey::FromPathString(path);
}

inline model::FieldPath Field(absl::string_view field) {
  return model::FieldPath::FromServerFormat(field);
}

inline model::ResourcePath Resource(absl::string_view field) {
  return model::ResourcePath::FromString(field);
}

/**
 * Creates a snapshot version from the given version timestamp.
 *
 * @param version a timestamp in microseconds since the epoch.
 */
inline model::SnapshotVersion Version(int64_t version) {
  namespace chr = std::chrono;
  auto timepoint =
      chr::time_point<chr::system_clock>(chr::microseconds(version));
  return model::SnapshotVersion{Timestamp::FromTimePoint(timepoint)};
}

// Returns a valid arbitrary constant of timestamp.
inline const Timestamp& TestTimestamp() {
  static const Timestamp timestamp = Timestamp::Now();
  return timestamp;
}

inline model::Document Doc(absl::string_view key,
                           int64_t version,
                           model::ObjectValue::Map data = {},
                           bool has_local_mutations = false) {
  return model::Document{model::FieldValue::ObjectValueFromMap(std::move(data)),
                         Key(key), Version(version), has_local_mutations};
}

inline model::MaybeDocumentPointer DocPointer(absl::string_view key,
                                              int64_t version,
                                              model::ObjectValue::Map data) {
  return std::make_shared<model::Document>(
      model::FieldValue::ObjectValueFromMap(std::move(data)), Key(key),
      Version(version),
      /* has_local_mutations= */ false);
}

inline model::NoDocument DeletedDoc(absl::string_view key, int64_t version) {
  return model::NoDocument{Key(key), Version(version)};
}

inline model::MaybeDocumentPointer DeletedDocPointer(absl::string_view key,
                                                     int64_t version) {
  return std::make_shared<model::NoDocument>(Key(key), Version(version));
}

inline model::SetMutation TestSetMutation(absl::string_view path,
                                          model::ObjectValue::Map values) {
  return model::SetMutation{
      Key(path), model::FieldValue::ObjectValueFromMap(std::move(values)),
      model::Precondition::None()};
}

inline model::PatchMutation TestPatchMutation(
    absl::string_view path,
    model::ObjectValue::Map values,
    std::vector<model::FieldPath> update_mask = {}) {
  // A string sentinel, specific to this helper function, to mark a field for
  // deletion.
  const model::FieldValue delete_sentinel =
      model::FieldValue::StringValue("<DELETE>");

  model::FieldValue object = model::FieldValue::ObjectValueFromMap({});
  std::vector<model::FieldPath> object_mask;
  for (const auto& entry : values) {
    object_mask.push_back(Field(entry.first));
    if (entry.second != delete_sentinel) {
      object = object.Set(Field(entry.first), entry.second);
    }
  }

  bool merge = !update_mask.empty();

  // We sort the fieldMaskPaths to make the order deterministic in tests.
  std::sort(object_mask.begin(), object_mask.end());

  return model::PatchMutation{
      Key(path), model::FieldMask{merge ? update_mask : object_mask},
      std::move(object),
      merge ? model::Precondition::None() : model::Precondition::Exists(true)};
}

inline model::TransformMutation ServerTimestampMutation(
    absl::string_view path,
    const std::vector<std::string>& server_timestamp_fields) {
  std::vector<model::FieldTransform> field_transforms;
  for (const std::string& field : server_timestamp_fields) {
    field_transforms.emplace_back(
        Field(field), absl::make_unique<model::ServerTimestampTransform>(
                          model::ServerTimestampTransform::Get()));
  }
  return model::TransformMutation{Key(path), std::move(field_transforms)};
}

inline model::DeleteMutation TestDeleteMutation(absl::string_view path) {
  return model::DeleteMutation{Key(path), model::Precondition::None()};
}

// Add a non-inline function to make this library buildable.
// TODO(zxu123): remove once there is non-inline function.
void dummy();

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_TESTUTIL_H_
