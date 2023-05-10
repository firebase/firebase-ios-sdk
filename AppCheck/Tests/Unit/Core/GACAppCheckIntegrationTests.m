/*
 * Copyright 2020 Google LLC
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

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import <TargetConditionals.h>

#import "AppCheck/Sources/Core/TokenRefresh/GACAppCheckTokenRefresher.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheck.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckProviderFactory.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckToken.h"

#import "AppCheck/Interop/GACAppCheckInterop.h"
#import "AppCheck/Interop/GACAppCheckTokenResultInterop.h"
#import "AppCheck/Sources/Public/AppCheck/GACDeviceCheckProvider.h"
#import "AppCheck/Sources/Public/AppCheck/GACDeviceCheckProviderFactory.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

#if GAC_DEVICE_CHECK_SUPPORTED_TARGETS

@interface DummyAppCheckProvider : NSObject <GACAppCheckProvider>
@end

@implementation DummyAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable, NSError *_Nullable))handler {
  GACAppCheckToken *token = [[GACAppCheckToken alloc] initWithToken:@"Token"
                                                     expirationDate:[NSDate distantFuture]];
  handler(token, nil);
}

@end

@interface AppCheckProviderFactory : NSObject <GACAppCheckProviderFactory>
@end

@implementation AppCheckProviderFactory

- (nullable id<GACAppCheckProvider>)createProviderWithApp:(nonnull FIRApp *)app {
  return [[DummyAppCheckProvider alloc] init];
}

@end

@interface GACAppCheckIntegrationTests : XCTestCase

@property(nonatomic, nullable) id mockProviderFactory;
@property(nonatomic, nullable) id mockAppCheckProvider;
@property(nonatomic, nullable) id mockTokenRefresher;

// TODO(andrewheard): Remove section from generic App Check SDK.
#ifdef FIREBASE_APP_CHECK_ONLY

- (void)testDefaultAppCheckProvider GAC_DEVICE_CHECK_PROVIDER_AVAILABILITY;

#endif  // FIREBASE_APP_CHECK_ONLY

@end

@implementation GACAppCheckIntegrationTests

- (void)setUp {
  [super setUp];

  // Disable token refresher to avoid any unexpected async tasks being scheduled.
  [self disableTokenRefresher];

  self.mockAppCheckProvider = OCMProtocolMock(@protocol(GACAppCheckProvider));
  self.mockProviderFactory = OCMProtocolMock(@protocol(GACAppCheckProviderFactory));
}

- (void)tearDown {
  [FIRApp resetApps];

  if (@available(iOS 11.0, macOS 10.15, macCatalyst 13.0, tvOS 11.0, watchOS 9.0, *)) {
    // Recover default provider factory.
    [GACAppCheck setAppCheckProviderFactory:[[GACDeviceCheckProviderFactory alloc] init]];
  }

  [self.mockTokenRefresher stopMocking];
  self.mockTokenRefresher = nil;
  [self.mockProviderFactory stopMocking];
  self.mockProviderFactory = nil;
  [self.mockAppCheckProvider stopMocking];
  self.mockAppCheckProvider = nil;

  [super tearDown];
}

// TODO(andrewheard): Remove section from generic App Check SDK.
#ifdef FIREBASE_APP_CHECK_ONLY

- (void)testDefaultAppCheckProvider {
  NSString *appName = @"testDefaultAppCheckProvider";

  // 1. Expect GACDeviceCheckProvider to be instantiated.

  id deviceCheckProviderMock = OCMClassMock([GACDeviceCheckProvider class]);
  id appValidationArg = [OCMArg checkWithBlock:^BOOL(FIRApp *app) {
    XCTAssertEqualObjects(app.name, appName);
    return YES;
  }];

  OCMStub([deviceCheckProviderMock alloc]).andReturn(deviceCheckProviderMock);
  OCMExpect([deviceCheckProviderMock initWithApp:appValidationArg])
      .andReturn(deviceCheckProviderMock);

  // 2. Configure Firebase
  [self configureAppWithName:appName];

  FIRApp *app = [FIRApp appNamed:appName];
  XCTAssertNotNil(FIR_COMPONENT(GACAppCheckInterop, app.container));

  // 3. Verify
  OCMVerifyAll(deviceCheckProviderMock);

  // 4. Cleanup
  // Recover default provider factory.
  [GACAppCheck setAppCheckProviderFactory:[[GACDeviceCheckProviderFactory alloc] init]];
  [deviceCheckProviderMock stopMocking];
}

// Tests that use the Keychain require a host app and Swift Package Manager
// does not support adding a host app to test targets.
#if !SWIFT_PACKAGE

// Skip keychain tests on Catalyst and macOS. Tests are skipped because they
// involve interactions with the keychain that require a provisioning profile.
// See go/firebase-macos-keychain-popups for more details.
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

- (void)testSetAppCheckProviderFactoryWithDefaultApp {
  NSString *appName = kFIRDefaultAppName;

  // 1. Set App Check Provider Factory.
  [GACAppCheck setAppCheckProviderFactory:self.mockProviderFactory];

  // 2. Expect factory to be used on [FIRApp configure].
  id appValidationArg = [OCMArg checkWithBlock:^BOOL(FIRApp *app) {
    XCTAssertEqual(app.name, appName);
    return YES;
  }];
  OCMExpect([self.mockProviderFactory createProviderWithApp:appValidationArg])
      .andReturn(self.mockAppCheckProvider);

  // 3. Configure FIRApp.
  [self configureAppWithName:appName];

  // 4. Expect App Check Provider to be called on getToken.
  GACAppCheckToken *fakeToken = [[GACAppCheckToken alloc] initWithToken:@"token"
                                                         expirationDate:[NSDate distantFuture]];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:fakeToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionBlockArg]);

  // 5. Call getToken and check the result.
  FIRApp *app = [FIRApp appNamed:appName];
  id<GACAppCheckInterop> appCheck = FIR_COMPONENT(GACAppCheckInterop, app.container);

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [appCheck getTokenForcingRefresh:YES
                        completion:^(id<GACAppCheckTokenResultInterop> tokenResult) {
                          [completionExpectation fulfill];
                          XCTAssertNil(tokenResult.error);
                          XCTAssertNotNil(tokenResult);
                          XCTAssertEqualObjects(tokenResult.token, fakeToken.token);
                          XCTAssertNil(tokenResult.error);
                        }];
  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 6. Verify mocks
  OCMVerifyAll(self.mockProviderFactory);
  OCMVerifyAll(self.mockAppCheckProvider);
}

#endif  // !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#endif  // !SWIFT_PACKAGE

#endif  // FIREBASE_APP_CHECK_ONLY

#pragma mark - Helpers

- (void)configureAppWithName:(NSString *)appName {
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  [FIRApp configureWithName:appName options:options];
}

- (void)usageExample {
  // Set a custom app check provider factory for the default FIRApp.
  [GACAppCheck setAppCheckProviderFactory:[[AppCheckProviderFactory alloc] init]];
  [FIRApp configure];

  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:@"path"];
  [FIRApp configureWithName:@"AppName" options:options];

  FIRApp *defaultApp = [FIRApp defaultApp];

  id<GACAppCheckInterop> defaultAppCheck = FIR_COMPONENT(GACAppCheckInterop, defaultApp.container);

  [defaultAppCheck getTokenForcingRefresh:NO
                               completion:^(id<GACAppCheckTokenResultInterop> tokenResult) {
                                 NSLog(@"Token: %@", tokenResult.token);
                                 if (tokenResult.error) {
                                   NSLog(@"Error: %@", tokenResult.error);
                                 }
                               }];
}

- (void)disableTokenRefresher {
  self.mockTokenRefresher = OCMClassMock([GACAppCheckTokenRefresher class]);
  OCMStub([self.mockTokenRefresher alloc]).andReturn(self.mockTokenRefresher);
  OCMStub([self.mockTokenRefresher initWithRefreshResult:[OCMArg any] settings:[OCMArg any]])
      .andReturn(self.mockTokenRefresher);
}

@end

#endif  // GAC_DEVICE_CHECK_SUPPORTED_TARGETS

NS_ASSUME_NONNULL_END
