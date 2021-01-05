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
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyAssertionRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyAssertionResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kProviderIDKey
    @brief The name of the "providerId" property in the response.
 */
static NSString *const kProviderIDKey = @"providerId";

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

/** @var kVerifiedProviderKey
    @brief The name of the "VerifiedProvider" property in the response.
 */
static NSString *const kVerifiedProviderKey = @"verifiedProvider";

/** @var kRawUserInfoKey
    @brief The name of the "rawUserInfo" property in the response.
 */
static NSString *const kRawUserInfoKey = @"rawUserInfo";

/** @var kUsernameKey
    @brief The name of the "username" property in the response.
 */
static NSString *const kUsernameKey = @"username";

/** @var kIsNewUserKey
    @brief The name of the "isNewUser" property in the response.
 */
static NSString *const kIsNewUserKey = @"isNewUser";

/** @var kTestProviderID
    @brief Fake provider ID used for testing.
 */
static NSString *const kTestProviderID = @"ProviderID";

/** @var kTestProviderIDToken
    @brief Fake provider ID token used for testing.
 */
static NSString *const kTestProviderIDToken = @"ProviderIDToken";

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

/** @var kTestProvider
    @brief Fake provider used for testing.
 */
static NSString *const kTestProvider = @"Provider";

/** @var kPhotoUrlKey
    @brief The name of the "PhotoUrl" property in the response.
 */
static NSString *const kPhotoUrlKey = @"photoUrl";

/** @var kTestPhotoUrl
    @brief The "PhotoUrl" value for testing the response.
 */
static NSString *const kTestPhotoUrl = @"www.example.com";

/** @var kUsername
    @brief The "username"  value for testing the response.
 */
static NSString *const kUsername = @"Joe Doe";

/** @var testInvalidCredentialError
    @brief This is the error message the server will respond with if the IDP token or requestUri is
        invalid.
 */
static NSString *const ktestInvalidCredentialError = @"INVALID_IDP_RESPONSE";

/** @var kUserDisabledErrorMessage
    @brief  This is the error message the server will respond with if the user's account has been
        disabled.
 */
static NSString *const kUserDisabledErrorMessage = @"USER_DISABLED";

/** @var kOperationNotAllowedErrorMessage
    @brief This is the error message the server will respond with if Admin disables IDP specified by
        provider.
 */
static NSString *const kOperationNotAllowedErrorMessage = @"OPERATION_NOT_ALLOWED";

/** @var kPasswordLoginDisabledErrorMessage
    @brief This is the error message the server responds with if password login is disabled.
 */
static NSString *const kPasswordLoginDisabledErrorMessage = @"PASSWORD_LOGIN_DISABLED";

/** @var kFederatedUserIDAlreadyLinkedMessage
    @brief This is the error message the server will respond with if the federated user ID has been
        already linked with another account.
 */
static NSString *const kFederatedUserIDAlreadyLinkedMessage = @"FEDERATED_USER_ID_ALREADY_LINKED:";

/** @var kAllowedTimeDifference
    @brief Allowed difference when comparing times because of execution time and floating point
        error.
 */
static const double kAllowedTimeDifference = 0.1;

/** @class FIRVerifyAssertionResponseTests
    @brief Tests for @c FIRVerifyAssertionResponse
 */
@interface FIRVerifyAssertionResponseTests : XCTestCase
@end
@implementation FIRVerifyAssertionResponseTests {
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

/** @fn profile
    @brief The "rawUserInfo" value for testing the response.
 */
+ (NSDictionary *)profile {
  static NSDictionary *kGoogleProfile = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kGoogleProfile = @{
      @"iss" : @"https://accounts.google.com\\",
      @"email" : @"test@email.com",
      @"given_name" : @"User",
      @"family_name" : @"Doe"
    };
  });
  return kGoogleProfile;
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

/** @fn testInvalidIDPResponseError
    @brief This test simulates @c invalidIDPResponseError with @c FIRAuthErrorCodeInvalidIDPResponse
        error code.
 */
- (void)testInvalidIDPResponseError {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerIDToken = kTestProviderIDToken;

  __block BOOL callbackInvoked;
  __block FIRVerifyAssertionResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error) {
               callbackInvoked = YES;
               RPCResponse = response;
               RPCError = error;
             }];

  [_RPCIssuer respondWithServerErrorMessage:ktestInvalidCredentialError];
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidCredential);
}

/** @fn testUserDisabledError
    @brief This test simulates @c userDisabledError with @c
        FIRAuthErrorCodeUserDisabled error code.
 */
- (void)testUserDisabledError {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerIDToken = kTestProviderIDToken;

  __block BOOL callbackInvoked;
  __block FIRVerifyAssertionResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error) {
               callbackInvoked = YES;
               RPCResponse = response;
               RPCError = error;
             }];

  [_RPCIssuer respondWithServerErrorMessage:kUserDisabledErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeUserDisabled);
}

#if TARGET_OS_IOS
/** @fn testCredentialAlreadyInUseError
    @brief This test simulates a @c FIRAuthErrorCodeCredentialAlreadyInUse error.
 */
- (void)testCredentialAlreadyInUseError {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerIDToken = kTestProviderIDToken;

  __block BOOL callbackInvoked;
  __block FIRVerifyAssertionResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error) {
               callbackInvoked = YES;
               RPCResponse = response;
               RPCError = error;
             }];

  [_RPCIssuer respondWithServerErrorMessage:kFederatedUserIDAlreadyLinkedMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeCredentialAlreadyInUse);
}
#endif  // TARGET_OS_IOS

/** @fn testOperationNotAllowedError
    @brief This test simulates a @c FIRAuthErrorCodeOperationNotAllowed error.
 */
- (void)testOperationNotAllowedError {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerIDToken = kTestProviderIDToken;

  __block BOOL callbackInvoked;
  __block FIRVerifyAssertionResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error) {
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
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerIDToken = kTestProviderIDToken;

  __block BOOL callbackInvoked;
  __block FIRVerifyAssertionResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error) {
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

/** @fn testSuccessfulVerifyAssertionResponse
    @brief This test simulates a successful verify assertion flow.
 */
- (void)testSuccessfulVerifyAssertionResponse {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerIDToken = kTestProviderIDToken;

  __block BOOL callbackInvoked;
  __block FIRVerifyAssertionResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error) {
               callbackInvoked = YES;
               RPCResponse = response;
               RPCError = error;
             }];

  [_RPCIssuer respondWithJSON:@{
    kProviderIDKey : kTestProviderID,
    kIDTokenKey : kTestIDToken,
    kExpiresInKey : kTestExpiresIn,
    kRefreshTokenKey : kTestRefreshToken,
    kVerifiedProviderKey : @[ kTestProvider ],
    kPhotoUrlKey : kTestPhotoUrl,
    kUsernameKey : kUsername,
    kIsNewUserKey : @YES,
    kRawUserInfoKey : [[self class] profile]
  }];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.IDToken, kTestIDToken);
  NSTimeInterval expiresIn = [RPCResponse.approximateExpirationDate timeIntervalSinceNow];
  XCTAssertEqualWithAccuracy(expiresIn, [kTestExpiresIn doubleValue], kAllowedTimeDifference);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kTestRefreshToken);
  XCTAssertEqualObjects(RPCResponse.verifiedProvider, @[ kTestProvider ]);
  XCTAssertEqualObjects(RPCResponse.photoURL, [NSURL URLWithString:kTestPhotoUrl]);
  XCTAssertEqualObjects(RPCResponse.username, kUsername);
  XCTAssertEqualObjects(RPCResponse.profile, [[self class] profile]);
  XCTAssertEqualObjects(RPCResponse.providerID, kTestProviderID);
  XCTAssertTrue(RPCResponse.isNewUser);
}

/** @fn testSuccessfulVerifyAssertionResponseWithTextData
    @brief This test simulates a successful verify assertion flow when response collection
        fields are sent as text values.
 */
- (void)testSuccessfulVerifyAssertionResponseWithTextData {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerIDToken = kTestProviderIDToken;

  __block BOOL callbackInvoked;
  __block FIRVerifyAssertionResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error) {
               callbackInvoked = YES;
               RPCResponse = response;
               RPCError = error;
             }];

  [_RPCIssuer respondWithJSON:@{
    kProviderIDKey : kTestProviderID,
    kIDTokenKey : kTestIDToken,
    kExpiresInKey : kTestExpiresIn,
    kRefreshTokenKey : kTestRefreshToken,
    kVerifiedProviderKey : [[self class] convertToJSONString:@[ kTestProvider ]],
    kPhotoUrlKey : kTestPhotoUrl,
    kUsernameKey : kUsername,
    kIsNewUserKey : @NO,
    kRawUserInfoKey : [[self class] convertToJSONString:[[self class] profile]]
  }];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.IDToken, kTestIDToken);
  NSTimeInterval expiresIn = [RPCResponse.approximateExpirationDate timeIntervalSinceNow];
  XCTAssertEqualWithAccuracy(expiresIn, [kTestExpiresIn doubleValue], kAllowedTimeDifference);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kTestRefreshToken);
  XCTAssertEqualObjects(RPCResponse.verifiedProvider, @[ kTestProvider ]);
  XCTAssertEqualObjects(RPCResponse.photoURL, [NSURL URLWithString:kTestPhotoUrl]);
  XCTAssertEqualObjects(RPCResponse.username, kUsername);
  XCTAssertEqualObjects(RPCResponse.profile, [[self class] profile]);
  XCTAssertEqualObjects(RPCResponse.providerID, kTestProviderID);
  XCTAssertFalse(RPCResponse.isNewUser);
}

#pragma mark - Helpers

+ (NSString *)convertToJSONString:(NSObject *)object {
  NSData *objectAsData = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
  return [[NSString alloc] initWithData:objectAsData encoding:NSUTF8StringEncoding];
}

@end
