/*
 * Copyright 2021 Google LLC
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

#import <Foundation/Foundation.h>

@class FBLPromise<Result>;
@class FIRAppAttestAttestationResponse;
@class FIRAppCheckToken;
@protocol FIRAppCheckAPIServiceProtocol;

NS_ASSUME_NONNULL_BEGIN

/// Methods to send API requests required for App Attest based attestation sequence.
@protocol FIRAppAttestAPIServiceProtocol <NSObject>

/// Request a random challenge from server.
- (FBLPromise<NSData *> *)getRandomChallenge;

/// Sends attestation data to Firebase backend for validation.
/// @param attestation The App Attest key attestation data obtained from the method
/// `-[DCAppAttestService attestKey:clientDataHash:completionHandler:]` using the random challenge
/// received from Firebase backend.
/// @param keyID The key ID used to generate the attestation.
/// @param challenge The challenge used to generate the attestation.
/// @return A promise that is fulfilled with a response object with an encrypted attestation
/// artifact and an Firebase App Check token or rejected with an error.
- (FBLPromise<FIRAppAttestAttestationResponse *> *)attestKeyWithAttestation:(NSData *)attestation
                                                                      keyID:(NSString *)keyID
                                                                  challenge:(NSData *)challenge;

/// Exchanges attestation data (artifact & assertion) and a challenge for a FAC token.
- (FBLPromise<FIRAppCheckToken *> *)getAppCheckTokenWithArtifact:(NSData *)artifact
                                                       challenge:(NSData *)challenge
                                                       assertion:(NSData *)assertion;

@end

/// A default implementation of `FIRAppAttestAPIServiceProtocol`.
@interface FIRAppAttestAPIService : NSObject <FIRAppAttestAPIServiceProtocol>

/// Default initializer.
/// @param APIService An instance implementing `FIRAppCheckAPIServiceProtocol` to be used to send
/// network requests to Firebase App Check backend.
/// @param projectID A Firebase project ID for the requests (`FIRApp.options.projectID`).
/// @param appID A Firebase app ID for the requests (`FIRApp.options.googleAppID`).
- (instancetype)initWithAPIService:(id<FIRAppCheckAPIServiceProtocol>)APIService
                         projectID:(NSString *)projectID
                             appID:(NSString *)appID;

@end

NS_ASSUME_NONNULL_END
