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
#include <memory>
#include <vector>

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

using util::ComparisonResult;

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
      }
      return TypeOrder::kMap;
    }

    default:
      HARD_FAIL("Invalid type value: %s", value.which_value_type);
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

ComparisonResult CompareTimestamps(const google_firestore_v1_Value& left,
                                   const google_firestore_v1_Value& right) {
  ComparisonResult cmp = util::Compare(left.timestamp_value.seconds,
                                       right.timestamp_value.seconds);
  if (cmp != ComparisonResult::Same) {
    return cmp;
  }
  return util::Compare(left.timestamp_value.nanos, right.timestamp_value.nanos);
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
    // An empty blob is represented by a nullptr
    return util::Compare(left.bytes_value != nullptr,
                         right.bytes_value != nullptr);
  }
}

ComparisonResult CompareReferences(const google_firestore_v1_Value& left,
                                   const google_firestore_v1_Value& right) {
  std::vector<std::string> left_segments = absl::StrSplit(
      nanopb::MakeStringView(left.reference_value), '/', absl::SkipEmpty());
  std::vector<std::string> right_segments = absl::StrSplit(
      nanopb::MakeStringView(right.reference_value), '/', absl::SkipEmpty());

  int min_length = std::min(left_segments.size(), right_segments.size());
  for (int i = 0; i < min_length; ++i) {
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

ComparisonResult CompareObjects(const google_firestore_v1_Value& left,
                                const google_firestore_v1_Value& right) {
  google_firestore_v1_MapValue left_map = left.map_value;
  google_firestore_v1_MapValue right_map = right.map_value;

  // Porting Note: MapValues in iOS are always kept in sorted order. We
  // therefore do no need to sort them before comparing.
  for (pb_size_t i = 0; i < left_map.fields_count && i < right_map.fields_count;
       ++i) {
    ComparisonResult key_cmp =
        util::Compare(nanopb::MakeStringView(left_map.fields[i].key),
                      nanopb::MakeStringView(right_map.fields[i].key));
    if (key_cmp != ComparisonResult::Same) {
      return key_cmp;
    }

    ComparisonResult value_cmp =
        Compare(left_map.fields[i].value, right.map_value.fields[i].value);
    if (value_cmp != ComparisonResult::Same) {
      return value_cmp;
    }
  }

  return util::Compare(left_map.fields_count, right_map.fields_count);
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
      return CompareTimestamps(left, right);

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
      return CompareObjects(left, right);

    default:
      HARD_FAIL("Invalid type value: %s", left_type);
  }
}

bool NumberEquals(const firebase::firestore::google_firestore_v1_Value& left,
                  const firebase::firestore::google_firestore_v1_Value& right) {
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

bool ArrayEquals(const firebase::firestore::google_firestore_v1_Value& left,
                 const firebase::firestore::google_firestore_v1_Value& right) {
  const google_firestore_v1_ArrayValue& left_array = left.array_value;
  const google_firestore_v1_ArrayValue& right_array = right.array_value;

  if (left_array.values_count != right_array.values_count) {
    return false;
  }

  for (size_t i = 0; i < left_array.values_count; ++i) {
    if (left_array.values[i] != right_array.values[i]) {
      return false;
    }
  }

  return true;
}

bool ObjectEquals(const firebase::firestore::google_firestore_v1_Value& left,
                  const firebase::firestore::google_firestore_v1_Value& right) {
  google_firestore_v1_MapValue left_map = left.map_value;
  google_firestore_v1_MapValue right_map = right.map_value;

  if (left_map.fields_count != right_map.fields_count) {
    return false;
  }

  // Porting Note: MapValues in iOS are always kept in sorted order. We
  // therefore do no need to sort them before comparing.
  for (size_t i = 0; i < right_map.fields_count; ++i) {
    if (nanopb::MakeStringView(left_map.fields[i].key) !=
        nanopb::MakeStringView(right_map.fields[i].key)) {
      return false;
    }

    if (left_map.fields[i].value != right_map.fields[i].value) {
      return false;
    }
  }

  return true;
}

bool operator==(const google_firestore_v1_Value& lhs,
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

    case TypeOrder::kServerTimestamp:
      return GetLocalWriteTime(lhs) == GetLocalWriteTime(rhs);

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
      return ArrayEquals(lhs, rhs);

    case TypeOrder::kMap:
      return ObjectEquals(lhs, rhs);

    default:
      HARD_FAIL("Invalid type value: %s", left_type);
  }
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

std::string CanonifyArray(const google_firestore_v1_Value& value) {
  const auto& array = value.array_value;

  std::string result = "[";
  for (size_t i = 0; i < array.values_count; ++i) {
    absl::StrAppend(&result, CanonicalId(array.values[i]));
    if (i != array.values_count - 1) {
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
      return CanonifyArray(value);

    case google_firestore_v1_Value_map_value_tag: {
      return CanonifyObject(value);
    }

    default:
      HARD_FAIL("Invalid type value: %s", value.which_value_type);
  }
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
