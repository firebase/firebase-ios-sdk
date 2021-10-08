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

#include "Firestore/core/src/credentials/firebase_auth_credentials_provider_apple.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

#include "Firestore/core/src/util/error_apple.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/string_apple.h"

namespace firebase {
namespace firestore {
namespace credentials {

FirebaseAuthCredentialsProvider::FirebaseAuthCredentialsProvider(
    FIRApp* app, id<FIRAuthInterop> auth) {
  contents_ =
      std::make_shared<Contents>(app, auth, User::FromUid([auth getUserID]));
  std::weak_ptr<Contents> weak_contents = contents_;

  auth_listener_handle_ = [[NSNotificationCenter defaultCenter]
      addObserverForName:FIRAuthStateDidChangeInternalNotification
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification* notification) {
                std::shared_ptr<Contents> contents = weak_contents.lock();
                if (!contents) {
                  return;
                }

                std::unique_lock<std::mutex> lock(contents->mutex);
                NSDictionary<NSString*, id>* user_info = notification.userInfo;

                // ensure we're only notifying for the current app.
                FIRApp* notified_app =
                    user_info[FIRAuthStateDidChangeInternalNotificationAppKey];
                if (![contents->app isEqual:notified_app]) {
                  return;
                }

                NSString* user_id =
                    user_info[FIRAuthStateDidChangeInternalNotificationUIDKey];
                contents->current_user = User::FromUid(user_id);
                contents->token_counter++;
                CredentialChangeListener<User> listener = change_listener_;
                if (listener) {
                  listener(contents->current_user);
                }
              }];
}

FirebaseAuthCredentialsProvider::~FirebaseAuthCredentialsProvider() {
  if (auth_listener_handle_) {
    [[NSNotificationCenter defaultCenter] removeObserver:auth_listener_handle_];
  }
}

void FirebaseAuthCredentialsProvider::GetToken(
    TokenListener<AuthToken> completion) {
  HARD_ASSERT(auth_listener_handle_,
              "GetToken cannot be called after listener removed.");

  // Take note of the current value of the token_counter so that this method can
  // fail if there is a token change while the request is outstanding.
  int initial_token_counter = contents_->token_counter;

  std::weak_ptr<Contents> weak_contents = contents_;
  void (^get_token_callback)(NSString*, NSError*) =
      ^(NSString* _Nullable token, NSError* _Nullable error) {
        std::shared_ptr<Contents> contents = weak_contents.lock();
        if (!contents) {
          return;
        }

        std::unique_lock<std::mutex> lock(contents->mutex);
        if (initial_token_counter != contents->token_counter) {
          // Cancel the request since the user changed while the request was
          // outstanding so the response is likely for a previous user (which
          // user, we can't be sure).
          LOG_DEBUG("GetToken aborted due to token change.");
          return GetToken(completion);
        } else {
          if (error == nil) {
            if (token != nil) {
              completion(
                  AuthToken{util::MakeString(token), contents->current_user});
            } else {
              completion(AuthToken::Unauthenticated());
            }
          } else {
            Error error_code = Error::kErrorUnknown;
            if (error.domain == FIRFirestoreErrorDomain) {
              error_code = static_cast<Error>(error.code);
            }
            completion(util::Status(
                error_code, util::MakeString(error.localizedDescription)));
          }
        }
      };

  // TODO(wilhuff): Need a better abstraction over a missing auth provider.
  if (contents_->auth) {
    [contents_->auth getTokenForcingRefresh:force_refresh_
                               withCallback:get_token_callback];
  } else {
    // If there's no Auth provider, call back immediately with a nil
    // (unauthenticated) token.
    get_token_callback(nil, nil);
  }
  force_refresh_ = false;
}

void FirebaseAuthCredentialsProvider::SetCredentialChangeListener(
    CredentialChangeListener<User> change_listener) {
  std::unique_lock<std::mutex> lock(contents_->mutex);
  if (change_listener) {
    HARD_ASSERT(!change_listener_, "set change_listener twice!");
    // Fire initial event.
    change_listener(contents_->current_user);
  } else {
    HARD_ASSERT(auth_listener_handle_, "removed change_listener twice!");
    HARD_ASSERT(change_listener_, "change_listener removed without being set!");
    [[NSNotificationCenter defaultCenter] removeObserver:auth_listener_handle_];
    auth_listener_handle_ = nil;
  }
  change_listener_ = change_listener;
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
