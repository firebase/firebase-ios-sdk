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

#import "FBLPromise+Testing.h"

#import <FirebaseAppCheck/FirebaseAppCheck.h>

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckErrors.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"

#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckTokenResult.h"
#import "FirebaseAppCheck/Sources/Core/Storage/FIRAppCheckStorage.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefreshResult.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefresher.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

// The FAC token value returned when an error occurs.
static NSString *const kDummyToken = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

@interface FIRAppCheck (Tests) <FIRAppCheckInterop>
- (instancetype)initWithAppName:(NSString *)appName
               appCheckProvider:(id<FIRAppCheckProvider>)appCheckProvider
                        storage:(id<FIRAppCheckStorageProtocol>)storage
                 tokenRefresher:(id<FIRAppCheckTokenRefresherProtocol>)tokenRefresher
             notificationCenter:(NSNotificationCenter *)notificationCenter
                       settings:(id<FIRAppCheckSettingsProtocol>)settings;

- (nullable instancetype)initWithApp:(FIRApp *)app;
@end

@interface FIRAppCheckTests : XCTestCase

@property(nonatomic) NSString *appName;
@property(nonatomic) OCMockObject<FIRAppCheckStorageProtocol> *mockStorage;
@property(nonatomic) OCMockObject<FIRAppCheckProvider> *mockAppCheckProvider;
@property(nonatomic) OCMockObject<FIRAppCheckTokenRefresherProtocol> *mockTokenRefresher;
@property(nonatomic) OCMockObject<FIRAppCheckSettingsProtocol> *mockSettings;
@property(nonatomic) NSNotificationCenter *notificationCenter;
@property(nonatomic) FIRAppCheck<FIRAppCheckInterop> *appCheck;

@property(nonatomic, copy, nullable) FIRAppCheckTokenRefreshBlock tokenRefreshHandler;

@end

@implementation FIRAppCheckTests

- (void)setUp {
  [super setUp];

  self.appName = @"FIRAppCheckTests";
  self.mockStorage = OCMProtocolMock(@protocol(FIRAppCheckStorageProtocol));
  self.mockAppCheckProvider = OCMProtocolMock(@protocol(FIRAppCheckProvider));
  self.mockTokenRefresher = OCMProtocolMock(@protocol(FIRAppCheckTokenRefresherProtocol));
  self.mockSettings = OCMProtocolMock(@protocol(FIRAppCheckSettingsProtocol));
  self.notificationCenter = [[NSNotificationCenter alloc] init];

  [self stubSetTokenRefreshHandler];

  self.appCheck = [[FIRAppCheck alloc] initWithAppName:self.appName
                                      appCheckProvider:self.mockAppCheckProvider
                                               storage:self.mockStorage
                                        tokenRefresher:self.mockTokenRefresher
                                    notificationCenter:self.notificationCenter
                                              settings:self.mockSettings];
}

- (void)tearDown {
  self.appCheck = nil;
  [self.mockAppCheckProvider stopMocking];
  self.mockAppCheckProvider = nil;
  [self.mockStorage stopMocking];
  self.mockStorage = nil;
  [self.mockTokenRefresher stopMocking];
  self.mockTokenRefresher = nil;

  [super tearDown];
}

- (void)testInitWithApp {
  NSString *googleAppID = @"testInitWithApp_googleAppID";
  NSString *appName = @"testInitWithApp_appName";
  NSString *appGroupID = @"testInitWithApp_appGroupID";

  // 1. Stub FIRApp and validate usage.
  id mockApp = OCMStrictClassMock([FIRApp class]);
  id mockAppOptions = OCMStrictClassMock([FIROptions class]);
  OCMStub([mockApp name]).andReturn(appName);
  OCMStub([(FIRApp *)mockApp options]).andReturn(mockAppOptions);
  OCMExpect([mockAppOptions googleAppID]).andReturn(googleAppID);
  OCMExpect([mockAppOptions appGroupID]).andReturn(appGroupID);

  // 2. Stub FIRAppCheckTokenRefresher and validate usage.
  id mockTokenRefresher = OCMClassMock([FIRAppCheckTokenRefresher class]);
  OCMExpect([mockTokenRefresher alloc]).andReturn(mockTokenRefresher);

  id refresherDateValidator =
      [OCMArg checkWithBlock:^BOOL(FIRAppCheckTokenRefreshResult *refreshResult) {
        XCTAssertEqual(refreshResult.status, FIRAppCheckTokenRefreshStatusNever);
        XCTAssertEqual(refreshResult.tokenExpirationDate, nil);
        XCTAssertEqual(refreshResult.tokenReceivedAtDate, nil);
        return YES;
      }];

  id settingsValidator = [OCMArg checkWithBlock:^BOOL(id obj) {
    XCTAssert([obj isKindOfClass:[FIRAppCheckSettings class]]);
    return YES;
  }];

  OCMExpect([mockTokenRefresher initWithRefreshResult:refresherDateValidator
                                             settings:settingsValidator])
      .andReturn(mockTokenRefresher);
  OCMExpect([mockTokenRefresher setTokenRefreshHandler:[OCMArg any]]);

  // 3. Stub FIRAppCheckStorage and validate usage.
  id mockStorage = OCMClassMock([FIRAppCheckStorage class]);
  OCMExpect([mockStorage alloc]).andReturn(mockStorage);
  OCMExpect([mockStorage initWithAppName:appName appID:googleAppID accessGroup:appGroupID])
      .andReturn(mockStorage);

  // 4. Stub attestation provider.
  OCMockObject<FIRAppCheckProviderFactory> *mockProviderFactory =
      OCMProtocolMock(@protocol(FIRAppCheckProviderFactory));
  OCMockObject<FIRAppCheckProvider> *mockProvider = OCMProtocolMock(@protocol(FIRAppCheckProvider));
  OCMExpect([mockProviderFactory createProviderWithApp:mockApp]).andReturn(mockProvider);

  [FIRAppCheck setAppCheckProviderFactory:mockProviderFactory];

  // 5. Call init.
  FIRAppCheck *appCheck = [[FIRAppCheck alloc] initWithApp:mockApp];
  XCTAssert([appCheck isKindOfClass:[FIRAppCheck class]]);

  // 6. Verify mocks.
  OCMVerifyAll(mockApp);
  OCMVerifyAll(mockAppOptions);
  OCMVerifyAll(mockTokenRefresher);
  OCMVerifyAll(mockStorage);
  OCMVerifyAll(mockProviderFactory);
  OCMVerifyAll(mockProvider);

  // 7. Stop mocking real class mocks.
  [mockApp stopMocking];
  mockApp = nil;
  [mockAppOptions stopMocking];
  mockAppOptions = nil;
  [mockTokenRefresher stopMocking];
  mockTokenRefresher = nil;
  [mockStorage stopMocking];
  mockStorage = nil;
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

  [FIRApp configureWithName:@"testAppCheckInstanceForApp" options:options];
  FIRApp *app = [FIRApp appNamed:@"testAppCheckInstanceForApp"];
  XCTAssertNotNil(app);

  XCTAssertNotNil([FIRAppCheck appCheckWithApp:app]);

  [FIRApp resetApps];
}

#pragma mark - Public Get Token

- (void)testGetToken_WhenNoCache_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenNoCache_withExpectedToken:expectedToken];

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

- (void)testGetToken_WhenCachedTokenIsValid_Success {
  [self assertGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testGetTokenForcingRefresh_WhenCachedTokenIsValid_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid_withExpectedToken:
                expectedToken];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:YES
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

- (void)testGetToken_WhenCachedTokenExpired_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenCachedTokenExpired_withExpectedToken:expectedToken];

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
  NSError *serverError = [FIRAppCheckErrorUtil APIErrorWithNetworkError:[self internalError]];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenError_withError:serverError andToken:nil];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [expectations.lastObject fulfill];
                 XCTAssertNil(token);
                 XCTAssertNotNil(error);
                 XCTAssertEqualObjects(error, serverError);
                 XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)testGetToken_KeychainError {
  // 1. Expect token to be requested from storage.
  NSError *keychainError = [FIRAppCheckErrorUtil keychainErrorWithError:[self internalError]];
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:keychainError]);

  // 2. Expect token requested from app check provider.
  FIRAppCheckToken *expectedToken = [self validToken];
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:expectedToken])
      .andReturn([FBLPromise resolvedWith:keychainError]);

  // 4. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""
                                                                                   isInverted:YES];

  // 5. Request token and verify result.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [getTokenExpectation fulfill];
                 XCTAssertNil(token);
                 XCTAssertNotNil(error);
                 XCTAssertEqualObjects(error, keychainError);
                 XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  [self verifyAllMocks];
}

- (void)testGetToken_UnsupportedError {
  // 1. Create expected error and configure expectations.
  NSError *providerError =
      [FIRAppCheckErrorUtil unsupportedAttestationProvider:@"AppAttestProvider"];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenError_withError:providerError andToken:nil];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [expectations.lastObject fulfill];
                 XCTAssertNil(token);
                 XCTAssertNotNil(error);
                 XCTAssertEqualObjects(error, providerError);
                 XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

#pragma mark - FIRAppCheckInterop Get Token

- (void)testInteropGetToken_WhenNoCache_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenNoCache_withExpectedToken:expectedToken];

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

- (void)testInteropGetToken_WhenCachedTokenIsValid_Success {
  [self assertInteropGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testInteropGetTokenForcingRefresh_WhenCachedTokenIsValid_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];
  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid_withExpectedToken:
                expectedToken];

  // 2. Request token and verify result.
  [self.appCheck getTokenForcingRefresh:YES
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

- (void)testInteropGetToken_WhenCachedTokenExpired_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenCachedTokenExpired_withExpectedToken:expectedToken];

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

- (void)testInteropGetToken_AppCheckProviderError {
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

#pragma mark - Token refresher

- (void)testTokenRefreshTriggeredAndRefreshSuccess {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from app check provider.
  NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:10000];
  FIRAppCheckToken *tokenToReturn = [[FIRAppCheckToken alloc] initWithToken:@"valid"
                                                             expirationDate:expirationDate];
  id completionArg = [OCMArg invokeBlockWithArgs:tokenToReturn, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:tokenToReturn])
      .andReturn([FBLPromise resolvedWith:tokenToReturn]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:tokenToReturn.token];

  // 5. Trigger refresh and expect the result.
  if (self.tokenRefreshHandler == nil) {
    XCTFail(@"`tokenRefreshHandler` must be not `nil`.");
    return;
  }

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completion"];
  self.tokenRefreshHandler(^(FIRAppCheckTokenRefreshResult *refreshResult) {
    [completionExpectation fulfill];
    XCTAssertEqualObjects(refreshResult.tokenExpirationDate, expirationDate);
    XCTAssertEqual(refreshResult.status, FIRAppCheckTokenRefreshStatusSuccess);
  });

  [self waitForExpectations:@[ notificationExpectation, completionExpectation ] timeout:0.5];
  [self verifyAllMocks];
}

- (void)testTokenRefreshTriggeredAndRefreshError {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from app check provider.
  NSError *providerError = [self internalError];
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], providerError, nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 4. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""
                                                                                   isInverted:YES];

  // 5. Trigger refresh and expect the result.
  if (self.tokenRefreshHandler == nil) {
    XCTFail(@"`tokenRefreshHandler` must be not `nil`.");
    return;
  }

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completion"];
  self.tokenRefreshHandler(^(FIRAppCheckTokenRefreshResult *refreshResult) {
    [completionExpectation fulfill];
    XCTAssertEqual(refreshResult.status, FIRAppCheckTokenRefreshStatusFailure);
    XCTAssertNil(refreshResult.tokenExpirationDate);
    XCTAssertNil(refreshResult.tokenReceivedAtDate);
  });

  [self waitForExpectations:@[ notificationExpectation, completionExpectation ] timeout:0.5];
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

#pragma mark - Merging multiple get token requests

- (void)testGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested and stored.
  NSArray * /*[expectedToken, storeTokenPromise]*/ expectedTokenAndPromise =
      [self expectTokenRequestFromAppCheckProvider];
  FIRAppCheckToken *expectedToken = expectedTokenAndPromise.firstObject;
  FBLPromise *storeTokenPromise = expectedTokenAndPromise.lastObject;

  // 2. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 3. Request token several times.
  NSInteger getTokenCallsCount = 10;
  NSMutableArray *getTokenCompletionExpectations =
      [NSMutableArray arrayWithCapacity:getTokenCallsCount];

  for (NSInteger i = 0; i < getTokenCallsCount; i++) {
    // 3.1. Expect a completion to be called for each method call.
    XCTestExpectation *getTokenExpectation =
        [self expectationWithDescription:[NSString stringWithFormat:@"getToken%@", @(i)]];
    [getTokenCompletionExpectations addObject:getTokenExpectation];

    // 3.2. Request token and verify result.
    [self.appCheck
        tokenForcingRefresh:NO
                 completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                   [getTokenExpectation fulfill];
                   XCTAssertNotNil(token);
                   XCTAssertEqualObjects(token.token, expectedToken.token);
                   XCTAssertNil(error);
                 }];
  }

  // 3.3. Fulfill the pending promise to finish the get token operation.
  [storeTokenPromise fulfill:expectedToken];

  // 4. Wait for expectations and validate mocks.
  NSArray *expectations =
      [getTokenCompletionExpectations arrayByAddingObject:notificationExpectation];
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];

  // 5. Check a get token call after.
  [self assertGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested and stored.
  NSArray * /*[expectedToken, storeTokenPromise]*/ expectedTokenAndPromise =
      [self expectTokenRequestFromAppCheckProvider];
  FIRAppCheckToken *expectedToken = expectedTokenAndPromise.firstObject;
  FBLPromise *storeTokenPromise = expectedTokenAndPromise.lastObject;

  // 1.1. Create an expected error to be rejected with later.
  NSError *storageError = [NSError errorWithDomain:self.name code:0 userInfo:nil];

  // 2. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token isInverted:YES];

  // 3. Request token several times.
  NSInteger getTokenCallsCount = 10;
  NSMutableArray *getTokenCompletionExpectations =
      [NSMutableArray arrayWithCapacity:getTokenCallsCount];

  for (NSInteger i = 0; i < getTokenCallsCount; i++) {
    // 3.1. Expect a completion to be called for each method call.
    XCTestExpectation *getTokenExpectation =
        [self expectationWithDescription:[NSString stringWithFormat:@"getToken%@", @(i)]];
    [getTokenCompletionExpectations addObject:getTokenExpectation];

    // 3.2. Request token and verify result.
    [self.appCheck
        tokenForcingRefresh:NO
                 completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                   [getTokenExpectation fulfill];
                   XCTAssertNil(token);
                   XCTAssertNotNil(error);
                   XCTAssertNotEqualObjects(error, storageError);
                   XCTAssertEqualObjects(error.domain, FIRAppCheckErrorDomain);
                   XCTAssertEqualObjects(error.userInfo[NSUnderlyingErrorKey], storageError);
                 }];
  }

  // 3.3. Reject the pending promise to finish the get token operation.
  [storeTokenPromise reject:storageError];

  // 4. Wait for expectations and validate mocks.
  NSArray *expectations =
      [getTokenCompletionExpectations arrayByAddingObject:notificationExpectation];
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];

  // 5. Check a get token call after.
  [self assertGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testInteropGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested and stored.
  NSArray * /*[expectedToken, storeTokenPromise]*/ expectedTokenAndPromise =
      [self expectTokenRequestFromAppCheckProvider];
  FIRAppCheckToken *expectedToken = expectedTokenAndPromise.firstObject;
  FBLPromise *storeTokenPromise = expectedTokenAndPromise.lastObject;

  // 2. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 3. Request token several times.
  NSInteger getTokenCallsCount = 10;
  NSMutableArray *getTokenCompletionExpectations =
      [NSMutableArray arrayWithCapacity:getTokenCallsCount];

  for (NSInteger i = 0; i < getTokenCallsCount; i++) {
    // 3.1. Expect a completion to be called for each method call.
    XCTestExpectation *getTokenExpectation =
        [self expectationWithDescription:[NSString stringWithFormat:@"getToken%@", @(i)]];
    [getTokenCompletionExpectations addObject:getTokenExpectation];

    // 3.2. Request token and verify result.
    [self.appCheck getTokenForcingRefresh:NO
                               completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                                 [getTokenExpectation fulfill];
                                 XCTAssertNotNil(tokenResult);
                                 XCTAssertEqualObjects(tokenResult.token, expectedToken.token);
                                 XCTAssertNil(tokenResult.error);
                               }];
  }

  // 3.3. Fulfill the pending promise to finish the get token operation.
  [storeTokenPromise fulfill:expectedToken];

  // 4. Wait for expectations and validate mocks.
  NSArray *expectations =
      [getTokenCompletionExpectations arrayByAddingObject:notificationExpectation];
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];

  // 5. Check a get token call after.
  [self assertInteropGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testInteropGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested and stored.
  NSArray * /*[expectedToken, storeTokenPromise]*/ expectedTokenAndPromise =
      [self expectTokenRequestFromAppCheckProvider];
  FIRAppCheckToken *expectedToken = expectedTokenAndPromise.firstObject;
  FBLPromise *storeTokenPromise = expectedTokenAndPromise.lastObject;

  // 1.1. Create an expected error to be reject the store token promise with later.
  NSError *storageError = [NSError errorWithDomain:self.name code:0 userInfo:nil];

  // 2. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token isInverted:YES];

  // 3. Request token several times.
  NSInteger getTokenCallsCount = 10;
  NSMutableArray *getTokenCompletionExpectations =
      [NSMutableArray arrayWithCapacity:getTokenCallsCount];

  for (NSInteger i = 0; i < getTokenCallsCount; i++) {
    // 3.1. Expect a completion to be called for each method call.
    XCTestExpectation *getTokenExpectation =
        [self expectationWithDescription:[NSString stringWithFormat:@"getToken%@", @(i)]];
    [getTokenCompletionExpectations addObject:getTokenExpectation];

    // 3.2. Request token and verify result.
    [self.appCheck getTokenForcingRefresh:NO
                               completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                                 [getTokenExpectation fulfill];
                                 XCTAssertNotNil(tokenResult);
                                 XCTAssertEqualObjects(tokenResult.error, storageError);
                                 XCTAssertEqualObjects(tokenResult.token, kDummyToken);
                               }];
  }

  // 3.3. Reject the pending promise to finish the get token operation.
  [storeTokenPromise reject:storageError];

  // 4. Wait for expectations and validate mocks.
  NSArray *expectations =
      [getTokenCompletionExpectations arrayByAddingObject:notificationExpectation];
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];

  // 5. Check a get token call after.
  [self assertInteropGetToken_WhenCachedTokenIsValid_Success];
}

#pragma mark - Helpers

- (NSError *)internalError {
  return [NSError errorWithDomain:@"com.internal.error" code:-1 userInfo:nil];
}

- (FIRAppCheckToken *)validToken {
  return [[FIRAppCheckToken alloc] initWithToken:[NSUUID UUID].UUIDString
                                  expirationDate:[NSDate distantFuture]];
}

- (FIRAppCheckToken *)soonExpiringToken {
  NSDate *soonExpiringTokenDate = [NSDate dateWithTimeIntervalSinceNow:4.5 * 60];
  return [[FIRAppCheckToken alloc] initWithToken:@"valid" expirationDate:soonExpiringTokenDate];
}

- (void)stubSetTokenRefreshHandler {
  id arg = [OCMArg checkWithBlock:^BOOL(id handler) {
    self.tokenRefreshHandler = handler;
    return YES;
  }];
  OCMExpect([self.mockTokenRefresher setTokenRefreshHandler:arg]);
}

- (XCTestExpectation *)tokenUpdateNotificationWithExpectedToken:(NSString *)expectedToken {
  return [self tokenUpdateNotificationWithExpectedToken:expectedToken isInverted:NO];
}

- (XCTestExpectation *)tokenUpdateNotificationWithExpectedToken:(NSString *)expectedToken
                                                     isInverted:(BOOL)isInverted {
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
  expectation.inverted = isInverted;
  return expectation;
}

- (void)assertGetToken_WhenCachedTokenIsValid_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *cachedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 [expectations.lastObject fulfill];
                 XCTAssertNotNil(token);
                 XCTAssertEqualObjects(token.token, cachedToken.token);
                 XCTAssertNil(error);
               }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)assertInteropGetToken_WhenCachedTokenIsValid_Success {
  // 1. Create expected token and configure expectations.
  FIRAppCheckToken *cachedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [expectations.lastObject fulfill];
                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, cachedToken.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (NSArray<XCTestExpectation *> *)configuredExpectations_GetTokenWhenNoCache_withExpectedToken:
    (FIRAppCheckToken *)expectedToken {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from app check provider.
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:expectedToken])
      .andReturn([FBLPromise resolvedWith:expectedToken]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *tokenNotificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ tokenNotificationExpectation, getTokenExpectation ];
}

- (NSArray<XCTestExpectation *> *)
    configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:
        (FIRAppCheckToken *)expectedToken {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:expectedToken]);

  // 2. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 3. Don't expect token update notification to be sent.
  XCTestExpectation *tokenNotificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:@"" isInverted:YES];

  // 4. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ tokenNotificationExpectation, getTokenExpectation ];
}

- (NSArray<XCTestExpectation *> *)
    configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid_withExpectedToken:
        (FIRAppCheckToken *)expectedToken {
  // 1. Don't expect token to be requested from storage.
  OCMReject([self.mockStorage getToken]);

  // 2. Expect token requested from app check provider.
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:expectedToken])
      .andReturn([FBLPromise resolvedWith:expectedToken]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ notificationExpectation, getTokenExpectation ];
}

- (NSArray<XCTestExpectation *> *)
    configuredExpectations_GetTokenWhenCachedTokenExpired_withExpectedToken:
        (FIRAppCheckToken *)expectedToken {
  // 1. Expect token to be requested from storage.
  FIRAppCheckToken *cachedToken = [[FIRAppCheckToken alloc] initWithToken:@"expired"
                                                           expirationDate:[NSDate date]];
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:cachedToken]);

  // 2. Expect token requested from app check provider.
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:expectedToken])
      .andReturn([FBLPromise resolvedWith:expectedToken]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ notificationExpectation, getTokenExpectation ];
}

- (NSArray<XCTestExpectation *> *)
    configuredExpectations_GetTokenWhenError_withError:(NSError *_Nonnull)error
                                              andToken:(FIRAppCheckToken *_Nullable)token {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:token]);

  // 2. Expect token requested from app check provider.
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], error, nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""
                                                                                   isInverted:YES];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ notificationExpectation, getTokenExpectation ];
}

- (NSArray *)expectTokenRequestFromAppCheckProvider {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from app check provider.
  FIRAppCheckToken *expectedToken = [self validToken];
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  // 3.1. Create a pending promise to resolve later.
  FBLPromise<FIRAppCheckToken *> *storeTokenPromise = [FBLPromise pendingPromise];
  // 3.2. Stub storage set token method.
  OCMExpect([self.mockStorage setToken:expectedToken]).andReturn(storeTokenPromise);

  return @[ expectedToken, storeTokenPromise ];
}

- (void)verifyAllMocks {
  OCMVerifyAll(self.mockAppCheckProvider);
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockSettings);
  OCMVerifyAll(self.mockTokenRefresher);
}

@end
