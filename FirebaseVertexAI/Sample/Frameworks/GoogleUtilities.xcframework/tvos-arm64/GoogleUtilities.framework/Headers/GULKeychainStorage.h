/*
 * Copyright 2019 Google
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

/// The class provides a convenient, multiplatform abstraction of the Keychain.
///
/// When using this API on macOS, the corresponding target must be signed with a provisioning
/// profile that has the Keychain Sharing capability enabled.
@interface GULKeychainStorage : NSObject

- (instancetype)init NS_UNAVAILABLE;

/** Initializes the keychain storage with Keychain Service name.
 *  @param service A Keychain Service name that will be used to store and retrieve objects. See also
 * `kSecAttrService`.
 */
- (instancetype)initWithService:(NSString *)service;

/// Get an object by key.
/// @param key The key.
/// @param objectClass The expected object class required by `NSSecureCoding`.
/// @param accessGroup The Keychain Access Group.
/// @param completionHandler The completion handler to call when the
/// synchronized keychain read is complete. An error is passed to the
/// completion handler if the keychain read fails. Else, the object stored in
/// the keychain, or `nil` if it does not exist, is passed to the completion
/// handler.
- (void)getObjectForKey:(NSString *)key
            objectClass:(Class)objectClass
            accessGroup:(nullable NSString *)accessGroup
      completionHandler:
          (void (^)(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error))completionHandler;

/// Saves the given object by the given key.
/// @param object The object to store.
/// @param key The key to store the object. If there is an existing object by the key, it will be
/// overridden.
/// @param accessGroup The Keychain Access Group.
/// @param completionHandler  The completion handler to call when the
/// synchronized keychain write is complete. An error is passed to the
/// completion handler if the keychain read fails. Else, the object written to
/// the keychain is passed to the completion handler.
- (void)setObject:(id<NSSecureCoding>)object
               forKey:(NSString *)key
          accessGroup:(nullable NSString *)accessGroup
    completionHandler:
        (void (^)(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error))completionHandler;

/// Removes the object by the given key.
/// @param key The key to store the object. If there is an existing object by
/// the key, it will be overridden.
/// @param accessGroup The Keychain Access Group.
/// @param completionHandler The completion handler to call when the
/// synchronized keychain removal is complete. An error is passed to the
/// completion handler if the keychain removal fails.
- (void)removeObjectForKey:(NSString *)key
               accessGroup:(nullable NSString *)accessGroup
         completionHandler:(void (^)(NSError *_Nullable error))completionHandler;

#if TARGET_OS_OSX
/// If not `nil`, then only this keychain will be used to save and read data (see
/// `kSecMatchSearchList` and `kSecUseKeychain`. It is mostly intended to be used by unit tests.
@property(nonatomic, nullable) SecKeychainRef keychainRef;
#endif  // TARGET_OS_OSX

@end

NS_ASSUME_NONNULL_END
