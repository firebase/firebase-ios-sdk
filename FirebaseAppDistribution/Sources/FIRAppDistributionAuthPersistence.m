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
#import "FIRAppDistributionAuthPersistence+Private.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kFIRAppDistributionKeychainErrorDomain = @"com.firebase.app_distribution.internal";

@implementation FIRAppDistributionAuthPersistence

+ (void)handleAuthStateError:(NSError **_Nullable)error
                 description:(NSString *)description
                        code:(FIRAppDistributionKeychainError)code {
  if (error) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};
    *error = [NSError errorWithDomain:kFIRAppDistributionKeychainErrorDomain
                                 code:code
                             userInfo:userInfo];
  }
}

+ (BOOL)clearAuthState:(NSError **_Nullable)error {
  NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
  OSStatus status = SecItemDelete((CFDictionaryRef)keychainQuery);

  if (status != errSecSuccess && status != errSecItemNotFound) {
    NSString *description = NSLocalizedString(
        @"Failed to clear auth state from keychain. Tester will overwrite data on sign in.",
        @"Error message for failure to retrieve auth state from keychain");
    [self handleAuthStateError:error
                   description:description
                          code:FIRAppDistributionErrorTokenDeletionFailure];
    return NO;
  }

  return YES;
}

+ (OIDAuthState *)retrieveAuthState:(NSError **_Nullable)error {
  NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
  [keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
  [keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
  NSData *passwordData = NULL;
  NSData *result = nil;
  OSStatus status = SecItemCopyMatching((CFDictionaryRef)keychainQuery, (void *)&passwordData);

  if (status != noErr || 0 == [passwordData length]) {
    NSString *description = NSLocalizedString(
        @"Failed to retrieve auth state from keychain. Tester will have to sign in again.",
        @"Error message for failure to retrieve auth state from keychain");
    [self handleAuthStateError:error
                   description:description
                          code:FIRAppDistributionErrorTokenRetrievalFailure];
    return nil;
  }

  result = [passwordData copy];

  if (!result) {
    NSString *description =
        NSLocalizedString(@"Failed to unarchive auth state. Tester will have to sign in again.",
                          @"Error message for failure to retrieve auth state from keychain");
    [self handleAuthStateError:error
                   description:description
                          code:FIRAppDistributionErrorTokenRetrievalFailure];
    return nil;
  }

  OIDAuthState *authState = (OIDAuthState *)[NSKeyedUnarchiver unarchiveObjectWithData:result];

  return authState;
}

+ (BOOL)persistAuthState:(OIDAuthState *)authState error:(NSError **_Nullable)error {
  NSData *authorizationData = [NSKeyedArchiver archivedDataWithRootObject:authState];
  NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
  OSStatus status = noErr;
  if ([self retrieveAuthState:NULL]) {
    status = SecItemUpdate((CFDictionaryRef)keychainQuery,
                           (CFDictionaryRef) @{(id)kSecValueData : authorizationData});
  } else {
    [keychainQuery setObject:authorizationData forKey:(id)kSecValueData];
    status = SecItemAdd((CFDictionaryRef)keychainQuery, NULL);
  }

  if (status != noErr) {
    NSString *description = NSLocalizedString(
        @"Failed to persist auth state. Tester will have to sign in again after app close.",
        @"Error message for failure to persist auth state to keychain");
    [self handleAuthStateError:error
                   description:description
                          code:FIRAppDistributionErrorTokenPersistenceFailure];
    return NO;
  }

  return YES;
}

+ (NSMutableDictionary *)getKeyChainQuery {
  NSMutableDictionary *keychainQuery = [NSMutableDictionary
      dictionaryWithObjectsAndKeys:(id)kSecClassGenericPassword, (id)kSecClass, @"OAuth",
                                   (id)kSecAttrGeneric, @"OAuth", (id)kSecAttrAccount,
                                   @"fire-fad-auth", (id)kSecAttrService, nil];
  return keychainQuery;
}

@end

NS_ASSUME_NONNULL_END
