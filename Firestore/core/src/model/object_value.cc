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

#include <map>
#include <set>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace model {

MutableObjectValue::MutableObjectValue() {
  value_->which_value_type = google_firestore_v1_Value_map_value_tag;
  value_->map_value.fields_count = 0;
  value_->map_value.fields =
      nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(0);
}

model::FieldMask MutableObjectValue::ToFieldMask() const {
  return ExtractFieldMask(value_->map_value);
}

model::FieldMask MutableObjectValue::ExtractFieldMask(
    const google_firestore_v1_MapValue& value) const {
  std::set<FieldPath> fields;
  for (size_t i = 0; i < value.fields_count; ++i) {
    FieldPath current_path({nanopb::MakeString(value.fields[i].key)});
    if (value.fields[i].value.which_value_type ==
        google_firestore_v1_Value_map_value_tag) {
      // Recursively extract the nested map
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
    return *value_;
  } else {
    google_firestore_v1_Value nested_value = *value_;
    for (const std::string& segment : path) {
      _google_firestore_v1_MapValue_FieldsEntry* entry =
          FindEntry(nested_value, segment);
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

  std::string last_segment = path.last_segment();
  std::map<std::string, google_firestore_v1_Value> upserts{
      {last_segment, value}};

  ApplyChanges(parent_map, upserts, /* deletes= */ {});
}

void MutableObjectValue::SetAll(const model::FieldMask& field_mask,
                                const MutableObjectValue& data) {
  FieldPath parent;

  std::map<std::string, google_firestore_v1_Value> upserts;
  std::set<std::string> deletes;

  for (const FieldPath& path : field_mask) {
    if (!parent.IsImmediateParentOf(path)) {
      // Insert the accumulated changes at this parent location
      _google_firestore_v1_MapValue* parent_map = ParentMap(parent);
      ApplyChanges(parent_map, upserts, deletes);
      upserts.clear();
      deletes.clear();
      parent = path.PopLast();
    }

    absl::optional<google_firestore_v1_Value> value = data.Get(path);
    if (value) {
      upserts.emplace(path.last_segment(), *value);
    } else {
      deletes.insert(path.last_segment());
    }
  }

  _google_firestore_v1_MapValue* parent_map = ParentMap(parent);
  ApplyChanges(parent_map, upserts, deletes);
}

google_firestore_v1_MapValue* MutableObjectValue::ParentMap(
    const FieldPath& path) {
  google_firestore_v1_Value* parent = value_.get();

  // Find a or create a parent map entry for `path`.
  for (const std::string& segment : path) {
    _google_firestore_v1_MapValue_FieldsEntry* entry =
        FindEntry(*parent, segment);

    if (entry) {
      if (entry->value.which_value_type !=
          google_firestore_v1_Value_map_value_tag) {
        // Since the element is not a map value, free all existing data and
        // change it to a map type
        nanopb::FreeNanopbMessage(google_firestore_v1_Value_fields,
                                  &entry->value);
        entry->value.which_value_type = google_firestore_v1_Value_map_value_tag;
      }
      parent = &entry->value;
    } else {
      // Create a new map value for the current segment
      _google_firestore_v1_Value new_entry{};
      new_entry.which_value_type = google_firestore_v1_Value_map_value_tag;

      std::map<std::string, google_firestore_v1_Value> upserts{
          {segment, new_entry}};
      ApplyChanges(&(parent->map_value), upserts, {});

      parent = &(FindEntry(*parent, segment)->value);
    }
  }

  return &parent->map_value;
}

void MutableObjectValue::ApplyChanges(
    google_firestore_v1_MapValue* parent,
    std::map<std::string, google_firestore_v1_Value> upserts,
    std::set<std::string> deletes) const {
  auto source_count = parent->fields_count;
  auto source_fields = parent->fields;

  // Compute the size of the map after applying all mutations. The final size is
  // the number of existing entries, plus the number of new entries
  // minus the number of deleted entries.
  size_t target_count =
      upserts.size() +
      std::count_if(source_fields, source_fields + source_count,
                    [&](_google_firestore_v1_MapValue_FieldsEntry entry) {
                      std::string field = nanopb::MakeString(entry.key);
                      // Check if the entry is deleted or if it is a replacement
                      // rather than an insert.
                      return deletes.find(field) == deletes.end() &&
                             upserts.find(field) == upserts.end();
                    });

  auto target_fields = static_cast<_google_firestore_v1_MapValue_FieldsEntry*>(
      malloc(target_count * sizeof(_google_firestore_v1_MapValue_FieldsEntry)));

  auto delete_it = deletes.begin();
  auto upsert_it = upserts.begin();

  // Merge the existing data with the deletes and updates.
  for (pb_size_t target_index = 0, source_index = 0;
       target_index < target_count;) {
    if (source_index < source_count) {
      std::string key = nanopb::MakeString(source_fields[source_index].key);

      // Check if the source key is deleted
      if (delete_it != deletes.end() && *delete_it == key) {
        nanopb::FreeNanopbMessage(
            google_firestore_v1_MapValue_FieldsEntry_fields,
            source_fields + source_index);
        ++delete_it;
        ++source_index;
        continue;
      }

      // Check if the source key is updated by the next upsert
      if (upsert_it != upserts.end() && upsert_it->first == key) {
        nanopb::FreeNanopbMessage(google_firestore_v1_Value_fields,
                                  &source_fields[source_index].value);
        target_fields[target_index].key = source_fields[source_index].key;
        target_fields[target_index].value = DeepClone(upsert_it->second);
        ++upsert_it;
        ++target_index;
        ++source_index;
        continue;
      }

      // Check if the source key comes before the next upsert
      if (upsert_it == upserts.end() || upsert_it->first > key) {
        target_fields[target_index] = source_fields[source_index];
        ++target_index;
        ++source_index;
        continue;
      }
    }

    // Otherwise, insert the next upsert.
    target_fields[target_index].key = nanopb::MakeBytesArray(upsert_it->first);
    target_fields[target_index].value = DeepClone(upsert_it->second);
    ++upsert_it;
    ++target_index;
  }

  free(source_fields);

  parent->fields = target_fields;
  parent->fields_count = target_count;
}

void MutableObjectValue::Delete(const FieldPath& path) {
  HARD_ASSERT(!path.empty(), "Cannot set field for empty path on ObjectValue");

  google_firestore_v1_Value* nested_value = value_.get();
  for (const std::string& segment : path.PopLast()) {
    _google_firestore_v1_MapValue_FieldsEntry* entry =
        FindEntry(*nested_value, segment);
    if (!entry) {
      // If the entry is not found, exit early. There is nothing to delete.
      return;
    }
    nested_value = &entry->value;
  }

  // We can only delete a leaf entry if its parent is a map.
  if (nested_value->which_value_type ==
      google_firestore_v1_Value_map_value_tag) {
    std::set<std::string> deletes{path.last_segment()};
    ApplyChanges(&nested_value->map_value, /* upserts= */ {}, deletes);
  }
}

_google_firestore_v1_MapValue_FieldsEntry* MutableObjectValue::FindEntry(
    const google_firestore_v1_Value& value, const std::string& segment) {
  if (value.which_value_type == google_firestore_v1_Value_map_value_tag) {
    const _google_firestore_v1_MapValue& map_value = value.map_value;

    // MapValues in iOS are always stored in sorted order. Binary search for the
    // key.
    pb_size_t low = 0;
    pb_size_t high = map_value.fields_count;

    while (low < high) {
      int mid = (low + (high - 1)) / 2;

      absl::string_view current_key =
          nanopb::MakeStringView(map_value.fields[mid].key);
      if (current_key < segment) {
        low = mid + 1;
      } else if (current_key == segment) {
        return &map_value.fields[mid];
      } else {
        high = mid;
      }
    }
  }
  return nullptr;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
