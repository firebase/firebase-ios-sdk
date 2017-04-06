/*
 * Copyright 2017 Google
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

#import "Phone/FIRPhoneAuthProvider.h"
#import "Phone/FIRPhoneAuthCredential.h"
#import "Phone/NSString+FIRAuth.h"
#import "FIRAuth_Internal.h"
#import "FIRAuthCredential_Internal.h"
#import "FIRAuthErrorUtils.h"
#import "FIRAuthGlobalWorkQueue.h"
#import "FIRAuthBackend.h"
#import "FIRSendVerificationCodeRequest.h"
#import "FIRSendVerificationCodeResponse.h"
#import "OCMStubRecorder+FIRAuthUnitTests.h"
#import <OCMock/OCMock.h>

/** @var kTestPhoneNumber
    @brief A testing phone number.
 */
static NSString *const kTestPhoneNumber = @"55555555";

/** @var kTestInvalidPhoneNumber
    @brief An invalid testing phone number.
 */
static NSString *const kTestInvalidPhoneNumber = @"555+!*55555";

/** @var kTestVerificationID
    @brief A testing verfication ID.
 */
static NSString *const kTestVerificationID = @"verificationID";

/** @var kTestVerificationCode
    @brief A testing verfication code.
 */
static NSString *const kTestVerificationCode = @"verificationCode";

/** @var kAPIKey
    @brief The fake API key.
 */
static NSString *const kAPIKey = @"FAKE_API_KEY";

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static const NSTimeInterval kExpectationTimeout = 1;

/** @class FIRPhoneAuhtProviderTests
    @brief Tests for @c FIRPhoneAuhtProvider
 */
@interface FIRPhoneAuhtProviderTests : XCTestCase
@end

@implementation FIRPhoneAuhtProviderTests {
  /** @var _mockBackend
      @brief The mock @c FIRAuthBackendImplementation .
   */
  id _mockBackend;
}

- (void)setUp {
  [super setUp];
  _mockBackend = OCMProtocolMock(@protocol(FIRAuthBackendImplementation));
  [FIRAuthBackend setBackendImplementation:_mockBackend];
}

- (void)tearDown {
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testCredentialWithVerificationID
    @brief Tests the @c credentialWithToken method to make sure that it returns a valid
        FIRAuthCredential instance.
 */
- (void)testCredentialWithVerificationID {
  // TODO:zsika update this test whenVerifyPhoneNumberRequest is added.
  FIRAuthCredential *credential =
      [[FIRPhoneAuthProvider provider] credentialWithVerificationID:kTestVerificationID
                                                   verificationCode:kTestVerificationCode];
  XCTAssertNotNil(credential);
  XCTAssert([credential isKindOfClass:[FIRPhoneAuthCredential class]]);
}

/** @fn testVerifyEmptyPhoneNumber
    @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an empty phone
        number was provided.
 */
- (void)testVerifyEmptyPhoneNumber {
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [[FIRPhoneAuthProvider provider] verifyPhoneNumber:@""
                                          completion:^(NSString *_Nullable verificationID,
                                                       NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRAuthErrorCodeMissingPhoneNumber);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testVerifyInvalidPhoneNumber
    @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an invalid phone
        number was provided.
 */
- (void)testVerifyInvalidPhoneNumber {
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertNotNil(request);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      callback(nil, [FIRAuthErrorUtils invalidPhoneNumberErrorWithMessage:nil]);
    });
  });

  [[FIRPhoneAuthProvider provider] verifyPhoneNumber:kTestPhoneNumber
                                          completion:^(NSString *_Nullable verificationID,
                                                       NSError *_Nullable error) {
    XCTAssertNil(verificationID);
    XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidPhoneNumber);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testVerifyPhoneNumber
    @brief Tests a successful invocation of @c verifyPhoneNumber:completion:.
 */
- (void)testVerifyPhoneNumber {
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertNotNil(request);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockSendVerificationCodeResponse = OCMClassMock([FIRSendVerificationCodeResponse class]);
      OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
      callback(mockSendVerificationCodeResponse, nil);
    });
  });

  [[FIRPhoneAuthProvider provider] verifyPhoneNumber:kTestPhoneNumber
                                          completion:^(NSString *_Nullable verificationID,
                                                       NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(verificationID, kTestVerificationID);
    XCTAssertEqualObjects(verificationID.fir_authPhoneNumber, kTestPhoneNumber);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

/** @fn testVerifyPhoneNumberCustomAuth
    @brief Tests a successful invocation @c verifyPhoneNumber:completion: with a custom auth object.
 */
- (void)testVerifyPhoneNumberCustomAuth {
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.APIKey, kAPIKey);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockSendVerificationCodeResponse = OCMClassMock([FIRSendVerificationCodeResponse class]);
      OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
      callback(mockSendVerificationCodeResponse, nil);
    });
  });

  id customAuth = OCMClassMock([FIRAuth class]);
  OCMStub([customAuth APIKey]).andReturn(kAPIKey);
  FIRPhoneAuthProvider *provider = [FIRPhoneAuthProvider providerWithAuth:customAuth];
  [provider verifyPhoneNumber:kTestPhoneNumber
                   completion:^(NSString *_Nullable verificationID,
                                NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(verificationID, kTestVerificationID);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
}

@end
