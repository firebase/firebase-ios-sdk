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

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)
#include <memory>

#import "Interop/Auth/Public/FIRAuthInterop.h"

#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/app_testing.h"

#include "gtest/gtest.h"

/// A fake class to handle Auth interaction.
@interface FSTAuthFake : NSObject <FIRAuthInterop>
@property(nonatomic, nullable, strong, readonly) NSString* token;
@property(nonatomic, nullable, strong, readonly) NSString* uid;
@property(nonatomic, readonly) BOOL forceRefreshTriggered;
- (instancetype)initWithToken:(nullable NSString*)token
                          uid:(nullable NSString*)uid NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation FSTAuthFake

- (instancetype)initWithToken:(nullable NSString*)token
                          uid:(nullable NSString*)uid {
  self = [super init];
  if (self) {
    _token = [token copy];
    _uid = [uid copy];
    _forceRefreshTriggered = NO;
  }
  return self;
}

// FIRAuthInterop conformance.

- (nullable NSString*)getUserID {
  return self.uid;
}

- (void)getTokenForcingRefresh:(BOOL)forceRefresh
                  withCallback:(nonnull FIRTokenCallback)callback {
  _forceRefreshTriggered = forceRefresh;
  callback(self.token, nil);
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
  FirebaseAuthCredentialsProvider credentials_provider(app, nil);
  credentials_provider.GetToken(
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
  FirebaseAuthCredentialsProvider credentials_provider(app, auth);
  credentials_provider.GetToken([](util::StatusOr<AuthToken> result) {
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
  FirebaseAuthCredentialsProvider credentials_provider(app, auth);
  credentials_provider.GetToken([](util::StatusOr<AuthToken> result) {
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
  FirebaseAuthCredentialsProvider credentials_provider(app, auth);
  credentials_provider.SetCredentialChangeListener([](User user) {
    EXPECT_EQ("fake uid", user.uid());
    EXPECT_TRUE(user.is_authenticated());
  });

  credentials_provider.SetCredentialChangeListener(nullptr);
}

TEST(FirebaseAuthCredentialsProviderTest, InvalidateToken) {
  FIRApp* app = testutil::AppForUnitTesting();
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:@"token for fake uid"
                                                     uid:@"fake uid"];
  FirebaseAuthCredentialsProvider credentials_provider(app, auth);
  credentials_provider.InvalidateToken();
  credentials_provider.GetToken([&auth](util::StatusOr<AuthToken> result) {
    EXPECT_TRUE(result.ok());
    EXPECT_TRUE(auth.forceRefreshTriggered);
    const AuthToken& token = result.ValueOrDie();
    EXPECT_EQ("token for fake uid", token.token());
    EXPECT_EQ("fake uid", token.user().uid());
  });
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
