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

#include "Firestore/core/src/remote/firebase_platform_logging_apple.h"

#import "FirebaseCore/Sources/Private/FIRAppInternal.h"
#import "FirebaseCore/Sources/Private/FIRHeartbeatInfo.h"
#import "FirebaseCore/Sources/Private/FIROptionsInternal.h"

#include "Firestore/core/src/util/string_apple.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace remote {

using util::MakeString;

FirebasePlatformLoggingApple::FirebasePlatformLoggingApple(FIRApp* app)
    : app_(app) {
}

void FirebasePlatformLoggingApple::UpdateMetadata(
    grpc::ClientContext& context) {
  if (![app_ isDataCollectionDefaultEnabled]) {
    return;
  }

  context.AddMetadata(kXFirebaseClientHeader, GetUserAgent());
  context.AddMetadata(kXFirebaseClientLogTypeHeader, GetHeartbeat());

  std::string gmp_app_id = GetGmpAppId();
  if (!gmp_app_id.empty()) {
    context.AddMetadata(kXFirebaseGmpIdHeader, gmp_app_id);
  }
}

std::string FirebasePlatformLoggingApple::GetUserAgent() const {
  return MakeString([FIRApp firebaseUserAgent]);
}

std::string FirebasePlatformLoggingApple::GetHeartbeat() const {
  return std::to_string([FIRHeartbeatInfo heartbeatCodeForTag:@"fire-fst"]);
}

std::string FirebasePlatformLoggingApple::GetGmpAppId() const {
  return MakeString(app_.options.googleAppID);
}

NS_ASSUME_NONNULL_END

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
