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
#if TARGET_OS_IOS

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend+MultiFactor.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/Enroll/FIRStartMFAEnrollmentRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/Enroll/FIRStartMFAEnrollmentResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoStartMFATOTPEnrollmentRequestInfo.h"
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
    @"https://identitytoolkit.googleapis.com/v2/accounts/mfaEnrollment:start?key=APIKey";

/**
 @var kIDToken
 @brief Token representing the user's identity.
 */
static NSString *const kIDToken = @"idToken";

/**
 @var kTOTPSessionInfo
 @brief Information about the TOTP (Time-Based One-Time Password) Enrollment.
 */
static NSString *const kTOTPEnrollmentInfo = @"totpEnrollmentInfo";

/**
 @var kPhoneSessionInfo
 @brief Information about the Phone Enrollment.
 */
static NSString *const kPhoneEnrollmentInfo = @"enrollmentInfo";

/**
 @class FIRStartMFAEnrollmentRequestTests
 @brief Tests for @c FIRStartMFAEnrollmentRequest.
 */
@interface FIRStartMFAEnrollmentRequestTests : XCTestCase
@end

@implementation FIRStartMFAEnrollmentRequestTests {
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

/**
 @fn testTOTPStartMFAEnrollmentRequest
 @brief Tests the Start MFA Enrollment using TOTP request.
 */
- (void)testTOTPStartMFAEnrollmentRequest {
  FIRAuthProtoStartMFATOTPEnrollmentRequestInfo *requestInfo =
      [[FIRAuthProtoStartMFATOTPEnrollmentRequestInfo alloc] init];
  FIRStartMFAEnrollmentRequest *request =
      [[FIRStartMFAEnrollmentRequest alloc] initWithIDToken:kIDToken
                                         TOTPEnrollmentInfo:requestInfo
                                       requestConfiguration:_requestConfiguration];

  [FIRAuthBackend startMultiFactorEnrollment:request
                                    callback:^(FIRStartMFAEnrollmentResponse *_Nullable response,
                                               NSError *_Nullable error){
                                    }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIDToken], kIDToken);
  XCTAssertNotNil(_RPCIssuer.decodedRequest[kTOTPEnrollmentInfo]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kPhoneEnrollmentInfo]);
}

@end
#endif
