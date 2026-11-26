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

#import "FirebaseCore/Extension/FIRAppInternal.h"

#import "FirebaseAuth/Interop/Public/FirebaseAuthInterop/FIRAuthInterop.h"

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
  GetTokenInternal(std::move(completion), /*is_retry=*/false);
}

void FirebaseAuthCredentialsProvider::GetTokenInternal(
    TokenListener<AuthToken> completion, bool is_retry) {
  int initial_token_counter = 0;
  {
    std::unique_lock<std::mutex> lock(contents_->mutex);
    if (!auth_listener_handle_) {
      HARD_ASSERT(is_retry,
                  "GetToken cannot be called after listener removed.");
      lock.unlock();
      LOG_DEBUG("GetToken aborted due to listener removal.");
      completion(util::Status(Error::kErrorAborted,
                              "GetToken aborted due to listener removal."));
      return;
    }

    // Take note of the current value of the token_counter so that this method
    // can fail if there is a token change while the request is outstanding.
    initial_token_counter = contents_->token_counter;
  }

  // Capture self via a shared_ptr to ensure that the credentials provider
  // is not deallocated while the getToken request is outstanding.
  std::shared_ptr<FirebaseAuthCredentialsProvider> self = shared_from_this();
  void (^get_token_callback)(NSString*, NSError*) =
      ^(NSString* _Nullable token, NSError* _Nullable error) {
        std::unique_lock<std::mutex> lock(self->contents_->mutex);
        if (initial_token_counter != self->contents_->token_counter) {
          // The user changed (or the listener was removed) while the request
          // was outstanding, so the token may be stale. Retry.
          lock.unlock();
          LOG_DEBUG("GetToken retrying due to token change.");
          return self->GetTokenInternal(completion, /*is_retry=*/true);
        } else {
          User current_user = self->contents_->current_user;
          lock.unlock();

          if (error == nil) {
            if (token != nil) {
              completion(
                  AuthToken{util::MakeString(token), std::move(current_user)});
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
    contents_->token_counter++;
  }
  change_listener_ = change_listener;
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
