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
#import <OCMock/OCMock.h>

#import "FBLPromise+Testing.h"

#import <FirebaseAppAttestation/FirebaseAppAttestation.h>
#import <FirebaseAppAttestationInterop/FIRAppAttestationInterop.h>
#import <FirebaseAppAttestationInterop/FIRAppAttestationTokenInterop.h>

#import "FIRAppAttestStorage.h"
#import "FIRAppAttestationToken+Interop.h"

@interface FIRAppAttestation (Tests) <FIRAppAttestationInterop>
- (instancetype)initWithAppName:(NSString *)appName
            attestationProvider:(id<FIRAppAttestationProvider>)attestationProvider
                        storage:(id<FIRAppAttestStorageProtocol>)storage;
@end

@interface FIRAppAttestationTests : XCTestCase

@property(nonatomic) NSString *appName;
@property(nonatomic) OCMockObject<FIRAppAttestStorageProtocol> *mockStorage;
@property(nonatomic) OCMockObject<FIRAppAttestationProvider> *mockAttestationProvider;
@property(nonatomic) FIRAppAttestation<FIRAppAttestationInterop> *attestation;

@end

@implementation FIRAppAttestationTests

- (void)setUp {
  [super setUp];

  self.appName = @"FIRAppAttestationTests";
  self.mockStorage = OCMProtocolMock(@protocol(FIRAppAttestStorageProtocol));
  self.mockAttestationProvider = OCMProtocolMock(@protocol(FIRAppAttestationProvider));
  self.attestation = [[FIRAppAttestation alloc] initWithAppName:self.appName
                                            attestationProvider:self.mockAttestationProvider
                                                        storage:self.mockStorage];
}

- (void)tearDown {
  self.attestation = nil;
  [self.mockAttestationProvider stopMocking];
  self.mockAttestationProvider = nil;
  [self.mockStorage stopMocking];
  self.mockStorage = nil;

  [super tearDown];
}

- (void)testGetToken_WhenNoCache_Success {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from attestation provider.
  FIRAppAttestationToken *tokenToReturn =
      [[FIRAppAttestationToken alloc] initWithToken:@"valid" expirationDate:[NSDate distantFuture]];
  id completionArg = [OCMArg invokeBlockWithArgs:tokenToReturn, [NSNull null], nil];
  OCMExpect([self.mockAttestationProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:tokenToReturn])
      .andReturn([FBLPromise resolvedWith:tokenToReturn]);

  // 4. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.attestation getTokenWithCompletion:^(id<FIRAppAttestationTokenInterop> _Nullable token,
                                             NSError *_Nullable error) {
    [getTokenExpectation fulfill];

    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.token, tokenToReturn.token);
    XCTAssertEqualObjects(token.expirationDate, tokenToReturn.expirationDate);
  }];

  // 5. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAttestationProvider);
}

- (void)testGetToken_WhenChachedTokenIsValid_Success {
  FIRAppAttestationToken *cachedToken =
      [[FIRAppAttestationToken alloc] initWithToken:@"valid" expirationDate:[NSDate distantFuture]];

  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:cachedToken]);

  // 2. Don't expect token requested from attestation provider.
  OCMReject([self.mockAttestationProvider getTokenWithCompletion:[OCMArg any]]);

  // 3. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.attestation getTokenWithCompletion:^(id<FIRAppAttestationTokenInterop> _Nullable token,
                                             NSError *_Nullable error) {
    [getTokenExpectation fulfill];

    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.token, cachedToken.token);
    XCTAssertEqualObjects(token.expirationDate, cachedToken.expirationDate);
  }];

  // 4. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAttestationProvider);
}

- (void)testGetToken_WhenCachedTokenExpired_Success {
  FIRAppAttestationToken *cachedToken =
      [[FIRAppAttestationToken alloc] initWithToken:@"valid" expirationDate:[NSDate date]];

  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:cachedToken]);

  // 2. Expect token requested from attestation provider.
  FIRAppAttestationToken *tokenToReturn =
      [[FIRAppAttestationToken alloc] initWithToken:@"valid" expirationDate:[NSDate distantFuture]];
  id completionArg = [OCMArg invokeBlockWithArgs:tokenToReturn, [NSNull null], nil];
  OCMExpect([self.mockAttestationProvider getTokenWithCompletion:completionArg]);

  // 3. Expect new token to be stored.
  OCMExpect([self.mockStorage setToken:tokenToReturn])
      .andReturn([FBLPromise resolvedWith:tokenToReturn]);

  // 4. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.attestation getTokenWithCompletion:^(id<FIRAppAttestationTokenInterop> _Nullable token,
                                             NSError *_Nullable error) {
    [getTokenExpectation fulfill];

    XCTAssertNil(error);
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.token, tokenToReturn.token);
    XCTAssertEqualObjects(token.expirationDate, tokenToReturn.expirationDate);
  }];

  // 5. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAttestationProvider);
}

- (void)testGetToken_AttestationProviderError {
  // 1. Expect token to be requested from storage.
  OCMExpect([self.mockStorage getToken]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect token requested from attestation provider.
  NSError *providerError = [NSError errorWithDomain:@"FIRAppAttestationTests" code:-1 userInfo:nil];
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], providerError, nil];
  OCMExpect([self.mockAttestationProvider getTokenWithCompletion:completionArg]);

  // 3. Don't expect token requested from attestation provider.
  OCMReject([self.mockAttestationProvider getTokenWithCompletion:[OCMArg any]]);

  // 4. Request token.
  XCTestExpectation *getTokenExpectation = [self expectationWithDescription:@"getToken"];
  [self.attestation getTokenWithCompletion:^(id<FIRAppAttestationTokenInterop> _Nullable token,
                                             NSError *_Nullable error) {
    [getTokenExpectation fulfill];

    XCTAssertNil(token);

    // TODO: Expect a public domain error to be returned - not the internal one.
    XCTAssertEqualObjects(error, providerError);
  }];

  // 5. Wait for expectations and validate mocks.
  [self waitForExpectations:@[ getTokenExpectation ] timeout:0.5];
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockAttestationProvider);
}

@end
