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

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)

#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"
#import "FirebaseCore/Internal/FIRAppInternal.h"

#include "Firestore/core/test/unit/testutil/app_testing.h"

#include "gtest/gtest.h"

// TODO(mrschmidt): Use SharedTestUtilities/AppCheckFake
@interface FSTAppCheckTokenResultFake : NSObject <FIRAppCheckTokenResultInterop>
@property(nonatomic, readonly) NSString* token;
@property(nonatomic, readonly, nullable) NSError* error;
- (instancetype)initWithToken:(nullable NSString*)token
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation FSTAppCheckTokenResultFake

- (instancetype)initWithToken:(nullable NSString*)token {
  self = [super init];
  if (self) {
    _token = [token copy];
  }
  return self;
}

@end

@interface FSTAppCheckFake : NSObject <FIRAppCheckInterop>
@property(nonatomic, nullable, strong, readonly) NSString* token;
@property(nonatomic, readonly) BOOL forceRefreshTriggered;
- (instancetype)initWithToken:(nullable NSString*)token
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation FSTAppCheckFake

- (instancetype)initWithToken:(nullable NSString*)token {
  self = [super init];
  if (self) {
    _token = [token copy];
    _forceRefreshTriggered = NO;
  }
  return self;
}

- (void)getTokenForcingRefresh:(BOOL)forceRefresh
                    completion:(FIRAppCheckTokenHandlerInterop)completion {
  _forceRefreshTriggered = forceRefresh;
  completion([[FSTAppCheckTokenResultFake alloc] initWithToken:_token]);
}

- (nonnull NSString*)notificationAppNameKey {
  return @"FakeAppCheckTokenDidChangeNotification";
}

- (nonnull NSString*)notificationTokenKey {
  return @"FakeTokenNotificationKey";
}

- (nonnull NSString*)tokenDidChangeNotificationName {
  return @"FakeAppCheckTokenDidChangeNotification";
}

@end

namespace firebase {
namespace firestore {
namespace credentials {

// Simulates the case where Firebase/Firestore is installed in the project but
// Firebase/AppCheck is not available.
TEST(FirebaseAppCheckCredentialsProviderTest, GetTokenNoProvider) {
  auto token_promise = std::make_shared<std::promise<std::string>>();

  FIRApp* app = testutil::AppForUnitTesting();
  FirebaseAppCheckCredentialsProvider credentials_provider(app, nil);
  credentials_provider.GetToken(
      [token_promise](util::StatusOr<std::string> result) {
        EXPECT_TRUE(result.ok());
        const std::string& token = result.ValueOrDie();
        EXPECT_EQ("", token);
        token_promise->set_value(token);
      });

  auto kTimeout = std::chrono::seconds(5);
  auto token_future = token_promise->get_future();
  ASSERT_EQ(std::future_status::ready, token_future.wait_for(kTimeout));
}

TEST(FirebaseAppCheckCredentialsProviderTest, GetToken) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAppCheckFake* app_check =
      [[FSTAppCheckFake alloc] initWithToken:@"fake token"];
  FirebaseAppCheckCredentialsProvider credentials_provider(app, app_check);
  credentials_provider.GetToken([](util::StatusOr<std::string> result) {
    EXPECT_TRUE(result.ok());
    const std::string& token = result.ValueOrDie();
    EXPECT_EQ("fake token", token);
  });
}

TEST(FirebaseAppCheckCredentialsProviderTest, SetListener) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAppCheckFake* app_check =
      [[FSTAppCheckFake alloc] initWithToken:@"fake token"];
  FirebaseAppCheckCredentialsProvider credentials_provider(app, app_check);
  credentials_provider.SetCredentialChangeListener(
      [](std::string token) { EXPECT_EQ("", token); });

  credentials_provider.SetCredentialChangeListener(nullptr);
}

TEST(FirebaseAppCheckCredentialsProviderTest, InvalidateToken) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAppCheckFake* app_check =
      [[FSTAppCheckFake alloc] initWithToken:@"fake token"];
  FirebaseAppCheckCredentialsProvider credentials_provider(app, app_check);
  credentials_provider.InvalidateToken();
  credentials_provider.GetToken(
      [&app_check](util::StatusOr<std::string> result) {
        EXPECT_TRUE(result.ok());
        EXPECT_TRUE(app_check.forceRefreshTriggered);
        const std::string& token = result.ValueOrDie();
        EXPECT_EQ("fake token", token);
      });
}

TEST(FirebaseAppCheckCredentialsProviderTest, ListenForTokenChanges) {
  auto token_promise = std::make_shared<std::promise<std::string>>();

  FIRApp* app = testutil::AppForUnitTesting();
  FSTAppCheckFake* app_check = [[FSTAppCheckFake alloc] initWithToken:@""];
  FirebaseAppCheckCredentialsProvider credentials_provider(app, app_check);

  credentials_provider.SetCredentialChangeListener(
      [token_promise](const std::string& result) {
        if (result != "") {
          token_promise->set_value(result);
        }
      });

  [[NSNotificationCenter defaultCenter]
      postNotificationName:[app_check tokenDidChangeNotificationName]
                    object:app_check
                  userInfo:@{
                    [app_check notificationTokenKey] :
                        @"updated_app_check_token",
                    [app_check notificationAppNameKey] : [app name],
                  }];

  auto kTimeout = std::chrono::seconds(5);
  auto token_future = token_promise->get_future();
  ASSERT_EQ(std::future_status::ready, token_future.wait_for(kTimeout));

  EXPECT_EQ("updated_app_check_token", token_future.get());
}

// Regression test for https://github.com/firebase/firebase-ios-sdk/issues/8895
TEST(FirebaseAppCheckCredentialsProviderTest,
     ListenForTokenChangesIgnoresUnrelatedNotifcations) {
  auto token_promise = std::make_shared<std::promise<std::string>>();

  FIRApp* app = testutil::AppForUnitTesting();
  FSTAppCheckFake* app_check = [[FSTAppCheckFake alloc] initWithToken:@""];
  FirebaseAppCheckCredentialsProvider credentials_provider(app, app_check);

  credentials_provider.SetCredentialChangeListener(
      [token_promise](const std::string& result) {
        if (result != "") {
          token_promise->set_value(result);
        }
      });

  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"unrelated"
                    object:app_check
                  userInfo:@{
                    [app_check notificationTokenKey] : @"token1",
                    [app_check notificationAppNameKey] : [app name],
                  }];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:[app_check tokenDidChangeNotificationName]
                    object:app_check
                  userInfo:@{
                    [app_check notificationTokenKey] : @"token2",
                    [app_check notificationAppNameKey] : [app name],
                  }];

  auto kTimeout = std::chrono::seconds(5);
  auto token_future = token_promise->get_future();
  ASSERT_EQ(std::future_status::ready, token_future.wait_for(kTimeout));

  // Verify that we get 'token2`, which is the second notification but the
  // only one that uses the AppCheck topic.
  EXPECT_EQ("token2", token_future.get());
}

// Regression test for https://github.com/firebase/firebase-ios-sdk/issues/8895
TEST(FirebaseAppCheckCredentialsProviderTest,
     ListenDoesNotCrashIfUnrelatedNotificationsAreInvalid) {
  auto token_promise = std::make_shared<std::promise<std::string>>();

  FIRApp* app = testutil::AppForUnitTesting();
  FSTAppCheckFake* app_check = [[FSTAppCheckFake alloc] initWithToken:@""];
  FirebaseAppCheckCredentialsProvider credentials_provider(app, app_check);

  credentials_provider.SetCredentialChangeListener(
      [token_promise](const std::string& result) {
        if (result != "") {
          token_promise->set_value(result);
        }
      });

  // Sending this notifcation would cause a crash if it was processed in the
  // AppCheck notification handlder since AppCheck expects the userInfo object
  // to an NSDictionary.
  id userInfo = @"this_should_be_a_dictionary";
  [[NSNotificationCenter defaultCenter] postNotificationName:@"unrelated"
                                                      object:app_check
                                                    userInfo:userInfo];

  // Send another valid notification that we can block on.
  userInfo = @{
    [app_check notificationTokenKey] : @"token",
    [app_check notificationAppNameKey] : [app name],
  };
  [[NSNotificationCenter defaultCenter]
      postNotificationName:[app_check tokenDidChangeNotificationName]
                    object:app_check
                  userInfo:userInfo];

  auto kTimeout = std::chrono::seconds(5);
  auto token_future = token_promise->get_future();
  ASSERT_EQ(std::future_status::ready, token_future.wait_for(kTimeout));
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
