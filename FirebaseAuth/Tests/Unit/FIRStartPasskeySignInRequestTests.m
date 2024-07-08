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
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_OSX || TARGET_OS_MACCATALYST

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Backend/RPC/FIRStartPasskeySignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRStartPasskeySignInResponse.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/**
 @var kTestAPIKey
 @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/**
 @var kTestFirebaseAppID
 @brief Fake Firebase app ID used for testing.
 */
static NSString *const kTestFirebaseAppID = @"appID";

/**
 @var kExpectedAPIURL
 @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://identitytoolkit.googleapis.com/v2/accounts/passkeySignIn:start?key=APIKey";

/**
 @class FIRStartPasskeySignInRequestTests
 @brief Tests for @c FIRStartPasskeySignInRequest.
 */
@interface FIRStartPasskeySignInRequestTests : XCTestCase
@end

@implementation FIRStartPasskeySignInRequestTests {
  /**
   @brief This backend RPC issuer is used to fake network responses for each test in the suite.
   In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
   */
  FIRFakeBackendRPCIssuer *_RPCIssuer;

  /**
   @brief This is the request configuration used for testing.
   */
  FIRAuthRequestConfiguration *_requestConfiguration;
}

- (void)setUp {
  [super setUp];
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  _RPCIssuer = RPCIssuer;
  _requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey
                                                                        appID:kTestFirebaseAppID];
}

- (void)tearDown {
  _RPCIssuer = nil;
  _requestConfiguration = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

- (void)testStartPasskeySignInRequest {
  FIRStartPasskeySignInRequest *request =
      [[FIRStartPasskeySignInRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  [FIRAuthBackend startPasskeySignIn:request
                            callback:^(FIRStartPasskeySignInResponse *_Nullable response,
                                       NSError *_Nullable error){
                            }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
}

@end
#endif
