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

#import "AppCheck/Sources/Public/AppCheck/GACAppCheck.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckErrors.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckProvider.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckSettings.h"

#import "AppCheck/Sources/Core/Errors/GACAppCheckErrorUtil.h"
#import "AppCheck/Sources/Core/Storage/GACAppCheckStorage.h"
#import "AppCheck/Sources/Core/TokenRefresh/GACAppCheckTokenRefreshResult.h"
#import "AppCheck/Sources/Core/TokenRefresh/GACAppCheckTokenRefresher.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckToken.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

// The FAC token value returned when an error occurs.
static NSString *const kDummyToken = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

static NSString *const kResourceName = @"projects/test_project_id/apps/test_app_id";
static NSString *const kAppName = @"GACAppCheckTests";
static NSString *const kAppGroupID = @"app_group_id";

@interface GACAppCheck (Tests) <GACAppCheckInterop>

- (instancetype)initWithInstanceName:(NSString *)instanceName
                    appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
                             storage:(id<GACAppCheckStorageProtocol>)storage
                      tokenRefresher:(id<GACAppCheckTokenRefresherProtocol>)tokenRefresher
                  notificationCenter:(NSNotificationCenter *)notificationCenter
                            settings:(id<GACAppCheckSettingsProtocol>)settings;

@end

@interface GACAppCheckTests : XCTestCase

@property(nonatomic) OCMockObject<GACAppCheckStorageProtocol> *mockStorage;
@property(nonatomic) OCMockObject<GACAppCheckProvider> *mockAppCheckProvider;
@property(nonatomic) OCMockObject<GACAppCheckTokenRefresherProtocol> *mockTokenRefresher;
@property(nonatomic) OCMockObject<GACAppCheckSettingsProtocol> *mockSettings;
@property(nonatomic) NSNotificationCenter *notificationCenter;
@property(nonatomic) GACAppCheck<GACAppCheckInterop> *appCheck;

@property(nonatomic, copy, nullable) GACAppCheckTokenRefreshBlock tokenRefreshHandler;

@end

@implementation GACAppCheckTests

- (void)setUp {
  [super setUp];

  self.mockStorage = OCMStrictProtocolMock(@protocol(GACAppCheckStorageProtocol));
  self.mockAppCheckProvider = OCMStrictProtocolMock(@protocol(GACAppCheckProvider));
  self.mockTokenRefresher = OCMStrictProtocolMock(@protocol(GACAppCheckTokenRefresherProtocol));
  self.mockSettings = OCMProtocolMock(@protocol(GACAppCheckSettingsProtocol));
  self.notificationCenter = [[NSNotificationCenter alloc] init];

  [self stubSetTokenRefreshHandler];

  self.appCheck = [[GACAppCheck alloc] initWithInstanceName:kAppName
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

#pragma mark - Public Init

- (void)testAppCheckInit {
  NSString *tokenKey =
      [NSString stringWithFormat:@"app_check_token.%@.%@", kAppName, kResourceName];

  // 1. Stub GACAppCheckTokenRefresher and validate usage.
  id mockTokenRefresher = OCMClassMock([GACAppCheckTokenRefresher class]);
  OCMExpect([mockTokenRefresher alloc]).andReturn(mockTokenRefresher);

  id refresherDateValidator =
      [OCMArg checkWithBlock:^BOOL(GACAppCheckTokenRefreshResult *refreshResult) {
        XCTAssertEqual(refreshResult.status, GACAppCheckTokenRefreshStatusNever);
        XCTAssertEqual(refreshResult.tokenExpirationDate, nil);
        XCTAssertEqual(refreshResult.tokenReceivedAtDate, nil);
        return YES;
      }];

  id settingsValidator = [OCMArg checkWithBlock:^BOOL(id obj) {
    XCTAssert([obj conformsToProtocol:@protocol(GACAppCheckSettingsProtocol)]);
    return YES;
  }];

  OCMExpect([mockTokenRefresher initWithRefreshResult:refresherDateValidator
                                             settings:settingsValidator])
      .andReturn(mockTokenRefresher);
  OCMExpect([mockTokenRefresher setTokenRefreshHandler:[OCMArg any]]);

  // 2. Stub GACAppCheckStorage and validate usage.
  id mockStorage = OCMStrictClassMock([GACAppCheckStorage class]);
  OCMExpect([mockStorage alloc]).andReturn(mockStorage);
  OCMExpect([mockStorage initWithTokenKey:tokenKey accessGroup:kAppGroupID]).andReturn(mockStorage);

  // 3. Stub attestation provider.
  OCMockObject<GACAppCheckProvider> *mockProvider =
      OCMStrictProtocolMock(@protocol(GACAppCheckProvider));

  // 4. Stub GACAppCheckSettingsProtocol.
  OCMockObject<GACAppCheckSettingsProtocol> *mockSettings =
      OCMStrictProtocolMock(@protocol(GACAppCheckSettingsProtocol));

  // 5. Call init.
  GACAppCheck *appCheck = [[GACAppCheck alloc] initWithInstanceName:kAppName
                                                   appCheckProvider:mockProvider
                                                           settings:mockSettings
                                                       resourceName:kResourceName
                                                keychainAccessGroup:kAppGroupID];
  XCTAssert([appCheck isKindOfClass:[GACAppCheck class]]);

  // 6. Verify mocks.
  OCMVerifyAll(mockTokenRefresher);
  OCMVerifyAll(mockStorage);
  OCMVerifyAll(mockProvider);
  OCMVerifyAll(mockSettings);

  // 7. Stop mocking real class mocks.
  [mockTokenRefresher stopMocking];
  mockTokenRefresher = nil;
  [mockStorage stopMocking];
  mockStorage = nil;
}

#pragma mark - Public Get Token

- (void)testGetToken_WhenCachedTokenIsValid_Success {
  [self assertGetToken_WhenCachedTokenIsValid_Success];
}

#pragma mark - GACAppCheckInterop Get Token

- (void)testInteropGetToken_WhenNoCache_Success {
  // 1. Create expected token and configure expectations.
  GACAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenNoCache_withExpectedToken:expectedToken];

  // 2. Request token and verify result.
  [self.appCheck
      getTokenForcingRefresh:NO
                  completion:^(id<GACAppCheckTokenInterop> _Nullable token, NSError *error) {
                    [expectations.lastObject fulfill];
                    XCTAssertNotNil(token);
                    XCTAssertEqualObjects(token.token, expectedToken.token);
                    XCTAssertNil(error);
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
  GACAppCheckToken *expectedToken = [self validToken];
  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenForcingRefreshWhenCacheIsValid_withExpectedToken:
                expectedToken];

  // 2. Request token and verify result.
  [self.appCheck
      getTokenForcingRefresh:YES
                  completion:^(id<GACAppCheckTokenInterop> _Nullable token, NSError *error) {
                    [expectations.lastObject fulfill];
                    XCTAssertNotNil(token);
                    XCTAssertEqualObjects(token.token, expectedToken.token);
                    XCTAssertNil(error);
                  }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)testInteropGetToken_WhenCachedTokenExpired_Success {
  // 1. Create expected token and configure expectations.
  GACAppCheckToken *expectedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenCachedTokenExpired_withExpectedToken:expectedToken];

  // 2. Request token and verify result.
  [self.appCheck
      getTokenForcingRefresh:NO
                  completion:^(id<GACAppCheckTokenInterop> _Nullable token, NSError *error) {
                    [expectations.lastObject fulfill];
                    XCTAssertNotNil(token);
                    XCTAssertEqualObjects(token.token, expectedToken.token);
                    XCTAssertNil(error);
                  }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (void)testInteropGetToken_AppCheckProviderError {
  // 1. Create expected tokens and errors and configure expectations.
  GACAppCheckToken *cachedToken = [self soonExpiringToken];
  NSError *providerError = [NSError errorWithDomain:@"GACAppCheckTests" code:-1 userInfo:nil];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenError_withError:providerError andToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck
      getTokenForcingRefresh:NO
                  completion:^(id<GACAppCheckTokenInterop> _Nullable token, NSError *error) {
                    [expectations.lastObject fulfill];
                    XCTAssertNil(token);
                    XCTAssertEqualObjects(error, providerError);
                    // Interop API does not wrap errors in public domain.
                    XCTAssertNotEqualObjects(error.domain, GACAppCheckErrorDomain);
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
  GACAppCheckToken *tokenToReturn = [[GACAppCheckToken alloc] initWithToken:@"valid"
                                                             expirationDate:expirationDate];
  id completionArg = [OCMArg invokeBlockWithArgs:tokenToReturn, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:tokenToReturn])
      .andReturn([FBLPromise resolvedWith:tokenToReturn]);
  OCMExpect([self.mockTokenRefresher updateWithRefreshResult:[OCMArg any]]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:tokenToReturn.token];

  // 5. Trigger refresh and expect the result.
  if (self.tokenRefreshHandler == nil) {
    XCTFail(@"`tokenRefreshHandler` must be not `nil`.");
    return;
  }

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completion"];
  self.tokenRefreshHandler(^(GACAppCheckTokenRefreshResult *refreshResult) {
    [completionExpectation fulfill];
    XCTAssertEqualObjects(refreshResult.tokenExpirationDate, expirationDate);
    XCTAssertEqual(refreshResult.status, GACAppCheckTokenRefreshStatusSuccess);
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
  self.tokenRefreshHandler(^(GACAppCheckTokenRefreshResult *refreshResult) {
    [completionExpectation fulfill];
    XCTAssertEqual(refreshResult.status, GACAppCheckTokenRefreshStatusFailure);
    XCTAssertNil(refreshResult.tokenExpirationDate);
    XCTAssertNil(refreshResult.tokenReceivedAtDate);
  });

  [self waitForExpectations:@[ notificationExpectation, completionExpectation ] timeout:0.5];
  [self verifyAllMocks];
}

- (void)testLimitedUseTokenWithSuccess {
  // 1. Don't expect token to be requested from storage.
  OCMReject([self.mockStorage getToken]);

  // 2. Expect token requested from app check provider.
  GACAppCheckToken *expectedToken = [self validToken];
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Don't expect token requested from storage.
  OCMReject([self.mockStorage setToken:expectedToken]);

  // 4. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""
                                                                                   isInverted:YES];
  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  [self.appCheck getLimitedUseTokenWithCompletion:^(id<GACAppCheckTokenInterop> _Nullable token,
                                                    NSError *_Nullable error) {
    [getTokenExpectation fulfill];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.token, expectedToken.token);
    XCTAssertNil(error);
  }];
  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  [self verifyAllMocks];
}

- (void)testLimitedUseToken_WhenTokenGenerationErrors {
  // 1. Don't expect token to be requested from storage.
  OCMReject([self.mockStorage getToken]);

  // 2. Expect error when requesting token from app check provider.
  NSError *providerError = [GACAppCheckErrorUtil keychainErrorWithError:[self internalError]];
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], providerError, nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 4. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""
                                                                                   isInverted:YES];
  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  [self.appCheck getLimitedUseTokenWithCompletion:^(id<GACAppCheckTokenInterop> _Nullable token,
                                                    NSError *_Nullable error) {
    [getTokenExpectation fulfill];
    XCTAssertNotNil(error);
    XCTAssertNil(token.token);
    XCTAssertEqualObjects(error, providerError);
    XCTAssertEqualObjects(error.domain, GACAppCheckErrorDomain);
  }];

  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  [self verifyAllMocks];
}

#pragma mark - Token update notifications

- (void)testTokenUpdateNotificationKeys {
  XCTAssertEqualObjects([self.appCheck tokenDidChangeNotificationName],
                        @"GACAppCheckAppCheckTokenDidChangeNotification");
  XCTAssertEqualObjects([self.appCheck notificationInstanceNameKey],
                        @"GACAppCheckInstanceNameNotificationKey");
  XCTAssertEqualObjects([self.appCheck notificationTokenKey], @"GACAppCheckTokenNotificationKey");
}

#pragma mark - Merging multiple get token requests

- (void)testInteropGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested and stored.
  NSArray * /*[expectedToken, storeTokenPromise]*/ expectedTokenAndPromise =
      [self expectTokenRequestFromAppCheckProvider];
  GACAppCheckToken *expectedToken = expectedTokenAndPromise.firstObject;
  FBLPromise *storeTokenPromise = expectedTokenAndPromise.lastObject;
  OCMExpect([self.mockTokenRefresher updateWithRefreshResult:[OCMArg any]]);

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
        getTokenForcingRefresh:NO
                    completion:^(id<GACAppCheckTokenInterop> _Nullable token, NSError *error) {
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
  [self assertInteropGetToken_WhenCachedTokenIsValid_Success];
}

- (void)testInteropGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOperation {
  // 1. Expect a token to be requested and stored.
  NSArray * /*[expectedToken, storeTokenPromise]*/ expectedTokenAndPromise =
      [self expectTokenRequestFromAppCheckProvider];
  GACAppCheckToken *expectedToken = expectedTokenAndPromise.firstObject;
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
    [self.appCheck
        getTokenForcingRefresh:NO
                    completion:^(id<GACAppCheckTokenInterop> _Nullable token, NSError *error) {
                      [getTokenExpectation fulfill];
                      XCTAssertNil(token);
                      XCTAssertEqualObjects(error, storageError);
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

- (GACAppCheckToken *)validToken {
  return [[GACAppCheckToken alloc] initWithToken:[NSUUID UUID].UUIDString
                                  expirationDate:[NSDate distantFuture]];
}

- (GACAppCheckToken *)soonExpiringToken {
  NSDate *soonExpiringTokenDate = [NSDate dateWithTimeIntervalSinceNow:4.5 * 60];
  return [[GACAppCheckToken alloc] initWithToken:@"valid" expirationDate:soonExpiringTokenDate];
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
  XCTestExpectation *expectation = [self
      expectationForNotification:[self.appCheck tokenDidChangeNotificationName]
                          object:nil
              notificationCenter:self.notificationCenter
                         handler:^BOOL(NSNotification *_Nonnull notification) {
                           XCTAssertEqualObjects(
                               notification.userInfo[[self.appCheck notificationInstanceNameKey]],
                               kAppName);
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
  GACAppCheckToken *cachedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<GACAppCheckTokenInterop> _Nullable token,
                                          NSError *_Nullable error) {
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
  GACAppCheckToken *cachedToken = [self validToken];

  NSArray * /*[tokenNotification, getToken]*/ expectations =
      [self configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:cachedToken];

  // 2. Request token and verify result.
  [self.appCheck
      getTokenForcingRefresh:NO
                  completion:^(id<GACAppCheckTokenInterop> _Nullable token, NSError *error) {
                    [expectations.lastObject fulfill];
                    XCTAssertNotNil(token);
                    XCTAssertEqualObjects(token.token, cachedToken.token);
                    XCTAssertNil(error);
                  }];

  // 3. Wait for expectations and validate mocks.
  [self waitForExpectations:expectations timeout:0.5];
  [self verifyAllMocks];
}

- (NSArray<XCTestExpectation *> *)configuredExpectations_GetTokenWhenNoCache_withExpectedToken:
    (GACAppCheckToken *)expectedToken {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from app check provider.
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:expectedToken])
      .andReturn([FBLPromise resolvedWith:expectedToken]);
  OCMExpect([self.mockTokenRefresher updateWithRefreshResult:[OCMArg any]]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *tokenNotificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ tokenNotificationExpectation, getTokenExpectation ];
}

- (NSArray<XCTestExpectation *> *)
    configuredExpectations_GetTokenWhenCacheTokenIsValid_withExpectedToken:
        (GACAppCheckToken *)expectedToken {
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
        (GACAppCheckToken *)expectedToken {
  // 1. Don't expect token to be requested from storage.
  OCMReject([self.mockStorage getToken]);

  // 2. Expect token requested from app check provider.
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:expectedToken])
      .andReturn([FBLPromise resolvedWith:expectedToken]);
  OCMExpect([self.mockTokenRefresher updateWithRefreshResult:[OCMArg any]]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ notificationExpectation, getTokenExpectation ];
}

- (NSArray<XCTestExpectation *> *)
    configuredExpectations_GetTokenWhenCachedTokenExpired_withExpectedToken:
        (GACAppCheckToken *)expectedToken {
  // 1. Expect token to be requested from storage.
  GACAppCheckToken *cachedToken = [[GACAppCheckToken alloc] initWithToken:@"expired"
                                                           expirationDate:[NSDate date]];
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:cachedToken]);

  // 2. Expect token requested from app check provider.
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:expectedToken])
      .andReturn([FBLPromise resolvedWith:expectedToken]);
  OCMExpect([self.mockTokenRefresher updateWithRefreshResult:[OCMArg any]]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:expectedToken.token];

  // 5. Expect token request to be completed.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];

  return @[ notificationExpectation, getTokenExpectation ];
}

- (NSArray<XCTestExpectation *> *)
    configuredExpectations_GetTokenWhenError_withError:(NSError *_Nonnull)error
                                              andToken:(GACAppCheckToken *_Nullable)token {
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
  GACAppCheckToken *expectedToken = [self validToken];
  id completionArg = [OCMArg invokeBlockWithArgs:expectedToken, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  // 3.1. Create a pending promise to resolve later.
  FBLPromise<GACAppCheckToken *> *storeTokenPromise = [FBLPromise pendingPromise];
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
