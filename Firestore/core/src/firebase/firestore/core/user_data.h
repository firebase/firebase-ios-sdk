/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_USER_DATA_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_USER_DATA_H_

#include <vector>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"

@class FSTMutation;
@class FSTObjectValue;

namespace firebase {
namespace firestore {
namespace core {

/** The result of parsing document data (e.g. for a SetData call). */
class ParsedSetData {
 public:
  ParsedSetData(FSTObjectValue* data,
                std::vector<model::FieldTransform> field_transforms);
  ParsedSetData(FSTObjectValue* data,
                model::FieldMask field_mask,
                std::vector<model::FieldTransform> field_transforms);

  /**
   * Converts the parsed document data into 1 or 2 mutations (depending on
   * whether there are any field transforms) using the specified document key
   * and precondition.
   *
   * This method consumes the values stored in the ParsedSetData
   */
  NSArray<FSTMutation*>* ToMutations(
      const model::DocumentKey& key,
      const model::Precondition& precondition) &&;

 private:
  FSTObjectValue* data_;
  model::FieldMask field_mask_;
  std::vector<model::FieldTransform> field_transforms_;
  bool patch_;
};

/** The result of parsing "update" data (i.e. for an UpdateData call). */
class ParsedUpdateData {
 public:
  ParsedUpdateData(FSTObjectValue* data,
                   model::FieldMask field_mask,
                   std::vector<model::FieldTransform> fieldTransforms);

  FSTObjectValue* data() const {
    return data_;
  }

  const std::vector<model::FieldTransform>& field_transforms() const {
    return field_transforms_;
  }

  /**
   * Converts the parsed update data into 1 or 2 mutations (depending on whether
   * there are any field transforms) using the specified document key and
   * precondition.
   *
   * This method consumes the values stored in the ParsedUpdateData
   */
  NSArray<FSTMutation*>* ToMutations(
      const model::DocumentKey& key,
      const model::Precondition& precondition) &&;

 private:
  FSTObjectValue* data_;
  model::FieldMask field_mask_;
  std::vector<model::FieldTransform> field_transforms_;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_USER_DATA_H_
