/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <AuthenticationServices/ASAuthorizationPlatformPublicKeyCredentialRegistration.h>
#import "FirebaseAuth/Sources/Backend/FIRAuthRPCRequest.h"
#import "FirebaseAuth/Sources/Backend/FIRIdentityToolkitRequest.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIRFinalizePasskeyEnrollmentRequest
    @brief Represents the parameters for the finalizePasskeyEnrollment endpoint.
 */
@interface FIRFinalizePasskeyEnrollmentRequest : FIRIdentityToolkitRequest <FIRAuthRPCRequest>

/**
 @property IDToken
 @brief The raw user access token.
 */
@property(nonatomic, copy, readonly) NSString *IDToken;

/**
 @property name
 @brief The passkey name.
 */
@property(nonatomic, copy, readonly) NSString *name;

/**
 @property credentialID
 @brief The credential ID.
 */
@property(nonatomic, copy, readonly) NSString *credentialID;

/**
 @property clientDataJson
 @brief The CollectedClientData object from the authenticator.
 */
@property(nonatomic, copy, readonly) NSString *clientDataJson;

/**

 @property attestationObject
 @brief The attestation object from the authenticator.
 */
@property(nonatomic, copy, readonly) NSString *attestationObject;

- (nullable instancetype)initWithIDToken:(NSString *)IDToken
                                    name:(NSString *)name
                            credentialID:(NSString *)credentialID
                          clientDataJson:(NSString *)clientDataJson
                       attestationObject:(NSString *)attestationObject
                    requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration;

@end

NS_ASSUME_NONNULL_END
