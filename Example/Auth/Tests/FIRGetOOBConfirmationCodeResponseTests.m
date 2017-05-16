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

#import "FIRAuthErrors.h"
#import "FIRAuthBackend.h"
#import "FIRGetOOBConfirmationCodeRequest.h"
#import "FIRGetOOBConfirmationCodeResponse.h"
#import "FIRFakeBackendRPCIssuer.h"

/** @var kTestEmail
    @brief Testing user email adadress.
 */
static NSString *const kTestEmail = @"test@gmail.com";

/** @var kTestAccessToken
    @brief Testing access token.
 */
static NSString *const kTestAccessToken = @"ACCESS_TOKEN";

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kOOBCodeKey
    @brief The name of the field in the response JSON for the OOB code.
 */
static NSString *const kOOBCodeKey = @"oobCode";

/** @var kTestOOBCode
    @brief Fake OOB Code used for testing.
 */
static NSString *const kTestOOBCode = @"OOBCode";

/** @var kEmailNotFoundMessage
    @brief The value of the "message" field returned for an "email not found" error.
 */
static NSString *const kEmailNotFoundMessage = @"EMAIL_NOT_FOUND: fake custom message";

/** @var kInvalidEmailErrorMessage
    @brief The error returned by the server if the email is invalid.
 */
static NSString *const kInvalidEmailErrorMessage = @"INVALID_EMAIL:";

/** @var kInvalidMessagePayloadErrorMessage
    @brief This is the prefix for the error message the server responds with if an invalid message
        payload was sent.
 */
static NSString *const kInvalidMessagePayloadErrorMessage = @"INVALID_MESSAGE_PAYLOAD";

/** @var kInvalidSenderErrorMessage
    @brief This is the prefix for the error message the server responds with if invalid sender is
        used to send the email for updating user's email address.
 */
static NSString *const kInvalidSenderErrorMessage = @"INVALID_SENDER";


/** @var kInvalidRecipientEmailErrorMessage
    @brief This is the prefix for the error message the server responds with if the recipient email
        is invalid.
 */
static NSString *const kInvalidRecipientEmailErrorMessage = @"INVALID_RECIPIENT_EMAIL";

/** @class FIRGetOOBConfirmationCodeResponseTests
    @brief Tests for @c FIRGetOOBConfirmationCodeResponse.
 */
@interface FIRGetOOBConfirmationCodeResponseTests : XCTestCase
@end
@implementation FIRGetOOBConfirmationCodeResponseTests {
  /** @var _RPCIssuer
      @brief This backend RPC issuer is used to fake network responses for each test in the suite.
          In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
   */
  FIRFakeBackendRPCIssuer *_RPCIssuer;
}

- (void)setUp {
  [super setUp];
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  _RPCIssuer = RPCIssuer;
}

- (void)tearDown {
  _RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testSuccessfulPasswordResetResponse
    @brief This test simulates a complete password reset response (with OOB Code) and makes sure
        it succeeds, and we get the OOB Code decoded correctly.
 */
- (void)testSuccessfulPasswordResetResponse {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                               APIKey:kTestAPIKey];

  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
    callbackInvoked = YES;
    RPCResponse = response;
    RPCError = error;
  }];

  [_RPCIssuer respondWithJSON:@{
    kOOBCodeKey : kTestOOBCode
  }];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.OOBCode, kTestOOBCode);
}

/** @fn testSuccessfulPasswordResetResponseWithoutOOBCode
    @brief This test simulates a password reset request where we don't receive the optional OOBCode
        response value. It should still succeed.
 */
- (void)testSuccessfulPasswordResetResponseWithoutOOBCode {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                               APIKey:kTestAPIKey];

  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
    callbackInvoked = YES;
    RPCResponse = response;
    RPCError = error;
  }];

  [_RPCIssuer respondWithJSON:@{}];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertNil(RPCResponse.OOBCode);
}

/** @fn testEmailNotFoundError
    @brief This test checks for email not found responses, and makes sure they are decoded to the
        correct error response.
 */
- (void)testEmailNotFoundError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                               APIKey:kTestAPIKey];

  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
    callbackInvoked = YES;
    RPCResponse = response;
    RPCError = error;
  }];

  [_RPCIssuer respondWithServerErrorMessage:kEmailNotFoundMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqualObjects(RPCError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeUserNotFound);
  XCTAssertNil(RPCResponse);
}

/** @fn testInvalidEmailError
    @brief This test checks for the INVALID_EMAIL error message from the backend.
 */
- (void)testInvalidEmailError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                               APIKey:kTestAPIKey];
  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
    callbackInvoked = YES;
    RPCResponse = response;
    RPCError = error;
  }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidEmailErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqualObjects(RPCError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidEmail);
  XCTAssertNil(RPCResponse);
}

/** @fn testInvalidMessagePayloadError
    @brief Tests for @c FIRAuthErrorCodeInvalidMessagePayload.
 */
- (void)testInvalidMessagePayloadError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                               APIKey:kTestAPIKey];
  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
    callbackInvoked = YES;
    RPCResponse = response;
    RPCError = error;
  }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidMessagePayloadErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidMessagePayload);
}

/** @fn testInvalidSenderError
    @brief Tests for @c FIRAuthErrorCodeInvalidSender.
 */
- (void)testInvalidSenderError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                               APIKey:kTestAPIKey];

  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
    callbackInvoked = YES;
    RPCResponse = response;
    RPCError = error;
  }];
  [_RPCIssuer respondWithServerErrorMessage:kInvalidSenderErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidSender);
}

/** @fn testInvalidRecipientEmailError
    @brief Tests for @c FIRAuthErrorCodeInvalidRecipientEmail.
 */
- (void)testInvalidRecipientEmailError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                               APIKey:kTestAPIKey];

  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
    callbackInvoked = YES;
    RPCResponse = response;
    RPCError = error;
  }];
  [_RPCIssuer respondWithServerErrorMessage:kInvalidRecipientEmailErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidRecipientEmail);
}

/** @fn testSuccessfulEmailVerificationResponse
    @brief This test is really not much different than the original test for password reset. But
        it's here for completeness sake.
 */
- (void)testSuccessfulEmailVerificationResponse {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                               APIKey:kTestAPIKey];
  __block BOOL callbackInvoked;
  __block FIRGetOOBConfirmationCodeResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getOOBConfirmationCode:request
                                callback:^(FIRGetOOBConfirmationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
    callbackInvoked = YES;
    RPCResponse = response;
    RPCError = error;
  }];

  [_RPCIssuer respondWithJSON:@{
    kOOBCodeKey : kTestOOBCode
  }];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.OOBCode, kTestOOBCode);
}

@end
