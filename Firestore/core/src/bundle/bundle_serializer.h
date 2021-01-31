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

#ifndef FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_SERIALIZER_H_
#define FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_SERIALIZER_H_

#include <string>
#include <utility>

#include "Firestore/core/src/bundle/bundle_metadata.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/util/read_context.h"
#include "nlohmann/json.hpp"

namespace firebase {
namespace firestore {
namespace bundle {

/** A JSON serializer to deserialize Firestore Bundles. */
class BundleSerializer {
 public:
  BundleMetadata DecodeBundleMetadata(util::ReadContext& context,
                                      const std::string& metadata) const;

 private:
  model::SnapshotVersion DecodeSnapshotVersion(
      util::ReadContext& context, const nlohmann::json& version) const;
};

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_SERIALIZER_H_
