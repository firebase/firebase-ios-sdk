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

#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckErrors.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProviderFactory.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckTokenResult.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

// The FAC token value returned when an error occurs.
static NSString *const kDummyToken = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

extern void FIRResetLogger(void);

@interface FIRAppCheck (Tests) <FIRAppCheckInterop, GACAppCheckTokenDelegate>
- (instancetype)initWithAppName:(NSString *)appName
                   appCheckCore:(GACAppCheck *)appCheckCore
               appCheckProvider:(id<FIRAppCheckProvider>)appCheckProvider
             notificationCenter:(NSNotificationCenter *)notificationCenter
                       settings:(FIRAppCheckSettings *)settings;

- (nullable instancetype)initWithApp:(FIRApp *)app;

- (void)tokenDidUpdate:(nonnull GACAppCheckToken *)token
           serviceName:(nonnull NSString *)serviceName;

@end

@interface FIRAppCheckTests : XCTestCase

@property(nonatomic) NSString *appName;
@property(nonatomic) OCMockObject<FIRAppCheckProvider> *mockAppCheckProvider;
@property(nonatomic) id mockSettings;
@property(nonatomic) NSNotificationCenter *notificationCenter;
@property(nonatomic) id mockAppCheckCore;
@property(nonatomic) FIRAppCheck<FIRAppCheckInterop> *appCheck;

@end

@implementation FIRAppCheckTests

- (void)setUp {
  [super setUp];

  FIRResetLogger();

  self.appName = @"FIRAppCheckTests";
  self.mockAppCheckProvider = OCMStrictProtocolMock(@protocol(FIRAppCheckProvider));
  self.mockSettings = OCMStrictClassMock([FIRAppCheckSettings class]);
  self.notificationCenter = [[NSNotificationCenter alloc] init];

  self.mockAppCheckCore = OCMStrictClassMock([GACAppCheck class]);

  self.appCheck = [[FIRAppCheck alloc] initWithAppName:self.appName
                                          appCheckCore:self.mockAppCheckCore
                                      appCheckProvider:self.mockAppCheckProvider
                                    notificationCenter:self.notificationCenter
                                              settings:self.mockSettings];
}

- (void)tearDown {
  self.appCheck = nil;
  self.mockAppCheckCore = nil;
  self.mockAppCheckProvider = nil;

  [super tearDown];
}

- (void)testInitWithApp {
  NSString *projectID = @"testInitWithApp_projectID";
  NSString *googleAppID = @"testInitWithApp_googleAppID";
  NSString *appName = @"testInitWithApp_appName";
  NSString *appGroupID = @"testInitWithApp_appGroupID";

  // 1. Stub FIRApp and validate usage.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:googleAppID GCMSenderID:@""];
  options.projectID = projectID;
  options.appGroupID = appGroupID;
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  app.dataCollectionDefaultEnabled = NO;

  // 2. Stub attestation provider.
  OCMockObject<FIRAppCheckProviderFactory> *mockProviderFactory =
      OCMStrictProtocolMock(@protocol(FIRAppCheckProviderFactory));
  OCMockObject<FIRAppCheckProvider> *mockProvider =
      OCMStrictProtocolMock(@protocol(FIRAppCheckProvider));
  OCMExpect([mockProviderFactory createProviderWithApp:app]).andReturn(mockProvider);

  [FIRAppCheck setAppCheckProviderFactory:mockProviderFactory];

  // 3. Set the Firebase logging level to Debug.
  FIRSetLoggerLevel(FIRLoggerLevelDebug);

  // 4. Call init.
  FIRAppCheck *appCheck = [[FIRAppCheck alloc] initWithApp:app];
  XCTAssert([appCheck isKindOfClass:[FIRAppCheck class]]);

  // 5. Verify mocks.
  OCMVerifyAll(mockProviderFactory);
  OCMVerifyAll(mockProvider);

  // 6. Verify that the App Check Core logging level is also Debug.
  XCTAssertEqual(GACAppCheckLogger.logLevel, GACAppCheckLogLevelDebug);
}

- (void)testAppCheckInstanceForApp {
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";

  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testAppCheckInstanceForApp" options:options];
  // The following disables automatic token refresh, which could interfere with tests.
  app.dataCollectionDefaultEnabled = NO;
  XCTAssertNotNil(app);

  XCTAssertNotNil([FIRAppCheck appCheckWithApp:app]);

  // Verify that the App Check Core logging level is the default (Warning).
  XCTAssertEqual(GACAppCheckLogger.logLevel, GACAppCheckLogLevelWarning);
}

#pragma mark - Public Get Token

- (void)testGetToken_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_TokenForcingRefresh_withExpectedToken:expectedToken];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [expectations.lastObject fulfill];
                 XCTAssertNotNil(token);
                 XCTAssertEqualObjects(token.token, expectedToken.token);
                 XCTAssertNil(error);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)testGetToken_AppCheckProviderError {
  // 1. Create expected token and error and configure expectations.
  FIRAppCheckToken *cachedToken = [self soonExpiringToken];
  NSError *providerError = [NSError errorWithDomain:@"FIRAppCheckTests" code:-1 userInfo:nil];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenError_withError:providerError andToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [expectations.lastObject fulfill];
                 XCTAssertNil(token);
                 XCTAssertNotNil(error);
                 XCTAssertNotEqualObjects(error, providerError);
                 XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
                 XCTAssertEqualObjects(error.userInfo[NSUnderlyingErrorKey], providerError);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)testGetToken_ServerUnreachableError {
  // 1. Create expected error and configure expectations.
  NSError *serverError = [self appCheckCoreErrorWithCode:GACAppCheckErrorCodeServerUnreachable
                                           failureReason:@"API request error."
                                         underlyingError:[self internalError]];
  NSError *publicServerError = [FIRAppCheckErrorUtil publicDomainErrorWithError:serverError];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenError_withError:serverError andToken:nil];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [expectations.lastObject fulfill];
                 XCTAssertNil(token);
                 XCTAssertNotNil(error);
                 XCTAssertEqualObjects(error, publicServerError);
                 XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
                 XCTAssertEqual(error.code, FIRAppCheckErrorCodeServerUnreachable);
                 XCTAssertEqualObjects(error.userInfo, serverError.userInfo);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)testGetToken_UnsupportedError {
  // 1. Create expected error and configure expectations.
  NSError *providerError = [self appCheckCoreErrorWithCode:GACAppCheckErrorCodeUnsupported
                                             failureReason:@"AppAttestProvider unsupported"
                                           underlyingError:nil];
  NSError *publicProviderError = [FIRAppCheckErrorUtil publicDomainErrorWithError:providerError];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenError_withError:providerError andToken:nil];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [expectations.lastObject fulfill];
                 XCTAssertNil(token);
                 XCTAssertNotNil(error);
                 XCTAssertEqualObjects(error, publicProviderError);
                 XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
                 XCTAssertEqual(error.code, FIRAppCheckErrorCodeUnsupported);
                 XCTAssertEqualObjects(error.userInfo, providerError.userInfo);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

#pragma mark - FIRAppCheckInterop Get Token

- (void)testInteropGetTokenForcingRefresh_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_TokenForcingRefresh_withExpectedToken:expectedToken];

  // 2. Request token and verify result.
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [expectations.lastObject fulfill];
                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, expectedToken.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)testInteropGetTokenForcingRefresh_AppCheckProviderError {
  // 1. Create expected tokens and errors and configure expectations.
  FIRAppCheckToken *cachedToken = [self soonExpiringToken];
  NSError *providerError = [NSError errorWithDomain:@"FIRAppCheckTests" code:-1 userInfo:nil];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenError_withError:providerError andToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck
      getTokenForcingRefresh:NO
                  completion:^(id<FIRAppCheckTokenResultInterop> result) {
                    [expectations.lastObject fulfill];
                    XCTAssertNotNil(result);
                    XCTAssertEqualObjects(result.token, kDummyToken);
                    XCTAssertEqualObjects(result.error, providerError);
                    // Interop API does not wrap errors in public domain.
                    XCTAssertNotEqualObjects(result.error.domain, FIRAppCheckErrorDomain);
                  }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)testLimitedUseTokenWithSuccess {
  // 1. Expect token requested from app check provider.
  FIRAppCheckToken *expectedToken = [self validToken];
  GACAppCheckToken *expectedInternalToken = [expectedToken internalToken];
  GACAppCheckTokenResult *expectedTokenResult =
      [[GACAppCheckTokenResult alloc] initWithToken:expectedInternalToken];
  id completionArg = [OCMArg invokeBlockWithArgs:expectedTokenResult, nil];
  OCMStub([self.mockAppCheckCore limitedUseTokenWithCompletion:completionArg]);

  // 2. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationNotPosted];
  // 3. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  [self.appCheck
      limitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [getTokenExpectation fulfill];
        XCTAssertNotNil(token);
        XCTAssertEqualObjects(token.token, expectedToken.token);
        XCTAssertNil(error);
      }];
  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  [self verifyAllMocks];
}

- (void)testLimitedUseToken_WhenTokenGenerationErrors {
  // 1. Expect error when requesting token from app check provider.
  NSError *providerError = [self appCheckCoreErrorWithCode:GACAppCheckErrorCodeKeychain
                                             failureReason:@"Keychain access error."
                                           underlyingError:[self internalError]];
  NSError *publicProviderError = [FIRAppCheckErrorUtil publicDomainErrorWithError:providerError];
  GACAppCheckTokenResult *expectedTokenResult =
      [[GACAppCheckTokenResult alloc] initWithError:providerError];
  id completionArg = [OCMArg invokeBlockWithArgs:expectedTokenResult, nil];
  OCMStub([self.mockAppCheckCore limitedUseTokenWithCompletion:completionArg]);

  // 2. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 3. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationNotPosted];
  // 4. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  [self.appCheck
      limitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [getTokenExpectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertNil(token.token);
        XCTAssertEqualObjects(error, publicProviderError);
        XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
        XCTAssertEqual(error.code, FIRAppCheckErrorCodeKeychain);
        XCTAssertEqualObjects(error.userInfo, providerError.userInfo);
      }];

  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  [self verifyAllMocks];
}

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
  [[[self.mockSettings expect] andReturnValue:@(NO)] isTokenAutoRefreshEnabled];
  XCTAssertFalse(self.appCheck.isTokenAutoRefreshEnabled);

  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];
  XCTAssertTrue(self.appCheck.isTokenAutoRefreshEnabled);

  OCMVerifyAll(self.mockSettings);
}

- (void)testSetIsTokenAutoRefreshEnabled {
  OCMExpect([self.mockSettings setIsTokenAutoRefreshEnabled:YES]);
  self.appCheck.isTokenAutoRefreshEnabled = YES;

  OCMExpect([self.mockSettings setIsTokenAutoRefreshEnabled:NO]);
  self.appCheck.isTokenAutoRefreshEnabled = NO;

  OCMVerifyAll(self.mockSettings);
}

#pragma mark - Helpers

- (NSError *)internalError {
  return [NSError errorWithDomain:@"com.internal.error" code:-1 userInfo:nil];
}

- (NSError *)appCheckCoreErrorWithCode:(GACAppCheckErrorCode)code
                         failureReason:(nullable NSString *)failureReason
                       underlyingError:(nullable NSError *)underlyingError {
  NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [NSMutableDictionary dictionary];
  userInfo[NSUnderlyingErrorKey] = underlyingError;
  userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;

  return [NSError errorWithDomain:GACAppCheckErrorDomain code:code userInfo:userInfo];
}

- (FIRAppCheckToken *)validToken {
  return [[FIRAppCheckToken alloc] initWithToken:[NSUUID UUID].UUIDString
                                  expirationDate:[NSDate distantFuture]];
}

- (FIRAppCheckToken *)soonExpiringToken {
  NSDate *soonExpiringTokenDate = [NSDate dateWithTimeIntervalSinceNow:4.5 * 60];
  return [[FIRAppCheckToken alloc] initWithToken:@"valid" expirationDate:soonExpiringTokenDate];
}

- (XCTestExpectation *)tokenUpdateNotificationWithExpectedToken:(NSString *)expectedToken {
  XCTestExpectation *expectation =
      [self expectationForNotification:[self.appCheck tokenDidChangeNotificationName]
                                object:nil
                    notificationCenter:self.notificationCenter
                               handler:^BOOL(NSNotification *_Nonnull notification) {
                                 XCTAssertEqualObjects(
                                     notification.userInfo[[self.appCheck notificationAppNameKey]],
                                     self.appName);
                                 XCTAssertEqualObjects(
                                     notification.userInfo[[self.appCheck notificationTokenKey]],
                                     expectedToken);
                                 XCTAssertEqualObjects(notification.object, self.appCheck);
                                 return YES;
                               }];
  return expectation;
}

- (XCTestExpectation *)tokenUpdateNotificationNotPosted {
  XCTNSNotificationExpectation *expectation = [[XCTNSNotificationExpectation alloc]
            initWithName:[self.appCheck tokenDidChangeNotificationName]
                  object:nil
      notificationCenter:self.notificationCenter];
  expectation.inverted = YES;
  return expectation;
}

- (NSArray<XCTestExpectation *> *)configuredExpectations_TokenForcingRefresh_withExpectedToken:
    (FIRAppCheckToken *)expectedToken {
  // 1. Expect token requested from app check core.
  GACAppCheckToken *expectedInternalToken = [expectedToken internalToken];
  GACAppCheckTokenResult *expectedTokenResult =
      [[GACAppCheckTokenResult alloc] initWithToken:expectedInternalToken];
  id completionArg = [OCMArg invokeBlockWithArgs:expectedTokenResult, nil];
  OCMExpect([self.mockAppCheckCore tokenForcingRefresh:NO completion:completionArg])
      .andDo(^(NSInvocation *invocation) {
        [self.appCheck tokenDidUpdate:expectedInternalToken serviceName:self.appName];
      })
      .ignoringNonObjectArgs();

  // 2. Expect token update notification to be sent.
  XCTestExpectation *tokenNotificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 3. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ tokenNotificationExpectation, getTokenExpectation ];
}

- (NSArray<XCTestExpectation *> *)
    configuredExpectations_GetTokenWhenError_withError:(NSError *_Nonnull)error
                                              andToken:(FIRAppCheckToken *_Nullable)token {
  // 1. Expect token requested from app check core.
  GACAppCheckTokenResult *expectedTokenResult =
      [[GACAppCheckTokenResult alloc] initWithError:error];
  id completionArg = [OCMArg invokeBlockWithArgs:expectedTokenResult, nil];
  OCMExpect([self.mockAppCheckCore tokenForcingRefresh:NO completion:completionArg])
      .ignoringNonObjectArgs();

  // 2. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 3. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationNotPosted];

  // 4. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ notificationExpectation, getTokenExpectation ];
}

- (void)verifyAllMocks {
  OCMVerifyAll(self.mockAppCheckProvider);
  OCMVerifyAll(self.mockSettings);
  OCMVerifyAll(self.mockAppCheckCore);
}

@end
