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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_TRANSFORM_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_TRANSFORM_H_

#include <memory>
#include <utility>

#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"

namespace firebase {
namespace firestore {
namespace model {

/** A field path and the TransformOperation to perform upon it. */
class FieldTransform {
 public:
  FieldTransform(FieldPath path,
                 std::unique_ptr<TransformOperation> transformation) noexcept
      : path_{std::move(path)}, transformation_{std::move(transformation)} {
  }

  const FieldPath& path() const {
    return path_;
  }

  const TransformOperation& transformation() const {
    return *transformation_.get();
  }

  bool operator==(const FieldTransform& other) const {
    return path_ == other.path_ && *transformation_ == *other.transformation_;
  }

#if defined(__OBJC__)
  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  NSUInteger Hash() const {
    NSUInteger hash = path_.Hash();
    hash = hash * 31 + transformation_->Hash();
    return hash;
  }
#endif  // defined(__OBJC__)

 private:
  FieldPath path_;
  // Shared by copies of the same FieldTransform.
  std::shared_ptr<const TransformOperation> transformation_;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_TRANSFORM_H_
