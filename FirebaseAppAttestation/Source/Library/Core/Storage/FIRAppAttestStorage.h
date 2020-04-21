/*
 * Copyright 2020 Google LLC
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

@class FIRAppAttestationToken;
@class FBLPromise<ValueType>;
@class GULKeychainStorage;

NS_ASSUME_NONNULL_BEGIN

@protocol FIRAppAttestStorageProtocol <NSObject>

/** Manages storage of the FAA token.
 *  @param token A token object to store or `nil` to remove existing token.
 *  @returns A promise that is resolved in the case of success or is rejected with a specific error
 * otherwise.
 */
- (FBLPromise<NSNull *> *)setToken:(nullable FIRAppAttestationToken *)token;

/** Reads a stored FAA token.
 *  @returns A promise that is resolved with a stored token or `nil` if there is no a stored token.
 * The promise is rejected with an error in the case of a failure.
 */
- (FBLPromise<FIRAppAttestationToken *> *)getToken;

@end

/// The class provides an implementation of persistent storage to store data like FAA token, etc.
@interface FIRAppAttestStorage : NSObject <FIRAppAttestStorageProtocol>

- (instancetype)init NS_UNAVAILABLE;

/** Default convenience initializer.
 *  @param appName A Firebase App name (`FIRApp.name`) to create a storage instance for.
 *  @param accessGroup The Keychain Access Group.
 */
- (instancetype)initWithAppName:(NSString *)appName accessGroup:(nullable NSString *)accessGroup;

/** Designated initializer.
 *  @param appName A Firebase App name (`FIRApp.name`) to create a storage instance for.
 *  @param keychainStorage An instance of `GULKeychainStorage` used as an underlying secure storage.
 *  @param accessGroup The Keychain Access Group.
 */
- (instancetype)initWithAppName:(NSString *)appName
                keychainStorage:(GULKeychainStorage *)keychainStorage
                    accessGroup:(nullable NSString *)accessGroup NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
