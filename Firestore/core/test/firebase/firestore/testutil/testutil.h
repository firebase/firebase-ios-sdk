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
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/core/relation_filter.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace testutil {

/**
 * A string sentinel that can be used with PatchMutation() to mark a field for
 * deletion.
 */
constexpr const char* kDeleteSentinel = "<DELETE>";

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

inline model::Document Doc(
    absl::string_view key,
    int64_t version = 0,
    const model::ObjectValue::Map& data = {},
    model::DocumentState document_state = model::DocumentState::kSynced) {
  return model::Document{model::FieldValue::FromMap(data), Key(key),
                         Version(version), document_state};
}

inline model::NoDocument DeletedDoc(absl::string_view key, int64_t version) {
  return model::NoDocument{Key(key), Version(version),
                           /*has_committed_mutations=*/false};
}

inline core::RelationFilter::Operator OperatorFromString(absl::string_view s) {
  if (s == "<")
    return core::RelationFilter::Operator::LessThan;
  else if (s == "<=")
    return core::RelationFilter::Operator::LessThanOrEqual;
  else if (s == "==")
    return core::RelationFilter::Operator::Equal;
  else if (s == ">")
    return core::RelationFilter::Operator::GreaterThan;
  else if (s == ">=")
    return core::RelationFilter::Operator::GreaterThanOrEqual;
  HARD_FAIL("Unknown operator: %s", s);
}

inline std::shared_ptr<core::Filter> Filter(absl::string_view key,
                                            absl::string_view op,
                                            model::FieldValue value) {
  return core::Filter::Create(Field(key), OperatorFromString(op),
                              std::move(value));
}

inline std::shared_ptr<core::Filter> Filter(absl::string_view key,
                                            absl::string_view op,
                                            const std::string& value) {
  return Filter(key, op, model::FieldValue::FromString(value));
}

inline std::shared_ptr<core::Filter> Filter(absl::string_view key,
                                            absl::string_view op,
                                            int value) {
  return Filter(key, op, model::FieldValue::FromInteger(value));
}

inline std::shared_ptr<core::Filter> Filter(absl::string_view key,
                                            absl::string_view op,
                                            double value) {
  return Filter(key, op, model::FieldValue::FromDouble(value));
}

inline core::Query Query(absl::string_view path) {
  return core::Query::AtPath(Resource(path));
}

inline std::unique_ptr<model::SetMutation> SetMutation(
    absl::string_view path, const model::ObjectValue::Map& values = {}) {
  return absl::make_unique<model::SetMutation>(
      Key(path), model::FieldValue::FromMap(values),
      model::Precondition::None());
}

std::unique_ptr<model::PatchMutation> PatchMutation(
    absl::string_view path,
    const model::ObjectValue::Map& values = {},
    const std::vector<model::FieldPath>* update_mask = nullptr);

inline std::unique_ptr<model::PatchMutation> PatchMutation(
    absl::string_view path,
    const model::ObjectValue::Map& values,
    const std::vector<model::FieldPath>& update_mask) {
  return PatchMutation(path, values, &update_mask);
}

inline model::MutationResult MutationResult(int64_t version) {
  return model::MutationResult(Version(version), nullptr);
}

inline std::vector<uint8_t> ResumeToken(int64_t snapshot_version) {
  if (snapshot_version == 0) {
    // TODO(rsgowman): The other platforms return null here, though I'm not sure
    // if they ever rely on that. I suspect it'd be sufficient to return '{}'.
    // But for now, we'll just abort() until we hit a test case that actually
    // makes use of this.
    abort();
  }

  std::string snapshot_string =
      std::string("snapshot-") + std::to_string(snapshot_version);
  return {snapshot_string.begin(), snapshot_string.end()};
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_TESTUTIL_H_
