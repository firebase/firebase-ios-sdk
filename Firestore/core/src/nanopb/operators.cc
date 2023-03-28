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

#include "Firestore/core/src/nanopb/operators.h"

#include "Firestore/core/src/nanopb/nanopb_util.h"

#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {

using nanopb::MakeStringView;

bool operator==(const google_firestore_v1_BloomFilter& lhs,
                const google_firestore_v1_BloomFilter& rhs) {
  if (lhs.hash_count != rhs.hash_count) {
    return false;
  }
  if (lhs.has_bits != rhs.has_bits) {
    return false;
  }
  if (lhs.has_bits) {
    if (lhs.bits != rhs.bits) {
      return false;
    }
  }
  return true;
}

bool operator==(const google_firestore_v1_BitSequence& lhs,
                const google_firestore_v1_BitSequence& rhs) {
  if (lhs.padding != rhs.padding) {
    return false;
  }
  if ((lhs.bitmap == nullptr) != (rhs.bitmap == nullptr)) {
    return false;
  }
  if (lhs.bitmap != nullptr) {
    absl::string_view lhs_bitmap = MakeStringView(lhs.bitmap);
    absl::string_view rhs_bitmap = MakeStringView(rhs.bitmap);
    if (lhs_bitmap != rhs_bitmap) {
      return false;
    }
  }
  return true;
}

}  // namespace firestore
}  // namespace firebase
