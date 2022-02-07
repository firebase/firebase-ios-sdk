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

#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefresher.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProviderFactory.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckTokenResultInterop.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProvider.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProviderFactory.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface DummyAppCheckProvider : NSObject <FIRAppCheckProvider>
@end

@implementation DummyAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable, NSError *_Nullable))handler {
  FIRAppCheckToken *token = [[FIRAppCheckToken alloc] initWithToken:@"Token"
                                                     expirationDate:[NSDate distantFuture]];
  handler(token, nil);
}

@end

@interface AppCheckProviderFactory : NSObject <FIRAppCheckProviderFactory>
@end

@implementation AppCheckProviderFactory

- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(nonnull FIRApp *)app {
  return [[DummyAppCheckProvider alloc] init];
}

@end

@interface FIRAppCheckIntegrationTests : XCTestCase

@property(nonatomic, nullable) id mockProviderFactory;
@property(nonatomic, nullable) id mockAppCheckProvider;
@property(nonatomic, nullable) id mockTokenRefresher;

@end

@implementation FIRAppCheckIntegrationTests

- (void)setUp {
  [super setUp];

  // Disable token refresher to avoid any unexpected async tasks being scheduled.
  [self disableTokenRefresher];

  self.mockAppCheckProvider = OCMProtocolMock(@protocol(FIRAppCheckProvider));
  self.mockProviderFactory = OCMProtocolMock(@protocol(FIRAppCheckProviderFactory));
}

- (void)tearDown {
  [FIRApp resetApps];

  if (@available(iOS 11.0, macOS 10.15, macCatalyst 13.0, tvOS 11.0, *)) {
    // Recover default provider factory.
    [FIRAppCheck setAppCheckProviderFactory:[[FIRDeviceCheckProviderFactory alloc] init]];
  }

  [self.mockTokenRefresher stopMocking];
  self.mockTokenRefresher = nil;
  [self.mockProviderFactory stopMocking];
  self.mockProviderFactory = nil;
  [self.mockAppCheckProvider stopMocking];
  self.mockAppCheckProvider = nil;

  [super tearDown];
}

- (void)testDefaultAppCheckProvider {
  if (@available(iOS 11.0, tvOS 11.0, macOS 10.15, *)) {
    NSString *appName = @"testDefaultAppCheckProvider";

    // 1. Expect FIRDeviceCheckProvider to be instantiated.

    id deviceCheckProviderMock = OCMClassMock([FIRDeviceCheckProvider class]);
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
    XCTAssertNotNil(FIR_COMPONENT(FIRAppCheckInterop, app.container));

    // 3. Verify
    OCMVerifyAll(deviceCheckProviderMock);

    // 4. Cleanup
    // Recover default provider factory.
    [FIRAppCheck setAppCheckProviderFactory:[[FIRDeviceCheckProviderFactory alloc] init]];
    [deviceCheckProviderMock stopMocking];
  } else {
    // Fallback on earlier versions
  }
}

#if !TARGET_OS_MACCATALYST  // Catalyst should be possible with Xcode 12.5+
- (void)testSetAppCheckProviderFactoryWithDefaultApp {
  NSString *appName = kFIRDefaultAppName;

  // 1. Set App Check Provider Factory.
  [FIRAppCheck setAppCheckProviderFactory:self.mockProviderFactory];

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
  FIRAppCheckToken *fakeToken = [[FIRAppCheckToken alloc] initWithToken:@"token"
                                                         expirationDate:[NSDate distantFuture]];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:fakeToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionBlockArg]);

  // 5. Call getToken and check the result.
  FIRApp *app = [FIRApp appNamed:appName];
  id<FIRAppCheckInterop> appCheck = FIR_COMPONENT(FIRAppCheckInterop, app.container);

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [appCheck getTokenForcingRefresh:YES
                        completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
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
#endif  // !TARGET_OS_MACCATALYST

#pragma mark - Helpers

- (void)configureAppWithName:(NSString *)appName {
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  [FIRApp configureWithName:appName options:options];
}

- (void)usageExample {
  // Set a custom app check provider factory for the default FIRApp.
  [FIRAppCheck setAppCheckProviderFactory:[[AppCheckProviderFactory alloc] init]];
  [FIRApp configure];

  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:@"path"];
  [FIRApp configureWithName:@"AppName" options:options];

  FIRApp *defaultApp = [FIRApp defaultApp];

  id<FIRAppCheckInterop> defaultAppCheck = FIR_COMPONENT(FIRAppCheckInterop, defaultApp.container);

  [defaultAppCheck getTokenForcingRefresh:NO
                               completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                                 NSLog(@"Token: %@", tokenResult.token);
                                 if (tokenResult.error) {
                                   NSLog(@"Error: %@", tokenResult.error);
                                 }
                               }];
}

- (void)disableTokenRefresher {
  self.mockTokenRefresher = OCMClassMock([FIRAppCheckTokenRefresher class]);
  OCMStub([self.mockTokenRefresher alloc]).andReturn(self.mockTokenRefresher);
  OCMStub([self.mockTokenRefresher initWithRefreshResult:[OCMArg any] settings:[OCMArg any]])
      .andReturn(self.mockTokenRefresher);
}

@end

NS_ASSUME_NONNULL_END
