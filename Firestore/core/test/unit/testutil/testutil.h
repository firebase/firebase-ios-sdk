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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TESTUTIL_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TESTUTIL_H_

#include <algorithm>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/core/core_fwd.h"
#include "Firestore/core/src/core/direction.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/precondition.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "absl/strings/string_view.h"

namespace firebase {
class Timestamp;

namespace firestore {
class GeoPoint;

namespace nanopb {
class ByteString;
}  // namespace nanopb

namespace testutil {
namespace details {

google_firestore_v1_Value BlobValue(std::initializer_list<uint8_t>);

}  // namespace details

// A bit pattern for our canonical NaN value. Exposed here for testing.
ABSL_CONST_INIT extern const uint64_t kCanonicalNanBits;

// Convenience methods for creating instances for tests.

nanopb::ByteString Bytes(std::initializer_list<uint8_t>);

google_firestore_v1_Value Value(std::nullptr_t);

/**
 * A type definition that evaluates to type V only if T is exactly type `bool`.
 */
template <typename T, typename V>
using EnableForExactlyBool =
    typename std::enable_if<std::is_same<bool, T>::value, V>::type;

/**
 * A type definition that evaluates to type V only if T is an integral type but
 * not `bool`.
 */
template <typename T, typename V>
using EnableForInts = typename std::enable_if<std::is_integral<T>::value &&
                                                  !std::is_same<bool, T>::value,
                                              V>::type;

/**
 * Creates a boolean FieldValue.
 *
 * @tparam T A type that must be exactly bool. Any T that is not bool causes
 *     this declaration to be disabled.
 * @param bool_value A boolean value that disallows implicit conversions.
 */
template <typename T>
EnableForExactlyBool<T, google_firestore_v1_Value> Value(T bool_value) {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_boolean_value_tag;
  result.boolean_value = bool_value;
  return result;
}

/**
 * Creates an integer FieldValue.
 *
 * This is defined as a template to capture all integer literals. Just defining
 * this as taking int64_t would make integer literals ambiguous because int64_t
 * and double are equally good choices according to the standard.
 *
 * @tparam T Any integral type (but not bool). Types larger than int64_t will
 *     likely generate a warning.
 * @param value An integer value.
 */
template <typename T>
EnableForInts<T, google_firestore_v1_Value> Value(T value) {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_integer_value_tag;
  result.integer_value = value;
  return result;
}

google_firestore_v1_Value Value(double value);

google_firestore_v1_Value Value(Timestamp value);

google_firestore_v1_Value Value(const char* value);

google_firestore_v1_Value Value(const std::string& value);

google_firestore_v1_Value Value(const nanopb::ByteString& value);

google_firestore_v1_Value Value(const GeoPoint& value);

template <typename... Ints>
google_firestore_v1_Value BlobValue(Ints... octets) {
  return details::BlobValue({static_cast<uint8_t>(octets)...});
}

google_firestore_v1_Value Value(const google_firestore_v1_Value& value);

google_firestore_v1_Value Value(const google_firestore_v1_ArrayValue& value);

google_firestore_v1_Value Value(const model::ObjectValue& value);

namespace details {

/**
 * Recursive base case for AddPairs, below. Returns the map.
 */
inline google_firestore_v1_Value AddPairs(
    const google_firestore_v1_Value& prior) {
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
google_firestore_v1_Value AddPairs(const google_firestore_v1_Value& prior,
                                   const std::string& key,
                                   const ValueType& value,
                                   Args... rest) {
  google_firestore_v1_Value result = prior;
  result.which_value_type = google_firestore_v1_Value_map_value_tag;
  pb_size_t new_count = result.map_value.fields_count + 1;
  result.map_value.fields_count = new_count;
  result.map_value.fields =
      nanopb::ResizeArray<google_firestore_v1_MapValue_FieldsEntry>(
          result.map_value.fields, new_count);
  result.map_value.fields[new_count - 1].key = nanopb::MakeBytesArray(key);
  result.map_value.fields[new_count - 1].value = Value(value);

  return AddPairs(result, rest...);
}

/**
 * Creates an immutable sorted map from the given key/value pairs.
 *
 * @param key_value_pairs Alternating strings naming keys and values that can
 *     be passed to Value().
 */
template <typename... Args>
google_firestore_v1_Value MakeMap(Args... key_value_pairs) {
  google_firestore_v1_Value map_value{};
  map_value.which_value_type = google_firestore_v1_Value_map_value_tag;
  return AddPairs(map_value, key_value_pairs...);
}

}  // namespace details

template <typename... Args>
google_firestore_v1_ArrayValue Array(Args... values) {
  std::vector<google_firestore_v1_Value> contents{Value(values)...};
  google_firestore_v1_ArrayValue result{};
  nanopb::SetRepeatedField(&result.values, &result.values_count, contents);
  return result;
}

/** Wraps an immutable sorted map into an ObjectValue. */
model::ObjectValue WrapObject(const google_firestore_v1_Value& value);

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
google_firestore_v1_Value Map(Args... key_value_pairs) {
  return details::MakeMap(key_value_pairs...);
}

model::DocumentKey Key(absl::string_view path);

model::FieldPath Field(absl::string_view field);

model::DatabaseId DbId(std::string project = "project/(default)");

google_firestore_v1_Value Ref(std::string project, absl::string_view path);

model::ResourcePath Resource(absl::string_view field);

/**
 * Creates a snapshot version from the given version timestamp.
 *
 * @param version a timestamp in microseconds since the epoch.
 */
model::SnapshotVersion Version(int64_t version);

model::MutableDocument Doc(absl::string_view key, int64_t version = 0);

model::MutableDocument Doc(absl::string_view key,
                           int64_t version,
                           const google_firestore_v1_Value& data);

model::MutableDocument Doc(absl::string_view key,
                           int64_t version,
                           const google_firestore_v1_Value& data);

/** A convenience method for creating deleted docs for tests. */
model::MutableDocument DeletedDoc(absl::string_view key, int64_t version = 0);

/** A convenience method for creating deleted docs for tests. */
model::MutableDocument DeletedDoc(model::DocumentKey key, int64_t version = 0);

/** A convenience method for creating unknown docs for tests. */
model::MutableDocument UnknownDoc(absl::string_view key, int64_t version);

/** A convenience method for creating invalid (missing) docs for tests. */
model::MutableDocument InvalidDoc(absl::string_view key);

/**
 * Creates a DocumentComparator that will compare Documents by the given
 * field_path string then by key.
 */
model::DocumentComparator DocComparator(absl::string_view field_path);

/**
 * Creates a DocumentSet based on the given comparator, initially containing the
 * given documents.
 */
model::DocumentSet DocSet(model::DocumentComparator comp,
                          std::vector<model::Document> docs);

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         google_firestore_v1_Value value);

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         google_firestore_v1_ArrayValue value);

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         std::nullptr_t);

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         const char* value);

template <typename T>
EnableForExactlyBool<T, core::FieldFilter> Filter(absl::string_view key,
                                                  absl::string_view op,
                                                  T value) {
  return Filter(key, op, Value(value));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         int value);

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         double value);

core::Direction Direction(absl::string_view direction);

core::OrderBy OrderBy(absl::string_view key,
                      absl::string_view direction = "asc");

core::OrderBy OrderBy(model::FieldPath field_path, core::Direction direction);

core::Query Query(absl::string_view path);

core::Query CollectionGroupQuery(absl::string_view collection_id);

model::SetMutation SetMutation(
    absl::string_view path,
    const google_firestore_v1_Value& values = google_firestore_v1_Value{},
    std::vector<std::pair<std::string, model::TransformOperation>> transforms =
        {});

model::PatchMutation PatchMutation(
    absl::string_view path,
    const google_firestore_v1_Value& values = google_firestore_v1_Value{},
    std::vector<std::pair<std::string, model::TransformOperation>> transforms =
        {});

model::PatchMutation MergeMutation(
    absl::string_view path,
    const google_firestore_v1_Value& values,
    const std::vector<model::FieldPath>& update_mask,
    std::vector<std::pair<std::string, model::TransformOperation>> transforms =
        {});

model::PatchMutation PatchMutationHelper(
    absl::string_view path,
    const google_firestore_v1_Value& values,
    std::vector<std::pair<std::string, model::TransformOperation>> transforms,
    model::Precondition precondition,
    const absl::optional<std::vector<model::FieldPath>>& update_mask);

/**
 * Creates a pair of field name, TransformOperation that represents a numeric
 * increment on the given field, suitable for passing to TransformMutation,
 * above.
 */
std::pair<std::string, model::TransformOperation> Increment(
    std::string field, google_firestore_v1_Value operand);

/**
 * Creates a pair of field name, TransformOperation that represents an array
 * union on the given field, suitable for passing to TransformMutation,
 * above.
 */
std::pair<std::string, model::TransformOperation> ArrayUnion(
    std::string field, std::vector<google_firestore_v1_Value> operands);

model::DeleteMutation DeleteMutation(absl::string_view path);

model::VerifyMutation VerifyMutation(absl::string_view path, int64_t version);

model::MutationResult MutationResult(int64_t version);

nanopb::ByteString ResumeToken(int64_t snapshot_version);

template <typename T, typename... Ts>
std::vector<T> Vector(T&& arg1, Ts&&... args) {
  return {std::forward<T>(arg1), std::forward<Ts>(args)...};
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
// work with `initializer_list`. Desired (doesn't work):
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

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TESTUTIL_H_
