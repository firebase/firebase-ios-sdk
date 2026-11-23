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

#include <chrono>
#include <future>
#include <memory>

#import "FirebaseAuth/Interop/Public/FirebaseAuthInterop/FIRAuthInterop.h"
#import "FirebaseCore/Extension/FIRAppInternal.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/app_testing.h"

#include "gtest/gtest.h"

/// A fake class to handle Auth interaction.
@interface FSTAuthFake : NSObject <FIRAuthInterop>
@property(nonatomic, nullable, copy) NSString* token;
@property(nonatomic, nullable, copy) NSString* uid;
@property(nonatomic, readonly) BOOL forceRefreshTriggered;
@property(nonatomic, assign) BOOL deferCallbacks;
@property(nonatomic, nullable, copy, readonly) FIRTokenCallback pendingCallback;
- (instancetype)initWithToken:(nullable NSString*)token
                          uid:(nullable NSString*)uid NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (void)completePendingGetTokenWithToken:(nullable NSString*)token
                                   error:(nullable NSError*)error;
@end

@implementation FSTAuthFake

- (instancetype)initWithToken:(nullable NSString*)token
                          uid:(nullable NSString*)uid {
  self = [super init];
  if (self) {
    _token = [token copy];
    _uid = [uid copy];
    _forceRefreshTriggered = NO;
    _deferCallbacks = NO;
  }
  return self;
}

- (void)completePendingGetTokenWithToken:(nullable NSString*)token
                                   error:(nullable NSError*)error {
  FIRTokenCallback callback = _pendingCallback;
  _pendingCallback = nil;
  if (callback) {
    callback(token, error);
  }
}

// FIRAuthInterop conformance.

- (nullable NSString*)getUserID {
  return self.uid;
}

- (void)getTokenForcingRefresh:(BOOL)forceRefresh
                  withCallback:(nonnull FIRTokenCallback)callback {
  _forceRefreshTriggered = forceRefresh;
  if (self.deferCallbacks) {
    _pendingCallback = [callback copy];
  } else {
    callback(self.token, nil);
  }
}

@end

namespace firebase {
namespace firestore {
namespace credentials {

// Simulates the case where Firebase/Firestore is installed in the project but
// Firebase/Auth is not available.
TEST(FirebaseAuthCredentialsProviderTest, GetTokenNoProvider) {
  auto token_promise = std::make_shared<std::promise<AuthToken>>();

  FIRApp* app = testutil::AppForUnitTesting();
  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, nil);
  credentials_provider->GetToken(
      [token_promise](util::StatusOr<AuthToken> result) {
        EXPECT_TRUE(result.ok());
        const AuthToken& token = result.ValueOrDie();
        EXPECT_ANY_THROW(token.token());
        const User& user = token.user();
        EXPECT_EQ("", user.uid());
        EXPECT_FALSE(user.is_authenticated());

        // TODO(wilhuff): convert between !result.ok() and a failed promise.
        token_promise->set_value(token);
      });

  // TODO(wilhuff): generalize this pattern or make util::Await for non-void
  // futures.
  auto kTimeout = std::chrono::seconds(5);
  auto token_future = token_promise->get_future();
  ASSERT_EQ(std::future_status::ready, token_future.wait_for(kTimeout));
}

TEST(FirebaseAuthCredentialsProviderTest, GetTokenUnauthenticated) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:nil uid:nil];
  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);
  credentials_provider->GetToken([](util::StatusOr<AuthToken> result) {
    EXPECT_TRUE(result.ok());
    const AuthToken& token = result.ValueOrDie();
    EXPECT_ANY_THROW(token.token());
    const User& user = token.user();
    EXPECT_EQ("", user.uid());
    EXPECT_FALSE(user.is_authenticated());
  });
}

TEST(FirebaseAuthCredentialsProviderTest, GetToken) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"token for fake uid"
                                                     uid:@"fake uid"];
  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);
  credentials_provider->GetToken([](util::StatusOr<AuthToken> result) {
    EXPECT_TRUE(result.ok());
    const AuthToken& token = result.ValueOrDie();
    EXPECT_EQ("token for fake uid", token.token());
    const User& user = token.user();
    EXPECT_EQ("fake uid", user.uid());
    EXPECT_TRUE(user.is_authenticated());
  });
}

TEST(FirebaseAuthCredentialsProviderTest, SetListener) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"default token"
                                                     uid:@"fake uid"];
  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);
  credentials_provider->SetCredentialChangeListener([](User user) {
    EXPECT_EQ("fake uid", user.uid());
    EXPECT_TRUE(user.is_authenticated());
  });

  credentials_provider->SetCredentialChangeListener(nullptr);
}

TEST(FirebaseAuthCredentialsProviderTest, InvalidateToken) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"token for fake uid"
                                                     uid:@"fake uid"];
  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);
  credentials_provider->InvalidateToken();
  credentials_provider->GetToken([&auth](util::StatusOr<AuthToken> result) {
    EXPECT_TRUE(result.ok());
    EXPECT_TRUE(auth.forceRefreshTriggered);
    const AuthToken& token = result.ValueOrDie();
    EXPECT_EQ("token for fake uid", token.token());
    EXPECT_EQ("fake uid", token.user().uid());
  });
}

// Catch race conditions in FirebaseAuthCredentialsProvider::GetToken() when
// run under thread sanitizer.
// See https://github.com/firebase/firebase-ios-sdk/issues/10393
TEST(FirebaseAuthCredentialsProviderTest, GetTokenCalledByAnotherThread) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"token for fake uid"
                                                     uid:@"fake uid"];
  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);

  std::thread thread1([credentials_provider] {
    credentials_provider->GetToken(
        [](util::StatusOr<AuthToken> result) { EXPECT_TRUE(result.ok()); });
  });
  std::thread thread2([credentials_provider] {
    credentials_provider->GetToken(
        [](util::StatusOr<AuthToken> result) { EXPECT_TRUE(result.ok()); });
  });

  thread1.join();
  thread2.join();
}

TEST(FirebaseAuthCredentialsProviderTest,
     GetTokenCallbackAfterAuthChangeAndListenerRemovedAborts) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"token-user-alpha"
                                                     uid:@"uid-user-alpha"];
  auth.deferCallbacks = YES;

  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);
  credentials_provider->SetCredentialChangeListener([](User) {});

  bool callback_invoked = false;
  util::StatusOr<AuthToken> token_result;
  credentials_provider->GetToken([&](util::StatusOr<AuthToken> result) {
    callback_invoked = true;
    token_result = std::move(result);
  });

  auth.uid = nil;
  auth.token = nil;
  [[NSNotificationCenter defaultCenter]
      postNotificationName:FIRAuthStateDidChangeInternalNotification
                    object:nil
                  userInfo:@{
                    FIRAuthStateDidChangeInternalNotificationAppKey : app,
                  }];
  credentials_provider->SetCredentialChangeListener(nullptr);

  [auth completePendingGetTokenWithToken:@"token-user-alpha" error:nil];

  ASSERT_TRUE(callback_invoked);
  EXPECT_FALSE(token_result.ok());
  EXPECT_EQ(Error::kErrorAborted, token_result.status().code());
  EXPECT_EQ(nil, auth.pendingCallback);
}

TEST(FirebaseAuthCredentialsProviderTest,
     GetTokenCallbackAfterListenerRemovedWithoutAuthChangeAborts) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"token-user-alpha"
                                                     uid:@"uid-user-alpha"];
  auth.deferCallbacks = YES;

  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);
  credentials_provider->SetCredentialChangeListener([](User) {});

  bool callback_invoked = false;
  util::StatusOr<AuthToken> token_result;
  credentials_provider->GetToken([&](util::StatusOr<AuthToken> result) {
    callback_invoked = true;
    token_result = std::move(result);
  });

  credentials_provider->SetCredentialChangeListener(nullptr);
  [auth completePendingGetTokenWithToken:@"token-user-alpha" error:nil];

  ASSERT_TRUE(callback_invoked);
  EXPECT_FALSE(token_result.ok());
  EXPECT_EQ(Error::kErrorAborted, token_result.status().code());
  EXPECT_EQ(nil, auth.pendingCallback);
}

TEST(FirebaseAuthCredentialsProviderTest,
     GetTokenRetriesWhenUserChangesWhileListenerActive) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"token-user-alpha"
                                                     uid:@"uid-user-alpha"];
  auth.deferCallbacks = YES;

  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);
  credentials_provider->SetCredentialChangeListener([](User) {});

  bool callback_invoked = false;
  util::StatusOr<AuthToken> token_result;
  credentials_provider->GetToken([&](util::StatusOr<AuthToken> result) {
    callback_invoked = true;
    token_result = std::move(result);
  });

  auth.uid = @"uid-user-beta";
  auth.token = @"token-user-beta";
  auth.deferCallbacks = NO;
  [[NSNotificationCenter defaultCenter]
      postNotificationName:FIRAuthStateDidChangeInternalNotification
                    object:nil
                  userInfo:@{
                    FIRAuthStateDidChangeInternalNotificationAppKey : app,
                    FIRAuthStateDidChangeInternalNotificationUIDKey :
                        @"uid-user-beta",
                  }];

  [auth completePendingGetTokenWithToken:@"token-user-alpha" error:nil];

  ASSERT_TRUE(callback_invoked);
  ASSERT_TRUE(token_result.ok());
  EXPECT_EQ("token-user-beta", token_result.ValueOrDie().token());
  EXPECT_EQ("uid-user-beta", token_result.ValueOrDie().user().uid());

  credentials_provider->SetCredentialChangeListener(nullptr);
}

TEST(FirebaseAuthCredentialsProviderTest,
     GetTokenCalledDirectlyAfterListenerRemovedAsserts) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"token-user-alpha"
                                                     uid:@"uid-user-alpha"];
  auto credentials_provider =
      std::make_shared<FirebaseAuthCredentialsProvider>(app, auth);
  credentials_provider->SetCredentialChangeListener([](User) {});
  credentials_provider->SetCredentialChangeListener(nullptr);

  EXPECT_ANY_THROW(
      credentials_provider->GetToken([](util::StatusOr<AuthToken>) {}));
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
