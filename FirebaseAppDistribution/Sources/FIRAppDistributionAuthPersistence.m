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
#import "FIRAppDistributionAuthPersistence+Private.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kFIRAppDistributionKeychainErrorDomain = @"com.firebase.app_distribution.internal";

@implementation FIRAppDistributionAuthPersistence

+ (Class<FIRAppDistributionKeychainProtocol>)keychainUtility {
  return [FIRAppDistributionKeychainUtility class];
}

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
  BOOL success = [[self keychainUtility] deleteKeychainItem:keychainQuery];

  if (!success) {
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
  BOOL success = [[self keychainUtility] fetchKeychainItemMatching:keychainQuery keychainItem:passwordData];

  if (!success) {
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

  OIDAuthState *authState = [[self keychainUtility] unarchiveKeychainResult:result];

  return authState;
}

+ (BOOL)persistAuthState:(OIDAuthState *)authState error:(NSError **_Nullable)error {
  NSData *authorizationData = [[self keychainUtility] archiveDataForKeychain:authState];
  NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
  BOOL success = NO;
  if ([self retrieveAuthState:NULL]) {
    success =[[self keychainUtility] updateKeychainItem:keychainQuery withDataDictionary:authorizationData];
  } else {
    success =[[self keychainUtility] addKeychainItem:keychainQuery withDataDictionary:authorizationData];
  }

  if (!success) {
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
