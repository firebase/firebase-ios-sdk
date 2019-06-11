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
#include <cstddef>
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
#include "Firestore/core/src/firebase/firestore/model/unknown_document.h"
#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"
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

// Convenience methods for creating instances for tests.

inline model::FieldValue Value(std::nullptr_t) {
  return model::FieldValue::Null();
}

/**
 * Creates a boolean FieldValue.
 *
 * @param bool_value A boolean value that disallows implicit conversions.
 */
template <typename T,
          typename = typename std::enable_if<std::is_same<bool, T>{}>::type>
inline model::FieldValue Value(T bool_value) {
  return model::FieldValue::FromBoolean(bool_value);
}

// Overload that captures integer literals. Without this, int64_t and double
// are equally applicable conversions.
inline model::FieldValue Value(int value) {
  return model::FieldValue::FromInteger(value);
}

inline model::FieldValue Value(int64_t value) {
  return model::FieldValue::FromInteger(value);
}

inline model::FieldValue Value(double value) {
  return model::FieldValue::FromDouble(value);
}

inline model::FieldValue Value(Timestamp value) {
  return model::FieldValue::FromTimestamp(std::move(value));
}

inline model::FieldValue Value(const char* value) {
  return model::FieldValue::FromString(value);
}

inline model::FieldValue Value(const std::string& value) {
  return model::FieldValue::FromString(value);
}

inline model::FieldValue Value(const GeoPoint& value) {
  return model::FieldValue::FromGeoPoint(value);
}

template <typename... Ints>
model::FieldValue BlobValue(Ints... octets) {
  nanopb::ByteString contents{static_cast<uint8_t>(octets)...};
  return model::FieldValue::FromBlob(std::move(contents));
}

// This overload allows Object() to appear as a value (along with any explicitly
// constructed FieldValues).
inline model::FieldValue Value(const model::FieldValue& value) {
  return value;
}

inline model::FieldValue Value(const model::ObjectValue& value) {
  return value.AsFieldValue();
}

inline model::FieldValue Value(const model::FieldValue::Map& value) {
  return Value(model::ObjectValue::FromMap(value));
}

inline model::FieldValue ArrayValue(std::vector<model::FieldValue>&& value) {
  return model::FieldValue::FromArray(std::move(value));
}

namespace details {

/**
 * Recursive base case for AddPairs, below. Returns the map.
 */
inline model::FieldValue::Map AddPairs(const model::FieldValue::Map& prior) {
  return prior;
}

/**
 * Inserts the given key-value pair into the map, and then recursively calls
 * AddPairs to add any remaining arguments.
 *
 * @param prior A map into which the values should be inserted.
 * @param key The key naming the field to insert.
 * @param value A value to wrap with a call to Value(), above.
 * @param rest Any remaining arguments
 *
 * @return The resulting map.
 */
template <typename ValueType, typename... Args>
model::FieldValue::Map AddPairs(const model::FieldValue::Map& prior,
                                const std::string& key,
                                const ValueType& value,
                                Args... rest) {
  return AddPairs(prior.insert(key, Value(value)), rest...);
}

/**
 * Creates an immutable sorted map from the given key/value pairs.
 *
 * @param key_value_pairs Alternating strings naming keys and values that can
 *     be passed to Value().
 */
template <typename... Args>
model::FieldValue::Map MakeMap(Args... key_value_pairs) {
  return AddPairs(model::FieldValue::Map(), key_value_pairs...);
}

}  // namespace details

inline model::FieldValue Array(const model::FieldValue::Array& value) {
  return model::FieldValue::FromArray(value);
}

template <typename... Args>
inline model::FieldValue Array(Args... values) {
  model::FieldValue::Array contents{Value(values)...};
  return model::FieldValue::FromArray(std::move(contents));
}

/** Wraps an immutable sorted map into an ObjectValue. */
inline model::ObjectValue WrapObject(const model::FieldValue::Map& value) {
  return model::ObjectValue::FromMap(value);
}

/**
 * Creates an ObjectValue from the given key/value pairs.
 *
 * @param key_value_pairs Alternating strings naming keys and values that can
 *     be passed to Value().
 */
template <typename... Args>
model::ObjectValue WrapObject(Args... key_value_pairs) {
  return WrapObject(details::MakeMap(key_value_pairs...));
}

/**
 * Creates an ObjectValue from the given key/value pairs with Type::Object.
 *
 * @param key_value_pairs Alternating strings naming keys and values that can
 *     be passed to Value().
 */
template <typename... Args>
model::FieldValue::Map Map(Args... key_value_pairs) {
  return details::MakeMap(key_value_pairs...);
}

inline model::DocumentKey Key(absl::string_view path) {
  return model::DocumentKey::FromPathString(path);
}

inline model::FieldPath Field(absl::string_view field) {
  return model::FieldPath::FromServerFormat(field);
}

inline model::DatabaseId DbId(std::string project, std::string database) {
  return model::DatabaseId(std::move(project), std::move(database));
}

inline model::DatabaseId DbId(std::string project) {
  return model::DatabaseId(std::move(project), model::DatabaseId::kDefault);
}

inline model::DatabaseId DbId() {
  return model::DatabaseId("project", model::DatabaseId::kDefault);
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

inline std::shared_ptr<model::Document> Doc(
    absl::string_view key,
    int64_t version = 0,
    const model::FieldValue::Map& data = model::FieldValue::Map(),
    model::DocumentState document_state = model::DocumentState::kSynced) {
  return std::make_shared<model::Document>(model::ObjectValue::FromMap(data),
                                           Key(key), Version(version),
                                           document_state);
}

inline std::shared_ptr<model::NoDocument> DeletedDoc(absl::string_view key,
                                                     int64_t version) {
  return std::make_shared<model::NoDocument>(Key(key), Version(version),
                                             /*has_committed_mutations=*/false);
}

inline std::shared_ptr<model::UnknownDocument> UnknownDoc(absl::string_view key,
                                                          int64_t version) {
  return std::make_shared<model::UnknownDocument>(Key(key), Version(version));
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
    absl::string_view path,
    const model::FieldValue::Map& values = model::FieldValue::Map()) {
  return absl::make_unique<model::SetMutation>(
      Key(path), model::ObjectValue::FromMap(values),
      model::Precondition::None());
}

std::unique_ptr<model::PatchMutation> PatchMutation(
    absl::string_view path,
    const model::FieldValue::Map& values = model::FieldValue::Map(),
    const std::vector<model::FieldPath>* update_mask = nullptr);

inline std::unique_ptr<model::PatchMutation> PatchMutation(
    absl::string_view path,
    const model::FieldValue::Map& values,
    const std::vector<model::FieldPath>& update_mask) {
  return PatchMutation(path, values, &update_mask);
}

inline std::unique_ptr<model::DeleteMutation> DeleteMutation(
    absl::string_view path) {
  return absl::make_unique<model::DeleteMutation>(Key(path),
                                                  model::Precondition::None());
}

inline model::MutationResult MutationResult(int64_t version) {
  return model::MutationResult(Version(version), nullptr);
}

inline nanopb::ByteString ResumeToken(int64_t snapshot_version) {
  if (snapshot_version == 0) {
    // TODO(rsgowman): The other platforms return null here, though I'm not sure
    // if they ever rely on that. I suspect it'd be sufficient to return '{}'.
    // But for now, we'll just abort() until we hit a test case that actually
    // makes use of this.
    abort();
  }

  std::string snapshot_string =
      std::string("snapshot-") + std::to_string(snapshot_version);
  return nanopb::ByteString(snapshot_string);
}

// Degenerate case to end recursion of `MoveIntoVector`.
template <typename T>
void MoveIntoVector(std::vector<std::unique_ptr<T>>*) {
}

template <typename T, typename Head, typename... Tail>
void MoveIntoVector(std::vector<std::unique_ptr<T>>* result,
                    Head head,
                    Tail... tail) {
  result->push_back(std::move(head));
  MoveIntoVector(result, std::move(tail)...);
}

// Works around the fact that move-only types (in this case, `unique_ptr`) don't
// work with `initialzer_list`. Desired (doesn't work):
//
//   std::unique_ptr<int> x, y;
//   std::vector<std::unique_ptr>> foo{std::move(x), std::move(y)};
//
// Actual:
//
//   std::unique_ptr<int> x, y;
//   std::vector<std::unique_ptr<int>> foo = Changes(std::move(x),
//   std::move(y));
template <typename T, typename... Elems>
std::vector<std::unique_ptr<T>> VectorOfUniquePtrs(Elems... elems) {
  std::vector<std::unique_ptr<T>> result;
  MoveIntoVector<T>(&result, std::move(elems)...);
  return result;
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_TESTUTIL_H_
