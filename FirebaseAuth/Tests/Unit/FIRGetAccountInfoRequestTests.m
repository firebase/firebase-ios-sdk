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

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetAccountInfoRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetAccountInfoResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeResponse.h"
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
    @brief testing token.
 */
static NSString *const kTestAccessToken = @"testAccessToken";

/** @var kExpectedAPIURL
    @brief The expected URL for test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken?key=APIKey";

@interface FIRGetAccountInfoRequestTests : XCTestCase
@end
@implementation FIRGetAccountInfoRequestTests {
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

/** @fn testGetAccountInfoRequest
    @brief Tests the set account info request.
 */
- (void)testGetAccountInfoRequest {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRGetAccountInfoRequest *request =
      [[FIRGetAccountInfoRequest alloc] initWithAccessToken:kTestAccessToken
                                       requestConfiguration:requestConfiguration];

  [FIRAuthBackend
      getAccountInfo:request
            callback:^(FIRGetAccountInfoResponse *_Nullable response, NSError *_Nullable error){

            }];
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertNotNil(_RPCIssuer.decodedRequest[kIDTokenKey]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIDTokenKey], kTestAccessToken);
}

@end
