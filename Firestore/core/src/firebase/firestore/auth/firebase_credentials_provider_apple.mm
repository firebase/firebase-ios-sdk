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

namespace firebase {
namespace firestore {
namespace auth {

std::mutex FirebaseCredentialsProvider::mutex_;

FirebaseCredentialsProvider::FirebaseCredentialsProvider()
    : FirebaseCredentialsProvider([FIRApp defaultApp]) {
}

FirebaseCredentialsProvider::FirebaseCredentialsProvider(FIRApp* app)
    : app_(app),
      auth_listener_handle_(nil),
      current_user_(firebase::firestore::util::MakeStringView([app getUID])),
      user_counter_(0) {
  auth_listener_handle_ = [[NSNotificationCenter defaultCenter]
      addObserverForName:FIRAuthStateDidChangeInternalNotification
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification* notification) {
                std::unique_lock<std::mutex> lock(mutex_);
                NSDictionary<NSString *, id>* user_info = notification.userInfo;

                // ensure we're only notifiying for the current app.
                FIRApp* notified_app =
                    user_info[FIRAuthStateDidChangeInternalNotificationAppKey];
                if (![app_ isEqual:notified_app]) {
                  return;
                }

                NSString* user_id =
                    user_info[FIRAuthStateDidChangeInternalNotificationUIDKey];
                User new_user(
                    firebase::firestore::util::MakeStringView(user_id));
                if (new_user != current_user_) {
                  current_user_ = new_user;
                  user_counter_++;
                  UserChangeListener listener = user_change_listener_;
                  if (listener) {
                    listener(current_user_);
                  }
                }
              }];
}

void FirebaseCredentialsProvider::GetToken(bool force_refresh,
                                           TokenListener completion) {
  FIREBASE_ASSERT_MESSAGE(auth_listener_handle_,
                          "GetToken cannot be called after listener removed.");

  // Take note of the current value of the userCounter so that this method can
  // fail if there is a user change while the request is outstanding.
  int initial_user_counter = user_counter_;

  void (^get_token_callback)(NSString*, NSError*) =
      ^(NSString* _Nullable token, NSError* _Nullable error) {
        std::unique_lock<std::mutex> lock(mutex_);
        if (initial_user_counter != user_counter_) {
          // Cancel the request since the user changed while the request was
          // outstanding so the response is likely for a previous user (which
          // user, we can't be sure).
          completion({"", User::Unauthenticated()},
                     "getToken aborted due to user change.");
        } else {
          completion(
              {firebase::firestore::util::MakeStringView(token), current_user_},
              error == nil ? ""
                           : firebase::firestore::util::MakeStringView(
                                 error.localizedDescription));
        }
      };

  [app_ getTokenForcingRefresh:force_refresh withCallback:get_token_callback];
}

void FirebaseCredentialsProvider::SetUserChangeListener(
    UserChangeListener listener) {
  std::unique_lock<std::mutex> lock(mutex_);
  if (listener) {
    FIREBASE_ASSERT_MESSAGE(!user_change_listener_,
                            "set user_change_listener twice!");
    // Fire initial event.
    listener(current_user_);
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
