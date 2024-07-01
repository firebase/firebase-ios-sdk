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
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_OSX || TARGET_OS_MACCATALYST

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeySignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeySignInResponse.h"
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
    @"https://identitytoolkit.googleapis.com/v2/accounts/passkeySignIn:finalize?key=APIKey";

/**
 @var kAuthenticatorAuthRespKey
 @brief The key for authentication response object from the authenticator.
 */
static NSString *const kAuthenticatorAuthRespKey = @"authenticatorAuthenticationResponse";

/**
 @var kAuthAssertionRespKey
 @brief The key for authentication assertion from the authenticator.
 */
static NSString *const kAuthAssertionRespKey = @"response";

/**
 @var kCredentialID
 @brief credential ID.
 */
static NSString *const kCredentialID = @"testCredentialID";

/**
 @var kCredentialIDKey
 @brief credential ID field.
 */
static NSString *const kCredentialIDKey = @"id";

/**
 @var kRawClientDataJSON
 @brief CollectedClientData object from the authenticator.
 */
static NSString *const kRawClientDataJSON = @"testRawClientDataJSON";

/**
 @var kRawClientDataJSONKey
 @brief The key for the attestation object from the authenticator.
 */
static NSString *const kRawClientDataJSONKey = @"clientDataJSON";

/**
 @var kAuthenticatorData
 @brief The authenticatorData from the authenticator.
 */
static NSString *const kAuthenticatorData = @"TestAuthenticatorData";

/**
 @var kAuthenticatorDataKey
 @brief The key for authenticatorData from the authenticator.
 */
static NSString *const kAuthenticatorDataKey = @"authenticatorData";

/**
 @var kSignature
 @brief The signature from the authenticator
 */
static NSString *const kSignature = @"testSignature";

/**
 @var kSignatureKey
 @brief The key for the signature from the authenticator.
 */
static NSString *const kSignatureKey = @"signature";

/**
 @var kUserHandle
 @brief The key for the user handle.
 */
static NSString *const kUserHandle = @"testUserHandle";

/**
 @var kUserHandleKey
 @brief The key for the user handle.
 */
static NSString *const kUserHandleKey = @"userHandle";

/**
 @class FIRFinalizePasskeySignInRequestTests
 @brief Tests for @c FIRFinalizePasskeySignInRequest.
 */
@interface FIRFinalizePasskeySignInRequestTests : XCTestCase
@end

@implementation FIRFinalizePasskeySignInRequestTests {
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

- (void)testFinalizePasskeySignInRequest {
  if (@available(iOS 15.0, *)) {
    FIRFinalizePasskeySignInRequest *request =
        [[FIRFinalizePasskeySignInRequest alloc] initWithCredentialID:kCredentialID
                                                       clientDataJson:kRawClientDataJSON
                                                    authenticatorData:kAuthenticatorData
                                                            signature:kSignature
                                                               userID:kUserHandle
                                                 requestConfiguration:_requestConfiguration];

    [FIRAuthBackend finalizePasskeySignIn:request
                                 callback:^(FIRFinalizePasskeySignInResponse *_Nullable response,
                                            NSError *_Nullable error){
                                 }];
    XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
    XCTAssertNotNil(_RPCIssuer.decodedRequest);
    XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAuthenticatorAuthRespKey][kCredentialIDKey],
                          kCredentialID);
    XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAuthenticatorAuthRespKey]
                                                   [kAuthAssertionRespKey][kRawClientDataJSONKey],
                          kRawClientDataJSON);
    XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAuthenticatorAuthRespKey]
                                                   [kAuthAssertionRespKey][kAuthenticatorDataKey],
                          kAuthenticatorData);
    XCTAssertEqualObjects(
        _RPCIssuer.decodedRequest[kAuthenticatorAuthRespKey][kAuthAssertionRespKey][kSignatureKey],
        kSignature);
    XCTAssertEqualObjects(
        _RPCIssuer.decodedRequest[kAuthenticatorAuthRespKey][kAuthAssertionRespKey][kUserHandleKey],
        kUserHandle);
  }
}

@end
#endif
