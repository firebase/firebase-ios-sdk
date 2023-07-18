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

#include "Firestore/core/src/model/aggregate_alias.h"

#include "Firestore/core/src/util/hashing.h"

namespace firebase {
namespace firestore {
namespace model {

const std::string& AggregateAlias::StringValue() const {
  return _alias;
}

bool operator==(const AggregateAlias& lhs, const AggregateAlias& rhs) {
  return lhs._alias == rhs._alias;
}

size_t AggregateAlias::Hash() const {
  return util::Hash(_alias);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
