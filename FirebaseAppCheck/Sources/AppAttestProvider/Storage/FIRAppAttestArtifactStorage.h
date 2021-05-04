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

@class FBLPromise<ValueType>;

NS_ASSUME_NONNULL_BEGIN

/// Defines API of a storage capable to store an encrypted artifact required to refresh Firebase App Check token obtained with App Attest provider.
@protocol FIRAppAttestArtifactStorageProtocol <NSObject>

/// Set the artifact.
- (FBLPromise<NSData *> *)setArtifact:(NSData *)artifact;

/// Get the artifact.
- (FBLPromise<NSData *> *)getArtifact;

@end

/// An implementation of FIRAppAttestArtifactStorageProtocol.
@interface FIRAppAttestArtifactStorage : NSObject <FIRAppAttestArtifactStorageProtocol>

@end

NS_ASSUME_NONNULL_END
