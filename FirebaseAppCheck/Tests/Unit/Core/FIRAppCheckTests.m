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

// TODO: Consider using manually implemented fakes instead of OCMock
// (see also go/srl-dev/why-fakes#no-ocmock)
#import "OCMock.h"

#import "FBLPromise+Testing.h"

#import <FirebaseAppCheck/FirebaseAppCheck.h>

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"

#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckTokenResultInterop.h"

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckTokenResult.h"
#import "FirebaseAppCheck/Sources/Core/Storage/FIRAppCheckStorage.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefresher.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

@interface FIRAppCheck (Tests) <FIRAppCheckInterop>
- (instancetype)initWithAppName:(NSString *)appName
               appCheckProvider:(id<FIRAppCheckProvider>)appCheckProvider
                        storage:(id<FIRAppCheckStorageProtocol>)storage
                 tokenRefresher:(id<FIRAppCheckTokenRefresherProtocol>)tokenRefresher
             notificationCenter:(NSNotificationCenter *)notificationCenter;

- (nullable instancetype)initWithApp:(FIRApp *)app;
@end

@interface FIRAppCheckTests : XCTestCase

@property(nonatomic) NSString *appName;
@property(nonatomic) OCMockObject<FIRAppCheckStorageProtocol> *mockStorage;
@property(nonatomic) OCMockObject<FIRAppCheckProvider> *mockAppCheckProvider;
@property(nonatomic) OCMockObject<FIRAppCheckTokenRefresherProtocol> *mockTokenRefresher;
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
  self.notificationCenter = [[NSNotificationCenter alloc] init];

  [self stubSetTokenRefreshHandler];

  self.appCheck = [[FIRAppCheck alloc] initWithAppName:self.appName
                                      appCheckProvider:self.mockAppCheckProvider
                                               storage:self.mockStorage
                                        tokenRefresher:self.mockTokenRefresher
                                    notificationCenter:self.notificationCenter];
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
  id refresherDateValidator = [OCMArg checkWithBlock:^BOOL(NSDate *tokenExpirationDate) {
    NSTimeInterval accuracy = 1;
    XCTAssertLessThanOrEqual(ABS([tokenExpirationDate timeIntervalSinceNow]), accuracy);
    return YES;
  }];
  OCMExpect([mockTokenRefresher initWithTokenExpirationDate:refresherDateValidator
                                   tokenExpirationThreshold:5 * 60])
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

- (void)testGetToken_WhenNoCache_Success {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from app check provider.
  FIRAppCheckToken *tokenToReturn = [[FIRAppCheckToken alloc] initWithToken:@"valid"
                                                             expirationDate:[NSDate distantFuture]];
  id completionArg = [OCMArg invokeBlockWithArgs:tokenToReturn, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:tokenToReturn])
      .andReturn([FBLPromise resolvedWith:tokenToReturn]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:tokenToReturn.token];

  // 5. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [getTokenExpectation fulfill];

                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, tokenToReturn.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 6. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAppCheckProvider);
}

- (void)testGetToken_WhenCachedTokenIsValid_Success {
  FIRAppCheckToken *cachedToken = [[FIRAppCheckToken alloc] initWithToken:@"valid"
                                                           expirationDate:[NSDate distantFuture]];

  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:cachedToken]);

  // 2. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 3. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""];
  notificationExpectation.inverted = YES;

  // 4. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [getTokenExpectation fulfill];
                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, cachedToken.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 5. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAppCheckProvider);
}

- (void)testGetTokenForcingRefresh_WhenCachedTokenIsValid_Success {
  // 1. Don't expect token to be requested from storage.
  OCMReject([self.mockStorage getToken]);

  // 2. Expect token requested from app check provider.
  FIRAppCheckToken *tokenToReturn = [[FIRAppCheckToken alloc] initWithToken:@"valid"
                                                             expirationDate:[NSDate distantFuture]];
  id completionArg = [OCMArg invokeBlockWithArgs:tokenToReturn, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:tokenToReturn])
      .andReturn([FBLPromise resolvedWith:tokenToReturn]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:tokenToReturn.token];

  // 5. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck getTokenForcingRefresh:YES
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [getTokenExpectation fulfill];

                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, tokenToReturn.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 6. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAppCheckProvider);
}

- (void)testGetToken_WhenCachedTokenExpired_Success {
  FIRAppCheckToken *cachedToken = [[FIRAppCheckToken alloc] initWithToken:@"valid"
                                                           expirationDate:[NSDate date]];

  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:cachedToken]);

  // 2. Expect token requested from app check provider.
  FIRAppCheckToken *tokenToReturn = [[FIRAppCheckToken alloc] initWithToken:@"valid"
                                                             expirationDate:[NSDate distantFuture]];
  id completionArg = [OCMArg invokeBlockWithArgs:tokenToReturn, [NSNull null], nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:tokenToReturn])
      .andReturn([FBLPromise resolvedWith:tokenToReturn]);

  // 4. Expect token update notification to be sent.
  XCTestExpectation *notificationExpectation =
      [self tokenUpdateNotificationWithExpectedToken:tokenToReturn.token];

  // 5. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [getTokenExpectation fulfill];
                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, tokenToReturn.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 6. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAppCheckProvider);
}

- (void)testGetToken_AppCheckProviderError {
  NSDate *soonExpiringTokenDate = [NSDate dateWithTimeIntervalSinceNow:4.5 * 60];
  FIRAppCheckToken *cachedToken = [[FIRAppCheckToken alloc] initWithToken:@"valid"
                                                           expirationDate:soonExpiringTokenDate];

  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:cachedToken]);

  // 2. Expect token requested from app check provider.
  NSError *providerError = [NSError errorWithDomain:@"FIRAppCheckTests" code:-1 userInfo:nil];
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], providerError, nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 4. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""];
  notificationExpectation.inverted = YES;

  // 5. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck
      getTokenForcingRefresh:NO
                  completion:^(id<FIRAppCheckTokenResultInterop> result) {
                    [getTokenExpectation fulfill];

                    XCTAssertNotNil(result);
                    XCTAssertEqualObjects(result.token, @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==");

                    // TODO: Expect a public domain error to be returned - not the
                    // internal one.
                    XCTAssertEqualObjects(result.error, providerError);
                  }];

  // 6. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ notificationExpectation, getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAppCheckProvider);
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
  self.tokenRefreshHandler(^(BOOL success, NSDate *_Nullable tokenExpirationDate) {
    [completionExpectation fulfill];
    XCTAssertEqual(tokenExpirationDate, expirationDate);
    XCTAssertTrue(success);
  });

  [self waitForExpectations:@[ notificationExpectation, completionExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAppCheckProvider);
}

- (void)testTokenRefreshTriggeredAndRefreshError {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from app check provider.
  NSError *providerError = [NSError errorWithDomain:@"FIRAppCheckTests" code:-1 userInfo:nil];
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], providerError, nil];
  OCMExpect([self.mockAppCheckProvider getTokenWithCompletion:completionArg]);

  // 3. Don't expect token requested from app check provider.
  OCMReject([self.mockAppCheckProvider getTokenWithCompletion:[OCMArg any]]);

  // 4. Don't expect token update notification to be sent.
  XCTestExpectation *notificationExpectation = [self tokenUpdateNotificationWithExpectedToken:@""];
  notificationExpectation.inverted = YES;

  // 5. Trigger refresh and expect the result.
  if (self.tokenRefreshHandler == nil) {
    XCTFail(@"`tokenRefreshHandler` must be not `nil`.");
    return;
  }

  XCTestExpectation *completionExpectation = [self expectationWithDescription:@"completion"];
  self.tokenRefreshHandler(^(BOOL success, NSDate *_Nullable tokenExpirationDate) {
    [completionExpectation fulfill];
    XCTAssertNil(tokenExpirationDate);
    XCTAssertFalse(success);
  });

  [self waitForExpectations:@[ notificationExpectation, completionExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAppCheckProvider);
}

#pragma mark - Token update notifications

- (void)testTokenUpdateNotificationKeys {
  XCTAssertEqualObjects([self.appCheck tokenDidChangeNotificationName],
                        @"FIRAppCheckAppCheckTokenDidChangeNotification");
  XCTAssertEqualObjects([self.appCheck notificationAppNameKey],
                        @"FIRAppCheckAppNameNotificationKey");
  XCTAssertEqualObjects([self.appCheck notificationTokenKey], @"FIRAppCheckTokenNotificationKey");
}

#pragma mark - Helpers

- (void)stubSetTokenRefreshHandler {
  id arg = [OCMArg checkWithBlock:^BOOL(id handler) {
    self.tokenRefreshHandler = handler;
    return YES;
  }];
  OCMExpect([self.mockTokenRefresher setTokenRefreshHandler:arg]);
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
                                 return YES;
                               }];

  return expectation;
}

@end
