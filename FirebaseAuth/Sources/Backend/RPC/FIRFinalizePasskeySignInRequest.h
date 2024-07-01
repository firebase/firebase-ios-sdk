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

#import "FirebaseAuth/Sources/Backend/FIRAuthRPCRequest.h"
#import "FirebaseAuth/Sources/Backend/FIRIdentityToolkitRequest.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIRFinalizePasskeySignInRequest
    @brief Represents the parameters for the finalizePasskeySignIn endpoint.
 */
@interface FIRFinalizePasskeySignInRequest : FIRIdentityToolkitRequest <FIRAuthRPCRequest>

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
 @property authenticatorData
 @brief The AuthenticatorData from the authenticator.
 */
@property(nonatomic, copy, readonly) NSString *authenticatorData;

/**
 @property signature
 @brief The signature from the authenticator.
 */
@property(nonatomic, copy, readonly) NSString *signature;

/**
 @property userID
 @brief The user handle
 */
@property(nonatomic, copy, readonly) NSString *userID;

- (nullable instancetype)initWithCredentialID:(NSString *)credentialID
                               clientDataJson:(NSString *)clientDataJson
                            authenticatorData:(NSString *)authenticatorData
                                    signature:(NSString *)signature
                                       userID:(NSString *)userID
                         requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration;

@end

NS_ASSUME_NONNULL_END
