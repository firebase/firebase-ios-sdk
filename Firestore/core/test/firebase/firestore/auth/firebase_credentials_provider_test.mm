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

#import <FirebaseAuthInterop/FIRAuthInterop.h>
#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainerInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>

#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/app_testing.h"

#include "gtest/gtest.h"

/// Testing interface for ComponentContainer (required for Auth).
@interface FIRComponentContainer ()
// The extra long type information in components causes clang-format to wrap in
// a weird way, turn for the declaration.
// clang-format off
/// Exposed for testing, create a container directly with components and a dummy
/// app.
- (instancetype)initWithApp:(FIRApp*)app
                 components:(NSDictionary<NSString*,
                             FIRComponentCreationBlock>*)components;
// clang-format on
@end

/// A fake class to handle Auth interaction.
@interface FSTAuthFake : NSObject<FIRAuthInterop>
@property(nonatomic, nullable, strong, readonly) NSString* token;
@property(nonatomic, nullable, strong, readonly) NSString* uid;
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
  }
  return self;
}

// FIRAuthUserIDProvider conformance.
- (nullable NSString*)getUserID {
  return self.uid;
}

// FIRAuthInteroperable conformance.
- (void)getTokenForcingRefresh:(BOOL)forceRefresh
                  withCallback:(nonnull FIRTokenCallback)callback {
  callback(self.token, nil);
}

@end

namespace firebase {
namespace firestore {
namespace auth {

FIRApp* AppWithFakeUidAndToken(NSString* _Nullable uid,
                               NSString* _Nullable token) {
  FIRApp* app = testutil::AppForUnitTesting();

  auto auth_provider_block =
      ^id _Nullable(FIRComponentContainer* container, BOOL* is_cacheable) {
    return [[FSTAuthFake alloc] initWithToken:token uid:uid];
  };

  // Inject a new container with the Auth interoperable fake into the app.
  NSString* auth_interoperable_key =
      NSStringFromProtocol(@protocol(FIRAuthInterop));
  NSDictionary* components = @{auth_interoperable_key : auth_provider_block};
  FIRComponentContainer* container =
      [[FIRComponentContainer alloc] initWithApp:app components:components];

  // Override the existing container for the app that contains the Auth fake.
  app.container = container;

  return app;
}

FIRApp* AppWithFakeUid(NSString* _Nullable uid) {
  return AppWithFakeUidAndToken(uid, uid == nil ? nil : @"default token");
}

TEST(FirebaseCredentialsProviderTest, GetTokenUnauthenticated) {
  FIRApp* app = AppWithFakeUid(nil);
  FSTAuthFake* auth = [[FSTAuthFake alloc] initWithToken:<#(nullable NSString *)#> uid:<#(nullable NSString *)#>]
  FirebaseCredentialsProvider credentials_provider(app);
  credentials_provider.GetToken([](util::StatusOr<Token> result) {
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
  credentials_provider.GetToken([](util::StatusOr<Token> result) {
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

FIRApp* FakeAppExpectingForceRefreshToken(NSString* _Nullable uid,
                                          NSString* _Nullable token) {
  FIRApp* app = testutil::AppForUnitTesting();
  app.getUIDImplementation = ^NSString* {
    return uid;
  };
  app.getTokenImplementation =
      ^(BOOL force_refresh, FIRTokenCallback callback) {
        EXPECT_TRUE(force_refresh);
        callback(token, nil);
      };
  return app;
}

TEST(FirebaseCredentialsProviderTest, InvalidateToken) {
  FIRApp* app =
      FakeAppExpectingForceRefreshToken(@"fake uid", @"token for fake uid");

  FirebaseCredentialsProvider credentials_provider{app};
  credentials_provider.InvalidateToken();
  credentials_provider.GetToken([](util::StatusOr<Token> result) {
    EXPECT_TRUE(result.ok());
    const Token& token = result.ValueOrDie();
    EXPECT_EQ("token for fake uid", token.token());
    EXPECT_EQ("fake uid", token.user().uid());
  });
}

}  // namespace auth
}  // namespace firestore
}  // namespace firebase
