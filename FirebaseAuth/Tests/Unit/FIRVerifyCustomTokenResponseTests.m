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
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyCustomTokenRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyCustomTokenResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestToken
    @brief testing token.
 */
static NSString *const kTestToken = @"test token";

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kIDTokenKey
    @brief The name of the "IDToken" property in the response.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kExpiresInKey
    @brief The name of the "expiresIn" property in the response.
 */
static NSString *const kExpiresInKey = @"expiresIn";

/** @var kRefreshTokenKey
    @brief The name of the "refreshToken" property in the response.
 */
static NSString *const kRefreshTokenKey = @"refreshToken";

/** @var kIsNewUserKey
    @brief The name of the "isNewUser" property in the response.
 */
static NSString *const kIsNewUserKey = @"isNewUser";

/** @var kTestIDToken
    @brief Testing ID token for verifying assertion.
 */
static NSString *const kTestIDToken = @"ID_TOKEN";

/** @var kTestExpiresIn
    @brief Fake token expiration time.
 */
static NSString *const kTestExpiresIn = @"12345";

/** @var kTestRefreshToken
    @brief Fake refresh token.
 */
static NSString *const kTestRefreshToken = @"REFRESH_TOKEN";

/** @var kMissingTokenCustomErrorMessage
    @brief This is the error message the server will respond with if token field is missing in
        request.
 */
static NSString *const kMissingCustomTokenErrorMessage = @"MISSING_CUSTOM_TOKEN";

/** @var kInvalidTokenCustomErrorMessage
    @brief This is the error message the server will respond with if there is a validation error
        with the custom token.
 */
static NSString *const kInvalidCustomTokenErrorMessage = @"INVALID_CUSTOM_TOKEN";

/** @var kInvalidCustomTokenServerErrorMessage
    @brief This is the error message the server will respond with if there is a validation error
        with the custom token. This message contains error details from the server.
 */
static NSString *const kInvalidCustomTokenServerErrorMessage =
    @"INVALID_CUSTOM_TOKEN : Detailed Error";

/** @var kInvalidCustomTokenEmptyServerErrorMessage
    @brief This is the error message the server will respond with if there is a validation error
        with the custom token.
    @remarks This message deliberately has no content where it should contain
        error details.
 */
static NSString *const kInvalidCustomTokenEmptyServerErrorMessage = @"INVALID_CUSTOM_TOKEN :";

/** @var kInvalidCustomTokenErrorDetails
    @brief This is the test detailed error message that could be returned by the backend.
 */
static NSString *const kInvalidCustomTokenErrorDetails = @"Detailed Error";

/** @var kCredentialMismatchErrorMessage
    @brief This is the error message the server will respond with if the service API key belongs to
        different projects.
 */
static NSString *const kCredentialMismatchErrorMessage = @"CREDENTIAL_MISMATCH:";

/** @var kAllowedTimeDifference
    @brief Allowed difference when comparing times because of execution time and floating point
        error.
 */
static const double kAllowedTimeDifference = 0.1;

@interface FIRVerifyCustomTokenResponseTests : XCTestCase
@end
@implementation FIRVerifyCustomTokenResponseTests {
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

/** @fn testInvalidCustomTokenError
    @brief This test simulates @c invalidCustomTokenError with @c
        FIRAuthErrorCodeINvalidCustomToken error code.
 */
- (void)testInvalidCustomTokenError {
  FIRVerifyCustomTokenRequest *request =
      [[FIRVerifyCustomTokenRequest alloc] initWithToken:kTestToken
                                    requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRVerifyCustomTokenResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend verifyCustomToken:request
                           callback:^(FIRVerifyCustomTokenResponse *_Nullable response,
                                      NSError *_Nullable error) {
                             callbackInvoked = YES;
                             RPCResponse = response;
                             RPCError = error;
                           }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidCustomTokenErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidCustomToken);
}

/** @fn testInvalidCustomTokenServerError
    @brief This test simulates @c invalidCustomTokenError with @c
        FIRAuthErrorCodeINvalidCustomToken error code, with a custom message from the server.
 */
- (void)testInvalidCustomTokenServerError {
  FIRVerifyCustomTokenRequest *request =
      [[FIRVerifyCustomTokenRequest alloc] initWithToken:kTestToken
                                    requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRVerifyCustomTokenResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend verifyCustomToken:request
                           callback:^(FIRVerifyCustomTokenResponse *_Nullable response,
                                      NSError *_Nullable error) {
                             callbackInvoked = YES;
                             RPCResponse = response;
                             RPCError = error;
                           }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidCustomTokenServerErrorMessage];
  NSString *errorDescription = [RPCError.userInfo valueForKey:NSLocalizedDescriptionKey];
  XCTAssertTrue([errorDescription isEqualToString:kInvalidCustomTokenErrorDetails]);
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidCustomToken);
}

/** @fn testEmptyServerDetailMessage
    @brief This test simulates @c invalidCustomTokenError with @c
        FIRAuthErrorCodeINvalidCustomToken error code, with an empty custom message from the server.
    @remarks An empty error message is not valid and therefore should not be added as an error
        description.
 */
- (void)testEmptyServerDetailMessage {
  FIRVerifyCustomTokenRequest *request =
      [[FIRVerifyCustomTokenRequest alloc] initWithToken:kTestToken
                                    requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRVerifyCustomTokenResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend verifyCustomToken:request
                           callback:^(FIRVerifyCustomTokenResponse *_Nullable response,
                                      NSError *_Nullable error) {
                             callbackInvoked = YES;
                             RPCResponse = response;
                             RPCError = error;
                           }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidCustomTokenEmptyServerErrorMessage];
  NSString *errorDescription = [RPCError.userInfo valueForKey:NSLocalizedDescriptionKey];
  XCTAssertFalse([errorDescription isEqualToString:@""]);
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidCustomToken);
}

/** @fn testInvalidCredentialMismatchError
    @brief This test simulates @c credentialMistmatchTokenError with @c
        FIRAuthErrorCodeCredetialMismatch error code.
 */
- (void)testInvalidCredentialMismatchError {
  FIRVerifyCustomTokenRequest *request =
      [[FIRVerifyCustomTokenRequest alloc] initWithToken:kTestToken
                                    requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRVerifyCustomTokenResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend verifyCustomToken:request
                           callback:^(FIRVerifyCustomTokenResponse *_Nullable response,
                                      NSError *_Nullable error) {
                             callbackInvoked = YES;
                             RPCResponse = response;
                             RPCError = error;
                           }];

  [_RPCIssuer respondWithServerErrorMessage:kCredentialMismatchErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeCustomTokenMismatch);
}

/** @fn testSuccessfulVerifyCustomTokenResponse
    @brief This test simulates a successful @c VerifyCustomToken flow.
 */
- (void)testSuccessfulVerifyCustomTokenResponse {
  FIRVerifyCustomTokenRequest *request =
      [[FIRVerifyCustomTokenRequest alloc] initWithToken:kTestToken
                                    requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRVerifyCustomTokenResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend verifyCustomToken:request
                           callback:^(FIRVerifyCustomTokenResponse *_Nullable response,
                                      NSError *_Nullable error) {
                             callbackInvoked = YES;
                             RPCResponse = response;
                             RPCError = error;
                           }];

  [_RPCIssuer respondWithJSON:@{
    kIDTokenKey : kTestIDToken,
    kExpiresInKey : kTestExpiresIn,
    kRefreshTokenKey : kTestRefreshToken,
    kIsNewUserKey : @YES,
  }];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.IDToken, kTestIDToken);
  NSTimeInterval expiresIn = [RPCResponse.approximateExpirationDate timeIntervalSinceNow];
  XCTAssertEqualWithAccuracy(expiresIn, [kTestExpiresIn doubleValue], kAllowedTimeDifference);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kTestRefreshToken);
  XCTAssertTrue(RPCResponse.isNewUser);
}

@end
