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
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPasswordRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPasswordResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestPassword
    @brief Testing user password.
 */
static NSString *const kTestPassword = @"testpassword";

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"_test_API_key_";

/** @var kLocalIDKey
    @brief The name of the 'localID' property in the response.
 */
static NSString *const kLocalIDKey = @"localId";

/** @var kTestLocalID
    @brief The fake localID for testing the response.
 */
static NSString *const kTestLocalID = @"testLocalId";

/** @var kEmailKey
    @brief The name of the 'email' property in the response.
 */
static NSString *const kEmailKey = @"email";

/** @var kTestEmail
    @brief Fake user email for testing the response.
 */
static NSString *const kTestEmail = @"test@gmail.com";

/** @var kDisplayNameKey
    @brief The name of the 'displayName' property in the response.
 */
static NSString *const kDisplayNameKey = @"displayName";

/** @var kTestDisplayName
    @brief Fake displayName for testing the response.
 */
static NSString *const kTestDisplayName = @"testDisplayName";

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

/** @var kOperationNotAllowedErrorMessage
    @brief This is the error message the server will respond with if Admin disables IDP specified by
        provider.
 */
static NSString *const kOperationNotAllowedErrorMessage = @"OPERATION_NOT_ALLOWED";

/** @var kPasswordLoginDisabledErrorMessage
    @brief This is the error message the server responds with if password login is disabled.
 */
static NSString *const kPasswordLoginDisabledErrorMessage = @"PASSWORD_LOGIN_DISABLED";

/** @var kPhotoUrlKey
    @brief The name of the 'photoUrl' property in the response.
 */
static NSString *const kPhotoUrlKey = @"photoUrl";

/** @var kTestPhotoUrl
    @brief Fake photoUrl for testing the response.
 */
static NSString *const kTestPhotoUrl = @"www.example.com";

/** @var kUserDisabledErrorMessage
    @brief This is the error message the server will respond with if the user's account has been
        disabled.
 */
static NSString *const kUserDisabledErrorMessage = @"USER_DISABLED";

/** @var kEmailNotFoundErrorMessage
    @brief This is the error message the server will respond with if the email entered is not
        found.
 */
static NSString *const kEmailNotFoundErrorMessage = @"EMAIL_NOT_FOUND";

/** @var kWrongPasswordErrorMessage
    @brief This is the error message the server will respond with if the user entered a wrong
        password.
 */
static NSString *const kWrongPasswordErrorMessage = @"INVALID_PASSWORD";

/** @var kInvalidEmailErrorMessage
    @brief The error returned by the server if the email is invalid.
 */
static NSString *const kInvalidEmailErrorMessage = @"INVALID_EMAIL";

/** @var kBadRequestErrorMessage
    @brief This is the error message returned when a bad request is made; often due to a bad API
        Key.
 */
static NSString *const kBadRequestErrorMessage = @"Bad Request";

/** @var kInvalidKeyReasonValue
    @brief The value for the "reason" key indicating an invalid API Key was received by the server.
 */
static NSString *const kInvalidKeyReasonValue = @"keyInvalid";

/** @var kAppNotAuthorizedReasonValue
    @brief The value for the "reason" key indicating the App is not authorized to use Firebase
        Authentication.
 */
static NSString *const kAppNotAuthorizedReasonValue = @"ipRefererBlocked";

/** @var kTooManyAttemptsErrorMessage
    @brief This is the error message the server will respond with if a user has tried (and failed)
        to sign in too many times.
 */
static NSString *const kTooManyAttemptsErrorMessage = @"TOO_MANY_ATTEMPTS_TRY_LATER:";

/** @var kAllowedTimeDifference
    @brief Allowed difference when comparing times because of execution time and floating point
        error.
 */
static const double kAllowedTimeDifference = 0.1;

/** @class FIRVerifyPasswordResponseTests
    @brief Tests for @c FIRVerifyPasswordResponse.
 */
@interface FIRVerifyPasswordResponseTests : XCTestCase
@end
@implementation FIRVerifyPasswordResponseTests {
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

/** @fn testUserDisabledError
    @brief Tests that @c FIRAuthErrorCodeUserDisabled error is received if the email is disabled.
 */
- (void)testUserDisabledError {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];
  [_RPCIssuer respondWithServerErrorMessage:kUserDisabledErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeUserDisabled);
}

/** @fn testEmailNotFoundError
    @brief Tests that @c FIRAuthErrorCodeEmailNotFound error is received if the email is not found.
 */
- (void)testEmailNotFoundError {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];
  [_RPCIssuer respondWithServerErrorMessage:kEmailNotFoundErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeUserNotFound);
}

/** @fn testInvalidPasswordError
    @brief Tests that @c FIRAuthErrorCodeInvalidPassword error is received if the password is
        invalid.
 */
- (void)testInvalidPasswordError {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];
  [_RPCIssuer respondWithServerErrorMessage:kWrongPasswordErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeWrongPassword);
}

/** @fn testInvalidEmailError
    @brief Tests that @c FIRAuthErrorCodeInvalidEmail error is received if the email address has an
        incorrect format.
 */
- (void)testInvalidEmailError {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];
  [_RPCIssuer respondWithServerErrorMessage:kInvalidEmailErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidEmail);
}

/** @fn testTooManyAttemptsError
    @brief Tests that @c FIRAuthErrorCodeTooManyRequests error is received if too many sign-in
        attempts were made.
 */
- (void)testTooManySignInAttemptsError {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];
  [_RPCIssuer respondWithServerErrorMessage:kTooManyAttemptsErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeTooManyRequests);
}

/** @fn testKeyInvalid
    @brief Tests that @c FIRAuthErrorCodeInvalidApiKey error is received from the server.
 */
- (void)testKeyInvalid {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];

  NSDictionary *errorDictionary = @{
    @"error" : @{
      @"message" : kBadRequestErrorMessage,
      @"errors" : @[ @{@"reason" : kInvalidKeyReasonValue} ]
    }
  };
  [_RPCIssuer respondWithJSONError:errorDictionary];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidAPIKey);
}

/** @fn testOperationNotAllowedError
    @brief This test simulates a @c FIRAuthErrorCodeOperationNotAllowed error.
 */
- (void)testOperationNotAllowedError {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kOperationNotAllowedErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeOperationNotAllowed);
}

/** @fn testPasswordLoginDisabledError
    @brief This test simulates a @c FIRAuthErrorCodeOperationNotAllowed error.
 */
- (void)testPasswordLoginDisabledError {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              callbackInvoked = YES;
              RPCResponse = response;
              RPCError = error;
            }];

  [_RPCIssuer respondWithServerErrorMessage:kPasswordLoginDisabledErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeOperationNotAllowed);
}

/** @fn testAppNotAuthorized
    @brief Tests that @c FIRAuthErrorCodeAppNotAuthorized error is received from the server.
 */
- (void)testAppNotAuthorized {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];

  NSDictionary *errorDictionary = @{
    @"error" : @{
      @"message" : kBadRequestErrorMessage,
      @"errors" : @[ @{@"reason" : kAppNotAuthorizedReasonValue} ]
    }
  };
  [_RPCIssuer respondWithJSONError:errorDictionary];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeAppNotAuthorized);
}

/** @fn testSuccessfulVerifyPasswordResponse
    @brief Tests a succesful attempt of the verify password flow.
 */
- (void)testSuccessfulVerifyPasswordResponse {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error) {
              RPCResponse = response;
              RPCError = error;
              callbackInvoked = YES;
            }];

  [_RPCIssuer respondWithJSON:@{
    kLocalIDKey : kTestLocalID,
    kEmailKey : kTestEmail,
    kDisplayNameKey : kTestDisplayName,
    kIDTokenKey : kTestIDToken,
    kExpiresInKey : kTestExpiresIn,
    kRefreshTokenKey : kTestRefreshToken,
    kPhotoUrlKey : kTestPhotoUrl
  }];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.email, kTestEmail);
  XCTAssertEqualObjects(RPCResponse.localID, kTestLocalID);
  XCTAssertEqualObjects(RPCResponse.displayName, kTestDisplayName);
  XCTAssertEqualObjects(RPCResponse.IDToken, kTestIDToken);
  NSTimeInterval expiresIn = [RPCResponse.approximateExpirationDate timeIntervalSinceNow];
  XCTAssertEqualWithAccuracy(expiresIn, [kTestExpiresIn doubleValue], kAllowedTimeDifference);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kTestRefreshToken);
  XCTAssertEqualObjects(RPCResponse.photoURL.absoluteString, kTestPhotoUrl);
}

@end
