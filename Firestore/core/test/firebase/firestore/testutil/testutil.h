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
#include "Firestore/core/src/firebase/firestore/core/field_filter.h"
#include "Firestore/core/src/firebase/firestore/core/order_by.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/delete_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/patch_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/unknown_document.h"
#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {

namespace model {
class TransformMutation;
class TransformOperation;
}  // namespace model

namespace testutil {

/**
 * A string sentinel that can be used with PatchMutation() to mark a field for
 * deletion.
 */
constexpr const char* kDeleteSentinel = "<DELETE>";

// Convenience methods for creating instances for tests.

template <typename... Ints>
nanopb::ByteString Bytes(Ints... octets) {
  return nanopb::ByteString{static_cast<uint8_t>(octets)...};
}

inline model::FieldValue Value(std::nullptr_t) {
  return model::FieldValue::Null();
}

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
EnableForExactlyBool<T, model::FieldValue> Value(T bool_value) {
  return model::FieldValue::FromBoolean(bool_value);
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
EnableForInts<T, model::FieldValue> Value(T value) {
  return model::FieldValue::FromInteger(value);
}

inline model::FieldValue Value(double value) {
  return model::FieldValue::FromDouble(value);
}

inline model::FieldValue Value(Timestamp value) {
  return model::FieldValue::FromTimestamp(value);
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
  return model::DocumentKey::FromPathString(std::string(path));
}

inline model::FieldPath Field(absl::string_view field) {
  return model::FieldPath::FromServerFormat(std::string(field));
}

inline model::DatabaseId DbId(std::string project = "project/(default)") {
  size_t slash = project.find('/');
  if (slash == std::string::npos) {
    return model::DatabaseId(std::move(project), model::DatabaseId::kDefault);
  } else {
    std::string database_id = project.substr(slash + 1);
    project = project.substr(0, slash);
    return model::DatabaseId(std::move(project), std::move(database_id));
  }
}

inline model::FieldValue Ref(std::string project, absl::string_view path) {
  return model::FieldValue::FromReference(DbId(std::move(project)), Key(path));
}

inline model::ResourcePath Resource(absl::string_view field) {
  return model::ResourcePath::FromString(std::string(field));
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
    const model::FieldValue::Map& data = model::FieldValue::Map(),
    model::DocumentState document_state = model::DocumentState::kSynced) {
  return model::Document(model::ObjectValue::FromMap(data), Key(key),
                         Version(version), document_state);
}

inline model::Document Doc(
    absl::string_view key,
    int64_t version,
    const model::FieldValue& data,
    model::DocumentState document_state = model::DocumentState::kSynced) {
  return model::Document(model::ObjectValue(data), Key(key), Version(version),
                         document_state);
}

/** A convenience method for creating deleted docs for tests. */
inline model::NoDocument DeletedDoc(absl::string_view key,
                                    int64_t version = 0,
                                    bool has_committed_mutations = false) {
  return model::NoDocument(Key(key), Version(version), has_committed_mutations);
}

/** A convenience method for creating deleted docs for tests. */
inline model::NoDocument DeletedDoc(model::DocumentKey key,
                                    int64_t version = 0,
                                    bool has_committed_mutations = false) {
  return model::NoDocument(std::move(key), Version(version),
                           has_committed_mutations);
}

/** A convenience method for creating unknown docs for tests. */
inline model::UnknownDocument UnknownDoc(absl::string_view key,
                                         int64_t version) {
  return model::UnknownDocument(Key(key), Version(version));
}

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

inline core::Filter::Operator OperatorFromString(absl::string_view s) {
  if (s == "<") {
    return core::Filter::Operator::LessThan;
  } else if (s == "<=") {
    return core::Filter::Operator::LessThanOrEqual;
  } else if (s == "==") {
    return core::Filter::Operator::Equal;
  } else if (s == ">") {
    return core::Filter::Operator::GreaterThan;
  } else if (s == ">=") {
    return core::Filter::Operator::GreaterThanOrEqual;
    // Both are accepted for compatibility with spec tests and existing
    // canonical ids.
  } else if (s == "array_contains" || s == "array-contains") {
    return core::Filter::Operator::ArrayContains;
  } else if (s == "in") {
    return core::Filter::Operator::In;
  } else if (s == "array-contains-any") {
    return core::Filter::Operator::ArrayContainsAny;
  } else {
    HARD_FAIL("Unknown operator: %s", s);
  }
}

inline core::FieldFilter Filter(absl::string_view key,
                                absl::string_view op,
                                model::FieldValue value) {
  return core::FieldFilter::Create(Field(key), OperatorFromString(op),
                                   std::move(value));
}

inline core::FieldFilter Filter(absl::string_view key,
                                absl::string_view op,
                                model::FieldValue::Map value) {
  return Filter(key, op, model::FieldValue::FromMap(std::move(value)));
}

inline core::FieldFilter Filter(absl::string_view key,
                                absl::string_view op,
                                std::nullptr_t) {
  return Filter(key, op, model::FieldValue::Null());
}

inline core::FieldFilter Filter(absl::string_view key,
                                absl::string_view op,
                                const char* value) {
  return Filter(key, op, model::FieldValue::FromString(value));
}

template <typename T,
          typename = typename std::enable_if<std::is_same<bool, T>{}>::type>
inline core::FieldFilter Filter(absl::string_view key,
                                absl::string_view op,
                                T value) {
  return Filter(key, op, model::FieldValue::FromBoolean(value));
}

inline core::FieldFilter Filter(absl::string_view key,
                                absl::string_view op,
                                int value) {
  return Filter(key, op, model::FieldValue::FromInteger(value));
}

inline core::FieldFilter Filter(absl::string_view key,
                                absl::string_view op,
                                double value) {
  return Filter(key, op, model::FieldValue::FromDouble(value));
}

inline core::Direction Direction(absl::string_view direction) {
  if (direction == "asc") {
    return core::Direction::Ascending;
  } else if (direction == "desc") {
    return core::Direction::Descending;
  } else {
    HARD_FAIL("Unknown direction: %s (use \"asc\" or \"desc\")", direction);
  }
}

inline core::OrderBy OrderBy(absl::string_view key,
                             absl::string_view direction = "asc") {
  return core::OrderBy(Field(key), Direction(direction));
}

inline core::OrderBy OrderBy(model::FieldPath field_path,
                             core::Direction direction) {
  return core::OrderBy(std::move(field_path), direction);
}

inline core::Query Query(absl::string_view path) {
  return core::Query(Resource(path));
}

inline core::Query CollectionGroupQuery(absl::string_view collection_id) {
  return core::Query(model::ResourcePath::Empty(),
                     std::make_shared<const std::string>(collection_id));
}

inline model::SetMutation SetMutation(
    absl::string_view path,
    const model::FieldValue::Map& values = model::FieldValue::Map()) {
  return model::SetMutation(Key(path), model::ObjectValue::FromMap(values),
                            model::Precondition::None());
}

model::PatchMutation PatchMutation(
    absl::string_view path,
    model::FieldValue::Map values = model::FieldValue::Map(),
    std::vector<model::FieldPath> update_mask = {});

model::TransformMutation TransformMutation(
    absl::string_view path,
    std::vector<std::pair<std::string, model::TransformOperation>> transforms);

/**
 * Creates a pair of field name, TransformOperation that represents a numeric
 * increment on the given field, suitable for passing to TransformMutation,
 * above.
 */
std::pair<std::string, model::TransformOperation> Increment(
    std::string field, model::FieldValue operand);

/**
 * Creates a pair of field name, TransformOperation that represents an array
 * union on the given field, suitable for passing to TransformMutation,
 * above.
 */
std::pair<std::string, model::TransformOperation> ArrayUnion(
    std::string field, std::vector<model::FieldValue> operands);

inline model::DeleteMutation DeleteMutation(absl::string_view path) {
  return model::DeleteMutation(Key(path), model::Precondition::None());
}

inline model::MutationResult MutationResult(int64_t version) {
  return model::MutationResult(Version(version), absl::nullopt);
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

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_TESTUTIL_H_
