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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIREmailLinkSignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIREmailLinkSignInResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestEmail
    @brief The key for the "email" value in the request.
 */
static NSString *const kTestEmail = @"TestEmail@email.com";

/** @var kTestOOBCode
    @brief The test value for the "oobCode" in the request.
 */
static NSString *const kTestOOBCode = @"TestOOBCode";

/** @var kTestIDToken
    @brief The test value for "idToken" in the request.
 */
static NSString *const kTestIDToken = @"testIDToken";

/** @var kEmailKey
    @brief The key for the "identifier" value in the request.
 */
static NSString *const kEmailKey = @"email";

/** @var kEmailLinkKey
    @brief The key for the "oobCode" value in the request.
 */
static NSString *const kOOBCodeKey = @"oobCode";

/** @var kIDTokenKey
    @brief The key for the "IDToken" value in the request.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kExpectedAPIURL
    @brief The value of the expected URL (including the backend endpoint) in the request.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/emailLinkSignin?key=APIKey";

/** @class FIREmailLinkRequestTests
    @brief Tests for @c FIREmailLinkRequests.
 */
@interface FIREmailLinkRequestTests : XCTestCase
@end

@implementation FIREmailLinkRequestTests {
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

/** @fn testEmailLinkRequestCreation
    @brief Tests the email link sign-in request with mandatory parameters.
 */
- (void)testEmailLinkRequest {
  FIREmailLinkSignInRequest *request =
      [[FIREmailLinkSignInRequest alloc] initWithEmail:kTestEmail
                                               oobCode:kTestOOBCode
                                  requestConfiguration:_requestConfiguration];
  [FIRAuthBackend
      emailLinkSignin:request
             callback:^(FIREmailLinkSignInResponse *_Nullable response, NSError *_Nullable error){
             }];
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kEmailKey], kTestEmail);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kOOBCodeKey], kTestOOBCode);
  XCTAssertNil(_RPCIssuer.decodedRequest[kIDTokenKey]);
}

/** @fn testEmailLinkRequestCreationOptional
    @brief Tests the email link sign-in request with mandatory parameters and optional ID token.
 */
- (void)testEmailLinkRequestCreationOptional {
  FIREmailLinkSignInRequest *request =
      [[FIREmailLinkSignInRequest alloc] initWithEmail:kTestEmail
                                               oobCode:kTestOOBCode
                                  requestConfiguration:_requestConfiguration];
  request.IDToken = kTestIDToken;
  [FIRAuthBackend
      emailLinkSignin:request
             callback:^(FIREmailLinkSignInResponse *_Nullable response, NSError *_Nullable error){
             }];
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kEmailKey], kTestEmail);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kOOBCodeKey], kTestOOBCode);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIDTokenKey], kTestIDToken);
}

@end

#endif
