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

#include <string>

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace auth {

/**
 * The current FSTUser and the authentication token provided by the underlying
 * authentication mechanism. This is the result of calling
 * -[FSTCredentialsProvider getTokenForcingRefresh].
 *
 * ## Portability notes: no TokenType on iOS
 *
 * The TypeScript client supports 1st party Oauth tokens (for the Firebase
 * Console to auth as the developer) and OAuth2 tokens for the node.js sdk to
 * auth with a service account. We don't have plans to support either case on
 * mobile so there's no TokenType here.
 */
// TODO(zxu123): Make this support token-type for desktop workflow.
class Token {
 public:
  Token(const absl::string_view token, const User& user);

  /** The actual raw token. */
  const std::string& token() const {
    return token_;
  }

  /** The user with which the token is associated (used for persisting user
   * state on disk, etc.). */
  const User& user() const {
    return user_;
  }

 private:
  const std::string token_;
  const User user_;
};

// `TokenErrorListener` is a listener that gets a token or an error.
// token: An auth token as a string, or nullptr if error occurred.
// error: The error if one occurred, or else nullptr.
typedef void (*TokenListener)(const Token& token,
                              const absl::string_view error);

// Listener notified with a User.
typedef void (*UserListener)(const User& user);

/** Provides methods for getting the uid and token for the current user and
 * listen for changes. */
class CredentialsProvider {
 public:
  /** Requests token for the current user, optionally forcing a refreshed token
   * to be fetched. */
  virtual void GetToken(bool force_refresh, TokenListener completion) = 0;

  /**
   * Sets the listener to be notified of user changes (sign-in / sign-out). It
   * is immediately called once with the initial user.
   */
  virtual void set_user_change_listener(UserListener listener) = 0;

  /** Removes the listener set with {@link #setUserChangeListener}. */
  virtual void RemoveUserChangeListener() {
    set_user_change_listener(nullptr);
  }

 protected:
  /**
   * A listener to be notified of user changes (sign-in / sign-out). It is
   * immediately called once with the initial user.
   *
   * Note that this block will be called back on an arbitrary thread that is not
   * the normal Firestore worker thread.
   */
  UserListener user_change_listener_;
};

}  // namespace auth
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_CREDENTIALS_PROVIDER_H_
