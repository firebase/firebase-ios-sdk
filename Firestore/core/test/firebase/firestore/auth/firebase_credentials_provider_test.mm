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

#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/app_testing.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace auth {

FIRApp* AppWithFakeUidAndToken(NSString* _Nullable uid,
                               NSString* _Nullable token) {
  FIRApp* app = testutil::AppForUnitTesting();
  app.getUIDImplementation = ^NSString* {
    return uid;
  };
  app.getTokenImplementation = ^(BOOL, FIRTokenCallback callback) {
    callback(token, nil);
  };
  return app;
}

FIRApp* AppWithFakeUid(NSString* _Nullable uid) {
  return AppWithFakeUidAndToken(uid, uid == nil ? nil : @"default token");
}

TEST(FirebaseCredentialsProviderTest, GetTokenUnauthenticated) {
  FIRApp* app = AppWithFakeUid(nil);

  FirebaseCredentialsProvider credentials_provider(app);
  credentials_provider.GetToken(
      /*force_refresh=*/true, [](util::StatusOr<Token> result) {
        EXPECT_TRUE(result.ok());
        const Token& token = result.ValueOrDie();
        EXPECT_ANY_THROW(token.token());
        const User& user = token.user();
        EXPECT_EQ("", user.uid());
        EXPECT_FALSE(user.is_authenticated());
      });
}

TEST(FirebaseCredentialsProviderTest, GetToken) {
  FIRApp* app = AppWithFakeUidAndToken(@"fake uid", @"token for fake uid");

  FirebaseCredentialsProvider credentials_provider(app);
  credentials_provider.GetToken(
      /*force_refresh=*/true, [](util::StatusOr<Token> result) {
        EXPECT_TRUE(result.ok());
        const Token& token = result.ValueOrDie();
        EXPECT_EQ("token for fake uid", token.token());
        const User& user = token.user();
        EXPECT_EQ("fake uid", user.uid());
        EXPECT_TRUE(user.is_authenticated());
      });
}

TEST(FirebaseCredentialsProviderTest, SetListener) {
  FIRApp* app = AppWithFakeUid(@"fake uid");

  FirebaseCredentialsProvider credentials_provider(app);
  credentials_provider.SetUserChangeListener([](User user) {
    EXPECT_EQ("fake uid", user.uid());
    EXPECT_TRUE(user.is_authenticated());
  });

  credentials_provider.SetUserChangeListener(nullptr);
}

}  // namespace auth
}  // namespace firestore
}  // namespace firebase
