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

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend+MultiFactor.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/SignIn/FIRFinalizeMFASignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/SignIn/FIRFinalizeMFASignInResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoFinalizeMFATotpSignInRequestInfo.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestFirebaseAppID
    @brief Fake Firebase app ID used for testing.
 */
static NSString *const kTestFirebaseAppID = @"appID";

static NSString *const kExpectedAPIURL =
    @"https://identitytoolkit.googleapis.com/v2/accounts/mfaSignIn:finalize?key=APIKey";

static NSString *const kMfaPendingCredential = @"mfaPendingCredential";

static NSString *const kVerificationCode = @"verificationCode";

static NSString *const kMfaEnrollmentID = @"mfaEnrollmentId";

static NSString *const kTotpVerificationInfo = @"totpVerificationInfo";

/** @class FIRFinalizeMFASignInRequestTest
    @brief Tests for @c FIRFinalizeMFASignInRequestTest.
 */
@interface FIRFinalizeMFASignInRequestTests : XCTestCase
@end
@implementation FIRFinalizeMFASignInRequestTests {
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
  _requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey
                                                                        appID:kTestFirebaseAppID];
}

- (void)tearDown {
  _RPCIssuer = nil;
  _requestConfiguration = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testTOTPFinalizeMFASignInRequest
    @brief Tests the Finalize MFA Sign in using TOTP request.
 */
- (void)testTOTPFinalizeMFASignInRequest {
  FIRAuthProtoFinalizeMFATotpSignInRequestInfo *requestInfo =
      [[FIRAuthProtoFinalizeMFATotpSignInRequestInfo alloc]
          initWithVerificationCode:kVerificationCode
                   mfaEnrollmentID:kMfaEnrollmentID];
  FIRFinalizeMFASignInRequest *request =
      [[FIRFinalizeMFASignInRequest alloc] initWithMFAPendingCredential:kMfaPendingCredential
                                                       verificationInfo:requestInfo
                                                   requestConfiguration:_requestConfiguration];

  [FIRAuthBackend finalizeMultiFactorSignIn:request
                                   callback:^(FIRFinalizeMFASignInResponse *_Nullable response,
                                              NSError *_Nullable error){
                                   }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kMfaPendingCredential], kMfaPendingCredential);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kMfaEnrollmentID], kMfaEnrollmentID);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kTotpVerificationInfo][kVerificationCode],
                        kVerificationCode);
}

@end
