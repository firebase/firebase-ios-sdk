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

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeResponse.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredential.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kTestPhoneNumber
    @brief Fake phone number used for testing.
 */
static NSString *const kTestPhoneNumber = @"12345678";

/** @var kTestSecret
    @brief Fake secret used for testing.
 */
static NSString *const kTestSecret = @"secret";

/** @var kTestReceipt
    @brief Fake receipt used for testing.
 */
static NSString *const kTestReceipt = @"receipt";

/** @var kTestReCAPTCHAToken
    @brief Fake reCAPTCHA token used for testing.
 */
static NSString *const kTestReCAPTCHAToken = @"reCAPTCHAToken";

/** @var kPhoneNumberKey
    @brief The key for the "phone number" value in the request.
 */
static NSString *const kPhoneNumberKey = @"phoneNumber";

/** @var kReceiptKey
    @brief The key for the receipt parameter in the request.
 */
static NSString *const kReceiptKey = @"iosReceipt";

/** @var kSecretKey
    @brief The key for the Secret parameter in the request.
 */
static NSString *const kSecretKey = @"iosSecret";

/** @var kExpectedAPIURL
    @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/sendVerificationCode?key=APIKey";

/** @class FIRSendVerificationCodeRequestTests
    @brief Tests for @c FIRSendVerificationCodeRequest.
 */
@interface FIRSendVerificationCodeRequestTests : XCTestCase
@end

@implementation FIRSendVerificationCodeRequestTests {
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

/** @fn testSendVerificationCodeRequest
    @brief Tests the sendVerificationCode request.
 */
- (void)testSendVerificationCodeRequest {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey];
  FIRAuthAppCredential *credential = [[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt
                                                                            secret:kTestSecret];
  FIRSendVerificationCodeRequest *request =
      [[FIRSendVerificationCodeRequest alloc] initWithPhoneNumber:kTestPhoneNumber
                                                    appCredential:credential
                                                   reCAPTCHAToken:kTestReCAPTCHAToken
                                             requestConfiguration:requestConfiguration];
  XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
  XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
  XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
  XCTAssertEqualObjects(request.reCAPTCHAToken, kTestReCAPTCHAToken);

  [FIRAuthBackend sendVerificationCode:request
                              callback:^(FIRSendVerificationCodeResponse *_Nullable response,
                                         NSError *_Nullable error){
                              }];
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPhoneNumberKey], kTestPhoneNumber);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPhoneNumberKey], kTestPhoneNumber);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kReceiptKey], kTestReceipt);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kSecretKey], kTestSecret);
}

@end

#endif
