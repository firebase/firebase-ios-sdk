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

/// The protocol defines methods to store App Attest key IDs per Firebase app.
@protocol GACAppAttestKeyIDStorageProtocol <NSObject>

/** Manages storage of an app attest key ID.
 *  @param keyID The app attest key ID to store or `nil` to remove the existing app attest key ID.
 *  @return A promise that is resolved with a stored app attest key ID or `nil` if the existing app
 * attest key ID has been removed.
 */
- (FBLPromise<NSString *> *)setAppAttestKeyID:(nullable NSString *)keyID;

/** Reads a stored app attest key ID.
 *  @return A promise that is resolved with a stored app attest key ID or `nil` if there is not a
 * stored app attest key ID. The promise is rejected with an error in the case of a missing app
 * attest key ID .
 */
- (FBLPromise<NSString *> *)getAppAttestKeyID;

@end

/// The App Attest key ID storage implementation.
/// This class is designed for use by `GACAppAttestProvider`. It's operations are managed by
/// `GACAppAttestProvider`'s internal serial queue. It is not considered thread safe and should not
/// be used by other classes at this time.
@interface GACAppAttestKeyIDStorage : NSObject <GACAppAttestKeyIDStorageProtocol>

- (instancetype)init NS_UNAVAILABLE;

/** Default convenience initializer.
 *  @param keySuffix A unique suffix that will be used as a part of the key to store the token for
 *  the storage instance.
 */
- (instancetype)initWithKeySuffix:(NSString *)keySuffix;

@end

NS_ASSUME_NONNULL_END
