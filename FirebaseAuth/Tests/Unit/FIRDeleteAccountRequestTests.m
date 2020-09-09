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
#import "FirebaseAuth/Sources/Backend/RPC/FIRDeleteAccountRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRDeleteAccountResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kLocalID
    @brief Fake LocalID used for testing.
 */
static NSString *const kLocalID = @"LocalID";

/** @var kLocalIDKey
    @brief The name of the "localID" property in the request.
 */
static NSString *const kLocalIDKey = @"localId";

/** @var kAccessToken
    @brief The name of the "AccessToken" property in the request.
 */
static NSString *const kAccessToken = @"AccessToken";

/** @var kExpectedAPIURL
    @brief The expected URL for test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/deleteAccount?key=APIKey";

/** @class FIRDeleteUserRequestTests
    @brief Tests for @c FIRDeleteAccountRequest.
 */
@interface FIRDeleteAccountRequestTests : XCTestCase
@end
@implementation FIRDeleteAccountRequestTests {
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

/** @fn testDeleteAccountRequest
    @brief Tests the delete account request.
 */
- (void)testDeleteAccountRequest {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRDeleteAccountRequest *request =
      [[FIRDeleteAccountRequest alloc] initWitLocalID:kLocalID
                                          accessToken:kAccessToken
                                 requestConfiguration:requestConfiguration];
  __block BOOL callbackInvoked;
  __block NSError *RPCError;
  [FIRAuthBackend deleteAccount:request
                       callback:^(NSError *_Nullable error) {
                         callbackInvoked = YES;
                         RPCError = error;
                       }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertNotNil(_RPCIssuer.decodedRequest[kLocalIDKey]);
}

@end
