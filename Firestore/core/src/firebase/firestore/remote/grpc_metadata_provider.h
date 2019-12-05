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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_METADATA_PROVIDER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_METADATA_PROVIDER_H_

#include <memory>
#include <string>
#include "grpcpp/client_context.h"

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Class providing the userAgent and the hearbeat information.
 */
class GrpcMetadataProvider {
 public:
  /** Creates a platform-specific GrpcMetadataProvider. */
  static std::unique_ptr<GrpcMetadataProvider> Create();
  /**
   * Called by grpc_connection.cc. Updates the metadata with the
   * heartbeat and the useragent header.
   */
  virtual void UpdateMetadata(
      const std::unique_ptr<grpc::ClientContext>& context) = 0;

  virtual ~GrpcMetadataProvider() = default;
};
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_METADATA_PROVIDER_H_
