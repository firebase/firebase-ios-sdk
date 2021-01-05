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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSetAccountInfoRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSetAccountInfoResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kEmailExistsErrorMessage
    @brief This is the error message the server will respond with if the user entered an invalid
        email address.
 */
static NSString *const kEmailExistsErrorMessage = @"EMAIL_EXISTS";

/** @var kVerifiedProviderKey
    @brief The name of the "VerifiedProvider" property in the response.
 */
static NSString *const kProviderUserInfoKey = @"providerUserInfo";

/** @var kPhotoUrlKey
    @brief The name of the "photoURL" property in the response.
 */
static NSString *const kPhotoUrlKey = @"photoUrl";

/** @var kTestPhotoURL
    @brief The fake photoUrl property value in the response.
 */
static NSString *const kTestPhotoURL = @"testPhotoURL";

/** @var kIDTokenKey
    @brief The name of the "IDToken" property in the response.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kTestIDToken
    @brief Testing ID token for verifying assertion.
 */
static NSString *const kTestIDToken = @"ID_TOKEN";

/** @var kExpiresInKey
    @brief The name of the "expiresIn" property in the response.
 */
static NSString *const kExpiresInKey = @"expiresIn";

/** @var kTestExpiresIn
    @brief Fake token expiration time.
 */
static NSString *const kTestExpiresIn = @"12345";

/** @var kRefreshTokenKey
    @brief The name of the "refreshToken" property in the response.
 */
static NSString *const kRefreshTokenKey = @"refreshToken";

/** @var kTestRefreshToken
    @brief Fake refresh token.
 */
static NSString *const kTestRefreshToken = @"REFRESH_TOKEN";

/** @var kEmailSignUpNotAllowedErrorMessage
    @brief This is the error message the server will respond with if admin disables password
        account.
 */
static NSString *const kEmailSignUpNotAllowedErrorMessage = @"OPERATION_NOT_ALLOWED";

/** @var kPasswordLoginDisabledErrorMessage
    @brief This is the error message the server responds with if password login is disabled.
 */
static NSString *const kPasswordLoginDisabledErrorMessage = @"PASSWORD_LOGIN_DISABLED";

/** @var kCredentialTooOldErrorMessage
    @brief This is the error message the server responds with if account change is attempted 5
        minutes after signing in.
 */
static NSString *const kCredentialTooOldErrorMessage = @"CREDENTIAL_TOO_OLD_LOGIN_AGAIN";

/** @var kinvalidUserTokenErrorMessage
    @brief This is the error message the server will respond with if the user's saved auth
        credential is invalid, the user has to sign-in again.
 */
static NSString *const kinvalidUserTokenErrorMessage = @"INVALID_ID_TOKEN";

/** @var kUserDisabledErrorMessage
    @brief This is the error message the server will respond with if the user's account has been
        disabled.
 */
static NSString *const kUserDisabledErrorMessage = @"USER_DISABLED";

/** @var kInvalidEmailErrorMessage
    @brief The error returned by the server if the email is invalid.
 */
static NSString *const kInvalidEmailErrorMessage = @"INVALID_EMAIL";

/** @var kWeakPasswordErrorMessage
    @brief This is the error message the server will respond with if the user's new password
        is too weak that it is too short.
 */
static NSString *const kWeakPasswordErrorMessage =
    @"WEAK_PASSWORD : Password should be at least 6 characters";

/** @var kWeakPasswordClientErrorMessage
    @brief This is the error message the client will see if the user's new password is too weak
        that it is too short.
    @remarks This message should be derived from @c kWeakPasswordErrorMessage .
 */
static NSString *const kWeakPasswordClientErrorMessage =
    @"Password should be at least 6 characters";

/** @var kExpiredActionCodeErrorMessage
    @brief This is the error message the server will respond with if the action code is expired.
 */
static NSString *const kExpiredActionCodeErrorMessage = @"EXPIRED_OOB_CODE:";

/** @var kInvalidActionCodeErrorMessage
    @brief This is the error message the server will respond with if the action code is invalid.
 */
static NSString *const kInvalidActionCodeErrorMessage = @"INVALID_OOB_CODE";

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

/** @var kAllowedTimeDifference
    @brief Allowed difference when comparing times because of execution time and floating point
        error.
 */
static const double kAllowedTimeDifference = 0.1;

/** @class FIRSetAccountInfoResponseTests
    @brief Tests for @c FIRSetAccountInfoResponse.
 */
@interface FIRSetAccountInfoResponseTests : XCTestCase
@end
@implementation FIRSetAccountInfoResponseTests {
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
  _RPCIssuer = nil;
  _requestConfiguration = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testEmailExistsError
    @brief This test simulates @c testSignUpNewUserEmailExistsError with @c
        FIRAuthErrorCodeEmailExists error.
 */
- (void)testEmailExistsError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kEmailExistsErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeEmailAlreadyInUse);
}

/** @fn testEmailSignUpNotAllowedError
    @brief This test simulates @c testEmailSignUpNotAllowedError with @c
        FIRAuthErrorCodeOperationNotAllowed error.
 */
- (void)testEmailSignUpNotAllowedError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kEmailSignUpNotAllowedErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeOperationNotAllowed);
}

/** @fn testPasswordLoginDisabledError
    @brief This test simulates @c passwordLoginDisabledError with @c
        FIRAuthErrorCodeOperationNotAllowed error.
 */
- (void)testPasswordLoginDisabledError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kPasswordLoginDisabledErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeOperationNotAllowed);
}

/** @fn testUserDisabledError
    @brief This test simulates @c testUserDisabledError with @c FIRAuthErrorCodeUserDisabled error.
 */
- (void)testUserDisabledError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kUserDisabledErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeUserDisabled);
}

/** @fn testInvalidUserTokenError
    @brief This test simulates @c testinvalidUserTokenError with @c
        FIRAuthErrorCodeCredentialTooOld error.
 */
- (void)testInvalidUserTokenError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kinvalidUserTokenErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidUserToken);
}

/** @fn testrequiresRecentLogin
    @brief This test simulates @c testCredentialTooOldError with @c
        FIRAuthErrorCodeRequiresRecentLogin error.
 */
- (void)testrequiresRecentLogin {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kCredentialTooOldErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeRequiresRecentLogin);
}

/** @fn testWeakPasswordError
    @brief This test simulates @c FIRAuthErrorCodeWeakPassword error.
 */
- (void)testWeakPasswordError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kWeakPasswordErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeWeakPassword);
  XCTAssertEqualObjects(RPCError.userInfo[NSLocalizedFailureReasonErrorKey],
                        kWeakPasswordClientErrorMessage);
}

/** @fn testInvalidEmailError
    @brief This test simulates @c FIRAuthErrorCodeInvalidEmail error code.
 */
- (void)testInvalidEmailError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidEmailErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidEmail);
}

/** @fn testInvalidActionCodeError
    @brief This test simulates @c FIRAuthErrorCodeInvalidActionCode error code.
 */
- (void)testInvalidActionCodeError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidActionCodeErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidActionCode);
}

/** @fn testExpiredActionCodeError
    @brief This test simulates @c FIRAuthErrorCodeExpiredActionCode error code.
 */
- (void)testExpiredActionCodeError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kExpiredActionCodeErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeExpiredActionCode);
}

/** @fn testInvalidMessagePayloadError
    @brief Tests for @c FIRAuthErrorCodeInvalidMessagePayload.
 */
- (void)testInvalidMessagePayloadError {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
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
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
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
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];
  [_RPCIssuer respondWithServerErrorMessage:kInvalidRecipientEmailErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidRecipientEmail);
}

/** @fn testSuccessfulSetAccountInfoResponse
    @brief This test simulates a successful @c SetAccountInfo flow.
 */
- (void)testSuccessfulSetAccountInfoResponse {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSetAccountInfoResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithJSON:@{
    kProviderUserInfoKey : @[ @{kPhotoUrlKey : kTestPhotoURL} ],
    kIDTokenKey : kTestIDToken,
    kExpiresInKey : kTestExpiresIn,
    kRefreshTokenKey : kTestRefreshToken
  }];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  if ([RPCResponse.providerUserInfo count]) {
    NSURL *responsePhotoUrl = RPCResponse.providerUserInfo[0].photoURL;
    XCTAssertEqualObjects(responsePhotoUrl.absoluteString, kTestPhotoURL);
  }
  XCTAssertEqualObjects(RPCResponse.IDToken, kTestIDToken);
  NSTimeInterval expiresIn = [RPCResponse.approximateExpirationDate timeIntervalSinceNow];
  XCTAssertEqualWithAccuracy(expiresIn, [kTestExpiresIn doubleValue], kAllowedTimeDifference);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kTestRefreshToken);
}

@end
