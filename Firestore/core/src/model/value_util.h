/*
 * Copyright 2021 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_MODEL_VALUE_UTIL_H_
#define FIRESTORE_CORE_SRC_MODEL_VALUE_UTIL_H_

#include <ostream>
#include <string>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {

namespace util {
enum class ComparisonResult;
}

namespace model {

class DocumentKey;
class DatabaseId;

/** The smallest reference value. */
extern pb_bytes_array_s* kMinimumReferenceValue;

/** The field type of a special object type. */
extern const char* kRawTypeValueFieldKey;
extern pb_bytes_array_s* kTypeValueFieldKey;

/** The field value of a maximum proto value. */
extern const char* kRawMaxValueFieldValue;
extern pb_bytes_array_s* kMaxValueFieldValue;

/** The type of a VectorValue proto. */
extern const char* kRawVectorTypeFieldValue;
extern pb_bytes_array_s* kVectorTypeFieldValue;

/** The  value key of a VectorValue proto. */
extern const char* kRawVectorValueFieldKey;
extern pb_bytes_array_s* kVectorValueFieldKey;

/** The key of a MinKey in a map proto. */
extern const char* kRawMinKeyTypeFieldValue;
extern pb_bytes_array_s* kMinKeyTypeFieldValue;

/** The key of a MaxKey in a map proto. */
extern const char* kRawMaxKeyTypeFieldValue;
extern pb_bytes_array_s* kMaxKeyTypeFieldValue;

/** The key of a regex in a map proto. */
extern const char* kRawRegexTypeFieldValue;
extern pb_bytes_array_s* kRegexTypeFieldValue;

/** The regex pattern key. */
extern const char* kRawRegexTypePatternFieldValue;
extern pb_bytes_array_s* kRegexTypePatternFieldValue;

/** The regex options key. */
extern const char* kRawRegexTypeOptionsFieldValue;
extern pb_bytes_array_s* kRegexTypeOptionsFieldValue;

/** The key of an int32 in a map proto. */
extern const char* kRawInt32TypeFieldValue;
extern pb_bytes_array_s* kInt32TypeFieldValue;

/** The key of a BSON ObjectId in a map proto. */
extern const char* kRawBsonObjectIdTypeFieldValue;
extern pb_bytes_array_s* kBsonObjectIdTypeFieldValue;

/** The key of a BSON Timestamp in a map proto. */
extern const char* kRawBsonTimestampTypeFieldValue;
extern pb_bytes_array_s* kBsonTimestampTypeFieldValue;

/** The key of a BSON Timestamp seconds in a map proto. */
extern const char* kRawBsonTimestampTypeSecondsFieldValue;
extern pb_bytes_array_s* kBsonTimestampTypeSecondsFieldValue;

/** The key of a BSON Timestamp increment in a map proto. */
extern const char* kRawBsonTimestampTypeIncrementFieldValue;
extern pb_bytes_array_s* kBsonTimestampTypeIncrementFieldValue;

/** The key of a BSON Binary Data in a map proto. */
extern const char* kRawBsonBinaryDataTypeFieldValue;
extern pb_bytes_array_s* kBsonBinaryDataTypeFieldValue;

/**
 * The order of types in Firestore. This order is based on the backend's
 * ordering, but modified to support server timestamps and `MAX_VALUE` inside
 * the SDK.
 */
enum class TypeOrder {
  kNull = 0,
  kMinKey = 1,
  kBoolean = 2,
  // Note: all numbers (32-bit int, 64-bit int, 64-bit double, 128-bit decimal,
  // etc.) are sorted together numerically. The `CompareNumbers` function
  // distinguishes between different number types and compares them accordingly.
  kNumber = 3,
  kTimestamp = 4,
  kBsonTimestamp = 5,
  kServerTimestamp = 6,
  kString = 7,
  kBlob = 8,
  kBsonBinaryData = 9,
  kReference = 10,
  kBsonObjectId = 11,
  kGeoPoint = 12,
  kRegex = 13,
  kArray = 14,
  kVector = 15,
  kMap = 16,
  kMaxKey = 17,
  kMaxValue = 18
};

/**
 * The type that a Map is used to represent.
 * Most Maps are NORMAL maps, however, some maps are used to identify more
 * complex types.
 */
enum class MapType {
  kNormal = 0,
  kServerTimestamp = 1,
  kMaxValue = 2,
  kVector = 3,
  kMinKey = 4,
  kMaxKey = 5,
  kRegex = 6,
  kInt32 = 7,
  kBsonObjectId = 8,
  kBsonTimestamp = 9,
  kBsonBinaryData = 10
};

/** Returns the Map type for the given value. */
MapType DetectMapType(const google_firestore_v1_Value& value);

/** Returns the backend's type order of the given Value type. */
TypeOrder GetTypeOrder(const google_firestore_v1_Value& value);

/** Traverses a Value proto and sorts all MapValues by key. */
void SortFields(google_firestore_v1_Value& value);

/** Traverses an ArrayValue proto and sorts all MapValues by key. */
void SortFields(google_firestore_v1_ArrayValue& value);

util::ComparisonResult Compare(const google_firestore_v1_Value& left,
                               const google_firestore_v1_Value& right);
util::ComparisonResult LowerBoundCompare(const google_firestore_v1_Value& left,
                                         bool left_inclusive,
                                         const google_firestore_v1_Value& right,
                                         bool right_inclusive);
util::ComparisonResult UpperBoundCompare(const google_firestore_v1_Value& left,
                                         bool left_inclusive,
                                         const google_firestore_v1_Value& right,
                                         bool right_inclusive);

bool Equals(const google_firestore_v1_Value& left,
            const google_firestore_v1_Value& right);

bool Equals(const google_firestore_v1_ArrayValue& left,
            const google_firestore_v1_ArrayValue& right);

/**
 * Generates the canonical ID for the provided field value (as used in Target
 * serialization).
 */
std::string CanonicalId(const google_firestore_v1_Value& value);

/**
 * Returns the lowest value for the given value type (inclusive).
 *
 * The returned value might point to heap allocated memory that is owned by
 * this function. To take ownership of this memory, call `DeepClone`.
 */
google_firestore_v1_Value GetLowerBound(const google_firestore_v1_Value& value);

/**
 * Returns the largest value for the given value type (exclusive).
 *
 * The returned value might point to heap allocated memory that is owned by
 * this function. To take ownership of this memory, call `DeepClone`.
 */
google_firestore_v1_Value GetUpperBound(const google_firestore_v1_Value& value);

/**
 * Generates the canonical ID for the provided array value (as used in Target
 * serialization).
 */
std::string CanonicalId(const google_firestore_v1_ArrayValue& value);

/** Returns true if the array value contains the specified element. */
bool Contains(google_firestore_v1_ArrayValue haystack,
              google_firestore_v1_Value needle);

/**
 * Returns a null Protobuf value.
 *
 * The returned value might point to heap allocated memory that is owned by
 * this function. To take ownership of this memory, call `DeepClone`.
 */
google_firestore_v1_Value NullValue();

/** Returns `true` if `value` is null in its Protobuf representation. */
bool IsNullValue(const google_firestore_v1_Value& value);

/**
 * Returns a Protobuf value that is smaller than any legitimate value SDK
 * users can create. Under the hood, it is a `NullValue()`.
 *
 * The returned value might point to heap allocated memory that is owned by
 * this function. To take ownership of this memory, call `DeepClone`.
 */
google_firestore_v1_Value MinValue();

/** Returns `true` if `value` is MinValue() in its Protobuf representation. */
bool IsMinValue(const google_firestore_v1_Value& value);

/**
 * Returns a Protobuf value that is larger than any legitimate value SDK
 * users can create.
 *
 * Under the hood, it is a sentinel Protobuf Map with special fields that
 * Firestore comparison logic always return true for `MaxValue() > v`, for any
 * v users can create, regardless `v`'s type and value.
 *
 * The returned value might point to heap allocated memory that is owned by
 * this function. To take ownership of this memory, call `DeepClone`.
 */
google_firestore_v1_Value MaxValue();

/**
 * Returns `true` if `value` is equal to `MaxValue()`.
 */
bool IsMaxValue(const google_firestore_v1_Value& value);

/**
 * Returns `true` if `value` represents a VectorValue.
 */
bool IsVectorValue(const google_firestore_v1_Value& value);

/**
 * Returns `true` if `value` represents a MinKey.
 */
bool IsMinKeyValue(const google_firestore_v1_Value& value);

/**
 * Returns `true` if `value` represents a MaxKey.
 */
bool IsMaxKeyValue(const google_firestore_v1_Value& value);

/**
 * Returns `true` if `value` represents a RegexValue.
 */
bool IsRegexValue(const google_firestore_v1_Value& value);

/**
 * Returns `true` if `value` represents an Int32Value.
 */
bool IsInt32Value(const google_firestore_v1_Value& value);

/**
 * Returns `true` if `value` represents a BsonObjectId.
 */
bool IsBsonObjectId(const google_firestore_v1_Value& value);

/**
 * Returns `true` if `value` represents a BsonTimestamp.
 */
bool IsBsonTimestamp(const google_firestore_v1_Value& value);

/**
 * Returns `true` if `value` represents a BsonBinaryData.
 */
bool IsBsonBinaryData(const google_firestore_v1_Value& value);

/** Returns true if `value` is a BSON Type. */
bool IsBsonType(const google_firestore_v1_Value& value);

/**
 * Returns the index of the specified key (`kRawTypeValueFieldKey`) in the
 * map (`mapValue`). `kTypeValueFieldKey` is an alternative representation
 * of the key specified in `kRawTypeValueFieldKey`.
 * If the key is not found, then `absl::nullopt` is returned.
 */
absl::optional<pb_size_t> IndexOfKey(
    const google_firestore_v1_MapValue& mapValue,
    const char* kRawTypeValueFieldKey,
    pb_bytes_array_s* kTypeValueFieldKey);

/**
 * Returns `NaN` in its Protobuf representation.
 *
 * The returned value might point to heap allocated memory that is owned by
 * this function. To take ownership of this memory, call `DeepClone`.
 */
google_firestore_v1_Value NaNValue();

/** Returns `true` if `value` is `NaN` in its Protobuf representation. */
bool IsNaNValue(const google_firestore_v1_Value& value);

google_firestore_v1_Value MinBoolean();

google_firestore_v1_Value MinNumber();

google_firestore_v1_Value MinTimestamp();

google_firestore_v1_Value MinString();

google_firestore_v1_Value MinBytes();

google_firestore_v1_Value MinReference();

google_firestore_v1_Value MinGeoPoint();

google_firestore_v1_Value MinBsonBinaryData();

google_firestore_v1_Value MinBsonObjectId();

google_firestore_v1_Value MinBsonTimestamp();

google_firestore_v1_Value MinRegex();

google_firestore_v1_Value MinArray();

google_firestore_v1_Value MinVector();

google_firestore_v1_Value MinMap();

/**
 * Returns a Protobuf reference value representing the given location.
 *
 * The returned value might point to heap allocated memory that is owned by
 * this function. To take ownership of this memory, call `DeepClone`.
 */
nanopb::Message<google_firestore_v1_Value> RefValue(
    const DatabaseId& database_id, const DocumentKey& document_key);

/** Creates a copy of the contents of the Value proto. */
nanopb::Message<google_firestore_v1_Value> DeepClone(
    const google_firestore_v1_Value& source);

/** Creates a copy of the contents of the ArrayValue proto. */
nanopb::Message<google_firestore_v1_ArrayValue> DeepClone(
    const google_firestore_v1_ArrayValue& source);

/** Creates a copy of the contents of the MapValue proto. */
nanopb::Message<google_firestore_v1_MapValue> DeepClone(
    const google_firestore_v1_MapValue& source);

/** Returns true if `value` is a INTEGER_VALUE. */
inline bool IsInteger(const absl::optional<google_firestore_v1_Value>& value) {
  return value &&
         value->which_value_type == google_firestore_v1_Value_integer_value_tag;
}

/** Returns true if `value` is a DOUBLE_VALUE. */
inline bool IsDouble(const absl::optional<google_firestore_v1_Value>& value) {
  return value &&
         value->which_value_type == google_firestore_v1_Value_double_value_tag;
}

/** Returns true if `value` is either a INTEGER_VALUE or a DOUBLE_VALUE. */
inline bool IsNumber(const absl::optional<google_firestore_v1_Value>& value) {
  return IsInteger(value) || IsDouble(value);
}

/** Returns true if `value` is an ARRAY_VALUE. */
inline bool IsArray(const absl::optional<google_firestore_v1_Value>& value) {
  return value &&
         value->which_value_type == google_firestore_v1_Value_array_value_tag;
}

/** Returns true if `value` is a MAP_VALUE. */
inline bool IsMap(const absl::optional<google_firestore_v1_Value>& value) {
  return value &&
         value->which_value_type == google_firestore_v1_Value_map_value_tag;
}

}  // namespace model

inline bool operator==(const google_firestore_v1_Value& lhs,
                       const google_firestore_v1_Value& rhs) {
  return model::Equals(lhs, rhs);
}

inline bool operator!=(const google_firestore_v1_Value& lhs,
                       const google_firestore_v1_Value& rhs) {
  return !model::Equals(lhs, rhs);
}

inline bool operator==(const google_firestore_v1_ArrayValue& lhs,
                       const google_firestore_v1_ArrayValue& rhs) {
  return model::Equals(lhs, rhs);
}

inline bool operator!=(const google_firestore_v1_ArrayValue& lhs,
                       const google_firestore_v1_ArrayValue& rhs) {
  return !model::Equals(lhs, rhs);
}

inline std::ostream& operator<<(std::ostream& out,
                                const google_firestore_v1_Value& value) {
  return out << model::CanonicalId(value);
}

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_VALUE_UTIL_H_
