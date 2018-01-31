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

// Right now, FirebaseCredentialsProvider only support APPLE build.
// TODO(zxu123): Make it for desktop workflow as well.

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_FIREBASE_CREDENTIALS_PROVIDER_APPLE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_FIREBASE_CREDENTIALS_PROVIDER_APPLE_H_

#import <Foundation/Foundation.h>

@class FIRApp;

namespace firebase {
namespace firestore {
namespace auth {

class AppImpl {
 public:
  AppImpl(FIRApp* app) : app_(app) {
  }

  operator FIRApp*() const {
    return app_;
  }

 private:
  FIRApp* app_;
};

struct AuthImpl {
  const FIRApp* app;

  /** Handle used to stop receiving auth changes once userChangeListener is
   * removed. */
  id<NSObject> auth_listener_handle;
};

}  // namespace auth
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_CREDENTIALS_PROVIDER_APPLE_H_
