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

#include "Firestore/core/src/firebase/firestore/remote/grpc_metadata_provider.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#import <FirebaseCore/FIRAppInternal.h>
#include "grpcpp/client_context.h"
#import <FirebaseCore/FIRHeartbeatInfo.h>
#import <Foundation/Foundation.h>
#include <string>
#include "absl/memory/memory.h"

NSString* const kFirebaseFirestoreHeartbeatTag = @"fire-fst";

namespace firebase {
namespace firestore {
namespace remote {
  class FirebaseClientGrpcMetadataProviderApple : public GrpcMetadataProvider {
  public:
    explicit FirebaseClientGrpcMetadataProviderApple()
    : GrpcMetadataProvider() {
    }

    void UpdateMetadata(grpc::ClientContext* context) {
      std::string kFirebaseFirestoreHeartbeatKey = "X-firebase-client-log-type";
      std::string kFirebaseFirestoreUserAgentKey = "X-firebase-client";
      std::string heartbeatCode = util::MakeString(@([FIRHeartbeatInfo heartbeatCodeForTag:kFirebaseFirestoreHeartbeatTag])
                                                   .stringValue);
      /*
      std::string heartbeatCode = GrpcMetadataProvider::getHeartbeatCode();
      if (heartbeatCode != "0") {
        context->AddMetadata(kFirebaseFirestoreHeartbeatKey,
                             GrpcMetadataProvider::getHeartbeatCode());
        context->AddMetadata(kFirebaseFirestoreUserAgentKey,
                             GrpcMetadataProvider::getUserAgentString());
      }
       */
      return;
    }
  };
  std::unique_ptr<GrpcMetadataProvider> GrpcMetadataProvider::Create() {
    return absl::make_unique<FirebaseClientGrpcMetadataProviderApple>();
  }
}  // namespace remote
}  // namespace firestore
} // namespace firebase
