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
#include <string>
#import <Foundation/Foundation.h>
#import <FirebaseCore/FIRHeartbeatInfo.h>
#import <FirebaseCore/FIRAppInternal.h>


NSString *const kFirebaseFirestoreHeartbeatTag = @"fire-fst";

namespace firebase {
  namespace firestore {
    namespace remote {
      std::string GrpcMetadataProvider::getHeartbeatCode() {
        return std::string([@([FIRHeartbeatInfo heartbeatCodeForTag:kFirebaseFirestoreHeartbeatTag])
        .stringValue UTF8String]);
      }
      std::string GrpcMetadataProvider::getUserAgentString() {
        return std::string([[FIRApp firebaseUserAgent] UTF8String]);
      }
    }  // namespace remote
  }  // namespace firestore
}  // namespace firebase

