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

+ (BOOL)clearAuthState {
    NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
    OSStatus status = SecItemDelete((CFDictionaryRef)keychainQuery);
    
    if (status != errSecSuccess && status != errSecItemNotFound) {
        NSLog(@"AUTH ERROR. Cant delete auth state in keychain");
    } else {
        NSLog(@"AUTH SUCCESS! deleted auth state in the keychain");
    }
    return errSecSuccess || status == errSecItemNotFound;
}

+ (OIDAuthState*)retrieveAuthState {
    NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
      [keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
      [keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
      CFDataRef passwordData = NULL;
      NSData *result = nil;
      OSStatus status = SecItemCopyMatching((CFDictionaryRef)keychainQuery,
                                         (CFTypeRef *)&passwordData);
      if (status == noErr && 0 < [(__bridge NSData *)passwordData length]) {
        result = [(__bridge NSData *)passwordData copy];
      } else {
          NSLog(@"AUTH ERROR - cannot lookup keystore config");
      }
      if (passwordData != NULL) {
        CFRelease(passwordData);
      }
    
    OIDAuthState *authState = nil;
    if(result) {
        authState = (OIDAuthState *)[NSKeyedUnarchiver unarchiveObjectWithData:result];
    }
    
    return authState;
}

+ (BOOL)persistAuthState:(OIDAuthState *)authState {
    NSData *authorizationData = [NSKeyedArchiver archivedDataWithRootObject:authState];
    NSMutableDictionary *keychainQuery = [self getKeyChainQuery];
    OSStatus status = noErr;
    if([self retrieveAuthState]) {
        NSLog(@"Auth state already persisted. Updating auth state");
        status = SecItemUpdate((CFDictionaryRef)keychainQuery, (CFDictionaryRef)@{(id)kSecValueData: authorizationData});
    } else {
        [keychainQuery setObject:authorizationData forKey:(id)kSecValueData];
        status = SecItemAdd((CFDictionaryRef)keychainQuery, NULL);
    }

      if (status != noErr) {
          NSLog(@"AUTH ERROR. Cant store auth state in keychain");
      } else {
          NSLog(@"AUTH SUCCESS! Added auth state to keychain");
      }
    
    return status == noErr;
}

+ (NSMutableDictionary*)getKeyChainQuery {
    NSMutableDictionary *keychainQuery =
         [NSMutableDictionary dictionaryWithObjectsAndKeys:(id)kSecClassGenericPassword, (id)kSecClass,
                                                           @"OAuth", (id)kSecAttrGeneric,
                                                           @"OAuth", (id)kSecAttrAccount,
                                                           @"fire-fad-auth", (id)kSecAttrService,
                                                           nil];
    return keychainQuery;
}

@end


NS_ASSUME_NONNULL_END
