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
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignUpNewUserRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignUpNewUserResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

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

/** @var kTestEmail
    @brief Testing user email adadress.
 */
static NSString *const kTestEmail = @"test@gmail.com";

/** @var kTestDisplayName
    @brief Testing display name.
 */
static NSString *const kTestDisplayName = @"DisplayName";

/** @var kTestPassword
    @brief Testing password.
 */
static NSString *const kTestPassword = @"Password";

/** @var kEmailAlreadyInUseErrorMessage
    @brief This is the error message the server will respond with if the user entered an invalid
        email address.
 */
static NSString *const kEmailAlreadyInUseErrorMessage = @"EMAIL_EXISTS";

/** @var kOperationNotAllowedErrorMessage
    @brief This is the error message the server will respond with if user/password account was
        disabled by the administrator.
 */
static NSString *const kEmailSignUpNotAllowedErrorMessage = @"OPERATION_NOT_ALLOWED";

/** @var kPasswordLoginDisabledErrorMessage
    @brief This is the error message the server responds with if password login is disabled.
 */
static NSString *const kPasswordLoginDisabledErrorMessage = @"PASSWORD_LOGIN_DISABLED:";

/** @var kInvalidEmailErrorMessage
    @brief The error returned by the server if the email is invalid.
 */
static NSString *const kInvalidEmailErrorMessage = @"INVALID_EMAIL";

/** @var kWeakPasswordErrorMessage
    @brief This is the error message the server will respond with if the new user's password
        is too weak that it is too short.
 */
static NSString *const kWeakPasswordErrorMessage =
    @"WEAK_PASSWORD : Password should be at least 6 characters";

/** @var kWeakPasswordClientErrorMessage
    @brief This is the error message the client will see if the new user's password is too weak
        that it is too short.
    @remarks This message should be derived from @c kWeakPasswordErrorMessage .
 */
static NSString *const kWeakPasswordClientErrorMessage =
    @"Password should be at least 6 characters";

/** @var kAllowedTimeDifference
    @brief Allowed difference when comparing times because of execution time and floating point
        error.
 */
static const double kAllowedTimeDifference = 0.1;

@interface FIRSignUpNewUserResponseTests : XCTestCase
@end
@implementation FIRSignUpNewUserResponseTests {
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

/** @fn testSuccessfulSignUp
    @brief This test simulates a complete sign up flow with no errors.
 */
- (void)testSuccessfulSignUp {
  FIRSignUpNewUserRequest *request =
      [[FIRSignUpNewUserRequest alloc] initWithEmail:kTestEmail
                                            password:kTestPassword
                                         displayName:kTestDisplayName
                                requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSignUpNewUserResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      signUpNewUser:request
           callback:^(FIRSignUpNewUserResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];

  [_RPCIssuer respondWithJSON:@{
    kIDTokenKey : kTestIDToken,
    kExpiresInKey : kTestExpiresIn,
    kRefreshTokenKey : kTestRefreshToken
  }];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.IDToken, kTestIDToken);
  NSTimeInterval expiresIn = [RPCResponse.approximateExpirationDate timeIntervalSinceNow];
  XCTAssertEqualWithAccuracy(expiresIn, [kTestExpiresIn doubleValue], kAllowedTimeDifference);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kTestRefreshToken);
  XCTAssertNil(RPCError, "There should be no error");
}

/** @fn testSignUpNewUserEmailAlreadyInUseError
    @brief This test simulates @c testSignUpNewUserEmailAlreadyInUseError with @c
        FIRAuthErrorCodeEmailAlreadyInUse error.
 */
- (void)testSignUpNewUserEmailAlreadyInUseError {
  FIRSignUpNewUserRequest *request =
      [[FIRSignUpNewUserRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSignUpNewUserResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      signUpNewUser:request
           callback:^(FIRSignUpNewUserResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kEmailAlreadyInUseErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeEmailAlreadyInUse);
}

/** @fn testSignUpNewUserOperationNotAllowedError
    @brief This test simulates @c testSignUpNewUserEmailExistsError with @c
        FIRAuthErrorCodeOperationNotAllowed error.
 */
- (void)testSignUpNewUserOperationNotAllowedError {
  FIRSignUpNewUserRequest *request =
      [[FIRSignUpNewUserRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSignUpNewUserResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      signUpNewUser:request
           callback:^(FIRSignUpNewUserResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kEmailSignUpNotAllowedErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeOperationNotAllowed);
}

/** @fn testSignUpNewUserPasswordLoginDisabledError
    @brief This test simulates @c signUpNewUserPasswordLoginDisabledError with @c
        FIRAuthErrorCodeOperationNotAllowed error.
 */
- (void)testSignUpNewUserPasswordLoginDisabledError {
  FIRSignUpNewUserRequest *request =
      [[FIRSignUpNewUserRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSignUpNewUserResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      signUpNewUser:request
           callback:^(FIRSignUpNewUserResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kPasswordLoginDisabledErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeOperationNotAllowed);
}

/** @fn testInvalidEmailError
    @brief This test simulates making a request containing an invalid email address and receiving @c
        FIRAuthErrorInvalidEmail error as a result.
 */
- (void)testInvalidEmailError {
  FIRSignUpNewUserRequest *request =
      [[FIRSignUpNewUserRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSignUpNewUserResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      signUpNewUser:request
           callback:^(FIRSignUpNewUserResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kInvalidEmailErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidEmail);
}

/** @fn testSignUpNewUserWeakPasswordError
    @brief This test simulates @c FIRAuthErrorCodeWeakPassword error.
 */
- (void)testSignUpNewUserWeakPasswordError {
  FIRSignUpNewUserRequest *request =
      [[FIRSignUpNewUserRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRSignUpNewUserResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      signUpNewUser:request
           callback:^(FIRSignUpNewUserResponse *_Nullable response, NSError *_Nullable error) {
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

@end
