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

#include <set>
#include <unordered_map>
#include <unordered_set>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace model {

MutableObjectValue::MutableObjectValue() {
  value_.which_value_type = google_firestore_v1_Value_map_value_tag;
  value_.map_value.fields_count = 0;
  value_.map_value.fields =
      nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(0);
}

model::FieldMask MutableObjectValue::ToFieldMask() const {
  return ExtractFieldMask(value_.map_value);
}

model::FieldMask MutableObjectValue::ExtractFieldMask(
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

absl::optional<google_firestore_v1_Value> MutableObjectValue::Get(
    const firebase::firestore::model::FieldPath& path) const {
  if (path.empty()) {
    return value_;
  } else {
    google_firestore_v1_Value nested_value = value_;
    for (const std::string& segment : path) {
      _google_firestore_v1_MapValue_FieldsEntry* entry =
          FindNestedEntry(nested_value, segment);
      if (!entry) return {};
      nested_value = entry->value;
    }

    return nested_value;
  }
}

void MutableObjectValue::Set(const model::FieldPath& path,
                             const google_firestore_v1_Value& value) {
  HARD_ASSERT(!path.empty(), "Cannot set field for empty path on ObjectValue");

  _google_firestore_v1_MapValue* parent_map = ParentMap(path.PopLast());
  std::unordered_map<std::string, google_firestore_v1_Value> inserts = {
      {path.last_segment(), value}};
  ApplyChanges(parent_map, {}, inserts);
}

void MutableObjectValue::SetAll(const model::FieldMask& field_mask,
                                const MutableObjectValue& data) {
  FieldPath parent = {};

  std::unordered_set<std::string> deletes;
  std::unordered_map<std::string, google_firestore_v1_Value> inserts;
  for (const FieldPath& path : field_mask) {
    if (!parent.IsImmediateParentOf(path)) {
      _google_firestore_v1_MapValue* parent_map = ParentMap(parent);
      ApplyChanges(parent_map, deletes, inserts);
      inserts.clear();
      deletes.clear();
      parent = path.PopLast();
    }

    absl::optional<google_firestore_v1_Value> value = data.Get(path);
    if (value) {
      inserts.emplace(path.last_segment(), *value);
    } else {
      deletes.insert(path.last_segment());
    }
  }

  _google_firestore_v1_MapValue* parent_map = ParentMap(parent);
  ApplyChanges(parent_map, deletes, inserts);
}

google_firestore_v1_MapValue* MutableObjectValue::ParentMap(
    const FieldPath& path) {
  google_firestore_v1_Value* parent = &value_;

  // Find a or create a parent map entry for `value`.
  for (const std::string& segment : path) {
    _google_firestore_v1_MapValue_FieldsEntry* entry =
        FindNestedEntry(*parent, segment);

    if (entry) {
      if (entry->value.which_value_type !=
          google_firestore_v1_Value_map_value_tag) {
        nanopb::FreeNanopbMessage(google_firestore_v1_Value_fields,
                                  &entry->value);
        entry->value.which_value_type = google_firestore_v1_Value_map_value_tag;
      }
      parent = &entry->value;
    } else {
      _google_firestore_v1_Value new_entry{};
      new_entry.which_value_type = google_firestore_v1_Value_map_value_tag;
      std::unordered_map<std::string, google_firestore_v1_Value> inserts = {
          {segment, new_entry}};
      ApplyChanges(&(parent->map_value), {}, inserts);
      parent =
          &parent->map_value.fields[parent->map_value.fields_count - 1].value;
    }
  }

  return &parent->map_value;
}

void MutableObjectValue::ApplyChanges(
    google_firestore_v1_MapValue* parent,
    const std::unordered_set<std::string>& deletes,
    std::unordered_map<std::string, google_firestore_v1_Value>& inserts) const {
  size_t target_size =
      inserts.size() +
      std::count_if(parent->fields, parent->fields + parent->fields_count,
                    [&](_google_firestore_v1_MapValue_FieldsEntry entry) {
                      std::string field = nanopb::MakeString(entry.key);
                      return deletes.find(field) == deletes.end() &&
                             inserts.find(field) == inserts.end();
                    });

  if (target_size > parent->fields_count) {
    parent->fields =
        static_cast<_google_firestore_v1_MapValue_FieldsEntry*>(realloc(
            parent->fields,
            target_size * sizeof(_google_firestore_v1_MapValue_FieldsEntry)));
  }

  pb_size_t target_index = 0;
  for (pb_size_t source_index = 0; source_index < parent->fields_count;
       ++source_index) {
    std::string key = nanopb::MakeString(parent->fields[source_index].key);

    const auto& delete_it = deletes.find(key);
    const auto& insert_it = inserts.find(key);

    if (insert_it != inserts.end()) {
      parent->fields[target_index].value = insert_it->second;
      inserts.erase(key);
      ++target_index;
    } else if (delete_it == deletes.end()) {
      parent->fields[target_index] = parent->fields[source_index];
      ++target_index;
    }
  }

  for (const auto& entry : inserts) {
    parent->fields[target_index].key = nanopb::MakeBytesArray(entry.first);
    parent->fields[target_index].value = entry.second;
    ++target_index;
  }

  if (target_size < parent->fields_count) {
    parent->fields =
        static_cast<_google_firestore_v1_MapValue_FieldsEntry*>(realloc(
            parent->fields,
            target_size * sizeof(_google_firestore_v1_MapValue_FieldsEntry)));
  }

  parent->fields_count = target_size;
}

void MutableObjectValue::Delete(const FieldPath& path) {
  HARD_ASSERT(!path.empty(), "Cannot set field for empty path on ObjectValue");

  std::unordered_set<std::string> deletes;
  std::unordered_map<std::string, google_firestore_v1_Value> inserts;

    google_firestore_v1_Value* nested_value = &value_;
    for (const std::string& segment : path.PopLast()) {
        _google_firestore_v1_MapValue_FieldsEntry* entry =
                FindNestedEntry(*nested_value, segment);
        if (!entry || entry->value.which_value_type != google_firestore_v1_Value_map_value_tag) return;
        nested_value = &entry->value;
    }

  deletes.emplace(path.last_segment());
  ApplyChanges(&nested_value->map_value, deletes, inserts);
}

_google_firestore_v1_MapValue_FieldsEntry* MutableObjectValue::FindNestedEntry(
    const google_firestore_v1_Value& value, const std::string& segment) {
  if (value.which_value_type == google_firestore_v1_Value_map_value_tag) {
    const _google_firestore_v1_MapValue& map_value = value.map_value;
    for (size_t i = 0; i < map_value.fields_count; ++i) {
      if (nanopb::MakeStringView(map_value.fields[i].key) == segment) {
        return &map_value.fields[i];
      }
    }
  }
  return nullptr;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
