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

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kEmailKey
    @brief The key for the "email" value in the request.
 */
static NSString *const kEmailKey = @"email";

/** @var kPasswordKey
    @brief The key for the "password" value in the request.
 */
static NSString *const kPasswordKey = @"password";

/** @var kTestEmail
    @brief Fake email address for testing the request.
 */
static NSString *const kTestEmail = @"testEmail.";

/** @var kTestPassword
    @brief Fake password for testing the request.
 */
static NSString *const kTestPassword = @"testPassword";

/** @var kPendingIDTokenKey
    @brief The key for the "pendingIdToken" value in the request.
 */
static NSString *const kPendingIDTokenKey = @"pendingIdToken";

/** @var kTestPendingToken
    @brief Fake pendingToken for testing the request.
 */
static NSString *const kTestPendingToken = @"testPendingToken";

/** @var kCaptchaChallengeKey
    @brief The key for the "captchaChallenge" value in the request.
 */
static NSString *const kCaptchaChallengeKey = @"captchaChallenge";

/** @var kTestCaptchaChallenge
    @brief Fake captchaChallenge for testing the request.
 */
static NSString *const kTestCaptchaChallenge = @"testCaptchaChallenge";

/** @var kCaptchaResponseKey
    @brief The key for the "captchaResponse" value in the request.
 */
static NSString *const kCaptchaResponseKey = @"captchaResponse";

/** @var kTestCaptchaResponse
    @brief Fake captchaResponse for testing the request.
 */
static NSString *const kTestCaptchaResponse = @"captchaResponse";

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
static NSString *const kReturnSecureTokenKey = @"returnSecureToken";

/** @var kExpectedAPIURL
    @brief The expected URL for test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=APIKey";

/** @class FIRVerifyPasswordRequestTest
    @brief Tests for @c FIRVerifyPasswordRequestTest.
 */
@interface FIRVerifyPasswordRequestTest : XCTestCase
@end
@implementation FIRVerifyPasswordRequestTest {
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

/** @fn testVerifyPasswordRequest
    @brief Tests the verify password request.
 */
- (void)testVerifyPasswordRequest {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  request.returnSecureToken = NO;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error){
            }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kEmailKey], kTestEmail);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPasswordKey], kTestPassword);
  XCTAssertNil(_RPCIssuer.decodedRequest[kCaptchaChallengeKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kCaptchaResponseKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kReturnSecureTokenKey]);
}

/** @fn testVerifyPasswordRequestOptionalFields
    @brief Tests the verify password request with optional fields.
 */
- (void)testVerifyPasswordRequestOptionalFields {
  FIRVerifyPasswordRequest *request =
      [[FIRVerifyPasswordRequest alloc] initWithEmail:kTestEmail
                                             password:kTestPassword
                                 requestConfiguration:_requestConfiguration];
  request.pendingIDToken = kTestPendingToken;
  request.captchaChallenge = kTestCaptchaChallenge;
  request.captchaResponse = kTestCaptchaResponse;
  [FIRAuthBackend
      verifyPassword:request
            callback:^(FIRVerifyPasswordResponse *_Nullable response, NSError *_Nullable error){
            }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kEmailKey], kTestEmail);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPasswordKey], kTestPassword);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kCaptchaChallengeKey], kTestCaptchaChallenge);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kCaptchaResponseKey], kTestCaptchaResponse);
  XCTAssertTrue([_RPCIssuer.decodedRequest[kReturnSecureTokenKey] boolValue]);
}

@end
