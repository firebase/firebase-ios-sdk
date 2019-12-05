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

#include "Firestore/core/src/firebase/firestore/remote/grpc_metadata_provider.h"

#if defined(__APPLE__)

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRHeartbeatInfo.h>
#import <Foundation/Foundation.h>
#include <memory>
#include <string>
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"
#include "grpcpp/client_context.h"

NSString* const kFirebaseFirestoreHeartbeatTag = @"fire-fst";

namespace firebase {
namespace firestore {
namespace remote {
class FirebaseClientGrpcMetadataProviderApple : public GrpcMetadataProvider {
 public:
  FirebaseClientGrpcMetadataProviderApple() : GrpcMetadataProvider() {
  }

  void UpdateMetadata(const std::unique_ptr<grpc::ClientContext>& context) {
    std::string kFirebaseFirestoreHeartbeatKey = "X-firebase-client-log-type";
    std::string kFirebaseFirestoreUserAgentKey = "X-firebase-client";
    std::string heartbeatCode = util::MakeString(
        @([FIRHeartbeatInfo heartbeatCodeForTag:kFirebaseFirestoreHeartbeatTag])
            .stringValue);
    std::string userAgentString = util::MakeString([FIRApp firebaseUserAgent]);
    if (heartbeatCode != "0") {
      context->AddMetadata(kFirebaseFirestoreHeartbeatKey, heartbeatCode);
      context->AddMetadata(kFirebaseFirestoreUserAgentKey, userAgentString);
    }
    return;
  }
};
std::unique_ptr<GrpcMetadataProvider> GrpcMetadataProvider::Create() {
  return absl::make_unique<FirebaseClientGrpcMetadataProviderApple>();
}
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)
