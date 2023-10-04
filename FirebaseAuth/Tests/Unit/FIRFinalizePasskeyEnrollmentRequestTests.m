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

#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeyEnrollmentRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeyEnrollmentResponse.h"
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
    @"https://identitytoolkit.googleapis.com/v2/accounts/passkeyEnrollment:finalize?key=APIKey";

/**
 @var kIDToken
 @brief Token representing the user's identity.
 */
static NSString *const kIDToken = @"testIDToken";

/**
 @var kIDTokenKey
 @brief ID Token field.
 */
static NSString *const kIDTokenKey = @"idToken";

/**
 @var kName
 @brief Passkey name.
 */
static NSString *const kName = @"testName";

/**
 @var kNameKey
 @brief Passkey name field
 */
static NSString *const kNameKey = @"name";

/**
 @var kCredentialID
 @brief credential ID.
 */
static NSString *const kCredentialID = @"testCredentialID";

/**
 @var kCredentialIDKey
 @brief credential ID field.
 */
static NSString *const kCredentialIDKey = @"credentialId";

/**
 @var kRawAttestationObject
 @brief Passkey attestation object.
 */
static NSString *const kRawAttestationObject = @"testRawAttestationObject";

/**
 @var kRawAttestationObjectKey
 @brief  The key for the attestation object from the authenticator.
 */
static NSString *const kRawAttestationObjectKey = @"attestationObject";

/**
 @var kRawClientDataJSON
 @brief CollectedClientData object from the authenticator.
 */
static NSString *const kRawClientDataJSON = @"testRawClientDataJSON";

/**
 @var kRawClientDataJSONKey
 @brief The key for the attestation object from the authenticator.
 */
static NSString *const kRawClientDataJSONKey = @"clientDataJson";

/**
 @var kAuthRegistrationRespKey
 @brief The registration object from the authenticator.
 */
static NSString *const kAuthRegistrationRespKey = @"authenticatorRegistrationResponse";

/**
 @var kAuthAttestationRespKey
 @brief The key for attestation response from a FIDO authenticator.
 */
static NSString *const kAuthAttestationRespKey = @"authenticatorAttestationResponse";

/**
 @class FIRFinalizePasskeyEnrollmentRequestTests
 @brief Tests for @c FIRFinalizePasskeyEnrollmentRequest.
 */
@interface FIRFinalizePasskeyEnrollmentRequestTests : XCTestCase
@end

@implementation FIRFinalizePasskeyEnrollmentRequestTests {
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

- (void)testFinalizePasskeyEnrollmentRequest {
  if (@available(iOS 15.0, *)) {
    FIRFinalizePasskeyEnrollmentRequest *request =
        [[FIRFinalizePasskeyEnrollmentRequest alloc] initWithIDToken:kIDToken
                                                                name:kName
                                                        credentialID:kCredentialID
                                                      clientDataJson:kRawClientDataJSON
                                                   attestationObject:kRawAttestationObject
                                                requestConfiguration:_requestConfiguration];

    [FIRAuthBackend
        finalizePasskeyEnrollment:request
                         callback:^(FIRFinalizePasskeyEnrollmentResponse *_Nullable response,
                                    NSError *_Nullable error){
                         }];
    XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
    XCTAssertNotNil(_RPCIssuer.decodedRequest);
    XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kIDTokenKey], kIDToken);
    XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kNameKey], kName);
    XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAuthRegistrationRespKey]
                                                   [kAuthAttestationRespKey][kRawClientDataJSONKey],
                          kRawClientDataJSON);
    XCTAssertEqualObjects(
        _RPCIssuer.decodedRequest[kAuthRegistrationRespKey][kAuthAttestationRespKey]
                                 [kRawAttestationObjectKey],
        kRawAttestationObject);
    XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAuthRegistrationRespKey][kCredentialIDKey],
                          kCredentialID);
  }
}

@end
#endif
