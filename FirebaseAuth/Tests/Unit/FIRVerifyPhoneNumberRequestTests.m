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

#import "FirebaseAuth/Sources/Auth/FIRAuthOperationType.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPhoneNumberRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPhoneNumberResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kVerificationCode
    @brief Fake verification code used for testing.
 */
static NSString *const kVerificationCode = @"12345678";

/** @var kVerificationID
    @brief Fake verification ID for testing.
 */
static NSString *const kVerificationID = @"55432";

/** @var kPhoneNumber
    @brief The fake user phone number.
 */
static NSString *const kPhoneNumber = @"12345658";

/** @var kTemporaryProof
    @brief The fake temporary proof.
 */
static NSString *const kTemporaryProof = @"12345658";

/** @var kVerificationCodeKey
    @brief The key for the verification code" value in the request.
 */
static NSString *const kVerificationCodeKey = @"code";

/** @var kVerificationIDKey
    @brief The key for the verification ID" value in the request.
 */
static NSString *const kVerificationIDKey = @"sessionInfo";

/** @var kIDTokenKey
    @brief The key for the "ID Token" value in the request.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kOperationKey
    @brief The key for the "operation" value in the request.
 */
static NSString *const kOperationKey = @"operation";

/** @var kTestAccessToken
    @bried Fake acess token for testing.
 */
static NSString *const kTestAccessToken = @"accessToken";

/** @var kTemporaryProofKey
   @brief The key for the temporary proof value in the request.
*/
static NSString *const kTemporaryProofKey = @"temporaryProof";

/** @var kPhoneNumberKey
    @brief The key for the phone number value in the request.
 */
static NSString *const kPhoneNumberKey = @"phoneNumber";

/** @var kExpectedAPIURL
    @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPhoneNumber?key=APIKey";

/** @Extension FIRVerifyPhoneNumberRequest
    @brief Exposes FIRAuthOperationString from FIRVerifyPhoneNumberRequest to assist testing.
 */
@interface FIRVerifyPhoneNumberRequest ()

/** @fn FIRAuthOperationString
    @brief Exposes FIRAuthOperationString from FIRVerifyPhoneNumberRequest to assist testing.
    @param operationType The value of the FIRAuthOperationType enum which will be translated to its
        corresponding string value.
    @return The string value corresponding to the FIRAuthOperationType argument.

 */
NSString *const FIRAuthOperationString(FIRAuthOperationType operationType);

@end

/** @class FIRVerifyPhoneNumberRequestTests
    @brief Tests for @c FIRVerifyPhoneNumberRequest.
 */
@interface FIRVerifyPhoneNumberRequestTests : XCTestCase
@end

@implementation FIRVerifyPhoneNumberRequestTests {
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

- (void)tearDown {
  _RPCIssuer = nil;
  _requestConfiguration = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testVerifyPhoneNumberRequest
    @brief Tests the verifyPhoneNumber request.
 */
- (void)testVerifyPhoneNumberRequest {
  FIRVerifyPhoneNumberRequest *request =
      [[FIRVerifyPhoneNumberRequest alloc] initWithVerificationID:kVerificationID
                                                 verificationCode:kVerificationCode
                                                        operation:FIRAuthOperationTypeSignUpOrSignIn
                                             requestConfiguration:_requestConfiguration];
  request.accessToken = kTestAccessToken;
  [FIRAuthBackend verifyPhoneNumber:request
                           callback:^(FIRVerifyPhoneNumberResponse *_Nullable response,
                                      NSError *_Nullable error){
                           }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kVerificationIDKey], kVerificationID);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kVerificationCodeKey], kVerificationCode);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIDTokenKey], kTestAccessToken);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kOperationKey],
                        FIRAuthOperationString(FIRAuthOperationTypeSignUpOrSignIn));
}

/** @fn testVerifyPhoneNumberRequestWithTemporaryProof
    @brief Tests the verifyPhoneNumber request when created using a temporary proof.
 */
- (void)testVerifyPhoneNumberRequestWithTemporaryProof {
  FIRVerifyPhoneNumberRequest *request =
      [[FIRVerifyPhoneNumberRequest alloc] initWithTemporaryProof:kTemporaryProof
                                                      phoneNumber:kPhoneNumber
                                                        operation:FIRAuthOperationTypeSignUpOrSignIn
                                             requestConfiguration:_requestConfiguration];
  request.accessToken = kTestAccessToken;
  [FIRAuthBackend verifyPhoneNumber:request
                           callback:^(FIRVerifyPhoneNumberResponse *_Nullable response,
                                      NSError *_Nullable error){
                           }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kTemporaryProofKey], kTemporaryProof);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPhoneNumberKey], kPhoneNumber);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIDTokenKey], kTestAccessToken);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kOperationKey],
                        FIRAuthOperationString(FIRAuthOperationTypeSignUpOrSignIn));
}

@end

#endif
