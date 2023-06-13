/*
 * Copyright 2023 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_MODEL_AGGREGATE_FIELD_H_
#define FIRESTORE_CORE_SRC_MODEL_AGGREGATE_FIELD_H_

#include <string>
#include <utility>

#include "Firestore/core/src/model/aggregate_alias.h"
#include "Firestore/core/src/model/aggregate_field.h"
#include "Firestore/core/src/model/field_path.h"

namespace firebase {
namespace firestore {
namespace model {

class AggregateField {
 public:
  enum class OpKind { Sum, Avg, Count };

  const OpKind op;
  const model::AggregateAlias alias;
  const model::FieldPath fieldPath;

  AggregateField(OpKind op, model::AggregateAlias&& alias)
      : op(op), alias(std::move(alias)) {
  }
  AggregateField(OpKind op,
                 model::AggregateAlias&& alias,
                 const model::FieldPath& fieldPath)
      : op(op), alias(std::move(alias)), fieldPath(fieldPath) {
  }

  friend bool operator==(const AggregateField& lhs, const AggregateField& rhs);

  size_t Hash() const;
};

inline bool operator==(const AggregateField& lhs, const AggregateField& rhs) {
  return lhs.op == rhs.op && lhs.alias == rhs.alias &&
         lhs.fieldPath.CanonicalString() == rhs.fieldPath.CanonicalString();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_AGGREGATE_FIELD_H_
