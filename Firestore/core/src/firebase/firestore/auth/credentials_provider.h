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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_CREDENTIALS_PROVIDER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_CREDENTIALS_PROVIDER_H_

#include <functional>
#include <string>

#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace auth {

// `TokenErrorListener` is a listener that gets a token or an error.
// token: An auth token as a string, or nullptr if error occurred.
// error: The error if one occurred, or else nullptr.
typedef std::function<void(const Token& token, const absl::string_view error)>
    TokenListener;

// Listener notified with a User change.
typedef std::function<void(const User& user)> UserChangeListener;

/**
 * Provides methods for getting the uid and token for the current user and
 * listen for changes.
 */
class CredentialsProvider {
 public:
  CredentialsProvider();

  virtual ~CredentialsProvider();

  /**
   * Requests token for the current user, optionally forcing a refreshed token
   * to be fetched.
   */
  virtual void GetToken(bool force_refresh, TokenListener completion) = 0;

  /**
   * Sets the listener to be notified of user changes (sign-in / sign-out). It
   * is immediately called once with the initial user.
   *
   * Call with nullptr to remove previous listener.
   */
  virtual void SetUserChangeListener(UserChangeListener listener) = 0;

 protected:
  /**
   * A listener to be notified of user changes (sign-in / sign-out). It is
   * immediately called once with the initial user.
   *
   * Note that this block will be called back on an arbitrary thread that is not
   * the normal Firestore worker thread.
   */
  UserChangeListener user_change_listener_;
};

}  // namespace auth
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_CREDENTIALS_PROVIDER_H_
