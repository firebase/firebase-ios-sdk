/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/index/firestore_index_value_writer.h"

#include <cmath>
#include <limits>
#include <string>
#include <vector>

#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

#include "absl/strings/str_split.h"

namespace firebase {
namespace firestore {
namespace index {
namespace {

// Note: This file is copied from the backend. Code that is not used by
// Firestore was removed. Code that has different behavior was modified.

// The client SDK only supports references to documents from the same database.
// We can skip the first five segments.
constexpr int DocumentNameOffset = 5;

void WriteValueTypeLabel(DirectionalIndexByteEncoder* encoder, int type_order) {
  encoder->WriteLong(type_order);
}

void WriteUnlabeledIndexString(pb_bytes_array_t* string_index,
                               DirectionalIndexByteEncoder* encoder) {
  encoder->WriteString(nanopb::MakeStringView(string_index));
}

void WriteUnlabeledIndexString(const std::string& string_index,
                               DirectionalIndexByteEncoder* encoder) {
  encoder->WriteString(string_index);
}

void WriteIndexString(pb_bytes_array_t* string_index,
                      DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kString);
  WriteUnlabeledIndexString(string_index, encoder);
}

void WriteTruncationMarker(DirectionalIndexByteEncoder* encoder) {
  // While the SDK does not implement truncation, the truncation marker is used
  // to terminate all variable length values (which are strings, bytes,
  // references, arrays and maps).
  encoder->WriteLong(IndexType::kNotTruncated);
}

void WriteIndexEntityRef(pb_bytes_array_t* reference_value,
                         DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kReference);

  // We must allow empty strings. We could be dealing with a reference_value
  // with empty segmenets. The reference value has the following format:
  // projects/<project_id>/databases/<database_id>/documents/<col>/<doc>
  // So we may have something like:
  // projects//databases//documents/coll_1/doc_1
  std::vector<std::string> segments = absl::StrSplit(
      nanopb::MakeStringView(reference_value), '/', absl::AllowEmpty());
  auto num_segments = segments.size();
  for (size_t index = DocumentNameOffset; index < num_segments; ++index) {
    const std::string& segment = segments[index];
    WriteValueTypeLabel(encoder, IndexType::kReferenceSegment);
    WriteUnlabeledIndexString(segment, encoder);
  }
}

void WriteIndexValueAux(const google_firestore_v1_Value& index_value,
                        DirectionalIndexByteEncoder* encoder);

void WriteIndexArray(const google_firestore_v1_ArrayValue& array_index_value,
                     DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kArray);
  for (pb_size_t i = 0; i < array_index_value.values_count; ++i) {
    WriteIndexValueAux(array_index_value.values[i], encoder);
  }
}

void WriteIndexVector(const google_firestore_v1_MapValue& map_index_value,
                      DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kVector);

  absl::optional<pb_size_t> valueIndex =
      model::IndexOfKey(map_index_value, model::kRawVectorValueFieldKey,
                        model::kVectorValueFieldKey);

  if (!valueIndex.has_value() ||
      map_index_value.fields[valueIndex.value()].value.which_value_type !=
          google_firestore_v1_Value_array_value_tag) {
    return WriteIndexArray(model::MinArray().array_value, encoder);
  }

  auto value = map_index_value.fields[valueIndex.value()].value;

  // Vectors sort first by length
  WriteValueTypeLabel(encoder, IndexType::kNumber);
  encoder->WriteLong(value.array_value.values_count);

  // Vectors then sort by position value
  WriteIndexString(model::kVectorValueFieldKey, encoder);
  WriteIndexValueAux(value, encoder);
}

void WriteIndexMap(google_firestore_v1_MapValue map_index_value,
                   DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kMap);
  for (pb_size_t i = 0; i < map_index_value.fields_count; ++i) {
    WriteIndexString(map_index_value.fields[i].key, encoder);
    WriteIndexValueAux(map_index_value.fields[i].value, encoder);
  }
}

void WriteIndexBsonBinaryData(
    const google_firestore_v1_MapValue& map_index_value,
    DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kBsonBinaryData);
  encoder->WriteBytes(map_index_value.fields[0].value.bytes_value);
  WriteTruncationMarker(encoder);
}

void WriteIndexBsonObjectId(const google_firestore_v1_MapValue& map_index_value,
                            DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kBsonObjectId);
  encoder->WriteBytes(map_index_value.fields[0].value.string_value);
}

void WriteIndexBsonTimestamp(
    const google_firestore_v1_MapValue& map_index_value,
    DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kBsonTimestamp);

  // Figure out the seconds and increment value.
  const google_firestore_v1_MapValue& inner_map =
      map_index_value.fields[0].value.map_value;
  absl::optional<pb_size_t> seconds_index = model::IndexOfKey(
      inner_map, model::kRawBsonTimestampTypeSecondsFieldValue,
      model::kBsonTimestampTypeSecondsFieldValue);
  absl::optional<pb_size_t> increment_index = model::IndexOfKey(
      inner_map, model::kRawBsonTimestampTypeIncrementFieldValue,
      model::kBsonTimestampTypeIncrementFieldValue);
  const int64_t seconds =
      inner_map.fields[seconds_index.value()].value.integer_value;
  const int64_t increment =
      inner_map.fields[increment_index.value()].value.integer_value;

  // BsonTimestamp is encoded as a 64-bit long.
  int64_t value_to_encode = (seconds << 32) | (increment & 0xFFFFFFFFL);
  encoder->WriteLong(value_to_encode);
}

void WriteIndexRegexValue(const google_firestore_v1_MapValue& map_index_value,
                          DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kRegex);

  // Figure out the pattern and options.
  const google_firestore_v1_MapValue& inner_map =
      map_index_value.fields[0].value.map_value;
  absl::optional<pb_size_t> pattern_index =
      model::IndexOfKey(inner_map, model::kRawRegexTypePatternFieldValue,
                        model::kRegexTypePatternFieldValue);
  absl::optional<pb_size_t> options_index =
      model::IndexOfKey(inner_map, model::kRawRegexTypeOptionsFieldValue,
                        model::kRegexTypeOptionsFieldValue);
  const auto& pattern =
      inner_map.fields[pattern_index.value()].value.string_value;
  const auto& options =
      inner_map.fields[options_index.value()].value.string_value;

  // Write pattern and then options.
  WriteUnlabeledIndexString(pattern, encoder);
  WriteUnlabeledIndexString(options, encoder);

  // Also needs truncation marker.
  WriteTruncationMarker(encoder);
}

void WriteIndexInt32Value(const google_firestore_v1_MapValue& map_index_value,
                          DirectionalIndexByteEncoder* encoder) {
  WriteValueTypeLabel(encoder, IndexType::kNumber);
  // Similar to 64-bit integers (see integer_value below), we write 32-bit
  // integers as double so that 0 and 0.0 are considered the same.
  encoder->WriteDouble(map_index_value.fields[0].value.integer_value);
}

void WriteIndexDoubleValue(double number,
                           DirectionalIndexByteEncoder* encoder) {
  if (std::isnan(number)) {
    WriteValueTypeLabel(encoder, IndexType::kNan);
    return;
  }

  WriteValueTypeLabel(encoder, IndexType::kNumber);
  if (number == -0.0) {
    // -0.0, 0 and 0.0 are all considered the same
    encoder->WriteDouble(0.0);
  } else {
    encoder->WriteDouble(number);
  }
}

void WriteIndexDecimal128Value(
    const google_firestore_v1_MapValue& map_index_value,
    DirectionalIndexByteEncoder* encoder) {
  // Note: We currently give up some precision and store the 128-bit decimal as
  // a 64-bit double for client-side indexing purposes. We could consider
  // improving this in the future.
  // Note: std::stod is able to parse 'NaN', '-NaN', 'Infinity' and '-Infinity',
  // with different string cases.
  const double number = std::stod(
      nanopb::MakeString(map_index_value.fields[0].value.string_value));
  WriteIndexDoubleValue(number, encoder);
}

void WriteIndexValueAux(const google_firestore_v1_Value& index_value,
                        DirectionalIndexByteEncoder* encoder) {
  switch (index_value.which_value_type) {
    case google_firestore_v1_Value_null_value_tag: {
      WriteValueTypeLabel(encoder, IndexType::kNull);
      break;
    }
    case google_firestore_v1_Value_boolean_value_tag: {
      WriteValueTypeLabel(encoder, IndexType::kBoolean);
      encoder->WriteLong(index_value.boolean_value ? 1 : 0);
      break;
    }
    case google_firestore_v1_Value_double_value_tag: {
      WriteIndexDoubleValue(index_value.double_value, encoder);
      break;
    }
    case google_firestore_v1_Value_integer_value_tag: {
      WriteValueTypeLabel(encoder, IndexType::kNumber);
      // Write as double instead of integer so 0 and 0.0 are considered the
      // same.
      encoder->WriteDouble(index_value.integer_value);
      break;
    }
    case google_firestore_v1_Value_timestamp_value_tag: {
      const auto& timestamp = index_value.timestamp_value;
      WriteValueTypeLabel(encoder, IndexType::kTimestamp);
      encoder->WriteLong(timestamp.seconds);
      encoder->WriteLong(timestamp.nanos);
      break;
    }
    case google_firestore_v1_Value_string_value_tag: {
      WriteIndexString(index_value.string_value, encoder);
      WriteTruncationMarker(encoder);
      break;
    }
    case google_firestore_v1_Value_bytes_value_tag: {
      WriteValueTypeLabel(encoder, IndexType::kBlob);
      encoder->WriteBytes(index_value.bytes_value);
      WriteTruncationMarker(encoder);
      break;
    }
    case google_firestore_v1_Value_reference_value_tag: {
      WriteIndexEntityRef(index_value.reference_value, encoder);
      break;
    }
    case google_firestore_v1_Value_geo_point_value_tag: {
      const auto& geo_point = index_value.geo_point_value;
      WriteValueTypeLabel(encoder, IndexType::kGeopoint);
      encoder->WriteDouble(geo_point.latitude);
      encoder->WriteDouble(geo_point.longitude);
      break;
    }
    case google_firestore_v1_Value_map_value_tag:
      // model::InternalMaxValue() is a sentinel map value (see the comment
      // there). In that case, we encode the max int value instead.
      if (model::IsInternalMaxValue(index_value)) {
        WriteValueTypeLabel(encoder, std::numeric_limits<int>::max());
        break;
      } else if (model::IsVectorValue(index_value)) {
        WriteIndexVector(index_value.map_value, encoder);
        break;
      } else if (model::IsMaxKeyValue(index_value)) {
        WriteValueTypeLabel(encoder, IndexType::kMaxKey);
        break;
      } else if (model::IsMinKeyValue(index_value)) {
        WriteValueTypeLabel(encoder, IndexType::kMinKey);
        break;
      } else if (model::IsBsonBinaryData(index_value)) {
        WriteIndexBsonBinaryData(index_value.map_value, encoder);
        break;
      } else if (model::IsRegexValue(index_value)) {
        WriteIndexRegexValue(index_value.map_value, encoder);
        break;
      } else if (model::IsBsonTimestamp(index_value)) {
        WriteIndexBsonTimestamp(index_value.map_value, encoder);
        break;
      } else if (model::IsBsonObjectId(index_value)) {
        WriteIndexBsonObjectId(index_value.map_value, encoder);
        break;
      } else if (model::IsDecimal128Value(index_value)) {
        WriteIndexDecimal128Value(index_value.map_value, encoder);
        break;
      } else if (model::IsInt32Value(index_value)) {
        WriteIndexInt32Value(index_value.map_value, encoder);
        break;
      }

      // For regular maps:
      WriteIndexMap(index_value.map_value, encoder);
      WriteTruncationMarker(encoder);
      break;
    case google_firestore_v1_Value_array_value_tag: {
      WriteIndexArray(index_value.array_value, encoder);
      WriteTruncationMarker(encoder);
      break;
    }
    default:
      HARD_FAIL("Unknown index value type");
  }
}

}  // namespace

/** Writes an index value. */
void WriteIndexValue(const google_firestore_v1_Value& value,
                     DirectionalIndexByteEncoder* encoder) {
  WriteIndexValueAux(value, encoder);
  // Write separator to split index values (see
  // go/firestore-storage-format#encodings).
  encoder->WriteInfinity();
}

}  // namespace index
}  // namespace firestore
}  // namespace firebase
