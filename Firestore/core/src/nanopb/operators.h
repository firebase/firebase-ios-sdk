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

#ifndef FIRESTORE_CORE_SRC_NANOPB_OPERATORS_H_
#define FIRESTORE_CORE_SRC_NANOPB_OPERATORS_H_

#include "Firestore/Protos/nanopb/google/firestore/v1/bloom_filter.nanopb.h"

// Provides operator overloads for some of the types defined by the nanopb-
// generated protos. Feel free to add overloads here, as needed. It is
// important that these overloads be defined in the same namespace as the proto
// structs themselves so that ADL (address-dependent lookup) will find them at
// compile time.

namespace firebase {
namespace firestore {

bool operator==(const google_firestore_v1_BloomFilter&,
                const google_firestore_v1_BloomFilter&);

inline bool operator!=(const google_firestore_v1_BloomFilter& lhs,
                       const google_firestore_v1_BloomFilter& rhs) {
  return !(lhs == rhs);
}

bool operator==(const google_firestore_v1_BitSequence&,
                const google_firestore_v1_BitSequence&);

inline bool operator!=(const google_firestore_v1_BitSequence& lhs,
                       const google_firestore_v1_BitSequence& rhs) {
  return !(lhs == rhs);
}

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_NANOPB_OPERATORS_H_
