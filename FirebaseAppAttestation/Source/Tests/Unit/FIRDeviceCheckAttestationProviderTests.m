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

#import <FirebaseAppAttestation/FIRAppAttestationToken.h>
#import <FirebaseAppAttestation/FIRDeviceCheckAttestationProvider.h>
#import "FIRDeviceCheckAttestationAPIService.h"
#import "FIRDeviceCheckTokenGenerator.h"

@interface FIRDeviceCheckAttestationProviderTests : XCTestCase
@property(nonatomic) FIRDeviceCheckAttestationProvider *provider;
@property(nonatomic) id fakeAPIService;
@property(nonatomic) id fakeTokenGenerator;
@end

@implementation FIRDeviceCheckAttestationProviderTests

- (void)setUp {
  [super setUp];

  self.fakeAPIService = OCMProtocolMock(@protocol(FIRDeviceCheckAttestationAPIServiceProtocol));
  self.fakeTokenGenerator = OCMProtocolMock(@protocol(FIRDeviceCheckTokenGenerator));
  self.provider =
      [[FIRDeviceCheckAttestationProvider alloc] initWithAPIService:self.fakeAPIService
                                               deviceTokenGenerator:self.fakeTokenGenerator];
}

- (void)tearDown {
  self.provider = nil;
  self.fakeAPIService = nil;
  self.fakeTokenGenerator = nil;
}

- (void)testGetTokenSuccess {
  // 1. Expect device token to be generated.
  NSData *deviceToken = [NSData data];
  id generateTokenArg = [OCMArg invokeBlockWithArgs:deviceToken, [NSNull null], nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Expect FAA token to be requested.
  FIRAppAttestationToken *validToken =
      [[FIRAppAttestationToken alloc] initWithToken:@"valid_token"
                                     expirationDate:[NSDate distantFuture]];
  OCMExpect([self.fakeAPIService attestationTokenWithDeviceToken:deviceToken])
      .andReturn([FBLPromise resolvedWith:validToken]);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppAttestationToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertEqualObjects(token.token, validToken.token);
        XCTAssertEqualObjects(token.expirationDate, validToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 4. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);
}

- (void)testGetTokenWhenDeviceTokenFails {
  // 1. Expect device token to be generated.
  NSError *deviceTokenError = [NSError errorWithDomain:@"FIRDeviceCheckAttestationProviderTests"
                                                  code:-1
                                              userInfo:nil];
  id generateTokenArg = [OCMArg invokeBlockWithArgs:[NSNull null], deviceTokenError, nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Don't expect FAA token to be requested.
  OCMReject([self.fakeAPIService attestationTokenWithDeviceToken:[OCMArg any]]);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppAttestationToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, deviceTokenError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 4. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);
}

- (void)testGetTokenWhenAPIServiceFails {
  // 1. Expect device token to be generated.
  NSData *deviceToken = [NSData data];
  id generateTokenArg = [OCMArg invokeBlockWithArgs:deviceToken, [NSNull null], nil];
  OCMExpect([self.fakeTokenGenerator generateTokenWithCompletionHandler:generateTokenArg]);

  // 2. Expect FAA token to be requested.
  NSError *APIServiceError = [NSError errorWithDomain:@"FIRDeviceCheckAttestationProviderTests"
                                                 code:-1
                                             userInfo:nil];
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIServiceError];
  OCMExpect([self.fakeAPIService attestationTokenWithDeviceToken:deviceToken])
      .andReturn(rejectedPromise);

  // 3. Call getToken and validate the result.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppAttestationToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];
        XCTAssertNil(token);
        XCTAssertEqualObjects(error, APIServiceError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 4. Verify fakes.
  OCMVerifyAll(self.fakeAPIService);
  OCMVerifyAll(self.fakeTokenGenerator);
}

@end
