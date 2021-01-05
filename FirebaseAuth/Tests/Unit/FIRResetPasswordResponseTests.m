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
#import "FirebaseAuth/Sources/Backend/RPC/FIRResetPasswordRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRResetPasswordResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kUserDisabledErrorMessage
    @brief This is the error message the server will respond with if the user's account has been
        disabled.
 */
static NSString *const kUserDisabledErrorMessage = @"USER_DISABLED";

/** @var kOperationNotAllowedErrorMessage
    @brief This is the error message the server will respond with if Admin disables IDP specified by
        provider.
 */
static NSString *const kOperationNotAllowedErrorMessage = @"OPERATION_NOT_ALLOWED";

/** @var kExpiredActionCodeErrorMessage
    @brief This is the error message the server will respond with if the action code is expired.
 */
static NSString *const kExpiredActionCodeErrorMessage = @"EXPIRED_OOB_CODE";

/** @var kInvalidActionCodeErrorMessage
    @brief This is the error message the server will respond with if the action code is invalid.
 */
static NSString *const kInvalidActionCodeErrorMessage = @"INVALID_OOB_CODE";

/** @var kWeakPasswordErrorMessagePrefix
    @brief This is the prefix for the error message the server responds with if user's new password
        to be set is too weak.
 */
static NSString *const kWeakPasswordErrorMessagePrefix = @"WEAK_PASSWORD : ";

/** @var kTestOOBCode
    @brief Fake OOBCode used for testing.
 */
static NSString *const kTestOOBCode = @"OOBCode";

/** @var kTestNewPassword
    @brief Fake new password used for testing.
 */
static NSString *const kTestNewPassword = @"newPassword";

/** @var kEmailKey
    @brief The key for the email returned in the response.
 */
static NSString *const kEmailKey = @"email";

/** @var kRequestTypeKey
    @brief The key for the request type returned in the response.
 */
static NSString *const kRequestTypeKey = @"requestType";

/** @var kTestEmail
    @brief The email returned in the response.
 */
static NSString *const kTestEmail = @"test@email.com";

/** @var kResetPasswordExpectedRequestType.
    @brief The expected request type returned for reset password request.
 */
static NSString *const kExpectedResetPasswordRequestType = @"PASSWORD_RESET";

/** @class FIRResetPasswordRequestTests
    @brief Tests for @c FIRResetPasswordRequest.
 */
@interface FIRResetPasswordResponseTests : XCTestCase
@end

@implementation FIRResetPasswordResponseTests {
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

/** @fn testUserDisabledError
    @brief Tests for @c FIRAuthErrorCodeUserDisabled.
 */
- (void)testUserDisabledError {
  FIRResetPasswordRequest *request =
      [[FIRResetPasswordRequest alloc] initWithOobCode:kTestOOBCode
                                           newPassword:kTestNewPassword
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRResetPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      resetPassword:request
           callback:^(FIRResetPasswordResponse *_Nullable response, NSError *_Nullable error) {
             RPCResponse = response;
             RPCError = error;
             callbackInvoked = YES;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kUserDisabledErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeUserDisabled);
}

/** @fn testOperationNotAllowedError
    @brief Tests for @c FIRAuthErrorCodeOperationNotAllowed.
 */
- (void)testOperationNotAllowedError {
  FIRResetPasswordRequest *request =
      [[FIRResetPasswordRequest alloc] initWithOobCode:kTestOOBCode
                                           newPassword:kTestNewPassword
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRResetPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      resetPassword:request
           callback:^(FIRResetPasswordResponse *_Nullable response, NSError *_Nullable error) {
             RPCResponse = response;
             RPCError = error;
             callbackInvoked = YES;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kOperationNotAllowedErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeOperationNotAllowed);
}

/** @fn testOOBExpiredError
    @brief Tests for @c FIRAuthErrorCodeExpiredActionCode.
 */
- (void)testOOBExpiredError {
  FIRResetPasswordRequest *request =
      [[FIRResetPasswordRequest alloc] initWithOobCode:kTestOOBCode
                                           newPassword:kTestNewPassword
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRResetPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      resetPassword:request
           callback:^(FIRResetPasswordResponse *_Nullable response, NSError *_Nullable error) {
             RPCResponse = response;
             RPCError = error;
             callbackInvoked = YES;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kExpiredActionCodeErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeExpiredActionCode);
}

/** @fn testOOBInvalidError
    @brief Tests for @c FIRAuthErrorCodeInvalidActionCode.
 */
- (void)testOOBInvalidError {
  FIRResetPasswordRequest *request =
      [[FIRResetPasswordRequest alloc] initWithOobCode:kTestOOBCode
                                           newPassword:kTestNewPassword
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRResetPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      resetPassword:request
           callback:^(FIRResetPasswordResponse *_Nullable response, NSError *_Nullable error) {
             RPCResponse = response;
             RPCError = error;
             callbackInvoked = YES;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kInvalidActionCodeErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidActionCode);
}

/** @fn testWeakPasswordError
    @brief Tests for @c FIRAuthErrorCodeWeakPassword.
 */
- (void)testWeakPasswordError {
  FIRResetPasswordRequest *request =
      [[FIRResetPasswordRequest alloc] initWithOobCode:kTestOOBCode
                                           newPassword:kTestNewPassword
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRResetPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      resetPassword:request
           callback:^(FIRResetPasswordResponse *_Nullable response, NSError *_Nullable error) {
             RPCResponse = response;
             RPCError = error;
             callbackInvoked = YES;
           }];
  [_RPCIssuer respondWithServerErrorMessage:kWeakPasswordErrorMessagePrefix];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeWeakPassword);
}

/** @fn testSuccessfulResetPassword
    @brief Tests a successful reset password flow.
 */
- (void)testSuccessfulResetPassword {
  FIRResetPasswordRequest *request =
      [[FIRResetPasswordRequest alloc] initWithOobCode:kTestOOBCode
                                           newPassword:kTestNewPassword
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRResetPasswordResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      resetPassword:request
           callback:^(FIRResetPasswordResponse *_Nullable response, NSError *_Nullable error) {
             RPCResponse = response;
             RPCError = error;
             callbackInvoked = YES;
           }];
  [_RPCIssuer respondWithJSON:@{
    kEmailKey : kTestEmail,
    kRequestTypeKey : kExpectedResetPasswordRequestType
  }];
  XCTAssert(callbackInvoked);
  XCTAssertEqualObjects(RPCResponse.email, kTestEmail);
  XCTAssertEqualObjects(RPCResponse.requestType, kExpectedResetPasswordRequestType);
  XCTAssertNil(RPCError);
}

@end
