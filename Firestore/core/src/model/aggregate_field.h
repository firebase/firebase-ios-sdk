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

#ifndef FIREBASE_AGGREGATE_FIELD_H_
#define FIREBASE_AGGREGATE_FIELD_H_

#include <string>
#include "Firestore/core/src/model/aggregate_alias.h"
#include "Firestore/core/src/model/field_path.h"

namespace firebase {
namespace firestore {
namespace model {

class AggregateField {
 public:
  static const std::string kOpSum;
  static const std::string kOpAvg;
  static const std::string kOpCount;

  const std::string op;
  const model::AggregateAlias alias;
  const model::FieldPath fieldPath;

  AggregateField() {}
  AggregateField(const std::string& op, model::AggregateAlias&& alias)
      : op(op), alias(std::move(alias)) {
  }
  AggregateField(const std::string& op, model::AggregateAlias&& alias, const model::FieldPath& fieldPath)
      : op(op), alias(std::move(alias)), fieldPath(fieldPath) {
  }

  friend bool operator==(const AggregateField& lhs, const AggregateField& rhs);
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_AGGREGATE_FIELD_H_
