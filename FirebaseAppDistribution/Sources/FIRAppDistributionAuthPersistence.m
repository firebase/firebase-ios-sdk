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

@implementation FIRAppDistributionAuthPersistence

+ (BOOL)clearAuthState:(NSError **_Nullable)error {
  NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
  OSStatus status = SecItemDelete((CFDictionaryRef)keychainQuery);

  if (status != errSecSuccess && status != errSecItemNotFound && error) {
    NSString *desc = NSLocalizedString(
        @"Failed to clear auth state from keychain. Tester will overwrite data on sign in.",
        @"Error message for failure to retrieve auth state from keychain");
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
    *error = [NSError errorWithDomain:kFIRAppDistributionInternalErrorDomain
                                 code:FIRAppDistributionErrorTokenDeletionFailure
                             userInfo:userInfo];
  }
  return errSecSuccess || status == errSecItemNotFound;
}

+ (OIDAuthState *)retrieveAuthState:(NSError **_Nullable)error {
  NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
  [keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
  [keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
  CFDataRef passwordData = NULL;
  NSData *result = nil;
  OSStatus status = SecItemCopyMatching((CFDictionaryRef)keychainQuery, (CFTypeRef *)&passwordData);

  if (status == noErr && 0 < [(__bridge NSData *)passwordData length]) {
    result = [(__bridge NSData *)passwordData copy];
  } else if (error) {
    NSString *desc = NSLocalizedString(
        @"Failed to retrieve auth state from keychain. Tester will have to sign in again.",
        @"Error message for failure to retrieve auth state from keychain");
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
    *error = [NSError errorWithDomain:kFIRAppDistributionInternalErrorDomain
                                 code:FIRAppDistributionErrorTokenRetrievalFailure
                             userInfo:userInfo];
  }

  OIDAuthState *authState = nil;
  if (result) {
    authState = (OIDAuthState *)[NSKeyedUnarchiver unarchiveObjectWithData:result];
  } else if (error) {
    NSString *desc =
        NSLocalizedString(@"Failed to unarchive auth state. Tester will have to sign in again.",
                          @"Error message for failure to copy password data from keychain");
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
    *error = [NSError errorWithDomain:kFIRAppDistributionInternalErrorDomain
                                 code:FIRAppDistributionErrorTokenRetrievalFailure
                             userInfo:userInfo];
  }

  if (passwordData != NULL) {
    CFRelease(passwordData);
  }

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

  if (status != noErr && error) {
    NSString *desc = NSLocalizedString(
        @"Failed to persist auth state. Tester will have to sign in again after app close.",
        @"Error message for failure to persist auth state to keychain");
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
    *error = [NSError errorWithDomain:kFIRAppDistributionInternalErrorDomain
                                 code:FIRAppDistributionErrorTokenPersistenceFailure
                             userInfo:userInfo];
  }

  return status == noErr;
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
