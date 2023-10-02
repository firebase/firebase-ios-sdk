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
#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeyEnrollmentRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeyEnrollmentResponse.h"
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
 @var kName
 @brief Passkey name.
 */
static NSString *const kName = @"testName";

/**
 @var kCredentialID
 @brief credential ID.
 */
static NSString *const kCredentialID = @"testCredentialID";

/**
 @var kRawAttestationObject
 @brief Passkey attestation object.
 */
static NSString *const kRawAttestationObject = @"testRawAttestationObject";

/**
 @var kRawClientDataJSON
 @brief Passkey client data json.
 */
static NSString *const kRawClientDataJSON = @"testRawClientDataJSON";

/**
 @class FIRFinalizePasskeyEnrollmentResponseTests
 @brief Tests for @c FIRFinalizePasskeyEnrollmentResponse.
 */
@interface FIRFinalizePasskeyEnrollmentResponseTests : XCTestCase
@end
@implementation FIRFinalizePasskeyEnrollmentResponseTests {
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

/** @fn testSuccessfulFinalizePasskeyEnrollmentResponse
    @brief This test simulates a successful @c FinalizePasskeyEnrollment flow.
 */
- (void)testSuccessfulFinalizePasskeyEnrollmentResponse {
  if (@available(iOS 15.0, *)) {
    FIRFinalizePasskeyEnrollmentRequest *request =
        [[FIRFinalizePasskeyEnrollmentRequest alloc] initWithIDToken:kIDToken
                                                                name:kName
                                                        credentialID:kCredentialID
                                                      clientDataJson:kRawClientDataJSON
                                                   attestationObject:kRawAttestationObject
                                                requestConfiguration:_requestConfiguration];

    __block BOOL callbackInvoked;
    __block FIRFinalizePasskeyEnrollmentResponse *RPCResponse;
    __block NSError *RPCError;

    [FIRAuthBackend
        finalizePasskeyEnrollment:request
                         callback:^(FIRFinalizePasskeyEnrollmentResponse *_Nullable response,
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

/** @fn testFinalizePasskeyEnrollmentResponseMissingIDTokenError
    @brief This test simulates an unexpected response returned from server in @c
   FinalizePasskeyEnrollment flow.
 */
- (void)testFinalizePasskeyEnrollmentResponseMissingIDTokenError {
  if (@available(iOS 15.0, *)) {
    FIRFinalizePasskeyEnrollmentRequest *request =
        [[FIRFinalizePasskeyEnrollmentRequest alloc] initWithIDToken:kIDToken
                                                                name:kName
                                                        credentialID:kCredentialID
                                                      clientDataJson:kRawClientDataJSON
                                                   attestationObject:kRawAttestationObject
                                                requestConfiguration:_requestConfiguration];

    __block BOOL callbackInvoked;
    __block FIRFinalizePasskeyEnrollmentResponse *RPCResponse;
    __block NSError *RPCError;

    [FIRAuthBackend
        finalizePasskeyEnrollment:request
                         callback:^(FIRFinalizePasskeyEnrollmentResponse *_Nullable response,
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
/** @fn testFinalizePasskeyEnrollmentResponseMissingRefreshTokenError
    @brief This test simulates an unexpected response returned from server in @c
 FinalizePasskeyEnrollment flow.
 */
- (void)testFinalizePasskeyEnrollmentResponseMissingRefreshTokenError {
  if (@available(iOS 15.0, *)) {
    FIRFinalizePasskeyEnrollmentRequest *request =
        [[FIRFinalizePasskeyEnrollmentRequest alloc] initWithIDToken:kIDToken
                                                                name:kName
                                                        credentialID:kCredentialID
                                                      clientDataJson:kRawClientDataJSON
                                                   attestationObject:kRawAttestationObject
                                                requestConfiguration:_requestConfiguration];

    __block BOOL callbackInvoked;
    __block FIRFinalizePasskeyEnrollmentResponse *RPCResponse;
    __block NSError *RPCError;

    [FIRAuthBackend
        finalizePasskeyEnrollment:request
                         callback:^(FIRFinalizePasskeyEnrollmentResponse *_Nullable response,
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
   FinalizePasskeyEnrollment flow.
 */
- (void)errorValidationHelperWithCallbackInvoked:(BOOL)callbackInvoked
                                        rpcError:(NSError *)RPCError
                                     rpcResponse:
                                         (FIRFinalizePasskeyEnrollmentResponse *)RPCResponse {
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
