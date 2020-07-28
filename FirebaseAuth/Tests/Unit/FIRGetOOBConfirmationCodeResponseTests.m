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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRActionCodeSettings.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

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

/** @var kMissingEmailErrorMessage
    @brief The value of the "message" field returned for a "missing email" error.
 */
static NSString *const kMissingEmailErrorMessage = @"MISSING_EMAIL";

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

/** @var kMissingIosBundleIDErrorMessage
    @brief This is the error message the server will respond with if iOS bundle ID is missing but
        the iOS App store ID is provided.
 */
static NSString *const kMissingIosBundleIDErrorMessage = @"MISSING_IOS_BUNDLE_ID";

/** @var kMissingAndroidPackageNameErrorMessage
    @brief This is the error message the server will respond with if Android Package Name is missing
        but the flag indicating the app should be installed is set to true.
 */
static NSString *const kMissingAndroidPackageNameErrorMessage = @"MISSING_ANDROID_PACKAGE_NAME";

/** @var kUnauthorizedDomainErrorMessage
    @brief This is the error message the server will respond with if the domain of the continue URL
        specified is not whitelisted in the firebase console.
 */
static NSString *const kUnauthorizedDomainErrorMessage = @"UNAUTHORIZED_DOMAIN";

/** @var kInvalidRecipientEmailErrorMessage
    @brief This is the prefix for the error message the server responds with if the recipient email
        is invalid.
 */
static NSString *const kInvalidRecipientEmailErrorMessage = @"INVALID_RECIPIENT_EMAIL";

/** @var kInvalidContinueURIErrorMessage
    @brief This is the error returned by the backend if the continue URL provided in the request
        is invalid.
 */
static NSString *const kInvalidContinueURIErrorMessage = @"INVALID_CONTINUE_URI";

/** @var kMissingContinueURIErrorMessage
    @brief This is the error message the server will respond with if there was no continue URI
        present in a request that required one.
 */
static NSString *const kMissingContinueURIErrorMessage = @"MISSING_CONTINUE_URI";

/** @var kIosBundleID
    @brief Fake iOS bundle ID for testing.
 */
static NSString *const kIosBundleID = @"testBundleID";

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

/** @fn testSuccessfulPasswordResetResponse
    @brief This test simulates a complete password reset response (with OOB Code) and makes sure
        it succeeds, and we get the OOB Code decoded correctly.
 */
- (void)testSuccessfulPasswordResetResponse {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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

  [_RPCIssuer respondWithJSON:@{kOOBCodeKey : kTestOOBCode}];

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
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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

/** @fn testMissingEmailError
    @brief This test checks for missing email responses, and makes sure they are decoded to the
        correct error response.
 */
- (void)testMissingEmailError {
  FIRGetOOBConfirmationCodeRequest *request = [FIRGetOOBConfirmationCodeRequest
      verifyEmailRequestWithAccessToken:kTestAccessToken
                     actionCodeSettings:[self fakeActionCodeSettings]
                   requestConfiguration:_requestConfiguration];

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

  [_RPCIssuer respondWithServerErrorMessage:kMissingEmailErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqualObjects(RPCError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeMissingEmail);
  XCTAssertNil(RPCResponse);
}

/** @fn testInvalidEmailError
    @brief This test checks for the INVALID_EMAIL error message from the backend.
 */
- (void)testInvalidEmailError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];
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
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];
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
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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

/** @fn testMissingIosBundleIDError
    @brief Tests for @c FIRAuthErrorCodeMissingIosBundleID.
 */
- (void)testMissingIosBundleIDError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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
  [_RPCIssuer respondWithServerErrorMessage:kMissingIosBundleIDErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeMissingIosBundleID);
}

/** @fn testMissingAndroidPackageNameError
    @brief Tests for @c FIRAuthErrorCodeMissingAndroidPackageName.
 */
- (void)testMissingAndroidPackageNameError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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
  [_RPCIssuer respondWithServerErrorMessage:kMissingAndroidPackageNameErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeMissingAndroidPackageName);
}

/** @fn testUnauthorizedDomainError
    @brief Tests for @c FIRAuthErrorCodeUnauthorizedDomain.
 */
- (void)testUnauthorizedDomainError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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
  [_RPCIssuer respondWithServerErrorMessage:kUnauthorizedDomainErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeUnauthorizedDomain);
}

/** @fn testInvalidContinueURIError
    @brief Tests for @c FIRAuthErrorCodeInvalidContinueAuthURI.
 */
- (void)testInvalidContinueURIError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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
  [_RPCIssuer respondWithServerErrorMessage:kInvalidContinueURIErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidContinueURI);
}

/** @fn testMissingContinueURIError
    @brief Tests for @c FIRAuthErrorCodeMissingContinueURI.
 */
- (void)testMissingContinueURIError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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
  [_RPCIssuer respondWithServerErrorMessage:kMissingContinueURIErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeMissingContinueURI);
}

/** @fn testInvalidRecipientEmailError
    @brief Tests for @c FIRAuthErrorCodeInvalidRecipientEmail.
 */
- (void)testInvalidRecipientEmailError {
  FIRGetOOBConfirmationCodeRequest *request =
      [FIRGetOOBConfirmationCodeRequest passwordResetRequestWithEmail:kTestEmail
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];

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
                                                   actionCodeSettings:[self fakeActionCodeSettings]
                                                 requestConfiguration:_requestConfiguration];
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

  [_RPCIssuer respondWithJSON:@{kOOBCodeKey : kTestOOBCode}];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.OOBCode, kTestOOBCode);
}

#pragma mark - Helpers

/** @fn fakeActionCodeSettings
    @brief Constructs and returns a fake instance of @c FIRActionCodeSettings for testing.
    @return An instance of @c FIRActionCodeSettings for testing.
 */
- (FIRActionCodeSettings *)fakeActionCodeSettings {
  FIRActionCodeSettings *actionCodeSettings = [[FIRActionCodeSettings alloc] init];
  [actionCodeSettings setIOSBundleID:kIosBundleID];
  return actionCodeSettings;
}

@end
