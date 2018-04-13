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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_SNAPSHOT_VERSION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_SNAPSHOT_VERSION_H_

#include "Firestore/core/include/firebase/firestore/timestamp.h"

#if defined(__OBJC__)
#import "FIRTimestamp.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#endif  // defined(__OBJC__)

namespace firebase {
namespace firestore {
namespace model {

/**
 * A version of a document in Firestore. This corresponds to the version
 * timestamp, such as update_time or read_time.
 */
class SnapshotVersion {
 public:
  explicit SnapshotVersion(const Timestamp& timestamp);

  const Timestamp& timestamp() const {
    return timestamp_;
  }

  /** Creates a new version that is smaller than all other versions. */
  static const SnapshotVersion& None();

#if defined(__OBJC__)
  SnapshotVersion(FSTSnapshotVersion* version)  // NOLINT(runtime/explicit)
      : timestamp_{version.timestamp.seconds, version.timestamp.nanoseconds} {
  }

  operator FSTSnapshotVersion*() const {
    if (timestamp_ == Timestamp{}) {
      return [FSTSnapshotVersion noVersion];
    } else {
      return [FSTSnapshotVersion
          versionWithTimestamp:[FIRTimestamp
                                   timestampWithSeconds:timestamp_.seconds()
                                            nanoseconds:timestamp_
                                                            .nanoseconds()]];
    }
  }
#endif  // defined(__OBJC__)

 private:
  Timestamp timestamp_;
};

/** Compares against another SnapshotVersion. */
inline bool operator<(const SnapshotVersion& lhs, const SnapshotVersion& rhs) {
  return lhs.timestamp() < rhs.timestamp();
}

inline bool operator>(const SnapshotVersion& lhs, const SnapshotVersion& rhs) {
  return lhs.timestamp() > rhs.timestamp();
}

inline bool operator>=(const SnapshotVersion& lhs, const SnapshotVersion& rhs) {
  return lhs.timestamp() >= rhs.timestamp();
}

inline bool operator<=(const SnapshotVersion& lhs, const SnapshotVersion& rhs) {
  return lhs.timestamp() <= rhs.timestamp();
}

inline bool operator!=(const SnapshotVersion& lhs, const SnapshotVersion& rhs) {
  return lhs.timestamp() != rhs.timestamp();
}

inline bool operator==(const SnapshotVersion& lhs, const SnapshotVersion& rhs) {
  return lhs.timestamp() == rhs.timestamp();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_SNAPSHOT_VERSION_H_
