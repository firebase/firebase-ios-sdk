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

#include "aggregate_field.h"

namespace firebase {
namespace firestore {
namespace model {

const std::string AggregateField::kOpSum = "sum";
const std::string AggregateField::kOpAvg = "avg";
const std::string AggregateField::kOpCount = "count";

bool operator==(const AggregateField& lhs, const AggregateField& rhs) {
  return lhs.op == rhs.op && lhs.alias == rhs.alias &&
         lhs.fieldPath.CanonicalString() == rhs.fieldPath.CanonicalString();
}

size_t AggregateField::Hash() const {
  return util::Hash(op, alias, fieldPath.CanonicalString());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase