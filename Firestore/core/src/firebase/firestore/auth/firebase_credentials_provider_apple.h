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
#if !defined(__OBJC__)
#error "This header only supports Objective-C++."
#endif  // !defined(__OBJC__)

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_FIREBASE_CREDENTIALS_PROVIDER_APPLE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_FIREBASE_CREDENTIALS_PROVIDER_APPLE_H_

#import <Foundation/Foundation.h>

#include <memory>
#include <mutex>  // NOLINT(build/c++11)

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "absl/strings/string_view.h"

@class FIRApp;

namespace firebase {
namespace firestore {
namespace auth {

/**
 * `FirebaseCredentialsProvider` uses Firebase Auth via `FIRApp` to get an auth
 * token.
 *
 * NOTE: To simplify the implementation, it requires that you set
 * `userChangeListener` with a non-`nil` value no more than once and don't call
 * `getTokenForcingRefresh:` after setting it to `nil`.
 *
 * This class must be implemented in a thread-safe manner since it is accessed
 * from the thread backing our internal worker queue and the callbacks from
 * FIRAuth will be executed on an arbitrary different thread.
 *
 * Any instance that has GetToken() calls has to be destructed in
 * FIRAuthGlobalWorkQueue i.e through another call to GetToken. This prevents
 * the object being destructed before the callback. For example, use the
 * following pattern:
 *
 * class Bar {
 *   Bar(): provider_(new FirebaseCredentialsProvider([FIRApp defaultApp])) {}
 *
 *   ~Bar() {
 *     credentials_provider->GetToken(
 *         false, [provider_](const Token& token, const absl::string_view error)
 * { delete provider_;
 *     });
 *   }
 *
 *   Foo() {
 *      credentials_provider->GetToken(
 *          true, [](const Token& token, const absl::string_view error) {
 *              ... ...
 *      });
 *   }
 *
 *   FirebaseCredentialsProvider* provider_;
 * };
 */
class FirebaseCredentialsProvider : public CredentialsProvider {
 public:
  // TODO(zxu123): Provide a ctor to accept the C++ Firebase Games App, which
  // deals all platforms. Right now, only works for FIRApp*.
  /**
   * Initializes a new FirebaseCredentialsProvider.
   *
   * @param app The Firebase app from which to get credentials.
   */
  explicit FirebaseCredentialsProvider(FIRApp* app);

  ~FirebaseCredentialsProvider() override;

  void GetToken(bool force_refresh, TokenListener completion) override;

  void SetUserChangeListener(UserChangeListener listener) override;

 private:
  const FIRApp* app_;

  /**
   * Handle used to stop receiving auth changes once userChangeListener is
   * removed.
   */
  id<NSObject> auth_listener_handle_;

  /** The current user as reported to us via our AuthStateDidChangeListener. */
  User current_user_;

  /**
   * Counter used to detect if the user changed while a -getTokenForcingRefresh:
   * request was outstanding.
   */
  int user_counter_;

  // Make it static as as it is used in some of the callbacks. Otherwise, we saw
  // mutex lock failed: Invalid argument.
  std::mutex mutex_;
};

}  // namespace auth
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_FIREBASE_CREDENTIALS_PROVIDER_APPLE_H_
