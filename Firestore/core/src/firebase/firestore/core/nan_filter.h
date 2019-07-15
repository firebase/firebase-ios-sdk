/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_NAN_FILTER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_NAN_FILTER_H_

#include <string>

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"

namespace firebase {
namespace firestore {
namespace core {

/** Filter that matches NaN (not-a-number) values. */
class NanFilter : public Filter {
 public:
  NanFilter() = default;

  explicit NanFilter(model::FieldPath field);

  Type type() const override {
    return Type::kNanFilter;
  }

  const model::FieldPath& field() const override {
    return field_;
  }

  bool Matches(const model::Document& doc) const override;

  std::string CanonicalId() const override;

  std::string ToString() const override;

  size_t Hash() const override;

 protected:
  bool Equals(const Filter& other) const override;

 private:
  model::FieldPath field_;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_NAN_FILTER_H_
