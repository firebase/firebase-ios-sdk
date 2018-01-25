/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/model/timestamp.h"

#include <time.h>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace model {

Timestamp::Timestamp(long seconds, int nanos)
    : seconds_(seconds), nanos_(nanos) {
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
      nanos >= 0, nanos >= 0, "timestamp nanoseconds out of range: %d", nanos);
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
      nanos < 1e9, nanos < 1e9, "timestamp nanoseconds out of range: %d",
      nanos);
  // Midnight at the beginning of 1/1/1 is the earliest timestamp Firestore
  // supports.
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
      seconds >= -62135596800L, seconds >= -62135596800L,
      "timestamp seconds out of range: %lld", seconds);
  // This will break in the year 10,000.
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
      seconds < 253402300800L, seconds < 253402300800L,
      "timestamp seconds out of range: %lld", seconds);
}

Timestamp::Timestamp() : seconds_(0), nanos_(0) {
}

Timestamp Timestamp::Now() {
  return Timestamp(time(nullptr), 0);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
