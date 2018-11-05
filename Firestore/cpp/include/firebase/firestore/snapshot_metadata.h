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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SNAPSHOT_METADATA_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SNAPSHOT_METADATA_H_

namespace firebase {
namespace firestore {

/** Metadata about a snapshot, describing the state of the snapshot. */
class SnapshotMetadata {
 public:
  SnapshotMetadata(bool has_pending_writes, bool is_from_cache)
      : has_pending_writes_(has_pending_writes), is_from_cache_(is_from_cache) {
  }

  bool has_pending_writes() const {
    return has_pending_writes_;
  }

  bool is_from_cache() const {
    return is_from_cache_;
  }

 private:
  const bool has_pending_writes_;
  const bool is_from_cache_;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SNAPSHOT_METADATA_H_
