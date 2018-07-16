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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_RELATION_FILTER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_RELATION_FILTER_H_

#include <string>

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"

namespace firebase {
namespace firestore {
namespace core {

/** Represents a filter to be applied to the query. */
class RelationFilter : public Filter {
 public:
  /**
   * Creates a new filter that compares fields and values. Only intended to be
   * called from Filter::Create().
   */
  RelationFilter(model::FieldPath field,
                 Operator op,
                 model::FieldValue value_rhs);

  const model::FieldPath& field() const override;

  bool Matches(const model::Document& doc) const override;

  std::string CanonicalId() const override;

 private:
  bool MatchesValue(const model::FieldValue& other) const;
  bool MatchesComparison(const model::FieldValue& other) const;

  const model::FieldPath field_;
  const Operator op_;
  const model::FieldValue value_rhs_;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_RELATION_FILTER_H_
