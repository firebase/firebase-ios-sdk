/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRRevokeTokenRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRRevokeTokenResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kFakeToken
    @brief The fake token to use in the test request.
 */
static NSString *const kFakeTokenKey = @"token";

/** @var kFakeToken
    @brief The fake token to use in the test request.
 */
static NSString *const kFakeToken = @"fakeToken";

/** @var kFakeIDToken
    @brief The fake ID token to use in the test request.
 */
static NSString *const kFakeIDTokenKey = @"idToken";

/** @var kFakeIDToken
    @brief The fake ID token to use in the test request.
 */
static NSString *const kFakeIDToken = @"fakeIDToken";

/** @var kFakeProviderIDKey
    @brief The fake provider id key to use in the test request.
 */
static NSString *const kFakeProviderIDKey = @"providerId";

/** @var kFakeTokenTypeKey
    @brief The fake ID token to use in the test request.
 */
static NSString *const kFakeTokenTypeKey = @"tokenType";

/** @var kFakeAPIKey
    @brief The fake API key to use in the test request.
 */
static NSString *const kFakeAPIKey = @"APIKey";

/** @var kFakeFirebaseAppID
    @brief The fake Firebase app ID to use in the test request.
 */
static NSString *const kFakeFirebaseAppID = @"appID";

/** @var kExpectedAPIURL
    @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://identitytoolkit.googleapis.com/v2/accounts:revokeToken?key=APIKey";

/** @class FIRRevokeTokenRequestTest
    @brief Tests for @c FIRRevokeTokenRequests.
 */
@interface FIRRevokeTokenRequestTest : XCTestCase
@end

@implementation FIRRevokeTokenRequestTest {
  /** @var _RPCIssuer
      @brief This backend RPC issuer is used to fake network responses for each test in the suite.
          In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
   */
  FIRFakeBackendRPCIssuer *_RPCIssuer;
}

- (void)setUp {
  [super setUp];
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  _RPCIssuer = RPCIssuer;
}

- (void)tearDown {
  _RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testRevokeTokenRequest
    @brief Tests the token revocation request.
 */
- (void)testRevokeTokenRequest {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kFakeAPIKey appID:kFakeFirebaseAppID];
  FIRRevokeTokenRequest *request =
      [[FIRRevokeTokenRequest alloc] initWithToken:kFakeToken
                                           idToken:kFakeIDToken
                              requestConfiguration:requestConfiguration];
  [FIRAuthBackend
      revokeToken:request
         callback:^(FIRRevokeTokenResponse *_Nullable response, NSError *_Nullable error){
         }];
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kFakeIDTokenKey], kFakeIDToken);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kFakeTokenKey], kFakeToken);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kFakeProviderIDKey], @"apple.com");
  XCTAssertEqual([_RPCIssuer.decodedRequest[kFakeTokenTypeKey] intValue], 3);
}

@end

#endif
