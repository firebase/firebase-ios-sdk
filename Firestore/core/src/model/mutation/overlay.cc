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

#include "Firestore/core/src/model/mutation/overlay.h"

#include <iostream>

#include "Firestore/core/src/util/hashing.h"
#include "Firestore/core/src/util/to_string.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace model {
namespace mutation {

bool operator==(const Overlay& lhs, const Overlay& rhs) {
  return lhs.largest_batch_id_ == rhs.largest_batch_id_ &&
         lhs.mutation_ == rhs.mutation_;
}

std::ostream& operator<<(std::ostream& os, const Overlay& result) {
  return os << result.ToString();
}

std::size_t Overlay::Hash() const {
  if (mutation_.is_valid()) {
    return util::Hash(largest_batch_id_, mutation_);
  } else {
    return util::Hash(largest_batch_id_, -1);
  }
}

std::string Overlay::ToString() const {
  return absl::StrCat("Overlay(largest_batch_id=", largest_batch_id_,
                      ", mutation=", util::ToString(mutation_), ")");
}

std::size_t OverlayHash::operator()(const Overlay& overlay) const {
  return overlay.Hash();
}

}  // namespace mutation
}  // namespace model
}  // namespace firestore
}  // namespace firebase
