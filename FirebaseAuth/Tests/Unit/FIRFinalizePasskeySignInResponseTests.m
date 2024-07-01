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
#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeySignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeySignInResponse.h"
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
 @var kIDToken
 @brief Token representing the user's identity.
 */
static NSString *const kIDToken = @"idToken";

/**
 @var kRefreshToken
 @brief Refresh Token
 */
static NSString *const kRefreshToken = @"refreshToken";

/**
 @var kCredentialID
 @brief credential ID.
 */
static NSString *const kCredentialID = @"testCredentialID";

/**
 @var kRawClientDataJSON
 @brief CollectedClientData object from the authenticator.
 */
static NSString *const kRawClientDataJSON = @"testRawClientDataJSON";

/**
 @var kAuthenticatorData
 @brief The authenticatorData from the authenticator.
 */
static NSString *const kAuthenticatorData = @"TestAuthenticatorData";

/**
 @var kSignature
 @brief The signature from the authenticator
 */
static NSString *const kSignature = @"testSignature";

/**
 @var kUserHandle
 @brief The key for the user handle.
 */
static NSString *const kUserHandle = @"testUserHandle";

/**
 @class FIRFinalizePasskeySignInResponseTests
 @brief Tests for @c FIRFinalizePasskeySignInResponse.
 */
@interface FIRFinalizePasskeySignInResponseTests : XCTestCase
@end
@implementation FIRFinalizePasskeySignInResponseTests {
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

/** @fn testSuccessfulFinalizePasskeySignInResponse
    @brief This test simulates a successful @c FinalizePasskeySignin flow.
 */
- (void)testSuccessfulFinalizePasskeySignInResponse {
  if (@available(iOS 15.0, *)) {
    FIRFinalizePasskeySignInRequest *request =
        [[FIRFinalizePasskeySignInRequest alloc] initWithCredentialID:kCredentialID
                                                       clientDataJson:kRawClientDataJSON
                                                    authenticatorData:kAuthenticatorData
                                                            signature:kSignature
                                                               userID:kUserHandle
                                                 requestConfiguration:_requestConfiguration];

    __block BOOL callbackInvoked;
    __block FIRFinalizePasskeySignInResponse *RPCResponse;
    __block NSError *RPCError;

    [FIRAuthBackend finalizePasskeySignIn:request
                                 callback:^(FIRFinalizePasskeySignInResponse *_Nullable response,
                                            NSError *_Nullable error) {
                                   callbackInvoked = YES;
                                   RPCResponse = response;
                                   RPCError = error;
                                 }];

    [_RPCIssuer respondWithJSON:@{
      @"idToken" : kIDToken,
      @"refreshToken" : kRefreshToken,
    }];

    XCTAssert(callbackInvoked);
    XCTAssertNil(RPCError);
    XCTAssertNotNil(RPCResponse);
    XCTAssertEqualObjects(RPCResponse.idToken, kIDToken);
    XCTAssertEqualObjects(RPCResponse.refreshToken, kRefreshToken);
  }
}

/** @fn testFinalizePasskeySignInResponseMissingIDTokenError
    @brief This test simulates an unexpected response returned from server in @c
   FinalizePasskeySignIn flow.
 */
- (void)testFinalizePasskeySignInResponseMissingIDTokenError {
  if (@available(iOS 15.0, *)) {
    FIRFinalizePasskeySignInRequest *request =
        [[FIRFinalizePasskeySignInRequest alloc] initWithCredentialID:kCredentialID
                                                       clientDataJson:kRawClientDataJSON
                                                    authenticatorData:kAuthenticatorData
                                                            signature:kSignature
                                                               userID:kUserHandle
                                                 requestConfiguration:_requestConfiguration];

    __block BOOL callbackInvoked;
    __block FIRFinalizePasskeySignInResponse *RPCResponse;
    __block NSError *RPCError;

    [FIRAuthBackend finalizePasskeySignIn:request
                                 callback:^(FIRFinalizePasskeySignInResponse *_Nullable response,
                                            NSError *_Nullable error) {
                                   callbackInvoked = YES;
                                   RPCResponse = response;
                                   RPCError = error;
                                 }];

    [_RPCIssuer respondWithJSON:@{
      @"wrongkey" : @{},
      @"refreshToken" : kRefreshToken,
    }];
    [self errorValidationHelperWithCallbackInvoked:callbackInvoked
                                          rpcError:RPCError
                                       rpcResponse:RPCResponse];
  }
}
/** @fn testFinalizePasskeySignInResponseMissingRefreshTokenError
    @brief This test simulates an unexpected response returned from server in @c
 FinalizePasskeySignIn flow.
 */
- (void)testFinalizePasskeySignInResponseMissingRefreshTokenError {
  if (@available(iOS 15.0, *)) {
    FIRFinalizePasskeySignInRequest *request =
        [[FIRFinalizePasskeySignInRequest alloc] initWithCredentialID:kCredentialID
                                                       clientDataJson:kRawClientDataJSON
                                                    authenticatorData:kAuthenticatorData
                                                            signature:kSignature
                                                               userID:kUserHandle
                                                 requestConfiguration:_requestConfiguration];

    __block BOOL callbackInvoked;
    __block FIRFinalizePasskeySignInResponse *RPCResponse;
    __block NSError *RPCError;

    [FIRAuthBackend finalizePasskeySignIn:request
                                 callback:^(FIRFinalizePasskeySignInResponse *_Nullable response,
                                            NSError *_Nullable error) {
                                   callbackInvoked = YES;
                                   RPCResponse = response;
                                   RPCError = error;
                                 }];

    [_RPCIssuer respondWithJSON:@{
      @"wrongkey" : @{},
      @"idToken" : kIDToken,
    }];
    [self errorValidationHelperWithCallbackInvoked:callbackInvoked
                                          rpcError:RPCError
                                       rpcResponse:RPCResponse];
  }
}

/** @fn errorValidationHelperWithCallbackInvoked:rpcError:rpcResponse:
    @brief Helper function to validate the unexpected response returned from server in @c
   FinalizePasskeySignIn flow.
 */
- (void)errorValidationHelperWithCallbackInvoked:(BOOL)callbackInvoked
                                        rpcError:(NSError *)RPCError
                                     rpcResponse:(FIRFinalizePasskeySignInResponse *)RPCResponse {
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
