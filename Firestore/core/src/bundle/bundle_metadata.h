/*
 * Copyright 2021 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_LOCAL_BUNDLE_H_
#define FIRESTORE_CORE_SRC_LOCAL_BUNDLE_H_

#include <memory>

#include "Firestore/core/src/model/snapshot_version.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace bundle {

/**
 * Represents a Firestore bundle metadata saved by the SDK in its local storage.
 */
class BundleMetadata {
 public:
  BundleMetadata(std::string bundle_id,
                 int version,
                 model::SnapshotVersion create_time)
      : bundle_id_(std::move(bundle_id)),
        version_(version),
        create_time_(create_time) {
  }

  BundleMetadata() = default;

  /**
   * @return The ID of the bundle. It is used together with `create_time()` to
   * determine if a bundle has been loaded by the SDK.
   */
  const std::string& bundle_id() const {
    return bundle_id_;
  }

  /**
   * @return The schema version of the bundle.
   */
  int version() const {
    return version_;
  }

  /**
   * @return The snapshot version of the bundle when created by the server SDKs.
   */
  model::SnapshotVersion create_time() const {
    return create_time_;
  }

 private:
  std::string bundle_id_;
  int version_;
  model::SnapshotVersion create_time_;
};

inline bool operator==(const BundleMetadata& lhs, const BundleMetadata& rhs) {
  return lhs.bundle_id() == rhs.bundle_id() && lhs.version() == rhs.version() &&
         lhs.create_time() == rhs.create_time();
}

inline bool operator!=(const BundleMetadata& lhs, const BundleMetadata& rhs) {
  return !(lhs == rhs);
}

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_BUNDLE_H_
