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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_TIMESTAMP_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_TIMESTAMP_H_

#include <stdint.h>

namespace firebase {
namespace firestore {
namespace model {

/**
 * A Timestamp represents an absolute time from the backend at up to nanosecond
 * precision. A Timestamp is always UTC.
 */
class Timestamp {
 public:
  /**
   * Creates a new timestamp with seconds and nanos set to 0.
   *
   * PORTING NOTE: This does NOT set to current timestamp by default. To get the
   * current timestamp, call Timestamp::Now().
   */
  Timestamp();

  /**
   * Creates a new timestamp.
   *
   * @param seconds the number of seconds since epoch.
   * @param nanos the number of nanoseconds after the seconds.
   */
  Timestamp(long seconds, int nanos);

  /** Returns a timestamp with the current date / time. */
  static Timestamp Now();

  long seconds() const {
    return seconds_;
  }

  int nanos() const {
    return nanos_;
  }

 private:
  long seconds_;
  int nanos_;
};

/** Compares against another Timestamp. */
inline bool operator<(const Timestamp& lhs, const Timestamp& rhs) {
  return lhs.seconds() < rhs.seconds() ||
         (lhs.seconds() == rhs.seconds() && lhs.nanos() < rhs.nanos());
}

inline bool operator>(const Timestamp& lhs, const Timestamp& rhs) {
  return rhs < lhs;
}

inline bool operator>=(const Timestamp& lhs, const Timestamp& rhs) {
  return !(lhs < rhs);
}

inline bool operator<=(const Timestamp& lhs, const Timestamp& rhs) {
  return !(lhs > rhs);
}

inline bool operator!=(const Timestamp& lhs, const Timestamp& rhs) {
  return lhs < rhs || lhs > rhs;
}

inline bool operator==(const Timestamp& lhs, const Timestamp& rhs) {
  return !(lhs != rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_VALUE_H_
