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

/** @var kTestPostBodyKey
    @brief The name of the "postBody" property in the response.
 */
static NSString *const kPostBodyKey = @"postBody";

/** @var kExpectedAPIURL
    @brief The expected URL for test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyAssertion?key=APIKey";

/** @var kIDTokenKey
    @brief The name of the "idToken" property in the response.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kTestAccessToken
    @brief Fake access token used for testing.
 */
static NSString *const kTestAccessToken = @"ACCESS_TOKEN";

/** @var kProviderIDKey
    @brief The key for the "providerId" value in the request.
 */
static NSString *const kProviderIDKey = @"providerId";

/** @var kTestProviderID
    @brief Fake provider ID used for testing.
 */
static NSString *const kTestProviderID = @"ProviderID";

/** @var kProviderIDTokenKey
    @brief The key for the "id_token" value in the request.
 */
static NSString *const kProviderIDTokenKey = @"id_token";

/** @var kTestProviderIDToken
    @brief Fake provider ID token used for testing.
 */
static NSString *const kTestProviderIDToken = @"ProviderIDToken";

/** @var kInputEmailKey
    @brief The key for the "inputEmail" value in the request.
 */
static NSString *const kInputEmailKey = @"identifier";

/** @var kTestInputEmail
    @brief Fake input email used for testing.
 */
static NSString *const kTestInputEmail = @"testInputEmail";

/** @var kPendingTokenKey
    @brief The key for the "pendingToken" value in the request.
 */
static NSString *const kPendingTokenKey = @"pendingToken";

/** @var kTestPendingToken
    @brief Fake pending token used for testing.
 */
static NSString *const kTestPendingToken = @"testPendingToken";

/** @var kProviderAccessTokenKey
    @brief The key for the "access_token" value in the request.
 */
static NSString *const kProviderAccessTokenKey = @"access_token";

/** @var kTestProviderAccessToken
    @brief Fake @c providerAccessToken used for testing the request.
 */
static NSString *const kTestProviderAccessToken = @"testProviderAccessToken";

/** @var kProviderOAuthTokenSecretKey
    @brief The key for the "oauth_token_secret" value in the request.
 */
static NSString *const kProviderOAuthTokenSecretKey = @"oauth_token_secret";

/** @var kTestProviderOAuthTokenSecret
    @brief Fake @c providerOAuthTokenSecret used for testing the request.
 */
static NSString *const kTestProviderOAuthTokenSecret = @"testProviderOAuthTokenSecret";

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
static NSString *const kReturnSecureTokenKey = @"returnSecureToken";

/** @var kAutoCreateKey
    @brief The key for the "auto-create" value in the request.
 */
static NSString *const kAutoCreateKey = @"autoCreate";

/** @class FIRVerifyAssertionRequestTests
    @brief Tests for @c FIRVerifyAssertionReuqest
 */
@interface FIRVerifyAssertionRequestTests : XCTestCase
@end
@implementation FIRVerifyAssertionRequestTests {
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

/** @fn testVerifyAssertionRequestMissingTokens
    @brief Tests the request with missing @c providerAccessToken and @c provideIDToken.
    @remarks The request creation will raise an @c NSInvalidArgumentException exception when both
        these tokens are missing.
 */
- (void)testVerifyAssertionRequestMissingTokens {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];

  FIRVerifyAssertionResponseCallback callback =
      ^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error) {
      };
  void (^verifyAssertionBlock)(void) = ^{
    [FIRAuthBackend verifyAssertion:request callback:callback];
  };
  XCTAssertThrowsSpecificNamed(verifyAssertionBlock(), NSException, NSInvalidArgumentException,
                               @"Either IDToken or accessToken must be supplied.");
  XCTAssertNil(_RPCIssuer.decodedRequest[kPostBodyKey]);
}

/** @fn testVerifyAssertionRequestProviderAccessToken
    @brief Tests the verify assertion request with the @c providerAccessToken field set.
    @remarks The presence of the @c providerAccessToken will prevent an @c
        NSInvalidArgumentException exception from being raised.
 */
- (void)testVerifyAssertionRequestProviderAccessToken {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerAccessToken = kTestProviderAccessToken;
  request.returnSecureToken = NO;
  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error){
             }];

  NSArray<NSURLQueryItem *> *queryItems = @[
    [NSURLQueryItem queryItemWithName:kProviderIDKey value:kTestProviderID],
    [NSURLQueryItem queryItemWithName:kProviderAccessTokenKey value:kTestProviderAccessToken],
  ];
  NSURLComponents *components = [[NSURLComponents alloc] init];
  [components setQueryItems:queryItems];
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest[kPostBodyKey]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPostBodyKey], [components query]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kIDTokenKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kReturnSecureTokenKey]);
  // Auto-create flag Should be true by default.
  XCTAssertTrue([_RPCIssuer.decodedRequest[kAutoCreateKey] boolValue]);
}

/** @fn testVerifyAssertionRequestOptionalFields
    @brief Tests the verify assertion request with all optinal fields set.
 */
- (void)testVerifyAssertionRequestOptionalFields {
  FIRVerifyAssertionRequest *request =
      [[FIRVerifyAssertionRequest alloc] initWithProviderID:kTestProviderID
                                       requestConfiguration:_requestConfiguration];
  request.providerIDToken = kTestProviderIDToken;
  request.providerAccessToken = kTestProviderAccessToken;
  request.accessToken = kTestAccessToken;
  request.inputEmail = kTestInputEmail;
  request.pendingToken = kTestPendingToken;
  request.providerOAuthTokenSecret = kTestProviderOAuthTokenSecret;
  request.autoCreate = NO;

  [FIRAuthBackend
      verifyAssertion:request
             callback:^(FIRVerifyAssertionResponse *_Nullable response, NSError *_Nullable error){
             }];

  NSArray<NSURLQueryItem *> *queryItems = @[
    [NSURLQueryItem queryItemWithName:kProviderIDKey value:kTestProviderID],
    [NSURLQueryItem queryItemWithName:kProviderIDTokenKey value:kTestProviderIDToken],
    [NSURLQueryItem queryItemWithName:kProviderAccessTokenKey value:kTestProviderAccessToken],
    [NSURLQueryItem queryItemWithName:kProviderOAuthTokenSecretKey
                                value:kTestProviderOAuthTokenSecret],
    [NSURLQueryItem queryItemWithName:kInputEmailKey value:kTestInputEmail],
  ];
  NSURLComponents *components = [[NSURLComponents alloc] init];
  [components setQueryItems:queryItems];
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest[kPostBodyKey]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPostBodyKey], [components query]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIDTokenKey], kTestAccessToken);
  XCTAssertTrue([_RPCIssuer.decodedRequest[kReturnSecureTokenKey] boolValue]);
  XCTAssertFalse([_RPCIssuer.decodedRequest[kAutoCreateKey] boolValue]);
}

@end
