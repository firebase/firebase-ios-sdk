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

NS_ASSUME_NONNULL_BEGIN

/// Represents different stages of App Attest attestation.
typedef NS_ENUM(NSInteger, GACAppAttestAttestationState) {
  /// App Attest is not supported on the current device.
  GACAppAttestAttestationStateUnsupported,

  /// App Attest is supported, the App Attest key pair has been generated.
  GACAppAttestAttestationStateSupportedInitial,

  /// App Attest key pair has been generated but has not been attested and registered with Firebase
  /// backend.
  GACAppAttestAttestationStateKeyGenerated,

  /// App Attest key has been generated, attested with Apple backend and registered with Firebase
  /// backend. An encrypted artifact required to refresh FAC token is stored on the device.
  GACAppAttestAttestationStateKeyRegistered,
};

/// Represents attestation stages of App Attest. The class is designed to be used exclusively by
/// `GACAppAttestProvider`.
@interface GACAppAttestProviderState : NSObject

/// App Attest attestation state.
@property(nonatomic, readonly) GACAppAttestAttestationState state;

/// An error object when state is GACAppAttestAttestationStateUnsupported.
@property(nonatomic, nullable, readonly) NSError *appAttestUnsupportedError;

/// An App Attest key ID when state is GACAppAttestAttestationStateKeyGenerated or
/// GACAppAttestAttestationStateKeyRegistered.
@property(nonatomic, nullable, readonly) NSString *appAttestKeyID;

/// An attestation artifact received from Firebase backend when state is
/// GACAppAttestAttestationStateKeyRegistered.
@property(nonatomic, nullable, readonly) NSData *attestationArtifact;

- (instancetype)init NS_UNAVAILABLE;

/// Init with GACAppAttestAttestationStateUnsupported and an error describing issue.
- (instancetype)initUnsupportedWithError:(NSError *)error;

/// Init with GACAppAttestAttestationStateSupportedInitial.
- (instancetype)initWithSupportedInitialState;

/// Init with GACAppAttestAttestationStateKeyGenerated and the key ID.
- (instancetype)initWithGeneratedKeyID:(NSString *)keyID;

/// Init with GACAppAttestAttestationStateKeyRegistered, the key ID and the attestation artifact
/// received from Firebase backend.
- (instancetype)initWithRegisteredKeyID:(NSString *)keyID artifact:(NSData *)artifact;

@end

NS_ASSUME_NONNULL_END
