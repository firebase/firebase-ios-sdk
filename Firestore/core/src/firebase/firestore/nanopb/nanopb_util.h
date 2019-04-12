/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_NANOPB_UTIL_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_NANOPB_UTIL_H_

#include <pb.h>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace nanopb {

/**
 * Static casts the given size_t value down to a nanopb compatible size, after
 * asserting that the value isn't out of range.
 */
inline pb_size_t CheckedSize(size_t size) {
  HARD_ASSERT(size <= PB_SIZE_MAX,
              "Size exceeds nanopb limits. Too many entries.");
  return static_cast<pb_size_t>(size);
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_NANOPB_UTIL_H_
