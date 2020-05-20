// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#import <AppAuth/AppAuth.h>

NS_ASSUME_NONNULL_BEGIN

/// @brief Wraps keychain operations to encapsulate interactions with CF data structures
@interface FIRAppDistributionKeychainUtility : NSObject

/// @brief Store an item in the keychain
+ (BOOL)addKeychainItem:(NSMutableDictionary *)keychainQuery withDataDictionary:(NSData *)data;

/// @brief Update an item in the keychain
+ (BOOL)updateKeychainItem:(NSMutableDictionary *)keychainQuery withDataDictionary:(NSData *)data;

/// @brief Delete an item in the keychain
+ (BOOL)deleteKeychainItem:(NSMutableDictionary *)keychainQuery;

/// @brief Fetch the item matching the keychain query from the keychain
+ (NSData *)fetchKeychainItemMatching:(nonnull NSMutableDictionary *)keychainQuery
                                error:(NSError **_Nullable)error;

/// @brief Unarchive the authentication state from the keychain result
+ (OIDAuthState *)unarchiveKeychainResult:(NSData *)result;

/// @brief Archive the authentication data for persistence to the keychain
+ (NSData *)archiveDataForKeychain:(OIDAuthState *)data;
@end

NS_ASSUME_NONNULL_END
