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

#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

#include <set>

namespace firebase {
namespace firestore {
namespace model {

FieldMask ObjectValue::FieldMask() const {
  return ExtractFieldMask(BuildProto().map_value);
}

FieldMask ObjectValue::ExtractFieldMask(
    const google_firestore_v1_MapValue& value) const {
  std::set<FieldPath> fields;
  for (size_t i = 0; i < value.fields_count; ++i) {
    FieldPath current_path({nanopb::MakeString(value.fields[i].key)});
    if (value.fields[i].value.which_value_type ==
        google_firestore_v1_Value_map_value_tag) {
      FieldMask nested_mask = ExtractFieldMask(value.fields[i].value.map_value);
      if (nested_mask.begin() == nested_mask.end()) {
        // Preserve the empty map by adding it to the FieldMask.
        fields.insert(current_path);
      } else {
        for (const FieldPath& nested_path : nested_mask) {
          fields.insert(current_path.Append(nested_path));
        }
      }
    } else {
      fields.insert(current_path);
    }
  }
  return model::FieldMask(fields);
}

absl::optional<google_firestore_v1_Value> ObjectValue::Get(
    const firebase::firestore::model::FieldPath& path) const {
  return ExtractNestedValue(BuildProto(), path);
}

absl::optional<google_firestore_v1_Value> ObjectValue::ExtractNestedValue(
    const google_firestore_v1_Value& value, const FieldPath& field_path) const {
  if (field_path.empty()) {
    return value;
  } else {
    google_firestore_v1_Value nested_value = value;
    for (const std::string& segment : field_path) {
      if (nested_value.which_value_type !=
          google_firestore_v1_Value_map_value_tag) {
        return {};
      }

      for (size_t i = 0; i < nested_value.map_value.fields_count; ++i) {
        if (segment ==
            nanopb::MakeStringView(nested_value.map_value.fields[i].key)) {
          nested_value = nested_value.map_value.fields[i].value;
          continue;
        }
      }

      return {};
    }

    return nested_value;
  }
}

void ObjectValue::Set(
    const firebase::firestore::model::FieldPath& path,
    const firebase::firestore::google_firestore_v1_Value& value) {
  HARD_ASSERT(!path.empty(), "Cannot set field for empty path on ObjectValue");
  Overlay overlay;
  overlay.tag_ = Overlay::Tag::Value;
  overlay.value_ = value;
  SetOverlay(path, overlay);
}

void ObjectValue::SetAll(
    const FieldMask& field_mask,
    const std::unordered_map<firebase::firestore::model::FieldPath,
                             google_firestore_v1_Value>& data) {
  for (const FieldPath& path : field_mask) {
    const auto& value = data.find(path);
    if (value == data.end()) {
      Delete(path);
    } else {
      Set(path, *value);
    }
  }
}

void ObjectValue::Delete(const firebase::firestore::model::FieldPath& path) {
  Overlay overlay;
  overlay.tag_ = Overlay::Tag::Delete;
  SetOverlay(path, overlay);
}

void ObjectValue::SetOverlay(const FieldPath& path,
                             const ObjectValue::Overlay& value) {
  std::unordered_map<std::string, Overlay> current_level = overlap_map_;

  for (const std::string& segment : path.PopLast()) {
    const auto& current_value = current_level.find(segment);

    if (current_value != current_level.end()) {
      if (current_value.tag_ == Overlay::Tag::NestedValue) {
        // Re-use a previously created map
        current_level = current_value.nested_value_;
      } else if (current_value.tag_ == Overlay::Tag::Value &&
                 current_value.value_.which_value_type ==
                     google_firestore_v1_Value_map_value_tag) {
        // Convert the existing Protobuf MapValue into a Java map
        Map<String, Object> nextLevel =
            new HashMap<>(((Value)current_value).getMapValue().getFieldsMap());
        current_level.put(currentSegment, nextLevel);
        current_level = nextLevel;
      }
    }
    // Create an empty hash map to represent the current nesting level
    std::unordered_map<std::string, Overlay> next_level;
    current_level.insert(segment, next_level);
    current_level = next_level;
  }

  current_level.insert(path.LastSegment(), value);
}

const google_firestore_v1_Value& ObjectValue::BuildProto() const {
  absl::optional<google_firestore_v1_MapValue> merged_result =
      ApplyOverlay(FieldPath(), overlap_map_);
  if (merged_result) {
    partial_value_.which_value_type = google_firestore_v1_Value_map_value_tag;
    partial_value_.map_value = *merged_result;
    overlap_map_.clear();
  }
  return partial_value_;
}

const absl::optional<google_firestore_v1_MapValue> ObjectValue::ApplyOverlay(
    const FieldPath& current_path,
    const std::unordered_map<std::string, Overlay>& current_overlays) const {
  bool modified = false;

  absl::optional<google_firestore_v1_Value> existing_value =
      ExtractNestedValue(partial_value_, current_path);
  std::unordered_map<std::string, google_firestore_v1_Value> result_at_path;

  // If there is already data at the current path, base our modifications on top
  // of the existing data.
  if (existing_value && existing_value->which_value_type ==
                            google_firestore_v1_Value_map_value_tag) {
    result_at_path = ConvertToUnorderedMap(existing_value);  // Copy
  }

  for (const auto& entry : current_overlays) {
    const std::string& path_segment = entry.first;
    const Overlay& value = entry.second;

    if (value.tag_ == Overlay::Tag::NestedValue) {
      const absl::optional<google_firestore_v1_MapValue>& nested =
          ApplyOverlay(current_path.Append(path_segment), value.nested_value_);
      if (nested) {
        result_at_path.putFields(
            path_segment, Value.newBuilder().setMapValue(nested).build());
        modified = true;
      }
    } else if (value.tag_ == Overlay::Tag::Value) {
      result_at_path.putFields(path_segment, (Value)value);
      modified = true;
    } else if (result_at_path.containsFields(path_segment)) {
      hardAssert(value == null, "Expected entry to be a Map, a Value or null");
      result_at_path.removeFields(path_segment);
      modified = true;
    }
  }

  return modified ? result_at_path.build() : null;
}

const   std::unordered_map<std::string, google_firestore_v1_Value>& ConvertToUnorderedMap(const google_firestore_v1_MapValue& map_value) {

}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
