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

// #import "FBLPromise+Testing.h"

#import <FirebaseAppCheck/FirebaseAppCheck.h>

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckErrors.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"

#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheck+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckTokenResult.h"
#import "FirebaseAppCheck/Sources/Core/FIRInternalAppCheckProvider.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

// The FAC token value returned when an error occurs.
static NSString *const kDummyToken = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

static NSString *const kResourceName = @"projects/test-project-id/apps/test-app-id";
static NSString *const kAppGroupID = @"test-app-group-id";

@interface FIRFakeAppCheckSettings
    : NSObject <GACAppCheckSettingsProtocol, FIRAppCheckSettingsProtocol>
@end

@implementation FIRFakeAppCheckSettings

@synthesize isTokenAutoRefreshEnabled;

@end

@interface FIRAppCheck (Tests) <GACAppCheckTokenDelegate, FIRAppCheckInterop>
- (instancetype)initWithAppName:(NSString *)appName
               appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
             notificationCenter:(NSNotificationCenter *)notificationCenter
                       settings:(id<GACAppCheckSettingsProtocol>)settings
                   resourceName:(NSString *)resourceName
                     appGroupID:(NSString *)appGroupID;

- (nullable instancetype)initWithApp:(FIRApp *)app;
@end

@interface FIRAppCheckTests : XCTestCase

@property(nonatomic) NSString *appName;
@property(nonatomic) OCMockObject<FIRAppCheckProvider> *mockAppCheckProvider;
@property(nonatomic) FIRFakeAppCheckSettings *fakeSettings;
@property(nonatomic) NSNotificationCenter *notificationCenter;
@property(nonatomic) FIRAppCheck<FIRAppCheckInterop> *appCheck;
@property(nonatomic) id mockInternalAppCheck;

@end

@implementation FIRAppCheckTests

- (void)setUp {
  [super setUp];

  self.appName = @"FIRAppCheckTests";
  self.mockAppCheckProvider = OCMProtocolMock(@protocol(FIRAppCheckProvider));
  self.fakeSettings = [[FIRFakeAppCheckSettings alloc] init];
  self.notificationCenter = [[NSNotificationCenter alloc] init];

  FIRInternalAppCheckProvider *internalAppCheckProvider =
      [[FIRInternalAppCheckProvider alloc] initWithAppCheckProvider:self.mockAppCheckProvider];

  self.mockInternalAppCheck = OCMStrictClassMock([GACAppCheck class]);
  OCMStub([self.mockInternalAppCheck alloc]).andReturn(self.mockInternalAppCheck);
  OCMStub([self.mockInternalAppCheck initWithInstanceName:self.appName
                                         appCheckProvider:[OCMArg any]
                                                 settings:[OCMArg any]
                                             resourceName:[OCMArg any]
                                      keychainAccessGroup:[OCMArg any]])
      .andReturn(self.mockInternalAppCheck);
  OCMStub([self.mockInternalAppCheck setTokenDelegate:[OCMArg any]]);

  self.appCheck = [[FIRAppCheck alloc] initWithAppName:self.appName
                                      appCheckProvider:internalAppCheckProvider
                                    notificationCenter:self.notificationCenter
                                              settings:self.fakeSettings
                                          resourceName:kResourceName
                                            appGroupID:kAppGroupID];
}

- (void)tearDown {
  self.appCheck = nil;
  [self.mockAppCheckProvider stopMocking];
  self.mockAppCheckProvider = nil;
  [self.mockInternalAppCheck stopMocking];
  self.mockInternalAppCheck = nil;

  [super tearDown];
}

- (void)testInitWithApp {
  //  NSString *googleAppID = @"testInitWithApp_googleAppID";
  NSString *appName = @"testInitWithApp_appName";
  NSString *appGroupID = @"testInitWithApp_appGroupID";

  // 1. Stub FIRApp and validate usage.
  id mockApp = OCMStrictClassMock([FIRApp class]);
  id mockAppOptions = OCMStrictClassMock([FIROptions class]);
  OCMStub([mockApp name]).andReturn(appName);
  OCMStub([mockApp resourceName]).andReturn(kResourceName);
  OCMStub([mockApp isDataCollectionDefaultEnabled]).andReturn(YES);
  OCMStub([(FIRApp *)mockApp options]).andReturn(mockAppOptions);
  //  OCMExpect([mockAppOptions googleAppID]).andReturn(googleAppID);
  OCMExpect([mockAppOptions appGroupID]).andReturn(appGroupID);

  // 4. Stub attestation provider.
  OCMockObject<FIRAppCheckProviderFactory> *mockProviderFactory =
      OCMProtocolMock(@protocol(FIRAppCheckProviderFactory));
  OCMockObject<FIRAppCheckProvider> *mockProvider = OCMProtocolMock(@protocol(FIRAppCheckProvider));
  OCMExpect([mockProviderFactory createProviderWithApp:mockApp]).andReturn(mockProvider);

  [FIRAppCheck setAppCheckProviderFactory:mockProviderFactory];

  // 5. Stub internal App Check and validate usage.
  OCMExpect([self.mockInternalAppCheck initWithInstanceName:OCMOCK_ANY
                                           appCheckProvider:OCMOCK_ANY
                                                   settings:OCMOCK_ANY
                                               resourceName:OCMOCK_ANY
                                        keychainAccessGroup:OCMOCK_ANY])
      .andReturn(self.mockInternalAppCheck);

  // 6. Call init.
  FIRAppCheck *appCheck = [[FIRAppCheck alloc] initWithApp:mockApp];
  XCTAssert([appCheck isKindOfClass:[FIRAppCheck class]]);

  // 7. Verify mocks.
  OCMVerifyAll(mockApp);
  OCMVerifyAll(mockAppOptions);
  OCMVerifyAll(mockProviderFactory);
  OCMVerifyAll(mockProvider);
  OCMVerifyAll(self.mockInternalAppCheck);

  // 7. Stop mocking real class mocks.
  [mockApp stopMocking];
  mockApp = nil;
  [mockAppOptions stopMocking];
  mockAppOptions = nil;
}

- (void)testAppCheckDefaultInstance {
  // Should throw an exception when the default app is not configured.
  XCTAssertThrows([FIRAppCheck appCheck]);

  // Configure default FIRApp.
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  OCMExpect([self.mockInternalAppCheck initWithInstanceName:OCMOCK_ANY
                                           appCheckProvider:OCMOCK_ANY
                                                   settings:OCMOCK_ANY
                                               resourceName:OCMOCK_ANY
                                        keychainAccessGroup:OCMOCK_ANY])
      .andReturn(self.mockInternalAppCheck);
  [FIRApp configureWithOptions:options];

  // Check.
  XCTAssertNotNil([FIRAppCheck appCheck]);

  [FIRApp resetApps];
}

- (void)testAppCheckInstanceForApp {
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";

  OCMExpect([self.mockInternalAppCheck initWithInstanceName:OCMOCK_ANY
                                           appCheckProvider:OCMOCK_ANY
                                                   settings:OCMOCK_ANY
                                               resourceName:OCMOCK_ANY
                                        keychainAccessGroup:OCMOCK_ANY])
      .andReturn(self.mockInternalAppCheck);

  [FIRApp configureWithName:@"testAppCheckInstanceForApp" options:options];
  FIRApp *app = [FIRApp appNamed:@"testAppCheckInstanceForApp"];
  XCTAssertNotNil(app);

  XCTAssertNotNil([FIRAppCheck appCheckWithApp:app]);

  [FIRApp resetApps];
}

#pragma mark - Public API

- (void)testGetToken_WhenNoCache_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];
  BOOL forcingRefresh = NO;

  OCMStub([self.mockInternalAppCheck
      tokenForcingRefresh:forcingRefresh
               completion:([OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil])]);

  //  NSArray * /*[tokenNotification, getToken]*/ expectations =
  //      [self configuredExpectations_GetTokenWhenNoCache_withExpectedToken:expectedToken];

  XCTestExpectation *expectation = [[XCTestExpectation alloc]
      initWithDescription:@"FIRAppCheck tokenForcingRefresh completion handler invoked."];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:forcingRefresh
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 //                 [expectations.lastObject fulfill];
                 [expectation fulfill];
                 XCTAssertNotNil(token);
                 XCTAssertEqualObjects(token.token, expectedToken.token);
                 XCTAssertNil(error);
               }];

  // 3. Wait for expectations and validate mocks.
  //  [self waitForExpectations:expectations timeout:0.5];
  [self waitForExpectations:@[ expectation ] timeout:0.5];
  [self verifyAllMocks];
}

- (void)testGetToken_AppCheckProviderError {
  // 1. Create expected token and error and configure expectations.
  //  FIRAppCheckToken *cachedToken = [self soonExpiringToken];
  NSError *expectedError = [NSError errorWithDomain:@"FIRAppCheckTests" code:-1 userInfo:nil];
  BOOL forcingRefresh = NO;

  //  NSArray * /*[tokenNotification, getToken]*/ expectations =
  //      [self configuredExpectations_GetTokenWhenError_withError:providerError
  //      andToken:cachedToken];
  OCMStub([self.mockInternalAppCheck
      tokenForcingRefresh:forcingRefresh
               completion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);

  XCTestExpectation *expectation = [[XCTestExpectation alloc]
      initWithDescription:@"FIRAppCheck tokenForcingRefresh completion handler invoked."];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:forcingRefresh
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [expectation fulfill];
                 XCTAssertNil(token);
                 XCTAssertNotEqualObjects(error, expectedError);
                 XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
                 XCTAssertEqualObjects(error.userInfo[NSUnderlyingErrorKey], expectedError);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ expectation ] timeout:0.5];
  [self verifyAllMocks];
}

#pragma mark - FIRAppCheckInterop Get Token

- (void)testInteropGetToken_WhenNoCache_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];
  BOOL forcingRefresh = NO;

  //  NSArray * /*[tokenNotification, getToken]*/ expectations =
  //      [self configuredExpectations_GetTokenWhenNoCache_withExpectedToken:expectedToken];

  OCMStub([self.mockInternalAppCheck
      tokenForcingRefresh:forcingRefresh
               completion:([OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil])]);

  XCTestExpectation *expectation = [[XCTestExpectation alloc]
      initWithDescription:@"FIRAppCheck tokenForcingRefresh completion handler invoked."];

  // 2. Request token and verify result.
  [self.appCheck getTokenForcingRefresh:forcingRefresh
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [expectation fulfill];
                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, expectedToken.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ expectation ] timeout:0.5];
  [self verifyAllMocks];
}

- (void)testInteropGetToken_AppCheckProviderError {
  // 1. Create expected tokens and errors and configure expectations.
  NSError *expectedError = [NSError errorWithDomain:@"FIRAppCheckTests" code:-1 userInfo:nil];
  BOOL forcingRefresh = NO;

  OCMStub([self.mockInternalAppCheck
      tokenForcingRefresh:forcingRefresh
               completion:([OCMArg invokeBlockWithArgs:[NSNull null], expectedError, nil])]);

  XCTestExpectation *expectation = [[XCTestExpectation alloc]
      initWithDescription:@"FIRAppCheck tokenForcingRefresh completion handler invoked."];

  // 2. Request token and verify result.
  [self.appCheck
      getTokenForcingRefresh:forcingRefresh
                  completion:^(id<FIRAppCheckTokenResultInterop> result) {
                    [expectation fulfill];
                    XCTAssertNotNil(result);
                    XCTAssertEqualObjects(result.token, kDummyToken);
                    XCTAssertEqualObjects(result.error, expectedError);
                    // Interop API does not wrap errors in public domain.
                    XCTAssertNotEqualObjects(result.error.domain, FIRAppCheckErrorDomain);
                  }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ expectation ] timeout:0.5];
  [self verifyAllMocks];
}

- (void)testLimitedUseTokenWithSuccess {
  // 1. Don't expect token to be requested from storage.
  //  OCMReject([self.mockStorage getToken]);

  // 2. Expect token requested from app check provider.
  FIRAppCheckToken *expectedToken = [self validToken];
  //  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  //  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  OCMStub([self.mockInternalAppCheck
      limitedUseTokenWithCompletion:([OCMArg
                                        invokeBlockWithArgs:expectedToken, [NSNull null], nil])]);
  // 3. Don't expect token requested from storage.
  //  OCMReject([self.mockStorage setToken:expectedToken]);

  // 4. Don't expect token update notification to be sent.
  //  XCTestExpectation *notificationExpectation = [self
  //  tokenUpdateNotificationWithExpectedToken:@""
  //                                                                                   isInverted:YES];
  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  [self.appCheck
      limitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [getTokenExpectation fulfill];
        XCTAssertNotNil(token);
        XCTAssertEqualObjects(token.token, expectedToken.token);
        XCTAssertNil(error);
      }];
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
  [self verifyAllMocks];
}

//- (void)testLimitedUseToken_WhenTokenGenerationErrors {
//  // 1. Don't expect token to be requested from storage.
//  OCMReject([self.mockStorage getToken]);
//
//  // 2. Expect error when requesting token from app check provider.
//  NSError *providerError = [FIRAppCheckErrorUtil keychainErrorWithError:[self internalError]];
//  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], providerError, nil];
//  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);
//
//  // 3. Don't expect token requested from app check provider.
//  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);
//
//  // 4. Don't expect token update notification to be sent.
//  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""
//                                                                                   isInverted:YES];
//  // 5. Expect token request to be completed.
//  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
//
//  [self.appCheck
//      limitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error)
//      {
//        [getTokenExpectation fulfill];
//        XCTAssertNotNil(error);
//        XCTAssertNil(token.token);
//        XCTAssertEqualObjects(error, providerError);
//        XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
//      }];
//
//  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
//  [self verifyAllMocks];
//}

#pragma mark - Token update notifications

- (void)testTokenUpdateNotificationKeys {
  XCTAssertEqualObjects([self.appCheck tokenDidChangeNotificationName],
                        @"FIRAppCheckAppCheckTokenDidChangeNotification");
  XCTAssertEqualObjects([self.appCheck notificationAppNameKey],
                        @"FIRAppCheckAppNameNotificationKey");
  XCTAssertEqualObjects([self.appCheck notificationTokenKey], @"FIRAppCheckTokenNotificationKey");
}

#pragma mark - Auto-refresh enabled

- (void)testIsTokenAutoRefreshEnabled {
  // Expect value from settings to be used.
  self.fakeSettings.isTokenAutoRefreshEnabled = YES;
  XCTAssertTrue(self.appCheck.isTokenAutoRefreshEnabled);

  self.fakeSettings.isTokenAutoRefreshEnabled = NO;
  XCTAssertFalse(self.appCheck.isTokenAutoRefreshEnabled);
}

- (void)testSetIsTokenAutoRefreshEnabled {
  self.appCheck.isTokenAutoRefreshEnabled = YES;
  XCTAssertTrue(self.fakeSettings.isTokenAutoRefreshEnabled);

  self.appCheck.isTokenAutoRefreshEnabled = NO;
  XCTAssertFalse(self.fakeSettings.isTokenAutoRefreshEnabled);
}

#pragma mark - Helpers

//- (NSError *)internalError {
//  return [NSError errorWithDomain:@"com.internal.error" code:-1 userInfo:nil];
//}

- (FIRAppCheckToken *)validToken {
  return [[FIRAppCheckToken alloc] initWithToken:[NSUUID UUID].UUIDString
                                  expirationDate:[NSDate distantFuture]];
}

//- (FIRAppCheckToken *)soonExpiringToken {
//  NSDate *soonExpiringTokenDate = [NSDate dateWithTimeIntervalSinceNow:4.5 * 60];
//  return [[FIRAppCheckToken alloc] initWithToken:@"valid" expirationDate:soonExpiringTokenDate];
//}
//
//- (void)stubSetTokenRefreshHandler {
//  id arg = [OCMArg checkWithBlock:^BOOL(id handler) {
//    self.tokenRefreshHandler = handler;
//    return YES;
//  }];
//  OCMExpect([self.mockTokenRefresher setTokenRefreshHandler:arg]);
//}
//
//- (XCTestExpectation *)tokenUpdateNotificationWithExpectedToken:(NSString *)expectedToken {
//  return [self tokenUpdateNotificationWithExpectedToken:expectedToken isInverted:NO];
//}
//
//- (XCTestExpectation *)tokenUpdateNotificationWithExpectedToken:(NSString *)expectedToken
//                                                     isInverted:(BOOL)isInverted {
//  XCTestExpectation *expectation =
//      [self expectationForNotification:[self.appCheck tokenDidChangeNotificationName]
//                                object:nil
//                    notificationCenter:self.notificationCenter
//                               handler:^BOOL(NSNotification *_Nonnull notification) {
//                                 XCTAssertEqualObjects(
//                                     notification.userInfo[[self.appCheck
//                                     notificationAppNameKey]], self.appName);
//                                 XCTAssertEqualObjects(
//                                     notification.userInfo[[self.appCheck notificationTokenKey]],
//                                     expectedToken);
//                                 XCTAssertEqualObjects(notification.object, self.appCheck);
//                                 return YES;
//                               }];
//  expectation.inverted = isInverted;
//  return expectation;
//}
//
//- (void)assertGetToken_WhenCachedTokenIsValid_Success {
//  // 1. Create expected token and configure expectations.
//  FIRAppCheckToken *cachedToken = [self validToken];
//
//  NSArray * /*[tokenNotification, getToken]*/ expectations =
//      [self configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:cachedToken];
//
//  // 2. Request token and verify result.
//  [self.appCheck
//      tokenForcingRefresh:NO
//               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
//                 [expectations.lastObject fulfill];
//                 XCTAssertNotNil(token);
//                 XCTAssertEqualObjects(token.token, cachedToken.token);
//                 XCTAssertNil(error);
//               }];
//
//  // 3. Wait for expectations and validate mocks.
//  [self waitForExpectations:expectations timeout:0.5];
//  [self verifyAllMocks];
//}
//
//- (void)assertInteropGetToken_WhenCachedTokenIsValid_Success {
//  // 1. Create expected token and configure expectations.
//  FIRAppCheckToken *cachedToken = [self validToken];
//
//  NSArray * /*[tokenNotification, getToken]*/ expectations =
//      [self configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:cachedToken];
//
//  // 2. Request token and verify result.
//  [self.appCheck getTokenForcingRefresh:NO
//                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
//                               [expectations.lastObject fulfill];
//                               XCTAssertNotNil(tokenResult);
//                               XCTAssertEqualObjects(tokenResult.token, cachedToken.token);
//                               XCTAssertNil(tokenResult.error);
//                             }];
//
//  // 3. Wait for expectations and validate mocks.
//  [self waitForExpectations:expectations timeout:0.5];
//  [self verifyAllMocks];
//}
//
//- (NSArray<XCTestExpectation *> *)configuredExpectations_GetTokenWhenNoCache_withExpectedToken:
//    (FIRAppCheckToken *)expectedToken {
//  // 1. Expect token to be requested from storage.
//  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);
//
//  // 2. Expect token requested from app check provider.
//  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
//  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);
//
//  // 3. Expect new token to be stored.
//  OCMExpect([self.mockStorage setToken:expectedToken])
//      .andReturn([FBLPromise resolvedWith:expectedToken]);
//
//  // 4. Expect token update notification to be sent.
//  XCTestExpectation *tokenNotificationExpectation =
//      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];
//
//  // 5. Expect token request to be completed.
//  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
//
//  return @[ tokenNotificationExpectation, getTokenExpectation ];
//}
//
//- (NSArray<XCTestExpectation *> *)
//    configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:
//        (FIRAppCheckToken *)expectedToken {
//  // 1. Expect token to be requested from storage.
//  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:expectedToken]);
//
//  // 2. Don't expect token requested from app check provider.
//  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);
//
//  // 3. Don't expect token update notification to be sent.
//  XCTestExpectation *tokenNotificationExpectation =
//      [self tokenUpdateNotificationWithExpectedToken:@"" isInverted:YES];
//
//  // 4. Expect token request to be completed.
//  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
//
//  return @[ tokenNotificationExpectation, getTokenExpectation ];
//}
//
//- (NSArray<XCTestExpectation *> *)
//    configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid_withExpectedToken:
//        (FIRAppCheckToken *)expectedToken {
//  // 1. Don't expect token to be requested from storage.
//  OCMReject([self.mockStorage getToken]);
//
//  // 2. Expect token requested from app check provider.
//  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
//  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);
//
//  // 3. Expect new token to be stored.
//  OCMExpect([self.mockStorage setToken:expectedToken])
//      .andReturn([FBLPromise resolvedWith:expectedToken]);
//
//  // 4. Expect token update notification to be sent.
//  XCTestExpectation *notificationExpectation =
//      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];
//
//  // 5. Expect token request to be completed.
//  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
//
//  return @[ notificationExpectation, getTokenExpectation ];
//}
//
//- (NSArray<XCTestExpectation *> *)
//    configuredExpectations_GetTokenWhenCachedTokenExpired_withExpectedToken:
//        (FIRAppCheckToken *)expectedToken {
//  // 1. Expect token to be requested from storage.
//  FIRAppCheckToken *cachedToken = [[FIRAppCheckToken alloc] initWithToken:@"expired"
//                                                           expirationDate:[NSDate date]];
//  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:cachedToken]);
//
//  // 2. Expect token requested from app check provider.
//  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
//  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);
//
//  // 3. Expect new token to be stored.
//  OCMExpect([self.mockStorage setToken:expectedToken])
//      .andReturn([FBLPromise resolvedWith:expectedToken]);
//
//  // 4. Expect token update notification to be sent.
//  XCTestExpectation *notificationExpectation =
//      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];
//
//  // 5. Expect token request to be completed.
//  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
//
//  return @[ notificationExpectation, getTokenExpectation ];
//}
//
//- (NSArray<XCTestExpectation *> *)
//    configuredExpectations_GetTokenWhenError_withError:(NSError *_Nonnull)error
//                                              andToken:(FIRAppCheckToken *_Nullable)token {
//  // 1. Expect token to be requested from storage.
//  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:token]);
//
//  // 2. Expect token requested from app check provider.
//  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], error, nil];
//  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);
//
//  // 3. Don't expect token requested from app check provider.
//  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);
//
//  // 4. Expect token update notification to be sent.
//  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""
//                                                                                   isInverted:YES];
//
//  // 5. Expect token request to be completed.
//  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
//
//  return @[ notificationExpectation, getTokenExpectation ];
//}
//
//- (NSArray *)expectTokenRequestFromAppCheckProvider {
//  // 1. Expect token to be requested from storage.
//  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);
//
//  // 2. Expect token requested from app check provider.
//  FIRAppCheckToken *expectedToken = [self validToken];
//  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
//  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);
//
//  // 3. Expect new token to be stored.
//  // 3.1. Create a pending promise to resolve later.
//  FBLPromise<FIRAppCheckToken *> *storeTokenPromise = [FBLPromise pendingPromise];
//  // 3.2. Stub storage set token method.
//  OCMExpect([self.mockStorage setToken:expectedToken]).andReturn(storeTokenPromise);
//
//  return @[ expectedToken, storeTokenPromise ];
//}

- (void)verifyAllMocks {
  OCMVerifyAll(self.mockAppCheckProvider);
  //  OCMVerifyAll(self.mockStorage);
  //  OCMVerifyAll(self.fakeSettings);
  //  OCMVerifyAll(self.mockTokenRefresher);
}

@end
