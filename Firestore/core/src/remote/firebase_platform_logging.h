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

#ifndef FIRESTORE_CORE_SRC_REMOTE_FIREBASE_PLATFORM_LOGGING_H_
#define FIRESTORE_CORE_SRC_REMOTE_FIREBASE_PLATFORM_LOGGING_H_

#include <string>

namespace firebase {
namespace firestore {
namespace remote {

class FirebasePlatformLogging {
 public:
   virtual ~FirebasePlatformLogging() = default;

   virtual bool IsLoggingAvailable() const = 0;
   virtual std::string GetUserAgent() const = 0;
   virtual std::string GetHeartbeat() const = 0;

   virtual bool IsGmpAppIdAvailable() const = 0;
   virtual std::string GetGmpAppId() const = 0;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_FIREBASE_PLATFORM_LOGGING_H_
