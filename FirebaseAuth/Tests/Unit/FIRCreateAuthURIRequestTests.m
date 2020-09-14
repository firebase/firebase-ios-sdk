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
#import "FirebaseAuth/Sources/Backend/RPC/FIRCreateAuthURIRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRCreateAuthURIResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestAuthUri
    @brief The test value of the "authURI" property in the json response.
 */
static NSString *const kTestAuthUri = @"AuthURI";

/** @var kTestIdentifier
    @brief Fake identifier key used for testing.
 */
static NSString *const kTestIdentifier = @"Identifier";

/** @var kContinueURITestKey
    @brief The key for the "continueUri" value in the request.
 */
static NSString *const kContinueURITestKey = @"continueUri";

/** @var kTestContinueURI
    @brief Fake Continue URI key used for testing.
 */
static NSString *const kTestContinueURI = @"ContinueUri";

/** @var kExpectedAPIURL
    @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/createAuthUri?key=APIKey";

/** @class FIRCreateAuthURIRequestTests
    @brief Tests for @c CreateAuthURIRequest.
 */
@interface FIRCreateAuthURIRequestTests : XCTestCase
@end
@implementation FIRCreateAuthURIRequestTests {
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

/** @fn testCreateAuthUriRequest
    @brief Tests the encoding of an create auth URI request.
 */
- (void)testEmailVerificationRequest {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRCreateAuthURIRequest *request =
      [[FIRCreateAuthURIRequest alloc] initWithIdentifier:kTestIdentifier
                                              continueURI:kTestContinueURI
                                     requestConfiguration:requestConfiguration];

  [FIRAuthBackend
      createAuthURI:request
           callback:^(FIRCreateAuthURIResponse *_Nullable response, NSError *_Nullable error){
           }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kContinueURITestKey], kTestContinueURI);
}

@end
