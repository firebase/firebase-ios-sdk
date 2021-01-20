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

@interface FIRAppCheck (Tests) <FIRAppCheckInterop>
- (instancetype)initWithAppName:(NSString *)appName
               appCheckProvider:(id<FIRAppCheckProvider>)appCheckProvider
                        storage:(id<FIRAppCheckStorageProtocol>)storage
                 tokenRefresher:(id<FIRAppCheckTokenRefresherProtocol>)tokenRefresher;
@end

@interface FIRAppCheckTests : XCTestCase

@property(nonatomic) NSString *appName;
@property(nonatomic) OCMockObject<FIRAppCheckStorageProtocol> *mockStorage;
@property(nonatomic) OCMockObject<FIRAppCheckProvider> *mockAppCheckProvider;
@property(nonatomic) OCMockObject<FIRAppCheckTokenRefresherProtocol> *mockTokenRefresher;
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

  [self stubSetTokenRefreshHandler];

  self.appCheck = [[FIRAppCheck alloc] initWithAppName:self.appName
                                      appCheckProvider:self.mockAppCheckProvider
                                               storage:self.mockStorage
                                        tokenRefresher:self.mockTokenRefresher];
}

- (void)tearDown {
  self.appCheck = nil;
  [self.mockAppCheckProvider stopMocking];
  self.mockAppCheckProvider = nil;
  [self.mockStorage stopMocking];
  self.mockStorage = nil;

  [super tearDown];
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

  // 4. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [getTokenExpectation fulfill];

                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, tokenToReturn.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 5. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
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

  // 3. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [getTokenExpectation fulfill];
                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, cachedToken.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 4. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
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

  // 4. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck getTokenForcingRefresh:YES
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [getTokenExpectation fulfill];

                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, tokenToReturn.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 5. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
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

  // 4. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [getTokenExpectation fulfill];
                               XCTAssertNotNil(tokenResult);
                               XCTAssertEqualObjects(tokenResult.token, tokenToReturn.token);
                               XCTAssertNil(tokenResult.error);
                             }];

  // 5. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
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

  // 4. Request token.
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

  // 5. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
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

  // 4. Trigger refresh and expect the result.
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

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
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

  // 4. Trigger refresh and expect the result.
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

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAppCheckProvider);
}

#pragma mark - Helpers

- (void)stubSetTokenRefreshHandler {
  id arg = [OCMArg checkWithBlock:^BOOL(id handler) {
    self.tokenRefreshHandler = handler;
    return YES;
  }];
  OCMExpect([self.mockTokenRefresher setTokenRefreshHandler:arg]);
}

@end
