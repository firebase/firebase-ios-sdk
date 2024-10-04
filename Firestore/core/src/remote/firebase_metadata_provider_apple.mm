/*
 * Copyright 2020 Google LLC
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

#include "Firestore/core/src/remote/firebase_metadata_provider_apple.h"

#import "FirebaseCore/Extension/FIRAppInternal.h"
#import "FirebaseCore/Extension/FIRHeartbeatLogger.h"
#import "FirebaseCore/Sources/FIROptionsInternal.h"

#include "Firestore/core/src/util/string_apple.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using util::MakeString;

std::string GetUserAgent() {
  return MakeString([FIRApp firebaseUserAgent]);
}

FIRDailyHeartbeatCode GetHeartbeat(FIRApp* app) {
  return [app.heartbeatLogger heartbeatCodeForToday];
}

std::string GetGmpAppId(FIRApp* app) {
  return MakeString(app.options.googleAppID);
}

}  // namespace

FirebaseMetadataProviderApple::FirebaseMetadataProviderApple(FIRApp* app)
    : app_(app) {
}

void FirebaseMetadataProviderApple::UpdateMetadata(
    grpc::ClientContext& context) {
  FIRDailyHeartbeatCode heartbeat = GetHeartbeat(app_);
  // TODO(ncooke3): If support for notifying a heartbeat logger when a
  // request fails is implemented, we will need to change the below
  // code to place the heartbeat data back into heartbeat storage.
  if (heartbeat != FIRDailyHeartbeatCodeNone) {
    context.AddMetadata(kXFirebaseClientLogTypeHeader,
                        std::to_string(heartbeat));
  }

  context.AddMetadata(kXFirebaseClientHeader, GetUserAgent());

  std::string gmp_app_id = GetGmpAppId(app_);
  if (!gmp_app_id.empty()) {
    context.AddMetadata(kXFirebaseGmpIdHeader, gmp_app_id);
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
