/*
 * Copyright 2026 Google LLC
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

#import <GoogleUtilities/GULKeychainStorage.h>

NS_ASSUME_NONNULL_BEGIN

/// An in-memory replacement for the keychain-backed `GULKeychainStorage`.
///
/// Objects are archived with `NSKeyedArchiver` when they are saved and unarchived with secure
/// coding when they are read, like `GULKeychainStorage` does, so the stored data goes through the
/// same encoding and decoding as on a device. Unlike the keychain, it doesn't need keychain
/// entitlements, so it works in test bundles without a host app. The data outlives the objects
/// that use it, so passing the same instance to a new `FIRInstallationsStore` simulates a new app
/// launch.
@interface FIRInstallationsFakeSecureStorage : GULKeychainStorage

- (instancetype)init;

/// The archived data stored for `key`, or `nil`.
- (nullable NSData *)dataForKey:(NSString *)key;

/// Replaces the archived data stored for `key`. Pass `nil` to remove it.
- (void)setData:(nullable NSData *)data forKey:(NSString *)key;

/// The number of stored items.
@property(nonatomic, readonly) NSUInteger itemCount;

@end

NS_ASSUME_NONNULL_END
