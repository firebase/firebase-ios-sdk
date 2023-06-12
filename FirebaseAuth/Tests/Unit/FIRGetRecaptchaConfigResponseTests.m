/*
 * Copyright 2022 Google LLC
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
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthInternalErrors.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestFirebaseAppID
    @brief Fake Firebase app ID used for testing.
 */
static NSString *const kTestFirebaseAppID = @"appID";

/** @var kTestRecaptchaID
    @brief Fake Recaptcha ID used for testing.
 */
static NSString *const kTestRecaptchaKey = @"projects/123/keys/456";

@interface FIRGetRecaptchaConfigResponseTests : XCTestCase
@end

@implementation FIRGetRecaptchaConfigResponseTests {
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

/** @fn testSuccessFulGetRecaptchaConfigRequest
    @brief This test simulates a successful @c getRecaptchaConfig Flow.
 */
- (void)testSuccessFulGetRecaptchaConfigRequest {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey appID:kTestFirebaseAppID];
  FIRGetRecaptchaConfigRequest *request =
      [[FIRGetRecaptchaConfigRequest alloc] initWithRequestConfiguration:requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRGetRecaptchaConfigResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend getRecaptchaConfig:request
                            callback:^(FIRGetRecaptchaConfigResponse *_Nullable response,
                                       NSError *_Nullable error) {
                              callbackInvoked = YES;
                              RPCResponse = response;
                              RPCError = error;
                            }];

  [_RPCIssuer respondWithJSON:@{
    @"recaptchaKey" : kTestRecaptchaKey,
  }];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertEqualObjects(kTestRecaptchaKey, RPCResponse.recaptchaKey);
}

@end
