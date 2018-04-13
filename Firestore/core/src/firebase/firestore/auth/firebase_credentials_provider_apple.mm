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

#include "Firestore/core/src/firebase/firestore/auth/firebase_credentials_provider_apple.h"

#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

// NB: This is also defined in Firestore/Source/Public/FIRFirestoreErrors.h
// NOLINTNEXTLINE: public constant
NSString* const FIRFirestoreErrorDomain = @"FIRFirestoreErrorDomain";

namespace firebase {
namespace firestore {
namespace auth {

FirebaseCredentialsProvider::FirebaseCredentialsProvider(FIRApp* app)
    : contents_(std::make_shared<Contents>(app, User::FromUid([app getUID]))) {
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
                User new_user = User::FromUid(user_id);
                if (new_user != contents->current_user) {
                  contents->current_user = new_user;
                  contents->user_counter++;
                  UserChangeListener listener = user_change_listener_;
                  if (listener) {
                    listener(contents->current_user);
                  }
                }
              }];
}

FirebaseCredentialsProvider::~FirebaseCredentialsProvider() {
  if (auth_listener_handle_) {
    // Even though iOS 9 (and later) and macOS 10.11 (and later) keep a weak
    // reference to the observer so we could avoid this removeObserver call, we
    // still support iOS 8 which requires it.
    [[NSNotificationCenter defaultCenter] removeObserver:auth_listener_handle_];
  }
}

void FirebaseCredentialsProvider::GetToken(bool force_refresh,
                                           TokenListener completion) {
  FIREBASE_ASSERT_MESSAGE(auth_listener_handle_,
                          "GetToken cannot be called after listener removed.");

  // Take note of the current value of the userCounter so that this method can
  // fail if there is a user change while the request is outstanding.
  int initial_user_counter = contents_->user_counter;

  std::weak_ptr<Contents> weak_contents = contents_;
  void (^get_token_callback)(NSString*, NSError*) =
      ^(NSString* _Nullable token, NSError* _Nullable error) {
        std::shared_ptr<Contents> contents = weak_contents.lock();
        if (!contents) {
          return;
        }

        std::unique_lock<std::mutex> lock(contents->mutex);
        if (initial_user_counter != contents->user_counter) {
          // Cancel the request since the user changed while the request was
          // outstanding so the response is likely for a previous user (which
          // user, we can't be sure).
          completion(util::Status(FirestoreErrorCode::Aborted,
                                  "getToken aborted due to user change."));
        } else {
          if (error == nil) {
            if (token != nil) {
              completion(
                  Token{util::MakeStringView(token), contents->current_user});
            } else {
              completion(Token::Unauthenticated());
            }
          } else {
            FirestoreErrorCode error_code = FirestoreErrorCode::Unknown;
            if (error.domain == FIRFirestoreErrorDomain) {
              error_code = static_cast<FirestoreErrorCode>(error.code);
            }
            completion(util::Status(
                error_code, util::MakeStringView(error.localizedDescription)));
          }
        }
      };

  [contents_->app getTokenForcingRefresh:force_refresh
                            withCallback:get_token_callback];
}

void FirebaseCredentialsProvider::SetUserChangeListener(
    UserChangeListener listener) {
  std::unique_lock<std::mutex> lock(contents_->mutex);
  if (listener) {
    FIREBASE_ASSERT_MESSAGE(!user_change_listener_,
                            "set user_change_listener twice!");
    // Fire initial event.
    listener(contents_->current_user);
  } else {
    FIREBASE_ASSERT_MESSAGE(auth_listener_handle_,
                            "removed user_change_listener twice!");
    FIREBASE_ASSERT_MESSAGE(user_change_listener_,
                            "user_change_listener removed without being set!");
    [[NSNotificationCenter defaultCenter] removeObserver:auth_listener_handle_];
    auth_listener_handle_ = nil;
  }
  user_change_listener_ = listener;
}

}  // namespace auth
}  // namespace firestore
}  // namespace firebase
