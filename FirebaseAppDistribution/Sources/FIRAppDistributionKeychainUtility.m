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
#import "FIRAppDistributionKeychainUtility+Private.h"

NSString *const kFIRAppDistributionKeychainErrorDomain = @"com.firebase.app_distribution.keychain";

@implementation FIRAppDistributionKeychainUtility

+ (void)handleAuthStateError:(NSError **_Nullable)error
                 description:(NSString *)description
                        code:(int)code {
  if (error) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};
    *error = [NSError errorWithDomain:kFIRAppDistributionKeychainErrorDomain
                                 code:code
                             userInfo:userInfo];
  }
}

+ (BOOL)addKeychainItem:(nonnull NSMutableDictionary *)keychainQuery withDataDictionary:(nonnull NSData *)data {
  [keychainQuery setObject:data forKey:(id)kSecValueData];
  OSStatus status = SecItemAdd((CFDictionaryRef)keychainQuery, NULL);

  return status == noErr ? YES : NO;
}

+ (BOOL)updateKeychainItem:(nonnull NSMutableDictionary *)keychainQuery withDataDictionary:(nonnull NSData *)data {
  OSStatus status = SecItemUpdate((CFDictionaryRef)keychainQuery,
                                  (CFDictionaryRef) @{(id)kSecValueData : data});
  return status == noErr ? YES : NO;
}

+ (BOOL)deleteKeychainItem:(nonnull NSMutableDictionary *)keychainQuery {
  OSStatus status = SecItemDelete((CFDictionaryRef)keychainQuery);
  
  return status != errSecSuccess && status != errSecItemNotFound ? NO : YES;
}

+ (NSData *)fetchKeychainItemMatching:(nonnull NSMutableDictionary *)keychainQuery error:(NSError **_Nullable)error {
  NSData *keychainItem;
  OSStatus status = SecItemCopyMatching((CFDictionaryRef)keychainQuery, (void *)&keychainItem);

  if(status != noErr || 0 == [keychainItem length]){
    if(error){
      NSString *description = NSLocalizedString(
        @"Failed to fetch keychain item.",
        @"Error message for failure to retrieve auth state from keychain");
      [self handleAuthStateError:error
                     description:description
                            code:0];
      return nil;
    }
  }

  return keychainItem;
}

+ (OIDAuthState *)unarchiveKeychainResult:(NSData *)result {
  return (OIDAuthState *)[NSKeyedUnarchiver unarchiveObjectWithData:result];
}

+ (NSData *)archiveDataForKeychain:(OIDAuthState *)data {
  return [NSKeyedArchiver archivedDataWithRootObject:data];
}

@end
