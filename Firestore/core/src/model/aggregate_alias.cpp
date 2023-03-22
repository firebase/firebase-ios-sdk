/*
* Copyright 2023 Google
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

#include "aggregate_alias.h"

#include "absl/strings/str_replace.h"

namespace firebase {
namespace firestore {
namespace model {

std::string AggregateAlias::CanonicalString() const {
  auto escaped = absl::StrReplaceAll(this->alias, {{"\\", "\\\\"}, {"`", "\\`"}});
  if (!AggregateAlias::IsValidAlias(escaped)) {
    escaped.insert(escaped.begin(), '`');
    escaped.push_back('`');
  }
  return escaped;
}

bool operator==(const AggregateAlias& lhs,
                const AggregateAlias& rhs) {
  return lhs.CanonicalString() == rhs.CanonicalString();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase