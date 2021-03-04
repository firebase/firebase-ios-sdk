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

#include "Firestore/core/src/model/values.h"

#include <map>
#include <memory>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/model/server_timestamps.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/str_join.h"
#include "absl/strings/str_split.h"

namespace firebase {
namespace firestore {
namespace model {

using util::ComparisonResult;

int32_t Values::GetTypeOrder(const google_firestore_v1_Value& value) {
  switch (value.which_value_type) {
    case google_firestore_v1_Value_null_value_tag:
      return TYPE_ORDER_NULL;

    case google_firestore_v1_Value_boolean_value_tag:
      return TYPE_ORDER_BOOLEAN;

    case google_firestore_v1_Value_integer_value_tag:
    case google_firestore_v1_Value_double_value_tag:
      return TYPE_ORDER_NUMBER;

    case google_firestore_v1_Value_timestamp_value_tag:
      return TYPE_ORDER_TIMESTAMP;

    case google_firestore_v1_Value_string_value_tag:
      return TYPE_ORDER_STRING;

    case google_firestore_v1_Value_bytes_value_tag:
      return TYPE_ORDER_BLOB;

    case google_firestore_v1_Value_reference_value_tag:
      return TYPE_ORDER_REFERENCE;

    case google_firestore_v1_Value_geo_point_value_tag:
      return TYPE_ORDER_GEOPOINT;

    case google_firestore_v1_Value_array_value_tag:
      return TYPE_ORDER_ARRAY;

    case google_firestore_v1_Value_map_value_tag: {
      if (ServerTimestamps::IsServerTimestamp(value)) {
        return TYPE_ORDER_SERVER_TIMESTAMP;
      }
      return TYPE_ORDER_MAP;
    }

    default:
      HARD_FAIL("Invalid type value: %s", value.which_value_type);
  }
}

bool Values::Equals(const google_firestore_v1_Value& left,
                    const google_firestore_v1_Value& right) {
  int left_type = GetTypeOrder(left);
  int right_type = GetTypeOrder(right);
  if (left_type != right_type) {
    return false;
  }

  switch (left_type) {
    case TYPE_ORDER_NULL:
      return true;
    case TYPE_ORDER_BOOLEAN:
      return left.boolean_value == right.boolean_value;
    case TYPE_ORDER_NUMBER:
      return NumberEquals(left, right);
    case TYPE_ORDER_TIMESTAMP:
      return left.timestamp_value.seconds == right.timestamp_value.seconds &&
             left.timestamp_value.nanos == right.timestamp_value.nanos;
    case TYPE_ORDER_SERVER_TIMESTAMP:
      return Equals(ServerTimestamps::GetLocalWriteTime(left),
                    ServerTimestamps::GetLocalWriteTime(right));
    case TYPE_ORDER_STRING:
      return nanopb::MakeStringView(left.string_value) ==
             nanopb::MakeStringView(right.string_value);
    case TYPE_ORDER_BLOB:
      return CompareBlobs(left, right) == ComparisonResult::Same;
    case TYPE_ORDER_REFERENCE:
      return nanopb::MakeString(left.reference_value) ==
             nanopb::MakeString(right.reference_value);
    case TYPE_ORDER_GEOPOINT:
      return left.geo_point_value.latitude == right.geo_point_value.latitude &&
             left.geo_point_value.longitude == right.geo_point_value.longitude;
    case TYPE_ORDER_ARRAY:
      return ArrayEquals(left, right);
    case TYPE_ORDER_MAP:
      return ObjectEquals(left, right);
    default:
      HARD_FAIL("Invalid type value: %s", left_type);
  }
}

bool Values::NumberEquals(
    const firebase::firestore::google_firestore_v1_Value& left,
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

bool Values::ArrayEquals(
    const firebase::firestore::google_firestore_v1_Value& left,
    const firebase::firestore::google_firestore_v1_Value& right) {
  const google_firestore_v1_ArrayValue& left_array = left.array_value;
  const google_firestore_v1_ArrayValue& right_array = right.array_value;

  if (left_array.values_count != right_array.values_count) {
    return false;
  }

  for (size_t i = 0; i < left_array.values_count; ++i) {
    if (!Equals(left_array.values[i], right_array.values[i])) {
      return false;
    }
  }

  return true;
}

bool Values::ObjectEquals(
    const firebase::firestore::google_firestore_v1_Value& left,
    const firebase::firestore::google_firestore_v1_Value& right) {
  google_firestore_v1_MapValue left_map = left.map_value;
  google_firestore_v1_MapValue right_map = right.map_value;

  if (left_map.fields_count != right_map.fields_count) {
    return false;
  }

  // Create a map of field names to index for one of the maps. This is then used
  // look up the corresponding value for the other map's fields.
  std::unordered_map<std::string, size_t> key_to_value_index;
  for (size_t i = 0; i < left_map.fields_count; ++i) {
    key_to_value_index.emplace(nanopb::MakeString(left_map.fields[i].key), i);
  }

  for (size_t i = 0; i < right_map.fields_count; ++i) {
    const std::string& key = nanopb::MakeString(right_map.fields[i].key);
    const auto& left_index = key_to_value_index.find(key);

    if (left_index == key_to_value_index.end()) {
      return false;
    }

    if (!Equals(left_map.fields[left_index->second].value,
                right_map.fields[i].value)) {
      return false;
    }
  }

  return true;
}

ComparisonResult Values::Compare(const google_firestore_v1_Value& left,
                                 const google_firestore_v1_Value& right) {
  int left_type = GetTypeOrder(left);
  int right_type = GetTypeOrder(right);

  if (left_type != right_type) {
    return util::Compare(left_type, right_type);
  }

  switch (left_type) {
    case TYPE_ORDER_NULL:
      return ComparisonResult::Same;
    case TYPE_ORDER_BOOLEAN:
      return util::Compare(left.boolean_value, right.boolean_value);
    case TYPE_ORDER_NUMBER:
      return CompareNumbers(left, right);
    case TYPE_ORDER_TIMESTAMP:
      return CompareTimestamps(left, right);
    case TYPE_ORDER_SERVER_TIMESTAMP:
      return CompareTimestamps(ServerTimestamps::GetLocalWriteTime(left),
                               ServerTimestamps::GetLocalWriteTime(right));
    case TYPE_ORDER_STRING:
      return CompareStrings(left, right);
    case TYPE_ORDER_BLOB:
      return CompareBlobs(left, right);
    case TYPE_ORDER_REFERENCE:
      return CompareReferences(left, right);
    case TYPE_ORDER_GEOPOINT:
      return CompareGeoPoints(left, right);
    case TYPE_ORDER_ARRAY:
      return CompareArrays(left, right);
    case TYPE_ORDER_MAP:
      return CompareObjects(left, right);
    default:
      HARD_FAIL("Invalid type value: %s", left_type);
  }
}

ComparisonResult Values::CompareNumbers(
    const google_firestore_v1_Value& left,
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

ComparisonResult Values::CompareTimestamps(
    const google_firestore_v1_Value& left,
    const google_firestore_v1_Value& right) {
  ComparisonResult cmp = util::Compare(left.timestamp_value.seconds,
                                       right.timestamp_value.seconds);
  if (cmp != ComparisonResult::Same) {
    return cmp;
  }
  return util::Compare(left.timestamp_value.nanos, right.timestamp_value.nanos);
}

ComparisonResult Values::CompareStrings(
    const google_firestore_v1_Value& left,
    const google_firestore_v1_Value& right) {
  const std::string& left_string = nanopb::MakeString(left.string_value);
  const std::string& right_string = nanopb::MakeString(right.string_value);
  return util::Compare(left_string, right_string);
}

ComparisonResult Values::CompareBlobs(const google_firestore_v1_Value& left,
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

ComparisonResult Values::CompareReferences(
    const google_firestore_v1_Value& left,
    const google_firestore_v1_Value& right) {
  std::vector<std::string> left_segments = absl::StrSplit(
      nanopb::MakeString(left.reference_value), '/', absl::SkipEmpty());
  std::vector<std::string> right_segments = absl::StrSplit(
      nanopb::MakeString(right.reference_value), '/', absl::SkipEmpty());

  int min_length = std::min(left_segments.size(), right_segments.size());
  for (int i = 0; i < min_length; i++) {
    ComparisonResult cmp = util::Compare(left_segments[i], right_segments[i]);
    if (cmp != ComparisonResult::Same) {
      return cmp;
    }
  }
  return util::Compare(left_segments.size(), right_segments.size());
}

ComparisonResult Values::CompareGeoPoints(
    const google_firestore_v1_Value& left,
    const google_firestore_v1_Value& right) {
  ComparisonResult cmp = util::Compare(left.geo_point_value.latitude,
                                       right.geo_point_value.latitude);
  if (cmp != ComparisonResult::Same) {
    return cmp;
  }
  return util::Compare(left.geo_point_value.longitude,
                       right.geo_point_value.longitude);
}

ComparisonResult Values::CompareArrays(const google_firestore_v1_Value& left,
                                       const google_firestore_v1_Value& right) {
  int min_length =
      std::min(left.array_value.values_count, right.array_value.values_count);
  for (int i = 0; i < min_length; i++) {
    ComparisonResult cmp =
        Compare(left.array_value.values[i], right.array_value.values[i]);
    if (cmp != ComparisonResult::Same) {
      return cmp;
    }
  }
  return util::Compare(left.array_value.values_count,
                       right.array_value.values_count);
}

ComparisonResult Values::CompareObjects(
    const google_firestore_v1_Value& left,
    const google_firestore_v1_Value& right) {
  google_firestore_v1_MapValue left_map = left.map_value;
  google_firestore_v1_MapValue right_map = right.map_value;

  // Create a sorted mapping of field key to index. This is then used to walk
  // both maps in sorted order.
  std::map<std::string, size_t> left_key_to_value_index;
  for (size_t i = 0; i < left_map.fields_count; ++i) {
    left_key_to_value_index.emplace(nanopb::MakeString(left_map.fields[i].key),
                                    i);
  }
  std::map<std::string, size_t> right_key_to_value_index;
  for (size_t i = 0; i < right_map.fields_count; ++i) {
    right_key_to_value_index.emplace(
        nanopb::MakeString(right_map.fields[i].key), i);
  }

  auto left_it = left_key_to_value_index.begin();
  auto right_it = right_key_to_value_index.begin();

  while (left_it != left_key_to_value_index.end() &&
         right_it != right_key_to_value_index.end()) {
    ComparisonResult key_cmp = util::Compare(left_it->first, right_it->first);
    if (key_cmp != ComparisonResult::Same) {
      return key_cmp;
    }

    ComparisonResult value_cmp =
        Compare(left.map_value.fields[left_it->second].value,
                right.map_value.fields[right_it->second].value);
    if (value_cmp != ComparisonResult::Same) {
      return value_cmp;
    }

    ++left_it;
    ++right_it;
  }

  return util::Compare(left_it != left_key_to_value_index.end(),
                       right_it != right_key_to_value_index.end());
}

std::string Values::CanonicalId(const google_firestore_v1_Value& value) {
  switch (value.which_value_type) {
    case google_firestore_v1_Value_null_value_tag:
      return "null";

    case google_firestore_v1_Value_boolean_value_tag:
      return value.boolean_value ? "true" : "false";

    case google_firestore_v1_Value_integer_value_tag:
      return std::to_string(value.integer_value);

    case google_firestore_v1_Value_double_value_tag:
      return std::to_string(value.double_value);

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

std::string Values::CanonifyTimestamp(const google_firestore_v1_Value& value) {
  return "time(" + std::to_string(value.timestamp_value.seconds) + "," +
         std::to_string(value.timestamp_value.nanos) + ")";
}

std::string Values::CanonifyBlob(const google_firestore_v1_Value& value) {
  static const char hex[] = "0123456789ABCDEF";

  int size = value.bytes_value->size;

  std::string result(size * 2, 0);
  for (size_t i = 0; i < value.bytes_value->size; ++i) {
    result[2 * i] = hex[value.bytes_value->bytes[i] >> 4];
    result[(2 * i) + 1] = hex[value.bytes_value->bytes[i] & 0x0F];
  }
  return result;
}

std::string Values::CanonifyReference(const google_firestore_v1_Value& value) {
  std::vector<std::string> segments = absl::StrSplit(
      nanopb::MakeStringView(value.reference_value), '/', absl::SkipEmpty());
  return absl::StrJoin(
      std::vector<std::string>(segments.begin() + 5, segments.end()), "/");
}

std::string Values::CanonifyGeoPoint(const google_firestore_v1_Value& value) {
  return "geo(" + std::to_string(value.geo_point_value.latitude) + "," +
         std::to_string(value.geo_point_value.longitude) + ")";
}

std::string Values::CanonifyArray(const google_firestore_v1_Value& value) {
  std::string result = "[";
  for (size_t i = 0; i < value.array_value.values_count; ++i) {
    result += CanonicalId(value.array_value.values[i]);
    if (i != value.array_value.values_count - 1) {
      result += ",";
    }
  }
  result += "]";
  return result;
}

std::string Values::CanonifyObject(const google_firestore_v1_Value& value) {
  // Even though MapValue are likely sorted correctly based on their insertion
  // order (e.g. when received from the backend), local modifications can bring
  // elements out of order. We need to re-sort the elements to ensure that
  // canonical IDs are independent of insertion order.
  std::map<std::string, size_t> sorted_keys_to_index;
  for (size_t i = 0; i < value.map_value.fields_count; ++i) {
    sorted_keys_to_index.emplace(
        nanopb::MakeString(value.map_value.fields[i].key), i);
  }

  std::string result = "{";
  bool first = true;
  for (const auto& entry : sorted_keys_to_index) {
    if (!first) {
      result += ",";
    } else {
      first = false;
    }
    result += entry.first + ":" +
              CanonicalId(value.map_value.fields[entry.second].value);
  }
  result += "}";

  return result;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
