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
#import "FirebaseAuth/Sources/Backend/RPC/FIRDeleteAccountRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRDeleteAccountResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kLocalID
    @brief Fake LocalID used for testing.
 */
static NSString *const kLocalID = @"LocalID";

/** @var kAccessToken
    @brief Fake AccessToken used for testing.
 */
static NSString *const kAccessToken = @"AccessToken";

/** @var kUserDisabledErrorMessage
    @brief The error returned by the server if the user account is diabled.
 */
static NSString *const kUserDisabledErrorMessage = @"USER_DISABLED";

/** @var kinvalidUserTokenErrorMessage
    @brief This is the error message the server responds with if user's saved auth credential is
        invalid, and the user needs to sign in again.
 */
static NSString *const kinvalidUserTokenErrorMessage = @"INVALID_ID_TOKEN:";

/** @var kCredentialTooOldErrorMessage
    @brief This is the error message the server responds with if account change is attempted 5
        minutes after signing in.
 */
static NSString *const kCredentialTooOldErrorMessage = @"CREDENTIAL_TOO_OLD_LOGIN_AGAIN:";

/** @class FIRDeleteUserResponseTests
    @brief Tests for @c FIRDeleteAccountResponse.
 */
@interface FIRDeleteAccountResponseTests : XCTestCase
@end
@implementation FIRDeleteAccountResponseTests {
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
    @brief This test simulates the occurrence of a @c userDisabled error.
 */
- (void)testUserDisabledError {
  FIRDeleteAccountRequest *request =
      [[FIRDeleteAccountRequest alloc] initWitLocalID:kLocalID
                                          accessToken:kAccessToken
                                 requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block NSError *RPCError;
  [FIRAuthBackend deleteAccount:request
                       callback:^(NSError *_Nullable error) {
                         callbackInvoked = YES;
                         RPCError = error;
                       }];

  [_RPCIssuer respondWithServerErrorMessage:kUserDisabledErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeUserDisabled);
}

/** @fn testinvalidUserTokenError
    @brief This test simulates the occurrence of a @c invalidUserToken error.
 */
- (void)testinvalidUserTokenError {
  FIRDeleteAccountRequest *request =
      [[FIRDeleteAccountRequest alloc] initWitLocalID:kLocalID
                                          accessToken:kAccessToken
                                 requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block NSError *RPCError;
  [FIRAuthBackend deleteAccount:request
                       callback:^(NSError *_Nullable error) {
                         callbackInvoked = YES;
                         RPCError = error;
                       }];

  [_RPCIssuer respondWithServerErrorMessage:kinvalidUserTokenErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidUserToken);
}

/** @fn testrequiredRecentLoginError
    @brief This test simulates the occurrence of a @c credentialTooOld error.
 */
- (void)testrequiredRecentLoginError {
  FIRDeleteAccountRequest *request =
      [[FIRDeleteAccountRequest alloc] initWitLocalID:kLocalID
                                          accessToken:kAccessToken
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block NSError *RPCError;
  [FIRAuthBackend deleteAccount:request
                       callback:^(NSError *_Nullable error) {
                         callbackInvoked = YES;
                         RPCError = error;
                       }];

  [_RPCIssuer respondWithServerErrorMessage:kCredentialTooOldErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeRequiresRecentLogin);
}

/** @fn testSuccessfulDeleteAccount
    @brief This test simulates a completed succesful deleteAccount operation.
 */
- (void)testSuccessfulDeleteAccountResponse {
  FIRDeleteAccountRequest *request =
      [[FIRDeleteAccountRequest alloc] initWitLocalID:kLocalID
                                          accessToken:kAccessToken
                                 requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block NSError *RPCError;
  [FIRAuthBackend deleteAccount:request
                       callback:^(NSError *_Nullable error) {
                         callbackInvoked = YES;
                         RPCError = error;
                       }];

  [_RPCIssuer respondWithJSON:@{}];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
}

@end
