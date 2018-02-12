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

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace auth {

// TODO(zxu123): Make this an integration test and get infos from environment.
// Set a .plist file here to enable the test-case.
static NSString* const kPlist = @"";

class FirebaseCredentialsProviderTest : public ::testing::Test {
 protected:
  void SetUp() override {
    app_ready_ = false;
    if (![kPlist hasSuffix:@".plist"]) {
      return;
    }

    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
      FIROptions* options = [[FIROptions alloc] initWithContentsOfFile:kPlist];
      [FIRApp configureWithOptions:options];
    });

    // Set getUID implementation.
    FIRApp* default_app = [FIRApp defaultApp];
    default_app.getUIDImplementation = ^NSString* {
      return @"I'm a fake uid.";
    };
    app_ready_ = true;
  }

  bool app_ready_;
};

// Set kPlist above before enable.
TEST_F(FirebaseCredentialsProviderTest, GetToken) {
  if (!app_ready_) {
    return;
  }

  FirebaseCredentialsProvider credentials_provider([FIRApp defaultApp]);
  credentials_provider.GetToken(
      /*force_refresh=*/true,
      [](const Token& token, const absl::string_view error) {
        EXPECT_EQ("", token.token());
        const User& user = token.user();
        EXPECT_EQ("I'm a fake uid.", user.uid());
        EXPECT_TRUE(user.is_authenticated());
        EXPECT_EQ("", error) << error;
      });
}

// Set kPlist above before enable.
TEST_F(FirebaseCredentialsProviderTest, SetListener) {
  if (!app_ready_) {
    return;
  }

  FirebaseCredentialsProvider credentials_provider([FIRApp defaultApp]);
  credentials_provider.SetUserChangeListener([](const User& user) {
    EXPECT_EQ("I'm a fake uid.", user.uid());
    EXPECT_TRUE(user.is_authenticated());
  });

  // TODO(wilhuff): We should wait for the above expectations to actually happen
  // before continuing.

  credentials_provider.SetUserChangeListener(nullptr);
}

}  // namespace auth
}  // namespace firestore
}  // namespace firebase
