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
#include "Firestore/core/src/firebase/firestore/auth/firebase_credentials_provider.h"

#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace firebase {
namespace firestore {
namespace auth {

FirebaseCredentialsProvider::FirebaseCredentialsProvider()
    : FirebaseCredentialsProvider([FIRApp defaultApp]) {
}

FirebaseCredentialsProvider::FirebaseCredentialsProvider(const AppImpl& app)
    : auth_(new AuthImpl{app, nullptr}),
      current_user_(firebase::firestore::util::MakeStringView([app getUID])),
      user_counter_(0) {
  auth_->auth_listener_handle = [[NSNotificationCenter defaultCenter]
      addObserverForName:FIRAuthStateDidChangeInternalNotification
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification* notification) {
                std::unique_lock<std::mutex> lock(this->mutex_);
                NSDictionary* user_info = notification.userInfo;

                // ensure we're only notifiying for the current app.
                FIRApp* notified_app =
                    user_info[FIRAuthStateDidChangeInternalNotificationAppKey];
                if (![this->auth_->app isEqual:notified_app]) {
                  return;
                }

                NSString* user_id =
                    user_info[FIRAuthStateDidChangeInternalNotificationUIDKey];
                User new_user(
                    firebase::firestore::util::MakeStringView(user_id));
                if (new_user != this->current_user_) {
                  this->current_user_ = new_user;
                  this->user_counter_++;
                  UserListener listener = this->user_change_listener_;
                  if (listener) {
                    listener(this->current_user_);
                  }
                }
              }];
}

FirebaseCredentialsProvider::~FirebaseCredentialsProvider() {
  auth_.reset(nullptr);
}

void FirebaseCredentialsProvider::GetToken(bool force_refresh,
                                           TokenListener completion) {
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
      this->auth_->auth_listener_handle, this->auth_->auth_listener_handle,
      "GetToken cannot be called after listener removed.");

  // Take note of the current value of the userCounter so that this method can
  // fail if there is a user change while the request is outstanding.
  int initial_user_counter = this->user_counter_;

  void (^get_token_callback)(NSString*, NSError*) =
      ^(NSString* _Nullable token, NSError* _Nullable error) {
        std::unique_lock<std::mutex> lock(this->mutex_);
        if (initial_user_counter != this->user_counter_) {
          // Cancel the request since the user changed while the request was
          // outstanding so the response is likely for a previous user (which
          // user, we can't be sure).
          completion({"", User()}, "getToken aborted due to user change.");
        } else {
          completion({firebase::firestore::util::MakeStringView(token),
                      this->current_user_},
                     error == nil ? ""
                                  : firebase::firestore::util::MakeStringView(
                                        (NSString*)error));
        }
      };

  [this->auth_->app getTokenForcingRefresh:force_refresh
                              withCallback:get_token_callback];
}

void FirebaseCredentialsProvider::set_user_change_listener(
    UserListener listener) {
  std::unique_lock<std::mutex> lock(this->mutex_);
  if (listener) {
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(!this->user_change_listener_,
                                            !this->user_change_listener_,
                                            "set user_change_listener twice!");
    // Fire initial event.
    listener(this->current_user_);
  } else {
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
        this->auth_->auth_listener_handle, this->auth_->auth_listener_handle,
        "removed user_change_listener twice!");
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
        this->user_change_listener_, this->user_change_listener_,
        "user_change_listener removed without being set!");
    [[NSNotificationCenter defaultCenter]
        removeObserver:this->auth_->auth_listener_handle];
    this->auth_->auth_listener_handle = nullptr;
  }
  this->user_change_listener_ = listener;
}

void FirebaseCredentialsProvider::PlatformDependentTestSetup(
    const absl::string_view config_path) {
  static dispatch_once_t once_token;
  dispatch_once(&once_token, ^{
    NSString* file_path =
        firebase::firestore::util::WrapNSStringNoCopy(config_path.data());
    FIROptions* options = [[FIROptions alloc] initWithContentsOfFile:file_path];
    [FIRApp configureWithOptions:options];
  });

  // Set getUID implementation.
  FIRApp* default_app = [FIRApp defaultApp];
  default_app.getUIDImplementation = ^NSString* {
    return @"I'm a fake uid.";
  };
}

}  // namespace auth
}  // namespace firestore
}  // namespace firebase
