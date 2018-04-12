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

#include <chrono>  // NOLINT(build/c++11)
#include <cstdint>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
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

inline model::Document Doc(absl::string_view key, int64_t version) {
  return model::Document{model::FieldValue::ObjectValueFromMap({}), Key(key),
                         Version(version),
                         /* has_local_mutations= */ false};
}

inline model::NoDocument DeletedDoc(absl::string_view key, int64_t version) {
  return model::NoDocument{Key(key), Version(version)};
}

// Add a non-inline function to make this library buildable.
// TODO(zxu123): remove once there is non-inline function.
void dummy();

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_TESTUTIL_H_
