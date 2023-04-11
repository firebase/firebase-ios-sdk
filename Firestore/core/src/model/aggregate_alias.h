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

#ifndef FIRESTORE_CORE_SRC_MODEL_AGGREGATE_ALIAS_H_
#define FIRESTORE_CORE_SRC_MODEL_AGGREGATE_ALIAS_H_

#include <string>

namespace firebase {
namespace firestore {
namespace model {

class AggregateAlias {
 public:
  AggregateAlias() : _alias() {
  }
  explicit AggregateAlias(const std::string alias) : _alias(alias) {
  }

  const std::string& StringValue() const;

  friend bool operator==(const AggregateAlias& lhs, const AggregateAlias& rhs);

  size_t Hash() const;

 private:
  const std::string _alias;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_AGGREGATE_ALIAS_H_
