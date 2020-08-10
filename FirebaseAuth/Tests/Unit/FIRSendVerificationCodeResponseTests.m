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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeResponse.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredential.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestPhoneNumber
    @brief Fake phone number used for testing.
 */
static NSString *const kTestPhoneNumber = @"12345678";

/** @var kTestInvalidPhoneNumber
    @brief An invalid testing phone number.
 */
static NSString *const kTestInvalidPhoneNumber = @"555+!*55555";

/** @var kVerificationIDKey
    @brief Fake key for the test verification ID.
 */
static NSString *const kVerificationIDKey = @"sessionInfo";

/** @var kFakeVerificationID
    @brief Fake verification ID for testing.
 */
static NSString *const kFakeVerificationID = @"testVerificationID";

/** @var kTestSecret
    @brief Fake secret used for testing.
 */
static NSString *const kTestSecret = @"secret";

/** @var kTestReceipt
    @brief Fake receipt used for testing.
 */
static NSString *const kTestReceipt = @"receipt";

/** @var kTestReCAPTCHAToken
    @brief Fake reCAPTCHA token used for testing.
 */
static NSString *const kTestReCAPTCHAToken = @"reCAPTCHAToken";

/** @var kInvalidPhoneNumberErrorMessage
    @brief This is the error message the server will respond with if an incorrectly formatted phone
        number is provided.
 */
static NSString *const kInvalidPhoneNumberErrorMessage = @"INVALID_PHONE_NUMBER";

/** @var kQuotaExceededErrorMessage
    @brief This is the error message the server will respond with if the quota for SMS text messages
        has been exceeded for the project.
 */
static NSString *const kQuotaExceededErrorMessage = @"QUOTA_EXCEEDED";

/** @var kAppNotVerifiedErrorMessage
    @brief This is the error message the server will respond with if Firebase could not verify the
        app during a phone authentication flow.
 */
static NSString *const kAppNotVerifiedErrorMessage = @"APP_NOT_VERIFIED";

/** @var kCaptchaCheckFailedErrorMessage
    @brief This is the error message the server will respond with if the reCAPTCHA token provided is
        invalid.
 */
static NSString *const kCaptchaCheckFailedErrorMessage = @"CAPTCHA_CHECK_FAILED";

/** @class FIRSendVerificationCodeResponseTests
    @brief Tests for @c FIRSendVerificationCodeResponseTests.
 */
@interface FIRSendVerificationCodeResponseTests : XCTestCase
@end

@implementation FIRSendVerificationCodeResponseTests {
  /** @var _RPCIssuer
     @brief This backend RPC issuer is used to fake network responses for each test in the suite.
         In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
  */
  FIRFakeBackendRPCIssuer *_RPCIssuer;

  /** @var _requestConfiguration
      @brief This is the request configuration used for testing.
   */
  FIRAuthRequestConfiguration *_requestConfiguration;
}

- (void)setUp {
  [super setUp];
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  _RPCIssuer = RPCIssuer;
  _requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
}

- (void)tearDown {
  _requestConfiguration = nil;
  _RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testSendVerificationCodeResponseInvalidPhoneNumber
    @brief Tests a failed attempt to send a verification code with an invalid phone number.
 */
- (void)testSendVerificationCodeResponseInvalidPhoneNumber {
  FIRAuthAppCredential *credential = [[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt
                                                                            secret:kTestSecret];
  FIRSendVerificationCodeRequest *request =
      [[FIRSendVerificationCodeRequest alloc] initWithPhoneNumber:kTestInvalidPhoneNumber
                                                    appCredential:credential
                                                   reCAPTCHAToken:nil
                                             requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRSendVerificationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend sendVerificationCode:request
                              callback:^(FIRSendVerificationCodeResponse *_Nullable response,
                                         NSError *_Nullable error) {
                                RPCResponse = response;
                                RPCError = error;
                                callbackInvoked = YES;
                              }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidPhoneNumberErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidPhoneNumber);
}

/** @fn testSendVerificationCodeResponseQuotaExceededError
    @brief Tests a failed attempt to send a verification code due to SMS quota having been exceeded.
 */
- (void)testSendVerificationCodeResponseQuotaExceededError {
  FIRAuthAppCredential *credential = [[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt
                                                                            secret:kTestSecret];
  FIRSendVerificationCodeRequest *request =
      [[FIRSendVerificationCodeRequest alloc] initWithPhoneNumber:kTestPhoneNumber
                                                    appCredential:credential
                                                   reCAPTCHAToken:nil
                                             requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRSendVerificationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend sendVerificationCode:request
                              callback:^(FIRSendVerificationCodeResponse *_Nullable response,
                                         NSError *_Nullable error) {
                                RPCResponse = response;
                                RPCError = error;
                                callbackInvoked = YES;
                              }];

  [_RPCIssuer respondWithServerErrorMessage:kQuotaExceededErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeQuotaExceeded);
}

/** @fn testSendVerificationCodeResponseAppNotVerifiedError
    @brief Tests a failed attempt to send a verification code due to Firebase not being able to
        verify the app.
 */
- (void)testSendVerificationCodeResponseAppNotVerifiedError {
  FIRAuthAppCredential *credential = [[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt
                                                                            secret:kTestSecret];
  FIRSendVerificationCodeRequest *request =
      [[FIRSendVerificationCodeRequest alloc] initWithPhoneNumber:kTestPhoneNumber
                                                    appCredential:credential
                                                   reCAPTCHAToken:nil
                                             requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRSendVerificationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend sendVerificationCode:request
                              callback:^(FIRSendVerificationCodeResponse *_Nullable response,
                                         NSError *_Nullable error) {
                                RPCResponse = response;
                                RPCError = error;
                                callbackInvoked = YES;
                              }];

  [_RPCIssuer respondWithServerErrorMessage:kAppNotVerifiedErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeAppNotVerified);
}

/** @fn testSendVerificationCodeResponseCaptchaCheckFailedError
    @brief Tests a failed attempt to send a verification code due to an invalid reCAPTCHA token
        being provided in the request.
 */
- (void)testSendVerificationCodeResponseCaptchaCheckFailedError {
  FIRAuthAppCredential *credential = [[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt
                                                                            secret:kTestSecret];
  FIRSendVerificationCodeRequest *request =
      [[FIRSendVerificationCodeRequest alloc] initWithPhoneNumber:kTestPhoneNumber
                                                    appCredential:credential
                                                   reCAPTCHAToken:kTestReCAPTCHAToken
                                             requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRSendVerificationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend sendVerificationCode:request
                              callback:^(FIRSendVerificationCodeResponse *_Nullable response,
                                         NSError *_Nullable error) {
                                RPCResponse = response;
                                RPCError = error;
                                callbackInvoked = YES;
                              }];

  [_RPCIssuer respondWithServerErrorMessage:kCaptchaCheckFailedErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeCaptchaCheckFailed);
}

/** @fn testSuccessfulSendVerificationCodeResponse
    @brief Tests a succesful to send a verification code.
 */
- (void)testSuccessfulSendVerificationCodeResponse {
  FIRAuthAppCredential *credential = [[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt
                                                                            secret:kTestSecret];
  FIRSendVerificationCodeRequest *request =
      [[FIRSendVerificationCodeRequest alloc] initWithPhoneNumber:kTestPhoneNumber
                                                    appCredential:credential
                                                   reCAPTCHAToken:nil
                                             requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRSendVerificationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend sendVerificationCode:request
                              callback:^(FIRSendVerificationCodeResponse *_Nullable response,
                                         NSError *_Nullable error) {
                                RPCResponse = response;
                                RPCError = error;
                                callbackInvoked = YES;
                              }];

  [_RPCIssuer respondWithJSON:@{kVerificationIDKey : kFakeVerificationID}];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.verificationID, kFakeVerificationID);
}

@end

#endif
