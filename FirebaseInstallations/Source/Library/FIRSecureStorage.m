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

#import "FIRSecureStorage.h"
#import <Security/Security.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FIRInstallationsErrorUtil.h"

@interface FIRSecureStorage ()
@property(nonatomic, strong) dispatch_queue_t keychainQueue;
@property(nonatomic, readonly) NSString *service;
@end

@implementation FIRSecureStorage

- (instancetype)init {
  return [self initWithService:@"com.firebase.FIRInstallations.installations"];
}

- (instancetype)initWithService:(NSString *)service {
  self = [super init];
  if (self) {
    _keychainQueue = dispatch_queue_create("com.firebase.FIRSecureStorage", DISPATCH_QUEUE_SERIAL);
    _service = [service copy];
  }
  return self;
}

- (FBLPromise<id<NSSecureCoding>> *)getObjectForKey:(NSString *)key
                                        objectClass:(Class)objectClass
                                        accessGroup:(nullable NSString *)accessGroup {
  return [FBLPromise onQueue:self.keychainQueue
                          do:^id {
                            NSDictionary *query = [self keychainQueryWithKey:key
                                                                 accessGroup:accessGroup];
                            NSError *error;
                            NSData *encodedObject = [self getItemWithQuery:query error:&error];

                            if (error) {
                              return error;
                            }
                            if (!encodedObject) {
                              return nil;
                            }
                            id object = [self unarchivedObjectOfClass:objectClass
                                                             fromData:encodedObject
                                                                error:&error];
                            if (error) {
                              return error;
                            }

                            return object;
                          }];
}

- (FBLPromise<NSNull *> *)setObject:(id<NSSecureCoding>)object
                             forKey:(NSString *)key
                        accessGroup:(nullable NSString *)accessGroup {
  return [FBLPromise onQueue:self.keychainQueue
                          do:^id _Nullable {
                            NSDictionary *query = [self keychainQueryWithKey:key
                                                                 accessGroup:accessGroup];
                            NSError *error;
                            NSData *encodedObject = [self archiveDataForObject:object error:&error];
                            if (!encodedObject) {
                              return error;
                            }

                            if (![self setItem:encodedObject withQuery:query error:&error]) {
                              return error;
                            }

                            return [NSNull null];
                          }];
}

- (FBLPromise<NSNull *> *)removeObjectForKey:(NSString *)key
                                 accessGroup:(nullable NSString *)accessGroup {
  return [FBLPromise onQueue:self.keychainQueue
                          do:^id _Nullable {
                            NSDictionary *query = [self keychainQueryWithKey:key
                                                                 accessGroup:accessGroup];

                            NSError *error;
                            if (![self removeItemWithQuery:query error:&error]) {
                              return error;
                            }

                            return [NSNull null];
                          }];
}

- (NSMutableDictionary<NSString *, id> *)keychainQueryWithKey:(NSString *)key
                                                  accessGroup:(nullable NSString *)accessGroup {
  NSMutableDictionary<NSString *, id> *query = [NSMutableDictionary dictionary];

  query[(__bridge NSString *)kSecClass] = (__bridge NSString *)kSecClassGenericPassword;
  query[(__bridge NSString *)kSecAttrService] = self.service;
  query[(__bridge NSString *)kSecAttrAccount] = key;

  if (accessGroup) {
    query[(__bridge NSString *)kSecAttrAccessGroup] = accessGroup;
  }

  return query;
}

- (nullable NSData *)archiveDataForObject:(id<NSSecureCoding>)object error:(NSError **)outError {
  NSData *archiveData;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    archiveData = [NSKeyedArchiver archivedDataWithRootObject:object
                                        requiringSecureCoding:YES
                                                        error:outError];
  } else {
    @try {
      NSMutableData *data = [NSMutableData data];
      NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
      archiver.requiresSecureCoding = YES;

      [archiver encodeObject:object forKey:NSKeyedArchiveRootObjectKey];
      [archiver finishEncoding];

      archiveData = [data copy];
    } @catch (NSException *exception) {
      if (outError) {
        *outError = [FIRInstallationsErrorUtil keyedArchiverErrorWithException:exception];
      }
    }
  }

  return archiveData;
}

- (nullable id)unarchivedObjectOfClass:(Class)class
                              fromData:(NSData *)data
                                 error:(NSError **)outError {
  id object;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    object = [NSKeyedUnarchiver unarchivedObjectOfClass:class fromData:data error:outError];
  } else {
    @try {
      NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
      unarchiver.requiresSecureCoding = YES;

      object = [unarchiver decodeObjectOfClass:class forKey:NSKeyedArchiveRootObjectKey];
    } @catch (NSException *exception) {
      if (outError) {
        *outError = [FIRInstallationsErrorUtil keyedArchiverErrorWithException:exception];
      }
    }
  }

  return object;
}

- (nullable NSData *)getItemWithQuery:(NSDictionary *)query
                                error:(NSError *_Nullable *_Nullable)outError {
  NSMutableDictionary *mutableQuery = [query mutableCopy];

  mutableQuery[(__bridge id)kSecReturnData] = @YES;
  mutableQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

  CFArrayRef result = NULL;
  OSStatus status =
      SecItemCopyMatching((__bridge CFDictionaryRef)mutableQuery, (CFTypeRef *)&result);

  if (status == noErr && result != NULL) {
    if (outError) {
      *outError = nil;
    }

    return (__bridge_transfer NSData *)result;
  }

  if (status == errSecItemNotFound) {
    if (outError) {
      *outError = nil;
    }
  } else {
    if (outError) {
      *outError = [FIRInstallationsErrorUtil keychainErrorWithFunction:@"SecItemCopyMatching"
                                                                status:status];
    }
  }
  return nil;
}

- (BOOL)setItem:(NSData *)item
      withQuery:(NSDictionary *)query
          error:(NSError *_Nullable *_Nullable)outError {
  NSData *existingItem = [self getItemWithQuery:query error:outError];
  if (outError && *outError) {
    return NO;
  }

  NSMutableDictionary *mutableQuery = [query mutableCopy];
  mutableQuery[(__bridge id)kSecAttrAccessible] =
      (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly;

  OSStatus status;
  if (!existingItem) {
    mutableQuery[(__bridge id)kSecValueData] = item;
    status = SecItemAdd((__bridge CFDictionaryRef)mutableQuery, NULL);
  } else {
    NSDictionary *attributes = @{(__bridge id)kSecValueData : item};
    status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
  }

  if (status == noErr) {
    if (outError) {
      *outError = nil;
    }
    return YES;
  }

  NSString *function = existingItem ? @"SecItemUpdate" : @"SecItemAdd";
  if (outError) {
    *outError = [FIRInstallationsErrorUtil keychainErrorWithFunction:function status:status];
  }
  return NO;
}

- (BOOL)removeItemWithQuery:(NSDictionary *)query error:(NSError *_Nullable *_Nullable)outError {
  OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);

  if (status == noErr || status == errSecItemNotFound) {
    if (outError) {
      *outError = nil;
    }
    return YES;
  }

  if (outError) {
    *outError = [FIRInstallationsErrorUtil keychainErrorWithFunction:@"SecItemDelete"
                                                              status:status];
  }
  return NO;
}

@end
