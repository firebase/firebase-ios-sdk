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

#include "Firestore/core/src/model/value_util.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <memory>
#include <type_traits>
#include <utility>
#include <vector>

#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/escaping.h"
#include "absl/strings/str_format.h"
#include "absl/strings/str_join.h"
#include "absl/strings/str_split.h"

namespace firebase {
namespace firestore {
namespace model {

using nanopb::Message;
using util::ComparisonResult;

/** The smallest reference value. */
pb_bytes_array_s* kMinimumReferenceValue =
    nanopb::MakeBytesArray("projects//databases//documents/");

/** The field type of a special object type. */
const char* kRawTypeValueFieldKey = "__type__";
pb_bytes_array_s* kTypeValueFieldKey =
    nanopb::MakeBytesArray(kRawTypeValueFieldKey);

/** The field value of a maximum proto value. */
const char* kRawMaxValueFieldValue = "__max__";
pb_bytes_array_s* kMaxValueFieldValue =
    nanopb::MakeBytesArray(kRawMaxValueFieldValue);

/** The type of a VectorValue proto. */
const char* kRawVectorTypeFieldValue = "__vector__";
pb_bytes_array_s* kVectorTypeFieldValue =
    nanopb::MakeBytesArray(kRawVectorTypeFieldValue);

/** The  value key of a VectorValue proto. */
const char* kRawVectorValueFieldKey = "value";
pb_bytes_array_s* kVectorValueFieldKey =
    nanopb::MakeBytesArray(kRawVectorValueFieldKey);

TypeOrder GetTypeOrder(const google_firestore_v1_Value& value) {
  switch (value.which_value_type) {
    case google_firestore_v1_Value_null_value_tag:
      return TypeOrder::kNull;

    case google_firestore_v1_Value_boolean_value_tag:
      return TypeOrder::kBoolean;

    case google_firestore_v1_Value_integer_value_tag:
    case google_firestore_v1_Value_double_value_tag:
      return TypeOrder::kNumber;

    case google_firestore_v1_Value_timestamp_value_tag:
      return TypeOrder::kTimestamp;

    case google_firestore_v1_Value_string_value_tag:
      return TypeOrder::kString;

    case google_firestore_v1_Value_bytes_value_tag:
      return TypeOrder::kBlob;

    case google_firestore_v1_Value_reference_value_tag:
      return TypeOrder::kReference;

    case google_firestore_v1_Value_geo_point_value_tag:
      return TypeOrder::kGeoPoint;

    case google_firestore_v1_Value_array_value_tag:
      return TypeOrder::kArray;

    case google_firestore_v1_Value_map_value_tag: {
      if (IsServerTimestamp(value)) {
        return TypeOrder::kServerTimestamp;
      } else if (IsMaxValue(value)) {
        return TypeOrder::kMaxValue;
      } else if (IsVectorValue(value)) {
        return TypeOrder::kVector;
      }
      return TypeOrder::kMap;
    }

    default:
      HARD_FAIL("Invalid type value: %s", value.which_value_type);
  }
}

void SortFields(google_firestore_v1_ArrayValue& value) {
  for (pb_size_t i = 0; i < value.values_count; ++i) {
    SortFields(value.values[i]);
  }
}

void SortFields(google_firestore_v1_MapValue& value) {
  std::sort(value.fields, value.fields + value.fields_count,
            [](const google_firestore_v1_MapValue_FieldsEntry& lhs,
               const google_firestore_v1_MapValue_FieldsEntry& rhs) {
              return nanopb::MakeStringView(lhs.key) <
                     nanopb::MakeStringView(rhs.key);
            });

  for (pb_size_t i = 0; i < value.fields_count; ++i) {
    SortFields(value.fields[i].value);
  }
}

void SortFields(google_firestore_v1_Value& value) {
  if (IsMap(value)) {
    SortFields(value.map_value);
  } else if (IsArray(value)) {
    SortFields(value.array_value);
  }
}

ComparisonResult CompareNumbers(const google_firestore_v1_Value& left,
                                const google_firestore_v1_Value& right) {
  if (left.which_value_type == google_firestore_v1_Value_double_value_tag) {
    double left_double = left.double_value;
    if (right.which_value_type == google_firestore_v1_Value_double_value_tag) {
      return util::Compare(left_double, right.double_value);
    } else {
      return util::CompareMixedNumber(left_double, right.integer_value);
    }
  } else {
    int64_t left_long = left.integer_value;
    if (right.which_value_type == google_firestore_v1_Value_integer_value_tag) {
      return util::Compare(left_long, right.integer_value);
    } else {
      return util::ReverseOrder(
          util::CompareMixedNumber(right.double_value, left_long));
    }
  }
}

ComparisonResult CompareTimestamps(const google_protobuf_Timestamp& left,
                                   const google_protobuf_Timestamp& right) {
  ComparisonResult cmp = util::Compare(left.seconds, right.seconds);
  if (cmp != ComparisonResult::Same) {
    return cmp;
  }
  return util::Compare(left.nanos, right.nanos);
}

ComparisonResult CompareStrings(const google_firestore_v1_Value& left,
                                const google_firestore_v1_Value& right) {
  absl::string_view left_string = nanopb::MakeStringView(left.string_value);
  absl::string_view right_string = nanopb::MakeStringView(right.string_value);
  return util::Compare(left_string, right_string);
}

ComparisonResult CompareBlobs(const google_firestore_v1_Value& left,
                              const google_firestore_v1_Value& right) {
  if (left.bytes_value && right.bytes_value) {
    size_t size = std::min(left.bytes_value->size, right.bytes_value->size);
    int cmp =
        std::memcmp(left.bytes_value->bytes, right.bytes_value->bytes, size);
    return cmp != 0
               ? util::ComparisonResultFromInt(cmp)
               : util::Compare(left.bytes_value->size, right.bytes_value->size);
  } else {
    // An empty blob is represented by a nullptr (or an empty byte array)
    return util::Compare(
        !(left.bytes_value == nullptr || left.bytes_value->size == 0),
        !(right.bytes_value == nullptr || right.bytes_value->size == 0));
  }
}

ComparisonResult CompareReferences(const google_firestore_v1_Value& left,
                                   const google_firestore_v1_Value& right) {
  std::vector<std::string> left_segments = absl::StrSplit(
      nanopb::MakeStringView(left.reference_value), '/', absl::SkipEmpty());
  std::vector<std::string> right_segments = absl::StrSplit(
      nanopb::MakeStringView(right.reference_value), '/', absl::SkipEmpty());

  size_t min_length = std::min(left_segments.size(), right_segments.size());
  for (size_t i = 0; i < min_length; ++i) {
    ComparisonResult cmp = util::Compare(left_segments[i], right_segments[i]);
    if (cmp != ComparisonResult::Same) {
      return cmp;
    }
  }
  return util::Compare(left_segments.size(), right_segments.size());
}

ComparisonResult CompareGeoPoints(const google_firestore_v1_Value& left,
                                  const google_firestore_v1_Value& right) {
  ComparisonResult cmp = util::Compare(left.geo_point_value.latitude,
                                       right.geo_point_value.latitude);
  if (cmp != ComparisonResult::Same) {
    return cmp;
  }
  return util::Compare(left.geo_point_value.longitude,
                       right.geo_point_value.longitude);
}

ComparisonResult CompareArrays(const google_firestore_v1_Value& left,
                               const google_firestore_v1_Value& right) {
  int min_length =
      std::min(left.array_value.values_count, right.array_value.values_count);
  for (int i = 0; i < min_length; ++i) {
    ComparisonResult cmp =
        Compare(left.array_value.values[i], right.array_value.values[i]);
    if (cmp != ComparisonResult::Same) {
      return cmp;
    }
  }
  return util::Compare(left.array_value.values_count,
                       right.array_value.values_count);
}

ComparisonResult CompareMaps(const google_firestore_v1_MapValue& left,
                             const google_firestore_v1_MapValue& right) {
  // Sort the given MapValues
  auto left_map = DeepClone(left);
  auto right_map = DeepClone(right);
  SortFields(*left_map);
  SortFields(*right_map);

  for (pb_size_t i = 0;
       i < left_map->fields_count && i < right_map->fields_count; ++i) {
    const ComparisonResult key_cmp =
        util::Compare(nanopb::MakeStringView(left_map->fields[i].key),
                      nanopb::MakeStringView(right_map->fields[i].key));
    if (key_cmp != ComparisonResult::Same) {
      return key_cmp;
    }

    const ComparisonResult value_cmp =
        Compare(left_map->fields[i].value, right_map->fields[i].value);
    if (value_cmp != ComparisonResult::Same) {
      return value_cmp;
    }
  }

  return util::Compare(left_map->fields_count, right_map->fields_count);
}

ComparisonResult CompareVectors(const google_firestore_v1_Value& left,
                                const google_firestore_v1_Value& right) {
  HARD_ASSERT(IsVectorValue(left) && IsVectorValue(right),
              "Cannot compare non-vector values as vectors.");

  absl::optional<pb_size_t> leftIndex =
      IndexOfKey(left.map_value, kRawVectorValueFieldKey, kVectorValueFieldKey);
  absl::optional<pb_size_t> rightIndex = IndexOfKey(
      right.map_value, kRawVectorValueFieldKey, kVectorValueFieldKey);

  pb_size_t leftArrayLength = 0;
  google_firestore_v1_Value leftArray;
  if (leftIndex.has_value()) {
    leftArray = left.map_value.fields[leftIndex.value()].value;
    leftArrayLength = leftArray.array_value.values_count;
  }

  pb_size_t rightArrayLength = 0;
  google_firestore_v1_Value rightArray;
  if (leftIndex.has_value()) {
    rightArray = right.map_value.fields[rightIndex.value()].value;
    rightArrayLength = rightArray.array_value.values_count;
  }

  if (leftArrayLength == 0 && rightArrayLength == 0) {
    return ComparisonResult::Same;
  }

  ComparisonResult lengthCompare =
      util::Compare(leftArrayLength, rightArrayLength);
  if (lengthCompare != ComparisonResult::Same) {
    return lengthCompare;
  }

  return CompareArrays(leftArray, rightArray);
}

ComparisonResult Compare(const google_firestore_v1_Value& left,
                         const google_firestore_v1_Value& right) {
  TypeOrder left_type = GetTypeOrder(left);
  TypeOrder right_type = GetTypeOrder(right);

  if (left_type != right_type) {
    return util::Compare(left_type, right_type);
  }

  switch (left_type) {
    case TypeOrder::kNull:
      return ComparisonResult::Same;

    case TypeOrder::kBoolean:
      return util::Compare(left.boolean_value, right.boolean_value);

    case TypeOrder::kNumber:
      return CompareNumbers(left, right);

    case TypeOrder::kTimestamp:
      return CompareTimestamps(left.timestamp_value, right.timestamp_value);

    case TypeOrder::kServerTimestamp:
      return CompareTimestamps(GetLocalWriteTime(left),
                               GetLocalWriteTime(right));

    case TypeOrder::kString:
      return CompareStrings(left, right);

    case TypeOrder::kBlob:
      return CompareBlobs(left, right);

    case TypeOrder::kReference:
      return CompareReferences(left, right);

    case TypeOrder::kGeoPoint:
      return CompareGeoPoints(left, right);

    case TypeOrder::kArray:
      return CompareArrays(left, right);

    case TypeOrder::kMap:
      return CompareMaps(left.map_value, right.map_value);

    case TypeOrder::kVector:
      return CompareVectors(left, right);

    case TypeOrder::kMaxValue:
      return util::ComparisonResult::Same;

    default:
      HARD_FAIL("Invalid type value: %s", left_type);
  }
}

ComparisonResult LowerBoundCompare(const google_firestore_v1_Value& left,
                                   bool left_inclusive,
                                   const google_firestore_v1_Value& right,
                                   bool right_inclusive) {
  auto cmp = Compare(left, right);
  if (cmp != util::ComparisonResult::Same) {
    return cmp;
  }

  if (left_inclusive && !right_inclusive) {
    return util::ComparisonResult::Ascending;
  } else if (!left_inclusive && right_inclusive) {
    return util::ComparisonResult::Descending;
  }

  return util::ComparisonResult::Same;
}

ComparisonResult UpperBoundCompare(const google_firestore_v1_Value& left,
                                   bool left_inclusive,
                                   const google_firestore_v1_Value& right,
                                   bool right_inclusive) {
  auto cmp = Compare(left, right);
  if (cmp != util::ComparisonResult::Same) {
    return cmp;
  }

  if (left_inclusive && !right_inclusive) {
    return util::ComparisonResult::Descending;
  } else if (!left_inclusive && right_inclusive) {
    return util::ComparisonResult::Ascending;
  }

  return util::ComparisonResult::Same;
}

bool NumberEquals(const google_firestore_v1_Value& left,
                  const google_firestore_v1_Value& right) {
  if (left.which_value_type == google_firestore_v1_Value_integer_value_tag &&
      right.which_value_type == google_firestore_v1_Value_integer_value_tag) {
    return left.integer_value == right.integer_value;
  } else if (left.which_value_type ==
                 google_firestore_v1_Value_double_value_tag &&
             right.which_value_type ==
                 google_firestore_v1_Value_double_value_tag) {
    return util::DoubleBitwiseEquals(left.double_value, right.double_value);
  }
  return false;
}

bool ArrayEquals(const google_firestore_v1_ArrayValue& left,
                 const google_firestore_v1_ArrayValue& right) {
  if (left.values_count != right.values_count) {
    return false;
  }

  for (size_t i = 0; i < left.values_count; ++i) {
    if (left.values[i] != right.values[i]) {
      return false;
    }
  }

  return true;
}

bool MapValueEquals(const google_firestore_v1_MapValue& left,
                    const google_firestore_v1_MapValue& right) {
  if (left.fields_count != right.fields_count) {
    return false;
  }
  return CompareMaps(left, right) == ComparisonResult::Same;
}

bool Equals(const google_firestore_v1_Value& lhs,
            const google_firestore_v1_Value& rhs) {
  TypeOrder left_type = GetTypeOrder(lhs);
  TypeOrder right_type = GetTypeOrder(rhs);
  if (left_type != right_type) {
    return false;
  }

  switch (left_type) {
    case TypeOrder::kNull:
      return true;

    case TypeOrder::kBoolean:
      return lhs.boolean_value == rhs.boolean_value;

    case TypeOrder::kNumber:
      return NumberEquals(lhs, rhs);

    case TypeOrder::kTimestamp:
      return lhs.timestamp_value.seconds == rhs.timestamp_value.seconds &&
             lhs.timestamp_value.nanos == rhs.timestamp_value.nanos;

    case TypeOrder::kServerTimestamp: {
      const auto& left_ts = GetLocalWriteTime(lhs);
      const auto& right_ts = GetLocalWriteTime(rhs);
      return left_ts.seconds == right_ts.seconds &&
             left_ts.nanos == right_ts.nanos;
    }

    case TypeOrder::kString:
      return nanopb::MakeStringView(lhs.string_value) ==
             nanopb::MakeStringView(rhs.string_value);

    case TypeOrder::kBlob:
      return CompareBlobs(lhs, rhs) == ComparisonResult::Same;

    case TypeOrder::kReference:
      return nanopb::MakeStringView(lhs.reference_value) ==
             nanopb::MakeStringView(rhs.reference_value);

    case TypeOrder::kGeoPoint:
      return lhs.geo_point_value.latitude == rhs.geo_point_value.latitude &&
             lhs.geo_point_value.longitude == rhs.geo_point_value.longitude;

    case TypeOrder::kArray:
      return ArrayEquals(lhs.array_value, rhs.array_value);

    case TypeOrder::kVector:
    case TypeOrder::kMap:
      return MapValueEquals(lhs.map_value, rhs.map_value);

    case TypeOrder::kMaxValue:
      return MapValueEquals(lhs.map_value, rhs.map_value);

    default:
      HARD_FAIL("Invalid type value: %s", left_type);
  }
}

bool Equals(const google_firestore_v1_ArrayValue& lhs,
            const google_firestore_v1_ArrayValue& rhs) {
  return ArrayEquals(lhs, rhs);
}

std::string CanonifyTimestamp(const google_firestore_v1_Value& value) {
  return absl::StrFormat("time(%d,%d)", value.timestamp_value.seconds,
                         value.timestamp_value.nanos);
}

std::string CanonifyBlob(const google_firestore_v1_Value& value) {
  return absl::BytesToHexString(nanopb::MakeStringView(value.bytes_value));
}

std::string CanonifyReference(const google_firestore_v1_Value& value) {
  std::vector<std::string> segments = absl::StrSplit(
      nanopb::MakeStringView(value.reference_value), '/', absl::SkipEmpty());
  HARD_ASSERT(segments.size() >= 5,
              "Reference values should have at least 5 components");
  return absl::StrJoin(segments.begin() + 5, segments.end(), "/");
}

std::string CanonifyGeoPoint(const google_firestore_v1_Value& value) {
  return absl::StrFormat("geo(%.1f,%.1f)", value.geo_point_value.latitude,
                         value.geo_point_value.longitude);
}

std::string CanonifyArray(const google_firestore_v1_ArrayValue& array_value) {
  std::string result = "[";
  for (size_t i = 0; i < array_value.values_count; ++i) {
    absl::StrAppend(&result, CanonicalId(array_value.values[i]));
    if (i != array_value.values_count - 1) {
      absl::StrAppend(&result, ",");
    }
  }
  result += "]";
  return result;
}

std::string CanonifyObject(const google_firestore_v1_Value& value) {
  pb_size_t fields_count = value.map_value.fields_count;
  const auto& fields = value.map_value.fields;

  // Porting Note: MapValues in iOS are always kept in sorted order. We
  // therefore do no need to sort them before generating the canonical ID.
  std::string result = "{";
  for (pb_size_t i = 0; i < fields_count; ++i) {
    absl::StrAppend(&result, nanopb::MakeStringView(fields[i].key), ":",
                    CanonicalId(fields[i].value));
    if (i != fields_count - 1) {
      absl::StrAppend(&result, ",");
    }
  }
  result += "}";

  return result;
}

std::string CanonicalId(const google_firestore_v1_Value& value) {
  switch (value.which_value_type) {
    case google_firestore_v1_Value_null_value_tag:
      return "null";

    case google_firestore_v1_Value_boolean_value_tag:
      return value.boolean_value ? "true" : "false";

    case google_firestore_v1_Value_integer_value_tag:
      return std::to_string(value.integer_value);

    case google_firestore_v1_Value_double_value_tag:
      return absl::StrFormat("%.1f", value.double_value);

    case google_firestore_v1_Value_timestamp_value_tag:
      return CanonifyTimestamp(value);

    case google_firestore_v1_Value_string_value_tag:
      return nanopb::MakeString(value.string_value);

    case google_firestore_v1_Value_bytes_value_tag:
      return CanonifyBlob(value);

    case google_firestore_v1_Value_reference_value_tag:
      return CanonifyReference(value);

    case google_firestore_v1_Value_geo_point_value_tag:
      return CanonifyGeoPoint(value);

    case google_firestore_v1_Value_array_value_tag:
      return CanonifyArray(value.array_value);

    case google_firestore_v1_Value_map_value_tag: {
      return CanonifyObject(value);
    }

    default:
      HARD_FAIL("Invalid type value: %s", value.which_value_type);
  }
}

std::string CanonicalId(const google_firestore_v1_ArrayValue& value) {
  return CanonifyArray(value);
}

google_firestore_v1_Value GetLowerBound(
    const google_firestore_v1_Value& value) {
  switch (value.which_value_type) {
    case google_firestore_v1_Value_null_value_tag:
      return NullValue();

    case google_firestore_v1_Value_boolean_value_tag: {
      return MinBoolean();
    }

    case google_firestore_v1_Value_integer_value_tag:
    case google_firestore_v1_Value_double_value_tag: {
      return MinNumber();
    }

    case google_firestore_v1_Value_timestamp_value_tag: {
      return MinTimestamp();
    }

    case google_firestore_v1_Value_string_value_tag: {
      return MinString();
    }

    case google_firestore_v1_Value_bytes_value_tag: {
      return MinBytes();
    }

    case google_firestore_v1_Value_reference_value_tag: {
      return MinReference();
    }

    case google_firestore_v1_Value_geo_point_value_tag: {
      return MinGeoPoint();
    }

    case google_firestore_v1_Value_array_value_tag: {
      return MinArray();
    }

    case google_firestore_v1_Value_map_value_tag: {
      if (IsVectorValue(value)) {
        return MinVector();
      }

      return MinMap();
    }

    default:
      HARD_FAIL("Invalid type value: %s", value.which_value_type);
  }
}

google_firestore_v1_Value GetUpperBound(
    const google_firestore_v1_Value& value) {
  switch (value.which_value_type) {
    case google_firestore_v1_Value_null_value_tag:
      return MinBoolean();
    case google_firestore_v1_Value_boolean_value_tag:
      return MinNumber();
    case google_firestore_v1_Value_integer_value_tag:
    case google_firestore_v1_Value_double_value_tag:
      return MinTimestamp();
    case google_firestore_v1_Value_timestamp_value_tag:
      return MinString();
    case google_firestore_v1_Value_string_value_tag:
      return MinBytes();
    case google_firestore_v1_Value_bytes_value_tag:
      return MinReference();
    case google_firestore_v1_Value_reference_value_tag:
      return MinGeoPoint();
    case google_firestore_v1_Value_geo_point_value_tag:
      return MinArray();
    case google_firestore_v1_Value_array_value_tag:
      return MinVector();
    case google_firestore_v1_Value_map_value_tag:
      if (IsVectorValue(value)) {
        return MinMap();
      }
      return MaxValue();
    default:
      HARD_FAIL("Invalid type value: %s", value.which_value_type);
  }
}

bool Contains(google_firestore_v1_ArrayValue haystack,
              google_firestore_v1_Value needle) {
  for (pb_size_t i = 0; i < haystack.values_count; ++i) {
    if (Equals(haystack.values[i], needle)) {
      return true;
    }
  }
  return false;
}

google_firestore_v1_Value NullValue() {
  google_firestore_v1_Value null_value;
  null_value.which_value_type = google_firestore_v1_Value_null_value_tag;
  null_value.null_value = {};
  return null_value;
}

bool IsNullValue(const google_firestore_v1_Value& value) {
  return value.which_value_type == google_firestore_v1_Value_null_value_tag;
}

google_firestore_v1_Value MinValue() {
  google_firestore_v1_Value null_value;
  null_value.which_value_type = google_firestore_v1_Value_null_value_tag;
  null_value.null_value = {};
  return null_value;
}

bool IsMinValue(const google_firestore_v1_Value& value) {
  return IsNullValue(value);
}

/**
 * Creates and returns a maximum value that is larger than any other Firestore
 * values. Underlying it is a map value with a special map field that SDK user
 * cannot possibly construct.
 */
google_firestore_v1_Value MaxValue() {
  google_firestore_v1_Value value;
  value.which_value_type = google_firestore_v1_Value_string_value_tag;
  value.string_value = kMaxValueFieldValue;

  // Make `field_entry` static so that it has a memory address that outlives
  // this function's scope; otherwise, using its address in the `map_value`
  // variable below would be invalid by the time the caller accessed it.
  static_assert(
      std::is_trivially_destructible<
          google_firestore_v1_MapValue_FieldsEntry>::value,
      "google_firestore_v1_MapValue_FieldsEntry should be "
      "trivially-destructible; otherwise, it should use NoDestructor below.");
  static google_firestore_v1_MapValue_FieldsEntry field_entry;
  field_entry.key = kTypeValueFieldKey;
  field_entry.value = value;

  google_firestore_v1_MapValue map_value;
  map_value.fields_count = 1;
  map_value.fields = &field_entry;

  google_firestore_v1_Value max_value;
  max_value.which_value_type = google_firestore_v1_Value_map_value_tag;
  max_value.map_value = map_value;

  return max_value;
}

bool IsMaxValue(const google_firestore_v1_Value& value) {
  if (value.which_value_type != google_firestore_v1_Value_map_value_tag) {
    return false;
  }

  if (value.map_value.fields_count != 1) {
    return false;
  }

  // Comparing the pointer address, then actual content if addresses are
  // different.
  if (value.map_value.fields[0].key != kTypeValueFieldKey &&
      nanopb::MakeStringView(value.map_value.fields[0].key) !=
          kRawTypeValueFieldKey) {
    return false;
  }

  if (value.map_value.fields->value.which_value_type !=
      google_firestore_v1_Value_string_value_tag) {
    return false;
  }

  // Comparing the pointer address, then actual content if addresses are
  // different.
  return value.map_value.fields[0].value.string_value == kMaxValueFieldValue ||
         nanopb::MakeStringView(value.map_value.fields[0].value.string_value) ==
             kRawMaxValueFieldValue;
}

absl::optional<pb_size_t> IndexOfKey(
    const google_firestore_v1_MapValue& mapValue,
    const char* kRawTypeValueFieldKey,
    pb_bytes_array_s* kTypeValueFieldKey) {
  for (pb_size_t i = 0; i < mapValue.fields_count; i++) {
    if (mapValue.fields[i].key == kTypeValueFieldKey ||
        nanopb::MakeStringView(mapValue.fields[i].key) ==
            kRawTypeValueFieldKey) {
      return i;
    }
  }

  return absl::nullopt;
}

bool IsVectorValue(const google_firestore_v1_Value& value) {
  if (value.which_value_type != google_firestore_v1_Value_map_value_tag) {
    return false;
  }

  if (value.map_value.fields_count < 2) {
    return false;
  }

  absl::optional<pb_size_t> typeFieldIndex =
      IndexOfKey(value.map_value, kRawTypeValueFieldKey, kTypeValueFieldKey);
  if (!typeFieldIndex.has_value()) {
    return false;
  }

  if (value.map_value.fields[typeFieldIndex.value()].value.which_value_type !=
      google_firestore_v1_Value_string_value_tag) {
    return false;
  }

  // Comparing the pointer address, then actual content if addresses are
  // different.
  if (value.map_value.fields[typeFieldIndex.value()].value.string_value !=
          kVectorTypeFieldValue &&
      nanopb::MakeStringView(
          value.map_value.fields[typeFieldIndex.value()].value.string_value) !=
          kRawVectorTypeFieldValue) {
    return false;
  }

  absl::optional<pb_size_t> valueFieldIndex = IndexOfKey(
      value.map_value, kRawVectorValueFieldKey, kVectorValueFieldKey);
  if (!valueFieldIndex.has_value()) {
    return false;
  }

  if (value.map_value.fields[valueFieldIndex.value()].value.which_value_type !=
      google_firestore_v1_Value_array_value_tag) {
    return false;
  }

  return true;
}

google_firestore_v1_Value NaNValue() {
  google_firestore_v1_Value nan_value;
  nan_value.which_value_type = google_firestore_v1_Value_double_value_tag;
  nan_value.double_value = std::numeric_limits<double>::quiet_NaN();
  return nan_value;
}

bool IsNaNValue(const google_firestore_v1_Value& value) {
  return value.which_value_type == google_firestore_v1_Value_double_value_tag &&
         std::isnan(value.double_value);
}

google_firestore_v1_Value MinBoolean() {
  google_firestore_v1_Value lowerBound;
  lowerBound.which_value_type = google_firestore_v1_Value_boolean_value_tag;
  lowerBound.boolean_value = false;
  return lowerBound;
}

google_firestore_v1_Value MinNumber() {
  return NaNValue();
}

google_firestore_v1_Value MinTimestamp() {
  google_firestore_v1_Value lowerBound;
  lowerBound.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  lowerBound.timestamp_value.seconds = std::numeric_limits<int64_t>::min();
  lowerBound.timestamp_value.nanos = 0;
  return lowerBound;
}

google_firestore_v1_Value MinString() {
  google_firestore_v1_Value lowerBound;
  lowerBound.which_value_type = google_firestore_v1_Value_string_value_tag;
  lowerBound.string_value = nullptr;
  return lowerBound;
}

google_firestore_v1_Value MinBytes() {
  google_firestore_v1_Value lowerBound;
  lowerBound.which_value_type = google_firestore_v1_Value_bytes_value_tag;
  lowerBound.bytes_value = nullptr;
  return lowerBound;
}

google_firestore_v1_Value MinReference() {
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_reference_value_tag;
  result.reference_value = kMinimumReferenceValue;
  return result;
}

google_firestore_v1_Value MinGeoPoint() {
  google_firestore_v1_Value lowerBound;
  lowerBound.which_value_type = google_firestore_v1_Value_geo_point_value_tag;
  lowerBound.geo_point_value.latitude = -90.0;
  lowerBound.geo_point_value.longitude = -180.0;
  return lowerBound;
}

google_firestore_v1_Value MinArray() {
  google_firestore_v1_Value lowerBound;
  lowerBound.which_value_type = google_firestore_v1_Value_array_value_tag;
  lowerBound.array_value.values = nullptr;
  lowerBound.array_value.values_count = 0;
  return lowerBound;
}

google_firestore_v1_Value MinVector() {
  google_firestore_v1_Value typeValue;
  typeValue.which_value_type = google_firestore_v1_Value_string_value_tag;
  typeValue.string_value = kVectorTypeFieldValue;

  google_firestore_v1_MapValue_FieldsEntry* field_entries =
      nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(2);
  field_entries[0].key = kTypeValueFieldKey;
  field_entries[0].value = typeValue;

  google_firestore_v1_Value arrayValue;
  arrayValue.which_value_type = google_firestore_v1_Value_array_value_tag;
  arrayValue.array_value.values = nullptr;
  arrayValue.array_value.values_count = 0;
  field_entries[1].key = kVectorValueFieldKey;
  field_entries[1].value = arrayValue;

  google_firestore_v1_MapValue map_value;
  map_value.fields_count = 2;
  map_value.fields = field_entries;

  google_firestore_v1_Value lowerBound;
  lowerBound.which_value_type = google_firestore_v1_Value_map_value_tag;
  lowerBound.map_value = map_value;

  return lowerBound;
}

google_firestore_v1_Value MinMap() {
  google_firestore_v1_Value lowerBound;
  lowerBound.which_value_type = google_firestore_v1_Value_map_value_tag;
  lowerBound.map_value.fields = nullptr;
  lowerBound.map_value.fields_count = 0;
  return lowerBound;
}

Message<google_firestore_v1_Value> RefValue(
    const model::DatabaseId& database_id,
    const model::DocumentKey& document_key) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_reference_value_tag;
  result->reference_value = nanopb::MakeBytesArray(util::StringFormat(
      "projects/%s/databases/%s/documents/%s", database_id.project_id(),
      database_id.database_id(), document_key.ToString()));
  return result;
}

Message<google_firestore_v1_Value> DeepClone(
    const google_firestore_v1_Value& source) {
  Message<google_firestore_v1_Value> target{source};
  switch (source.which_value_type) {
    case google_firestore_v1_Value_string_value_tag:
      target->string_value =
          source.string_value
              ? nanopb::MakeBytesArray(source.string_value->bytes,
                                       source.string_value->size)
              : nullptr;
      break;

    case google_firestore_v1_Value_reference_value_tag:
      target->reference_value = nanopb::MakeBytesArray(
          source.reference_value->bytes, source.reference_value->size);
      break;

    case google_firestore_v1_Value_bytes_value_tag:
      target->bytes_value =
          source.bytes_value ? nanopb::MakeBytesArray(source.bytes_value->bytes,
                                                      source.bytes_value->size)
                             : nullptr;
      break;

    case google_firestore_v1_Value_array_value_tag:
      target->array_value = *DeepClone(source.array_value).release();
      break;

    case google_firestore_v1_Value_map_value_tag:
      target->map_value = *DeepClone(source.map_value).release();
      break;
  }
  return target;
}

Message<google_firestore_v1_ArrayValue> DeepClone(
    const google_firestore_v1_ArrayValue& source) {
  Message<google_firestore_v1_ArrayValue> target{source};
  target->values_count = source.values_count;
  target->values =
      nanopb::MakeArray<google_firestore_v1_Value>(source.values_count);
  for (pb_size_t i = 0; i < source.values_count; ++i) {
    target->values[i] = *DeepClone(source.values[i]).release();
  }
  return target;
}

Message<google_firestore_v1_MapValue> DeepClone(
    const google_firestore_v1_MapValue& source) {
  Message<google_firestore_v1_MapValue> target{source};
  target->fields_count = source.fields_count;
  target->fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(
      source.fields_count);
  for (pb_size_t i = 0; i < source.fields_count; ++i) {
    target->fields[i].key = nanopb::MakeBytesArray(source.fields[i].key->bytes,
                                                   source.fields[i].key->size);
    target->fields[i].value = *DeepClone(source.fields[i].value).release();
  }
  return target;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
