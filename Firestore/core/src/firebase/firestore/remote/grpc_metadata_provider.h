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
   * Called by grpc_connection.cc. Provides the heartbeatcode corresponding to
   * firestore.
   */
  virtual void UpdateMetadata(grpc::ClientContext* context) = 0;

  /**
   * Called by grpc_connection.cc. Provides the userAgentString.
   */
  virtual ~GrpcMetadataProvider() = default;
};
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
