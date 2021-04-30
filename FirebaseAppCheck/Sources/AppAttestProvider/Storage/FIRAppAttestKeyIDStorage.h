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
@protocol FIRAppAttestKeyIDStorageProtocol <NSObject>

/** Manages storage of an app attest key ID.
 *  @param keyID The app attest key ID to store or `nil` to remove the existing app attest key ID.
 *  @returns A promise that is resolved with the stored app attest key ID in the case of success or
 * is rejected with a specific error otherwise.
 */
- (FBLPromise<NSString *> *)setAppAttestKeyID:(nullable NSString *)keyID;

/** Reads a stored app attest key ID.
 *  @returns A promise that is resolved with a stored app attest key ID or `nil` if there is not a
 * stored app attest key ID. The promise is rejected with an error in the case of a failure.
 */
- (FBLPromise<NSString *> *)getAppAttestKeyID;

@end

/// The App Attest key ID storage implementation.
@interface FIRAppAttestKeyIDStorage : NSObject <FIRAppAttestKeyIDStorageProtocol>

- (instancetype)init NS_UNAVAILABLE;

/** Default convenience initializer.
 *  @param appName A Firebase App name (`FirebaseApp.name`). The app name will be used as a part of
 * the key to store the token for the storage instance.
 *  @param appID A Firebase App identifier (`FirebaseOptions.googleAppID`). The app ID will be used
 * as a part of the key to store the token for the storage instance.
 */
- (instancetype)initWithAppName:(NSString *)appName appID:(NSString *)appID;

@end

NS_ASSUME_NONNULL_END
