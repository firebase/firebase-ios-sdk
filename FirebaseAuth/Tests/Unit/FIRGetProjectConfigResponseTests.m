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
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetProjectConfigRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetProjectConfigResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthInternalErrors.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestProjectID
    @brief Fake project ID used for testing.
 */
static NSString *const kTestProjectID = @"21141651616";

/** @var kTestDomain1
    @brief Fake whitelisted domain used for testing.
 */
static NSString *const kTestDomain1 = @"localhost";

/** @var kTestDomain2
    @brief Fake whitelisted domain used for testing.
 */
static NSString *const kTestDomain2 = @"example.firebaseapp.com";

/** @var kMissingAPIKeyErrorMessage
    @brief The error message the server would respond with if the API Key was missing.
 */
static NSString *const kMissingAPIKeyErrorMessage = @"MISSING_API_KEY";

@interface FIRGetProjectConfigResponseTests : XCTestCase
@end

@implementation FIRGetProjectConfigResponseTests {
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

/** @fn testMissingAPIKeyError
    @brief This test simulates a missing API key error. Since the API key is provided to the backend
        from the auth library this error should map to an internal error.
 */
- (void)testMissingAPIKeyError {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRGetProjectConfigRequest *request =
      [[FIRGetProjectConfigRequest alloc] initWithRequestConfiguration:requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRGetProjectConfigResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getProjectConfig:request
                          callback:^(FIRGetProjectConfigResponse *_Nullable response,
                                     NSError *_Nullable error) {
                            callbackInvoked = YES;
                            RPCResponse = response;
                            RPCError = error;
                          }];

  [_RPCIssuer respondWithServerErrorMessage:kMissingAPIKeyErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqualObjects(RPCError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInternalError);
  XCTAssertNotNil(RPCError.userInfo[NSUnderlyingErrorKey]);
}

/** @fn testSuccessFulGetProjectConfigRequest
    @brief This test simulates a successful @c getProjectConfig Flow.
 */
- (void)testSuccessFulGetProjectConfigRequest {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRGetProjectConfigRequest *request =
      [[FIRGetProjectConfigRequest alloc] initWithRequestConfiguration:requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRGetProjectConfigResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getProjectConfig:request
                          callback:^(FIRGetProjectConfigResponse *_Nullable response,
                                     NSError *_Nullable error) {
                            callbackInvoked = YES;
                            RPCResponse = response;
                            RPCError = error;
                          }];

  [_RPCIssuer respondWithJSON:@{
    @"projectId" : kTestProjectID,
    @"authorizedDomains" : @[ kTestDomain1, kTestDomain2 ]
  }];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertEqualObjects(kTestProjectID, RPCResponse.projectID);
  XCTAssertEqualObjects(kTestDomain1, RPCResponse.authorizedDomains[0]);
  XCTAssertEqualObjects(kTestDomain2, RPCResponse.authorizedDomains[1]);
}

@end
