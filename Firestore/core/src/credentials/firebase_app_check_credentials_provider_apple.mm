/*
 * Copyright 2021 Google LLC
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

#include "Firestore/core/src/credentials/firebase_app_check_credentials_provider_apple.h"

#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"
#import "FirebaseCore/Extension/FIRAppInternal.h"

#include "Firestore/core/src/util/error_apple.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"

namespace firebase {
namespace firestore {
namespace credentials {

FirebaseAppCheckCredentialsProvider::FirebaseAppCheckCredentialsProvider(
    FIRApp* app, id<FIRAppCheckInterop> app_check) {
  contents_ = std::make_shared<Contents>(app, app_check);

  if (app_check == nil) {
    return;
  }

  std::weak_ptr<Contents> weak_contents = contents_;
  app_check_listener_handle_ = [[NSNotificationCenter defaultCenter]
      addObserverForName:[app_check tokenDidChangeNotificationName]
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
                NSString* notified_app_name =
                    user_info[[app_check notificationAppNameKey]];
                if (![[contents->app name] isEqual:notified_app_name]) {
                  return;
                }

                NSString* app_check_token =
                    user_info[[app_check notificationTokenKey]];
                contents_->current_token = util::MakeString(app_check_token);
                CredentialChangeListener<std::string> listener =
                    change_listener_;
                if (change_listener_) {
                  change_listener_(contents_->current_token);
                }
              }];
}

FirebaseAppCheckCredentialsProvider::~FirebaseAppCheckCredentialsProvider() {
  if (app_check_listener_handle_) {
    [[NSNotificationCenter defaultCenter]
        removeObserver:app_check_listener_handle_];
  }
}

void FirebaseAppCheckCredentialsProvider::GetToken(
    TokenListener<std::string> completion) {
  std::weak_ptr<Contents> weak_contents = contents_;
  if (contents_->app_check) {
    void (^get_token_callback)(id<FIRAppCheckTokenResultInterop>) =
        ^(id<FIRAppCheckTokenResultInterop> result) {
          if (result.error != nil) {
            LOG_WARN("AppCheck failed: '%s'",
                     util::MakeString(result.error.localizedDescription));
          }
          completion(util::MakeString(result.token));  // Always return token
        };

    // Retrieve a cached or generate a new FAC Token. If forcingRefresh == YES
    // always generates a new token and updates the cache.
    [contents_->app_check getTokenForcingRefresh:force_refresh_
                                      completion:get_token_callback];
  } else {
    // If there's no AppCheck provider, call back immediately with a nil token.
    completion(std::string{""});
  }
  force_refresh_ = false;
}

void FirebaseAppCheckCredentialsProvider::SetCredentialChangeListener(
    CredentialChangeListener<std::string> change_listener) {
  std::unique_lock<std::mutex> lock(contents_->mutex);
  if (change_listener) {
    HARD_ASSERT(!change_listener_, "set change_listener twice!");
    // Fire initial event.
    change_listener(contents_->current_token);
  } else {
    HARD_ASSERT(change_listener_, "change_listener removed without being set!");
    if (app_check_listener_handle_) {
      [[NSNotificationCenter defaultCenter]
          removeObserver:app_check_listener_handle_];
      app_check_listener_handle_ = nil;
    }
  }

  change_listener_ = change_listener;
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
