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
#import "FirebaseAuth/Sources/Backend/RPC/FIRResetPasswordRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRResetPasswordResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestOOBCode
    @brief Fake OOBCode used for testing.
 */
static NSString *const kTestOOBCode = @"OOBCode";

/** @var kTestNewPassword
    @brief Fake new password used for testing.
 */
static NSString *const kTestNewPassword = @"newPassword:-)";

/** @var kOOBCodeKey
    @brief The "resetPassword" key.
 */
static NSString *const kOOBCodeKey = @"oobCode";

/** @var knewPasswordKey
    @brief The "newPassword" key.
 */
static NSString *const knewPasswordKey = @"newPassword";

/** @var kExpectedAPIURL
    @brief The expected URL for test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/resetPassword?key=APIKey";

/** @class FIRResetPasswordRequestTests
    @brief Tests for @c FIRResetPasswordRequest.
 */
@interface FIRResetPasswordRequestTest : XCTestCase
@end

@implementation FIRResetPasswordRequestTest {
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

/** @fn testResetPasswordRequest
    @brief Tests the reset password reqeust.
 */
- (void)testResetPasswordRequest {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRResetPasswordRequest *request =
      [[FIRResetPasswordRequest alloc] initWithOobCode:kTestOOBCode
                                           newPassword:kTestNewPassword
                                  requestConfiguration:requestConfiguration];
  [FIRAuthBackend
      resetPassword:request
           callback:^(FIRResetPasswordResponse *_Nullable response, NSError *_Nullable error){

           }];
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[knewPasswordKey], kTestNewPassword);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kOOBCodeKey], kTestOOBCode);
}

@end
