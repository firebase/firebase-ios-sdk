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

#include "Firestore/core/src/bundle/named_query.h"
#include "Firestore/core/src/remote/serializer.h"
#include "nlohmann/json.hpp"

namespace firebase {
namespace firestore {
namespace bundle {

/**
 * TODO
 */
class BundleSerializer {
 public:
  explicit BundleSerializer(remote::Serializer rpc_serializer)
  : rpc_serializer_(std::move(rpc_serializer)) {
  }

  NamedQuery DecodeNamedQuery(nlohmann::json query);

 private:
  remote::Serializer rpc_serializer_;
};

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_SERIALIZER_H_
