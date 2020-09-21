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

/**
 * Wraps the platform-dependent functionality associated with Firebase platform
 * logging.
 */
class FirebasePlatformLogging {
 public:
   virtual ~FirebasePlatformLogging() = default;

   /**
    * Returns whether logging is avaliable for sending. If false, no information
    * should be sent to the backend.
    */
   virtual bool IsLoggingAvailable() const = 0;

   /**
    * Returns the user agent string that contains the platform info to send to
    * the backend.
    */
   virtual std::string GetUserAgent() const = 0;

   /** Returns the heartbeat value to send along with the user agent string. */
   virtual std::string GetHeartbeat() const = 0;

   /** Returns whether the GMP app ID can be sent to the backend. */
   virtual bool IsGmpAppIdAvailable() const = 0;

   /**
    * Returns the GMP app ID. Make sure to check whether it can be sent by
    * calling `IsGmpAppIdAvailable` first.
    */
   virtual std::string GetGmpAppId() const = 0;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_FIREBASE_PLATFORM_LOGGING_H_
