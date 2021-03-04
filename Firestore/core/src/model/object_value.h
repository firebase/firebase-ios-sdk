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

#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/model/field_mask.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/mutation.h"

namespace firebase {
namespace firestore {
namespace model {

/** A structured object value stored in Firestore. */
class ObjectValue {
 public:
  ObjectValue();

  ObjectValue(Value value);

  static ObjectValue fromMap(Map<String, Value> value);

  PatchMutation(DocumentKey key,
                ObjectValue value,
                FieldMask mask,
                Precondition precondition,
                std::vector<FieldTransform> field_transforms);

  Map<String, Value> getFieldsMap() const;

  /** Recursively extracts the FieldPaths that are set in this ObjectValue. */
  FieldMask getFieldMask() const;

  /**
   * Returns the value at the given path or null.
   *
   * @param fieldPath the path to search
   * @return The value at the path or null if it doesn't exist.
   */
  absl::optional<Value> get(FieldPath fieldPath) const;

  /**
   * Removes the field at the specified path. If there is no field at the
   * specified path nothing is changed.
   *
   * @param path The field path to remove
   */
  void delete (FieldPath path);

  /**
   * Sets the field to the provided value.
   *
   * @param path The field path to set.
   * @param value The value to set.
   */
  void set(FieldPath path, Value value);

  /**
   * Sets the provided fields to the provided values.
   *
   * @param data A map of fields to values (or null for deletes).
   */
  void setAll(Map<FieldPath, Value> data);

 private:
}


            bool operator==(const ObjectValue& lhs, const ObjectValue& rhs);

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_OBJECT_VALUE_H_
