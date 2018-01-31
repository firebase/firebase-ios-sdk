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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_FIREBASE_CREDENTIALS_PROVIDER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_FIREBASE_CREDENTIALS_PROVIDER_H_

#include <memory>
#include <mutex>

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace auth {

class AppImpl;
struct AuthImpl;

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
 * For non-Apple desktop build, this is right now just a stub.
 */
class FirebaseCredentialsProvider : public CredentialsProvider {
 public:
  // TODO(zxu123): Provide a ctor to accept the C++ Firebase Games App, which
  // deals all platforms. Right now, AppImpl is only a wrapper for FIRApp*.
  /**
   * Initializes a new FirebaseCredentialsProvider.
   *
   * @param app The Firebase app from which to get credentials.
   */
  FirebaseCredentialsProvider(const AppImpl& app);

  ~FirebaseCredentialsProvider();

  void GetToken(bool force_refresh, TokenListener completion) override;

  void set_user_change_listener(UserListener listener) override;

  friend class FirebaseCredentialsProvider_GetToken_Test;
  friend class FirebaseCredentialsProvider_SetListener_Test;

 private:
  /** Initialize with default app for internal usage such as test. */
  FirebaseCredentialsProvider();

  static void PlatformDependentTestSetup(const absl::string_view config_path);

  /** Platform-dependent members defined inside. */
  std::unique_ptr<AuthImpl> auth_;

  /** The current user as reported to us via our AuthStateDidChangeListener. */
  User current_user_;

  /**
   * Counter used to detect if the user changed while a -getTokenForcingRefresh:
   * request was outstanding.
   */
  int user_counter_;

  std::mutex mutex_;
};

}  // namespace auth
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_CREDENTIALS_PROVIDER_H_
