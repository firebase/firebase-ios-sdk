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
#include "object_value.h"

#include <Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h>
#include <set>

namespace firebase {
namespace firestore {
namespace model {

model::FieldMask ObjectValue::FieldMask() const {
  return ExtractFieldMask(BuildProto().map_value);
}

model::FieldMask ObjectValue::ExtractFieldMask(
    const google_firestore_v1_MapValue& value) const {
  std::set<FieldPath> fields;
  for (size_t i = 0; i < value.fields_count; ++i) {
    FieldPath current_path({nanopb::MakeString(value.fields[i].key)});
    if (value.fields[i].value.which_value_type ==
        google_firestore_v1_Value_map_value_tag) {
      model::FieldMask nested_mask =
          ExtractFieldMask(value.fields[i].value.map_value);
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

      bool key_found = false;
      for (size_t i = 0; !key_found && i < nested_value.map_value.fields_count;
           ++i) {
        if (segment ==
            nanopb::MakeStringView(nested_value.map_value.fields[i].key)) {
          nested_value = nested_value.map_value.fields[i].value;
          key_found = true;
        }
      }

      if (!key_found) return {};
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
    const model::FieldMask& field_mask,
    const std::unordered_map<FieldPath, google_firestore_v1_Value>& data) {
  for (const FieldPath& path : field_mask) {
    const auto& value = data.find(path);
    if (value == data.end()) {
      Delete(path);
    } else {
      Set(path, *value);
    }
  }
}

void ObjectValue::Delete(const FieldPath& path) {
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
      const Overlay& existing_overlay = current_value->second;
      if (existing_overlay.tag_ == Overlay::Tag::OverlayMap) {
        // Re-use a previously created map
        current_level = existing_overlay.overlay_map_;
      } else if (existing_overlay.tag_ == Overlay::Tag::Value &&
                 existing_overlay.value_.which_value_type ==
                     google_firestore_v1_Value_map_value_tag) {
        // Convert the existing Protobuf MapValue into a Java map

        std::unordered_map<std::string, Overlay> next_level =
            ConvertToOverlay(existing_overlay.value_.map_value);
        Overlay overlay;
        overlay.tag_ = Overlay::Tag::OverlayMap;
        overlay.overlay_map_ = next_level;
        current_level.emplace(segment, next_level);
        current_level = next_level;
      }
    } else {
      // Create an empty hash map to represent the current nesting level
      std::unordered_map<std::string, Overlay> next_level;
      Overlay overlay;
      overlay.tag_ = Overlay::Tag::OverlayMap;
      overlay.overlay_map_ = next_level;
      current_level.emplace(segment, overlay);
      current_level = next_level;
    }
  }

  current_level.emplace(path.last_segment(), value);
}

const google_firestore_v1_Value& ObjectValue::BuildProto() const {
  absl::optional<OverlayMap> merged_result =
      ApplyOverlay(FieldPath(), overlap_map_);
  if (merged_result) {
    partial_value_.which_value_type = google_firestore_v1_Value_map_value_tag;
    partial_value_.map_value = ConvertToMapValue(*merged_result);
    overlap_map_.clear();
  }
  return partial_value_;
}

absl::optional<ObjectValue::OverlayMap> ObjectValue::ApplyOverlay(
    const FieldPath& current_path,
    const std::unordered_map<std::string, Overlay>& current_overlays) const {
  bool modified = false;

  absl::optional<google_firestore_v1_Value> existing_value =
      ExtractNestedValue(partial_value_, current_path);
  OverlayMap result_at_path;

  // If there is already data at the current path, base our modifications on top
  // of the existing data.
  if (existing_value && existing_value->which_value_type ==
                            google_firestore_v1_Value_map_value_tag) {
    result_at_path = ConvertToOverlay(existing_value->map_value);
  }

  for (const auto& entry : current_overlays) {
    const std::string& path_segment = entry.first;
    const Overlay& value = entry.second;

    if (value.tag_ == Overlay::Tag::OverlayMap) {
      absl::optional<std::unordered_map<std::string, Overlay>> nested =
          ApplyOverlay(current_path.Append(path_segment), value.overlay_map_);
      if (nested) {
        Overlay overlay;
        overlay.tag_ = Overlay::Tag::OverlayMap;
        google_firestore_v1_Value nested_map;
        nested_map.which_value_type = google_firestore_v1_Value_map_value_tag;
        nested_map.map_value = *nested;
        result_at_path.emplace(path_segment, nested_map);
        modified = true;
      }
    } else if (value.tag_ == Overlay::Tag::Value) {
      result_at_path.emplace(path_segment, value.value_);
      modified = true;
    } else if (result_at_path.find(path_segment) != result_at_path.end()) {
      HARD_ASSERT(value.tag_ == Overlay::Tag::Delete,
                  "Expected entry to be a NestedValue, a Value or a delete.");
      result_at_path.erase(path_segment);
      modified = true;
    }
  }

  return modified ? absl::optional<OverlayMap>{result_at_path}
                  : absl::optional<google_firestore_v1_MapValue>{};
}

ObjectValue::OverlayMap ObjectValue::ConvertToOverlay(
    const google_firestore_v1_MapValue& map) {
  std::unordered_map<std::string, Overlay> result;
  for (size_t i = 0; i < map.fields_count; ++i) {
    Overlay overlay;
    overlay.tag_ = Overlay::Tag::Value;
    overlay.value_ = map.fields[i].value;
    result.emplace(nanopb::MakeString(map.fields[i].key), overlay);
  }
  return result;
}

google_firestore_v1_MapValue ObjectValue::ConvertToMapValue(
    const ObjectValue::OverlayMap& overlay_map) {
  google_firestore_v1_MapValue result;
  result.fields_count = overlay_map.size();
  result.fields = nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(
      overlay_map.size());

  size_t i = overlay_map.size();

  for (const auto& entry : overlay_map) {
    result.fields[i].key = nanopb::MakeBytesArray(entry.first);
    if (entry.second.tag_ == Overlay::Tag::Value) {
      result.fields[i].value = entry.second.value_;
    } else if (entry.second.tag_ == Overlay::Tag::OverlayMap) {
      result.fields[i].value.which_value_type =
          google_firestore_v1_Value_map_value_tag;
      result.fields[i].value.map_value =
          ConvertToMapValue(entry.second.overlay_map_);
    }
    // what about deletes?
    ++i;
  }
  return result;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
