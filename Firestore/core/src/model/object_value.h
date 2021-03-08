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

#ifndef FIRESTORE_CORE_SRC_MODEL_OBJECT_VALUE_H_
#define FIRESTORE_CORE_SRC_MODEL_OBJECT_VALUE_H_

#include <string>
#include <unordered_map>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/model/field_mask.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

class FieldPath;

/** A structured object value stored in Firestore. */
class ObjectValue {
 public:
  ObjectValue() = default;

  ObjectValue(google_firestore_v1_Value value) : partial_value_(value) {
    HARD_ASSERT(
        value.which_value_type == google_firestore_v1_Value_map_value_tag,
        "ObjectValues should be backed by a MapValue");
  };

  std::unordered_map<std::string, google_firestore_v1_Value> FieldsMap() const;

  /** Recursively extracts the FieldPaths that are set in this ObjectValue. */
  FieldMask FieldMask() const;

  /**
   * Returns the value at the given path or null.
   *
   * @param fieldPath the path to search
   * @return The value at the path or null if it doesn't exist.
   */
  absl::optional<google_firestore_v1_Value> Get(const FieldPath& path) const;

  /**
   * Removes the field at the specified path. If there is no field at the
   * specified path nothing is changed.
   *
   * @param path The field path to remove
   */
  void Delete(const FieldPath& path);

  /**
   * Sets the field to the provided value.
   *
   * @param path The field path to set.
   * @param value The value to set.
   */
  void Set(const FieldPath& path, const google_firestore_v1_Value& value);

  /**
   * Sets the provided fields to the provided values.
   *
   * @param data A map of fields to values (or null for deletes).
   */
  void SetAll(
      const FieldMask& field_mask,
      const std::unordered_map<FieldPath, google_firestore_v1_Value>& data);

 private:
  struct Overlay {
      Overlay() = default;
    enum class Tag { Delete, Value, NestedValue };

    Tag tag_;
    union {
      google_firestore_v1_Value value_;
      std::unordered_map<std::string, google_firestore_v1_Value> nested_value_{};
    };
  };

  FieldMask ExtractFieldMask(const google_firestore_v1_MapValue& value) const;
  absl::optional<google_firestore_v1_Value> ExtractNestedValue(
      const google_firestore_v1_Value& value,
      const FieldPath& field_path) const;
  const google_firestore_v1_Value& BuildProto() const;

  /**
   * Adds value to the overlay map at { path. Creates nested map entries if
   * needed.
   */
  void SetOverlay(const FieldPath& path, const Overlay& overlay);

  /**
   * Applies any overlays from currentOverlays that exist at currentPath and
   * returns the merged data at currentPatj if there were no changes).
   *
   * @param current_path The path at the current nesting level. Can be set to an
   * empty field path to represent the root.
   * @param current_overlays The overlays at the current nesting level in the
   * same format as overlay_map_.
   * @return The merged data at currentPath or an empty optional if no
   * modifications were applied.
   */
  const absl::optional<google_firestore_v1_MapValue> ApplyOverlay(
      const FieldPath& current_path,
      const std::unordered_map<std::string, Overlay>& current_overlays) const;

  /**
   * The immutable Value proto for this object. Local mutations are stored in
   * `overlayMap` and only applied when buildProto() is invoked.
   */
  mutable google_firestore_v1_Value partial_value_;

  /**
   * A nested map that contains the accumulated changes that haven't yet been
   * applied to {@link #partialValue}. Values can either be {@link Value}
   * protos, {@code Map<String, Object>} values (to represent additional
   * nesting) or {@code null} (to represent field deletes).
   */
  mutable std::unordered_map<std::string, Overlay> overlap_map_;
};

bool operator==(const ObjectValue& lhs, const ObjectValue& rhs);

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_OBJECT_VALUE_H_
