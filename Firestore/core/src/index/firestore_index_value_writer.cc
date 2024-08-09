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

#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace index {
namespace {

// Note: This code is copied from the backend. Code that is not used by
// Firestore was removed.

// The client SDK only supports references to documents from the same database.
// We can skip the first five segments.
constexpr int DocumentNameOffset = 5;

enum IndexType {
  kNull = 5,
  kBoolean = 10,
  kNan = 13,
  kNumber = 15,
  kTimestamp = 20,
  kString = 25,
  kBlob = 30,
  kReference = 37,
  kGeopoint = 45,
  kArray = 50,
  kVector = 53,
  kMap = 55,
  kReferenceSegment = 60,
  // A terminator that indicates that a truncatable value was not truncated.
  // This must be smaller than all other type labels.
  kNotTruncated = 2
};

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

  auto path = model::ResourcePath::FromStringView(
      nanopb::MakeStringView(reference_value));
  auto num_segments = path.size();
  for (size_t index = DocumentNameOffset; index < num_segments; ++index) {
    const std::string& segment = path[index];
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
      double number = index_value.double_value;
      if (std::isnan(number)) {
        WriteValueTypeLabel(encoder, IndexType::kNan);
        break;
      }
      WriteValueTypeLabel(encoder, IndexType::kNumber);
      if (number == -0.0) {
        // -0.0, 0 and 0.0 are all considered the same
        encoder->WriteDouble(0.0);
      } else {
        encoder->WriteDouble(number);
      }
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
      // model::MaxValue() is sentinel map value (see the comment there).
      // In that case, we encode the max int value instead.
      if (model::IsMaxValue(index_value)) {
        WriteValueTypeLabel(encoder, std::numeric_limits<int>::max());
        break;
      } else if (model::IsVectorValue(index_value)) {
        WriteIndexVector(index_value.map_value, encoder);
        break;
      }
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
