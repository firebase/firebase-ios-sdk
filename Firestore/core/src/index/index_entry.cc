/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/index/index_entry.h"

#include "Firestore/core/src/util/hashing.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace index {

util::ComparisonResult IndexEntry::CompareTo(const IndexEntry& rhs) const {
  util::ComparisonResult cmp = util::Compare(index_id(), rhs.index_id());
  if (!util::Same(cmp)) return cmp;

  cmp = util::Compare(document_key(), rhs.document_key());
  if (!util::Same(cmp)) return cmp;

  cmp = util::Compare(directional_value(), rhs.directional_value());
  if (!util::Same(cmp)) return cmp;

  return util::Compare(array_value(), rhs.array_value());
}

std::string IndexEntry::ToString() const {
  return absl::StrCat("IndexEntry(", index_id(), ":", document_key().ToString(),
                      " dir_val:", directional_value(),
                      " array_val:", array_value(), ")");
}

std::ostream& operator<<(std::ostream& out, const IndexEntry& entry) {
  return out << entry.ToString();
}

size_t IndexEntry::Hash() const {
  return util::Hash(index_id(), document_key(), directional_value(),
                    array_value());
}

}  // namespace index
}  // namespace firestore
}  // namespace firebase
