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

#import "Firebase/InstanceID/FIRInstanceIDKeychain.h"

#import "Firebase/InstanceID/FIRInstanceIDLogger.h"

NSString *const kFIRInstanceIDKeychainErrorDomain = @"com.google.iid";

@interface FIRInstanceIDKeychain () {
  dispatch_queue_t _keychainOperationQueue;
}

@end

@implementation FIRInstanceIDKeychain

+ (instancetype)sharedInstance {
  static FIRInstanceIDKeychain *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRInstanceIDKeychain alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _keychainOperationQueue =
        dispatch_queue_create("com.google.FirebaseInstanceID.Keychain", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (CFTypeRef)itemWithQuery:(NSDictionary *)keychainQuery {
  __block SecKeyRef keyRef = NULL;
  dispatch_sync(_keychainOperationQueue, ^{
    OSStatus status =
        SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyRef);

    if (status != noErr) {
      if (keyRef) {
        CFRelease(keyRef);
      }
      FIRInstanceIDLoggerDebug(kFIRInstanceIDKeychainReadItemError,
                               @"Info is not found in Keychain. OSStatus: %d. Keychain query: %@",
                               (int)status, keychainQuery);
    }
  });
  return keyRef;
}

- (void)removeItemWithQuery:(NSDictionary *)keychainQuery
                    handler:(void (^)(NSError *error))handler {
  dispatch_async(_keychainOperationQueue, ^{
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    if (status != noErr) {
      FIRInstanceIDLoggerDebug(
          kFIRInstanceIDKeychainDeleteItemError,
          @"Couldn't delete item from Keychain OSStatus: %d with the keychain query %@",
          (int)status, keychainQuery);
    }

    if (handler) {
      NSError *error;
      // When item is not found, it should NOT be considered as an error. The operation should
      // continue.
      if (status != noErr && status != errSecItemNotFound) {
        error = [NSError errorWithDomain:kFIRInstanceIDKeychainErrorDomain
                                    code:status
                                userInfo:nil];
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(error);
      });
    }
  });
}

- (void)addItemWithQuery:(NSDictionary *)keychainQuery handler:(void (^)(NSError *))handler {
  dispatch_async(_keychainOperationQueue, ^{
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);

    if (handler) {
      NSError *error;
      if (status != noErr) {
        FIRInstanceIDLoggerWarning(kFIRInstanceIDKeychainAddItemError,
                                   @"Couldn't add item to Keychain OSStatus: %d", (int)status);
        error = [NSError errorWithDomain:kFIRInstanceIDKeychainErrorDomain
                                    code:status
                                userInfo:nil];
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(error);
      });
    }
  });
}

@end
