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

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kTestAccessToken
    @bried Fake acess token for testing.
 */
static NSString *const kTestAccessToken = @"accessToken";

/** @var kDisplayNameKey
    @brief The key for the "displayName" value in the request.
 */
static NSString *const kDisplayNameKey = @"displayName";

/** @var kTestDisplayName
    @brief The fake @c displayName for testing.
 */
static NSString *const kTestDisplayName = @"testDisplayName";

/** @var kLocalIDKey
    @brief The key for the "localID" value in the request.
 */
static NSString *const kLocalIDKey = @"localId";

/** @var kTestLocalID
    @brief The fake @c localID for testing in the request.
 */
static NSString *const kTestLocalID = @"testLocalId";

/** @var kEmailKey
    @brief The key for the "email" value in the request.
 */
static NSString *const kEmailKey = @"email";

/** @var kTestEmail
    @brief The fake @c email used for testing in the request.
 */
static NSString *const ktestEmail = @"testEmail";

/** @var kPasswordKey
    @brief The key for the "password" value in the request.
 */
static NSString *const kPasswordKey = @"password";

/** @var kTestPassword
    @brief The fake @c password used for testing in the request.
 */
static NSString *const kTestPassword = @"testPassword";

/** @var kPhotoURLKey
    @brief The key for the "photoURL" value in the request.
 */
static NSString *const kPhotoURLKey = @"photoUrl";

/** @var kTestPhotoURL
    @brief The fake photoUrl for testing in the request.
 */
static NSString *const kTestPhotoURL = @"testPhotoUrl";

/** @var kProvidersKey
    @brief The key for the "providers" value in the request.
 */
static NSString *const kProvidersKey = @"provider";

/** @var kTestProviders
    @brief The fake @c providers value used for testing in the request.
 */
static NSString *const kTestProviders = @"testProvider";

/** @var kOOBCodeKey
    @brief The key for the "OOBCode" value in the request.
 */
static NSString *const kOOBCodeKey = @"oobCode";

/** @var kTestOOBCode
    @brief The fake @c OOBCode used for testing the request.
 */
static NSString *const kTestOOBCode = @"testOobCode";

/** @var kEmailVerifiedKey
    @brief The key for the "emailVerified" value in the request.
 */
static NSString *const kEmailVerifiedKey = @"emailVerified";

/** @var kTestEmailVerified
    @brief The fake @c emailVerified value used for testing the request.
 */
static const BOOL kTestEmailVerified = YES;

/** @var kUpgradeToFederatedLoginKey
    @brief The key for the "upgradeToFederatedLogin" value in the request.
 */
static NSString *const kUpgradeToFederatedLoginKey = @"upgradeToFederatedLogin";

/** @var kTestUpgradeToFederatedLogin
    @brief The fake @c upgradeToFederatedLogin value for testing the request.
 */
static const BOOL kTestUpgradeToFederatedLogin = YES;

/** @var kCaptchaChallengeKey
    @brief The key for the "captchaChallenge" value in the request.
 */
static NSString *const kCaptchaChallengeKey = @"captchaChallenge";

/** @var kTestCaptchaChallenge
    @brief The fake @c captchaChallenge for testing in the request.
 */
static NSString *const kTestCaptchaChallenge = @"TestCaptchaChallenge";

/** @var kCaptchaResponseKey
    @brief The key for the "captchaResponse" value the request.
 */
static NSString *const kCaptchaResponseKey = @"captchaResponse";

/** @var kTestCaptchaResponse
    @brief The fake @c captchaResponse for testing the request.
 */
static NSString *const kTestCaptchaResponse = @"TestCaptchaResponse";

/** @var kDeleteAttributesKey
    @brief The key for the "deleteAttribute" value in the request.
 */
static NSString *const kDeleteAttributesKey = @"deleteAttribute";

/** @var kTestDeleteAttributes
    @brief The fake @c deleteAttribute value for testing the request.
 */
static NSString *const kTestDeleteAttributes = @"TestDeleteAttributes";

/** @var kDeleteProvidersKey
    @brief The key for the "deleteProvider" value in the request.
 */
static NSString *const kDeleteProvidersKey = @"deleteProvider";

/** @var kTestDeleteProviders
    @brief The fake @c deleteProviders for testing the request.
 */
static NSString *const kTestDeleteProviders = @"TestDeleteProviders";

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
static NSString *const kReturnSecureTokenKey = @"returnSecureToken";

/** @var kExpectedAPIURL
    @brief The expected URL for test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/setAccountInfo?key=APIKey";

/** @class FIRSetAccountInfoRequestTests
    @brief Tests for @c FIRSetAccountInfoRequest.
 */
@interface FIRSetAccountInfoRequestTests : XCTestCase
@end
@implementation FIRSetAccountInfoRequestTests {
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

/** @fn testSetAccountInfoRequest
    @brief Tests the set account info request.
 */
- (void)testSetAccountInfoRequest {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];
  request.returnSecureToken = NO;
  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error){
            }];

  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kIDTokenKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kDisplayNameKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kLocalIDKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kEmailKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kPasswordKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kPhotoURLKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kProvidersKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kOOBCodeKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kEmailVerifiedKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kUpgradeToFederatedLoginKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kCaptchaChallengeKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kCaptchaResponseKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kDeleteAttributesKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kDeleteProvidersKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kReturnSecureTokenKey]);
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
}

/** @fn testSetAccountInfoRequestOptionalFields
    @brief Tests the set account info request with optional fields.
 */
- (void)testSetAccountInfoRequestOptionalFields {
  FIRSetAccountInfoRequest *request =
      [[FIRSetAccountInfoRequest alloc] initWithRequestConfiguration:_requestConfiguration];
  request.accessToken = kTestAccessToken;
  request.displayName = kTestDisplayName;
  request.localID = kTestLocalID;
  request.email = ktestEmail;
  request.password = kTestPassword;
  request.providers = @[ kTestProviders ];
  request.OOBCode = kTestOOBCode;
  request.emailVerified = kTestEmailVerified;
  request.photoURL = [NSURL URLWithString:kTestPhotoURL];
  request.upgradeToFederatedLogin = kTestUpgradeToFederatedLogin;
  request.captchaChallenge = kTestCaptchaChallenge;
  request.captchaResponse = kTestCaptchaResponse;
  request.deleteAttributes = @[ kTestDeleteAttributes ];
  request.deleteProviders = @[ kTestDeleteProviders ];

  [FIRAuthBackend
      setAccountInfo:request
            callback:^(FIRSetAccountInfoResponse *_Nullable response, NSError *_Nullable error){
            }];

  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIDTokenKey], kTestAccessToken);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kDisplayNameKey], kTestDisplayName);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kLocalIDKey], kTestLocalID);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kEmailKey], ktestEmail);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPasswordKey], kTestPassword);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPhotoURLKey], kTestPhotoURL);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kProvidersKey], @[ kTestProviders ]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kOOBCodeKey], kTestOOBCode);
  XCTAssert(_RPCIssuer.decodedRequest[kEmailVerifiedKey]);
  XCTAssert(_RPCIssuer.decodedRequest[kUpgradeToFederatedLoginKey]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kCaptchaChallengeKey], kTestCaptchaChallenge);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kCaptchaResponseKey], kTestCaptchaResponse);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kDeleteAttributesKey],
                        @[ kTestDeleteAttributes ]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kDeleteProvidersKey], @[ kTestDeleteProviders ]);
  XCTAssertTrue([_RPCIssuer.decodedRequest[kReturnSecureTokenKey] boolValue]);
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
}

@end
