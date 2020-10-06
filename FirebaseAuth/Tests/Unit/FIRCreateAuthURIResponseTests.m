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
#import "FirebaseAuth/Sources/Backend/RPC/FIRCreateAuthURIRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRCreateAuthURIResponse.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kTestAPIKey
    @brief Fake API key used for testing.
 */
static NSString *const kTestAPIKey = @"APIKey";

/** @var kAuthUriKey
    @brief The name of the "authURI" property in the json response.
 */
static NSString *const kAuthUriKey = @"authUri";

/** @var kTestAuthUri
    @brief The test value of the "authURI" property in the json response.
 */
static NSString *const kTestAuthUri = @"AuthURI";

/** @var kTestIdentifier
    @brief Fake identifier key used for testing.
 */
static NSString *const kTestIdentifier = @"Identifier";

/** @var kTestContinueURI
    @brief Fake Continue URI key used for testing.
 */
static NSString *const kTestContinueURI = @"ContinueUri";

/** @var kMissingContinueURIErrorMessage
    @brief The error returned by the server if continue Uri is invalid.
 */
static NSString *const kMissingContinueURIErrorMessage = @"MISSING_CONTINUE_URI:";

/** @var kInvalidEmailErrorMessage
    @brief The error returned by the server if the email is invalid.
 */
static NSString *const kInvalidIdentifierErrorMessage = @"INVALID_IDENTIFIER :";

/** @var kInvalidEmailErrorMessage
    @brief The error returned by the server if the email is invalid.
 */
static NSString *const kInvalidEmailErrorMessage = @"INVALID_EMAIL:";

/** @class CreateAuthURIResponseTests
    @brief Tests for @c FIRCreateAuthURIResponse.
 */
@interface FIRCreateAuthURIResponseTests : XCTestCase
@end
@implementation FIRCreateAuthURIResponseTests {
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

/** @fn testMissingContinueURIError
    @brief This test checks for invalid continue URI in the response.
 */
- (void)testMissingContinueURIError {
  FIRCreateAuthURIRequest *request =
      [[FIRCreateAuthURIRequest alloc] initWithIdentifier:kTestIdentifier
                                              continueURI:kTestContinueURI
                                     requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRCreateAuthURIResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      createAuthURI:request
           callback:^(FIRCreateAuthURIResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];

  [_RPCIssuer respondWithServerErrorMessage:kMissingContinueURIErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeMissingContinueURI);
  XCTAssertNil(RPCResponse);
}

/** @fn testInvalidIdentifierError
    @brief This test checks for the INVALID_IDENTIFIER error message from the backend.
 */
- (void)testInvalidIdentifierError {
  FIRCreateAuthURIRequest *request =
      [[FIRCreateAuthURIRequest alloc] initWithIdentifier:kTestIdentifier
                                              continueURI:kTestContinueURI
                                     requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRCreateAuthURIResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      createAuthURI:request
           callback:^(FIRCreateAuthURIResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidIdentifierErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidEmail);
  XCTAssertNil(RPCResponse);
}

/** @fn testInvalidEmailError
    @brief This test checks for INVALID_EMAIL error message from the backend.
 */
- (void)testInvalidEmailError {
  FIRCreateAuthURIRequest *request =
      [[FIRCreateAuthURIRequest alloc] initWithIdentifier:kTestIdentifier
                                              continueURI:kTestContinueURI
                                     requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRCreateAuthURIResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      createAuthURI:request
           callback:^(FIRCreateAuthURIResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];

  [_RPCIssuer respondWithServerErrorMessage:kInvalidEmailErrorMessage];

  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInvalidEmail);
  XCTAssertNil(RPCResponse);
}

/** @fn testSuccessfulCreateAuthURI
    @brief This test checks for invalid email identifier error.
 */
- (void)testSuccessfulCreateAuthURIResponse {
  FIRCreateAuthURIRequest *request =
      [[FIRCreateAuthURIRequest alloc] initWithIdentifier:kTestIdentifier
                                              continueURI:kTestContinueURI
                                     requestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRCreateAuthURIResponse *RPCResponse;
  __block NSError *RPCError;
  [FIRAuthBackend
      createAuthURI:request
           callback:^(FIRCreateAuthURIResponse *_Nullable response, NSError *_Nullable error) {
             callbackInvoked = YES;
             RPCResponse = response;
             RPCError = error;
           }];

  [_RPCIssuer respondWithJSON:@{kAuthUriKey : kTestAuthUri}];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.authURI, kTestAuthUri);
}

@end
