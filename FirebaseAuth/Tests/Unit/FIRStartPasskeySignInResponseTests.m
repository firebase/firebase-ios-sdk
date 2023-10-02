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

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_OSX || TARGET_OS_MACCATALYST
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuthErrors.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRStartPasskeySignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRStartPasskeySignInResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthInternalErrors.h"
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
 @var kTestRpID
 @brief Fake Relying Party ID used for testing.
 */
static NSString *const kTestRpID = @"1234567890";

/**
 @var kTestChallenge
 @brief Fake challenge used for testing.
 */
static NSString *const kTestChallenge = @"challengebytes";

/**
 @var kTestRpKey
 @brief the name of the "rp" property in the response.
 */
static NSString *const kRpKey = @"rpId";

/**
 @var kTestChallengeKey
 @brief the name of the "challenge" property in the response.
 */
static NSString *const kChallengeKey = @"challenge";

/**
 @class FIRStartPasskeySignInResponseTests
 @brief Tests for @c FIRStartPasskeySingInResponse.
 */
@interface FIRStartPasskeySignInResponseTests : XCTestCase
@end
@implementation FIRStartPasskeySignInResponseTests {
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

/** @fn testSuccessfulStartPasskeySignInResponse
    @brief This test simulates a successful @c StartPasskeySignIn flow.
 */
- (void)testSuccessfulStartPasskeySignInResponse {
  FIRStartPasskeySignInRequest *request =
      [[FIRStartPasskeySignInRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRStartPasskeySignInResponse *RPCResponse;
  __block NSError *RPCError;

  [FIRAuthBackend startPasskeySignIn:request
                            callback:^(FIRStartPasskeySignInResponse *_Nullable response,
                                       NSError *_Nullable error) {
                              callbackInvoked = YES;
                              RPCResponse = response;
                              RPCError = error;
                            }];

  [_RPCIssuer respondWithJSON:@{
    @"credentialRequestOptions" : @{
      kChallengeKey : kTestChallenge,
      kRpKey : kTestRpID,
    },
  }];

  XCTAssert(callbackInvoked);
  XCTAssertNil(RPCError);
  XCTAssertNotNil(RPCResponse);
  XCTAssertEqualObjects(RPCResponse.rpID, kTestRpID);
  XCTAssertEqualObjects(RPCResponse.challenge, kTestChallenge);
}

/** @fn testStartPasskeySignInResponseMissingRequestOptionsError
    @brief This test simulates an unexpected response returned from server in @c
   StartPasskeySignIn flow.
 */
- (void)testStartPasskeySignInResponseMissingRequestOptionsError {
  FIRStartPasskeySignInRequest *request =
      [[FIRStartPasskeySignInRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRStartPasskeySignInResponse *RPCResponse;
  __block NSError *RPCError;

  [FIRAuthBackend startPasskeySignIn:request
                            callback:^(FIRStartPasskeySignInResponse *_Nullable response,
                                       NSError *_Nullable error) {
                              callbackInvoked = YES;
                              RPCResponse = response;
                              RPCError = error;
                            }];

  [_RPCIssuer respondWithJSON:@{
    @"wrongkey" : @{},
  }];
  [self errorValidationHelperWithCallbackInvoked:callbackInvoked
                                        rpcError:RPCError
                                     rpcResponse:RPCResponse];
}

/** @fn testStartPasskeySignInResponseMissingRpIdError
    @brief This test simulates an unexpected response returned from server in @c
   StartPasskeySignIn flow.
 */
- (void)testStartPasskeySignInResponseMissingRpIdError {
  FIRStartPasskeySignInRequest *request =
      [[FIRStartPasskeySignInRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRStartPasskeySignInResponse *RPCResponse;
  __block NSError *RPCError;

  [FIRAuthBackend startPasskeySignIn:request
                            callback:^(FIRStartPasskeySignInResponse *_Nullable response,
                                       NSError *_Nullable error) {
                              callbackInvoked = YES;
                              RPCResponse = response;
                              RPCError = error;
                            }];

  [_RPCIssuer respondWithJSON:@{
    @"credentialRequestOptions" : @{
      kChallengeKey : kTestChallenge,
    },
  }];
  [self errorValidationHelperWithCallbackInvoked:callbackInvoked
                                        rpcError:RPCError
                                     rpcResponse:RPCResponse];
}

/** @fn testStartPasskeySignInResponseMissingChallengeError
    @brief This test simulates an unexpected response returned from server in @c
   StartPasskeySignIn flow.
 */
- (void)testStartPasskeySignInResponseMissingChallengeError {
  FIRStartPasskeySignInRequest *request =
      [[FIRStartPasskeySignInRequest alloc] initWithRequestConfiguration:_requestConfiguration];

  __block BOOL callbackInvoked;
  __block FIRStartPasskeySignInResponse *RPCResponse;
  __block NSError *RPCError;

  [FIRAuthBackend startPasskeySignIn:request
                            callback:^(FIRStartPasskeySignInResponse *_Nullable response,
                                       NSError *_Nullable error) {
                              callbackInvoked = YES;
                              RPCResponse = response;
                              RPCError = error;
                            }];

  [_RPCIssuer respondWithJSON:@{
    @"credentialCreationOptions" : @{
      kRpKey : kTestRpID,
    },
  }];
  [self errorValidationHelperWithCallbackInvoked:callbackInvoked
                                        rpcError:RPCError
                                     rpcResponse:RPCResponse];
}

/** @fn errorValidationHelperWithCallbackInvoked:rpcError:rpcResponse:
    @brief Helper function to validate the unexpected response returned from server in @c
   StartPasskeySignIn flow.
 */
- (void)errorValidationHelperWithCallbackInvoked:(BOOL)callbackInvoked
                                        rpcError:(NSError *)RPCError
                                     rpcResponse:(FIRStartPasskeySignInResponse *)RPCResponse {
  XCTAssert(callbackInvoked);
  XCTAssertNotNil(RPCError);
  XCTAssertEqualObjects(RPCError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(RPCError.code, FIRAuthErrorCodeInternalError);
  XCTAssertNotNil(RPCError.userInfo[NSUnderlyingErrorKey]);
  NSError *underlyingError = RPCError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertNotNil(underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey]);
  XCTAssertNil(RPCResponse);
}

@end
#endif
