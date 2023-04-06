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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRRevokeTokenRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRRevokeTokenResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kFakeToken
    @brief The fake token to use in the test request.
 */
static NSString *const kFakeToken = @"fakeToken";

/** @var kFakeIDToken
    @brief The fake ID token to use in the test request.
 */
static NSString *const kFakeIDToken = @"fakeIDToken";

/** @var kFakeToken
    @brief The fake token to use in the test request.
 */
static NSString *const kFakeTokenKey = @"tokenKey";

/** @var kFakeIDToken
    @brief The fake ID token to use in the test request.
 */
static NSString *const kFakeIDTokenKey = @"idTokenKey";

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
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/revokeToken?key=APIKey";

@interface FIRRevokeTokenResponseTests : XCTestCase
@end

@implementation FIRRevokeTokenResponseTests {
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
  _requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kFakeAPIKey
                                                                        appID:kFakeFirebaseAppID];
}

/** @fn testSuccessfulRevokeTokenResponse
    @brief Tests a successful attempt of the token revocation flow.
 */
- (void)testSuccessfulResponse {
  FIRRevokeTokenRequest *request =
      [[FIRRevokeTokenRequest alloc] initWithToken:kFakeToken
                                           idToken:kFakeIDToken
                              requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRRevokeTokenResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      revokeToken:request
         callback:^(FIRRevokeTokenResponse *_Nullable response, NSError *_Nullable error) {
           RPCResponse = response;
           RPCError = error;
           callbackInvoked = YES;
         }];

  [_RPCIssuer respondWithJSON:@{}];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCResponse);
}

@end

#endif
