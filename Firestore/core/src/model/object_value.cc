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

#include <algorithm>
#include <map>
#include <set>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/nanopb/fields_array.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace model {

namespace {

using nanopb::FieldsArray;
using nanopb::FreeNanopbMessage;
using nanopb::MakeArray;
using nanopb::MakeBytesArray;
using nanopb::MakeString;
using nanopb::MakeStringView;

struct MapEntryKeyCompare {
  bool operator()(const google_firestore_v1_MapValue_FieldsEntry& entry,
                  absl::string_view segment) {
    return nanopb::MakeStringView(entry.key) < segment;
  }
  bool operator()(absl::string_view segment,
                  const google_firestore_v1_MapValue_FieldsEntry& entry) {
    return segment < nanopb::MakeStringView(entry.key);
  }
};

/**
 * Finds an entry by key in the provided map value. Returns `nullptr` if the
 * entry does not exist.
 */
static google_firestore_v1_MapValue_FieldsEntry* FindEntry(
    const google_firestore_v1_Value& value, absl::string_view segment) {
  if (value.which_value_type != google_firestore_v1_Value_map_value_tag) {
    return nullptr;
  }
  const google_firestore_v1_MapValue& map_value = value.map_value;

  // MapValues in iOS are always stored in sorted order.
  auto found = std::equal_range(map_value.fields,
                                map_value.fields + map_value.fields_count,
                                segment, MapEntryKeyCompare());

  if (found.first == found.second) {
    return nullptr;
  }

  return found.first;
}

}  // namespace

MutableObjectValue::MutableObjectValue() {
  value_->which_value_type = google_firestore_v1_Value_map_value_tag;
  value_->map_value.fields_count = 0;
  value_->map_value.fields = nullptr;
}

model::FieldMask MutableObjectValue::ToFieldMask() const {
  return ExtractFieldMask(value_->map_value);
}

model::FieldMask MutableObjectValue::ExtractFieldMask(
    const google_firestore_v1_MapValue& value) const {
  std::set<FieldPath> fields;

  for (size_t i = 0; i < value.fields_count; ++i) {
    google_firestore_v1_MapValue_FieldsEntry& entry = value.fields[i];
    FieldPath current_path({MakeString(entry.key)});

    if (entry.value.which_value_type !=
        google_firestore_v1_Value_map_value_tag) {
      fields.insert(current_path);
      continue;
    }

    // Recursively extract the nested map
    FieldMask nested_mask = ExtractFieldMask(entry.value.map_value);
    if (nested_mask.begin() == nested_mask.end()) {
      // Preserve the empty map by adding it to the FieldMask.
      fields.insert(current_path);
    } else {
      for (const FieldPath& nested_path : nested_mask) {
        fields.insert(current_path.Append(nested_path));
      }
    }
  }

  return FieldMask(std::move(fields));
}

absl::optional<google_firestore_v1_Value> MutableObjectValue::Get(
    const FieldPath& path) const {
  if (path.empty()) {
    return *value_;
  }

  google_firestore_v1_Value nested_value = *value_;
  for (const std::string& segment : path) {
    google_firestore_v1_MapValue_FieldsEntry* entry =
        FindEntry(nested_value, segment);
    if (!entry) return {};
    nested_value = entry->value;
  }
  return nested_value;
}

void MutableObjectValue::Set(const FieldPath& path,
                             const google_firestore_v1_Value& value) {
  HARD_ASSERT(!path.empty(), "Cannot set field for empty path on ObjectValue");

  google_firestore_v1_MapValue* parent_map = ParentMap(path.PopLast());

  std::string last_segment = path.last_segment();
  std::map<std::string, google_firestore_v1_Value> upserts{
      {std::move(last_segment), value}};

  ApplyChanges(parent_map, upserts, /*deletes=*/{});
}

void MutableObjectValue::SetAll(const FieldMask& field_mask,
                                const MutableObjectValue& data) {
  FieldPath parent;

  std::map<std::string, google_firestore_v1_Value> upserts;
  std::set<std::string> deletes;

  for (const FieldPath& path : field_mask) {
    if (!parent.IsImmediateParentOf(path)) {
      // Insert the accumulated changes at this parent location
      google_firestore_v1_MapValue* parent_map = ParentMap(parent);
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

  google_firestore_v1_MapValue* parent_map = ParentMap(parent);
  ApplyChanges(parent_map, upserts, deletes);
}

void MutableObjectValue::Delete(const FieldPath& path) {
  HARD_ASSERT(!path.empty(), "Cannot set field for empty path on ObjectValue");

  google_firestore_v1_Value* nested_value = value_.get();
  for (const std::string& segment : path.PopLast()) {
    google_firestore_v1_MapValue_FieldsEntry* entry =
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
    ApplyChanges(&nested_value->map_value, /*upserts=*/{}, deletes);
  }
}

/**
 * Returns the map that contains the leaf element of `path`. If the parent
 * entry does not yet exist, or if it is not a map, a new map will be created.
 */
google_firestore_v1_MapValue* MutableObjectValue::ParentMap(
    const FieldPath& path) {
  google_firestore_v1_Value* parent = value_.get();

  // Find a or create a parent map entry for `path`.
  for (const std::string& segment : path) {
    google_firestore_v1_MapValue_FieldsEntry* entry =
        FindEntry(*parent, segment);

    if (entry) {
      if (entry->value.which_value_type !=
          google_firestore_v1_Value_map_value_tag) {
        // Since the element is not a map value, free all existing data and
        // change it to a map type
        FreeNanopbMessage(FieldsArray<google_firestore_v1_Value>(),
                          &entry->value);
        entry->value.which_value_type = google_firestore_v1_Value_map_value_tag;
      }

      parent = &entry->value;
    } else {
      // Create a new map value for the current segment
      google_firestore_v1_Value new_entry{};
      new_entry.which_value_type = google_firestore_v1_Value_map_value_tag;

      std::map<std::string, google_firestore_v1_Value> upserts{
          {segment, new_entry}};
      ApplyChanges(&(parent->map_value), upserts, /*deletes=*/{});

      parent = &(FindEntry(*parent, segment)->value);
    }
  }

  return &parent->map_value;
}

void MutableObjectValue::ApplyChanges(
    google_firestore_v1_MapValue* parent,
    const std::map<std::string, google_firestore_v1_Value>& upserts,
    const std::set<std::string>& deletes) const {
  auto source_count = parent->fields_count;
  auto* source_fields = parent->fields;

  // Compute the size of the map after applying all mutations. The final size is
  // the number of existing entries, plus the number of new entries
  // minus the number of deleted entries.
  size_t target_count =
      upserts.size() +
      std::count_if(source_fields, source_fields + source_count,
                    [&](const google_firestore_v1_MapValue_FieldsEntry& entry) {
                      std::string field = MakeString(entry.key);
                      // Don't count if entry is deleted or if it is a
                      // replacement rather than an insert.
                      return deletes.find(field) == deletes.end() &&
                             upserts.find(field) == upserts.end();
                    });

  auto* target_fields =
      MakeArray<google_firestore_v1_MapValue_FieldsEntry>(target_count);

  auto delete_it = deletes.begin();
  auto upsert_it = upserts.begin();

  // Merge the existing data with the deletes and updates.
  for (pb_size_t source_index = 0, target_index = 0;
       target_index < target_count;) {
    if (source_index < source_count) {
      std::string key = MakeString(source_fields[source_index].key);

      // Check if the source key is deleted
      if (delete_it != deletes.end() && *delete_it == key) {
        FreeNanopbMessage(google_firestore_v1_MapValue_FieldsEntry_fields,
                          source_fields + source_index);
        ++delete_it;
        ++source_index;
        continue;
      }

      // Check if the source key is updated by the next upsert
      if (upsert_it != upserts.end() && upsert_it->first == key) {
        FreeNanopbMessage(google_firestore_v1_Value_fields,
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
    target_fields[target_index].key = MakeBytesArray(upsert_it->first);
    target_fields[target_index].value = DeepClone(upsert_it->second);
    ++upsert_it;
    ++target_index;
  }

  free(source_fields);

  parent->fields = target_fields;
  parent->fields_count = target_count;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
