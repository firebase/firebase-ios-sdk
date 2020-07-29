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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyClientRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyClientResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kFakeAppToken
    @brief The fake app token to use in the test request.
 */
static NSString *const kFakeAppToken = @"appToken";

/** @var kFakeAPIKey
    @brief The fake API key to use in the test request.
 */
static NSString *const kFakeAPIKey = @"APIKey";

/** @var kAppTokenKey
    @brief The key for the appToken request paramenter.
 */
static NSString *const kAPPTokenKey = @"appToken";

/** @var kIsSandboxKey
    @brief The key for the isSandbox request parameter
 */
static NSString *const kIsSandboxKey = @"isSandbox";

/** @var kReceiptKey
    @brief The key for the receipt response paramenter.
 */
static NSString *const kReceiptKey = @"receipt";

/** @var kFakeReceipt
    @brief The fake receipt returned in the response.
 */
static NSString *const kFakeReceipt = @"receipt";

/** @var kSuggestedTimeOutKey
    @brief The key for the suggested timeout response parameter
 */
static NSString *const kSuggestedTimeOutKey = @"suggestedTimeout";

/** @var kFakeSuggestedTimeout
    @brief The fake suggested timeout returned in the response.
 */
static NSString *const kFakeSuggestedTimeout = @"1234";

/** @var kAllowedTimeDifference
    @brief Allowed difference when comparing times because of execution time and floating point
        error.
 */
static const double kAllowedTimeDifference = 0.1;

/** @var kMissingAppCredentialErrorMessage
    @brief This is the error message the server will respond with if the APNS token is missing in a
        verifyClient request is missing.
 */
static NSString *const kMissingAppCredentialErrorMessage = @"MISSING_APP_CREDENTIAL";

/** @var kMissingAppCredentialErrorMessage
    @brief This is the error message the server will respond with if the APNS token is missing in a
        verifyClient request is invalid.
 */
static NSString *const kInvalidAppCredentialErrorMessage = @"INVALID_APP_CREDENTIAL";

@interface FIRVerifyClientResponseTests : XCTestCase
@end

@implementation FIRVerifyClientResponseTests {
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
  _requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kFakeAPIKey];
}

/** @fn testMissingAppCredentialError
    @brief Tests that @c FIRAuthErrorCodeMissingAppCredential error.
 */
- (void)testMissingAppCredentialError {
  FIRVerifyClientRequest *request =
      [[FIRVerifyClientRequest alloc] initWithAppToken:kFakeAppToken
                                             isSandbox:YES
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyClientResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyClient:request
          callback:^(FIRVerifyClientResponse *_Nullable response, NSError *_Nullable error) {
            RPCResponse = response;
            RPCError = error;
            callbackInvoked = YES;
          }];
  [_RPCIssuer respondWithServerErrorMessage:kMissingAppCredentialErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeMissingAppCredential);
}

/** @fn testInvalidAppCredentialError
    @brief Tests that @c FIRAuthErrorCodeInvalidAppCredential error.
 */
- (void)testInvalidAppCredentialError {
  FIRVerifyClientRequest *request =
      [[FIRVerifyClientRequest alloc] initWithAppToken:kFakeAppToken
                                             isSandbox:YES
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyClientResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyClient:request
          callback:^(FIRVerifyClientResponse *_Nullable response, NSError *_Nullable error) {
            RPCResponse = response;
            RPCError = error;
            callbackInvoked = YES;
          }];
  [_RPCIssuer respondWithServerErrorMessage:kInvalidAppCredentialErrorMessage];
  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidAppCredential);
}

/** @fn testSuccessfulVerifyClientResponse
    @brief Tests a succesful attempt of the verify password flow.
 */
- (void)testSuccessfulVerifyPasswordResponse {
  FIRVerifyClientRequest *request =
      [[FIRVerifyClientRequest alloc] initWithAppToken:kFakeAppToken
                                             isSandbox:YES
                                  requestConfiguration:_requestConfiguration];
  __block BOOL callbackInvoked;
  __block FIRVerifyClientResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      verifyClient:request
          callback:^(FIRVerifyClientResponse *_Nullable response, NSError *_Nullable error) {
            RPCResponse = response;
            RPCError = error;
            callbackInvoked = YES;
          }];

  [_RPCIssuer
      respondWithJSON:@{kReceiptKey : kFakeReceipt, kSuggestedTimeOutKey : kFakeSuggestedTimeout}];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.receipt, kFakeReceipt);
  NSTimeInterval suggestedTimeout = [RPCResponse.suggestedTimeOutDate timeIntervalSinceNow];
  XCTAssertEqualWithAccuracy(suggestedTimeout, [kFakeSuggestedTimeout doubleValue],
                             kAllowedTimeDifference);
}

@end

#endif
