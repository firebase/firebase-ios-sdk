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
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignUpNewUserRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignUpNewUserResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kExpectedAPIURL
    @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=APIKey";

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kEmailKey
    @brief The name of the "email" property in the request.
 */
static NSString *const kEmailKey = @"email";

/** @var kTestEmail
    @brief Testing user email adadress.
 */
static NSString *const kTestEmail = @"test@gmail.com";

/** @var kDisplayNameKey
    @brief the name of the "displayName" property in the request.
 */
static NSString *const kDisplayNameKey = @"displayName";

/** @var kTestDisplayName
    @brief Testing display name.
 */
static NSString *const kTestDisplayName = @"DisplayName";

/** @var kPasswordKey
    @brief the name of the "password" property in the request.
 */
static NSString *const kPasswordKey = @"password";

/** @var kTestPassword
    @brief Testing password.
 */
static NSString *const kTestPassword = @"Password";

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
static NSString *const kReturnSecureTokenKey = @"returnSecureToken";

@interface FIRSignUpNewUserRequestTests : XCTestCase

@end

@implementation FIRSignUpNewUserRequestTests {
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
  _requestConfiguration = nil;
  _RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testSignUpNewUserRequestAnonymous
    @brief Tests the encoding of a sign up new user request when user is signed in anonymously.
 */
- (void)testSignUpNewUserRequestAnonymous {
  FIRSignUpNewUserRequest *request =
      [[FIRSignUpNewUserRequest alloc] initWithRequestConfiguration:_requestConfiguration];
  request.returnSecureToken = NO;
  [FIRAuthBackend
      signUpNewUser:request
           callback:^(FIRSignUpNewUserResponse *_Nullable response, NSError *_Nullable error){
           }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kEmailKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kDisplayNameKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kPasswordKey]);
  XCTAssertNil(_RPCIssuer.decodedRequest[kReturnSecureTokenKey]);
}

/** @fn testSignUpNewUserRequestNotAnonymous
    @brief Tests the encoding of a sign up new user request when user is not signed in anonymously.
 */
- (void)testSignUpNewUserRequestNotAnonymous {
  FIRSignUpNewUserRequest *request =
      [[FIRSignUpNewUserRequest alloc] initWithEmail:kTestEmail
                                            password:kTestPassword
                                         displayName:kTestDisplayName
                                requestConfiguration:_requestConfiguration];
  [FIRAuthBackend
      signUpNewUser:request
           callback:^(FIRSignUpNewUserResponse *_Nullable response, NSError *_Nullable error){
           }];

  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssert([_RPCIssuer.decodedRequest isKindOfClass:[NSDictionary class]]);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kEmailKey], kTestEmail);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kPasswordKey], kTestPassword);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kDisplayNameKey], kTestDisplayName);
  XCTAssertTrue([_RPCIssuer.decodedRequest[kReturnSecureTokenKey] boolValue]);
}

@end
