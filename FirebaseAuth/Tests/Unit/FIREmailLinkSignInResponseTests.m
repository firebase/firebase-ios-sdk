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
#import "FirebaseAuth/Sources/Backend/RPC/FIREmailLinkSignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIREmailLinkSignInResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestEmail
    @brief The key for the "email" value in the request.
 */
static NSString *const kTestEmail = @"TestEmail@email.com";

/** @var kTestOOBCode
    @brief The test value for the "oobCode" in the request.
 */
static NSString *const kTestOOBCode = @"TestOOBCode";

/** @var kTestIDToken
    @brief The test value for "idToken" in the request.
 */
static NSString *const kTestIDToken = @"testIDToken";

/** @var kEmailKey
    @brief The key for the "identifier" value in the request.
 */
static NSString *const kEmailKey = @"email";

/** @var kEmailLinkKey
    @brief The key for the "emailLink" value in the request.
 */
static NSString *const kOOBCodeKey = @"oobCode";

/** @var kIDTokenKey
    @brief The key for the "IDToken" value in the request.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kTestIDTokenResponse
    @brief A fake ID Token in the server response.
 */
static NSString *const kTestIDTokenResponse = @"fakeToken";

/** @var kTestEmailResponse
    @brief A fake email in the server response.
 */
static NSString *const kTestEmailResponse = @"fake email";

/** @var kTestRefreshToken
    @brief A fake refresh token in the server response.
 */
static NSString *const kTestRefreshToken = @"testRefreshToken";

/** @var kInvalidEmailErrorMessage
    @brief The error returned by the server if the email is invalid.
 */
static NSString *const kInvalidEmailErrorMessage = @"INVALID_EMAIL";

/** @var kTestTokenExpirationTimeInterval
    @brief The fake time interval that it takes a token to expire.
 */
static const NSTimeInterval kTestTokenExpirationTimeInterval = 55 * 60;

/** @var kMaxDifferenceBetweenDates
    @brief The maximum difference between time two dates (in seconds), after which they will be
        considered different.
 */
static const NSTimeInterval kMaxDifferenceBetweenDates = 0.001;

/** @var kFakeIsNewUSerFlag
    @brief The fake fake isNewUser flag in the response.
 */
static const BOOL kFakeIsNewUSerFlag = YES;

/** @class FIREmailLinkRequestTests
    @brief Tests for @c FIREmailLinkRequests.
 */
@interface FIREmailLinkSignInResponseTests : XCTestCase
@end

@implementation FIREmailLinkSignInResponseTests {
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
  _requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
}

/** @fn testFailedEmailLinkSignInResponse
    @brief Tests a failed email link sign-in response.
 */
- (void)testFailedEmailLinkSignInResponse {
  FIREmailLinkSignInRequest *request =
      [[FIREmailLinkSignInRequest alloc] initWithEmail:kTestEmail
                                               oobCode:kTestOOBCode
                                  requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked = NO;
  __block FIREmailLinkSignInResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      emailLinkSignin:request
             callback:^(FIREmailLinkSignInResponse *_Nullable response, NSError *_Nullable error) {
               callbackInvoked = YES;
               RPCResponse = response;
               RPCError = error;
             }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidEmailErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCResponse);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidEmail);
}

/** @fn testSuccessfulEmailLinkSignInResponse
    @brief Tests a succesful email link sign-in response.
 */
- (void)testSuccessfulEmailLinkSignInResponse {
  FIREmailLinkSignInRequest *request =
      [[FIREmailLinkSignInRequest alloc] initWithEmail:kTestEmail
                                               oobCode:kTestOOBCode
                                  requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked = NO;
  __block FIREmailLinkSignInResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      emailLinkSignin:request
             callback:^(FIREmailLinkSignInResponse *_Nullable response, NSError *_Nullable error) {
               callbackInvoked = YES;
               RPCResponse = response;
               RPCError = error;
             }];

  [_RPCIssuer respondWithJSON:@{
    @"idToken" : kTestIDTokenResponse,
    @"email" : kTestEmailResponse,
    @"isNewUser" : kFakeIsNewUSerFlag ? @YES : @NO,
    @"expiresIn" : [NSString stringWithFormat:@"%f", kTestTokenExpirationTimeInterval],
    @"refreshToken" : kTestRefreshToken,
  }];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.IDToken, kTestIDTokenResponse);
  XCTAssertEqualObjects(RPCResponse.email, kTestEmailResponse);
  XCTAssertEqualObjects(RPCResponse.refreshToken, kTestRefreshToken);
  XCTAssertTrue(RPCResponse.isNewUser);
  NSTimeInterval expirationTimeInterval =
      [RPCResponse.approximateExpirationDate timeIntervalSinceNow];
  NSTimeInterval testTimeInterval =
      [[NSDate dateWithTimeIntervalSinceNow:kTestTokenExpirationTimeInterval] timeIntervalSinceNow];
  NSTimeInterval timeIntervalDifference = fabs(expirationTimeInterval - testTimeInterval);
  XCTAssert(timeIntervalDifference < kMaxDifferenceBetweenDates);
}

@end

#endif
