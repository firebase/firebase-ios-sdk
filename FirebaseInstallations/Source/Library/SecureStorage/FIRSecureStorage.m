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
#import "FIRInstallationsKeychainUtils.h"

@interface FIRSecureStorage ()
@property(nonatomic, readonly) dispatch_queue_t keychainQueue;
@property(nonatomic, readonly) dispatch_queue_t inMemoryCacheQueue;
@property(nonatomic, readonly) NSString *service;
@property(nonatomic, readonly) NSCache<NSString *, id<NSSecureCoding>> *inMemoryCache;
@end

@implementation FIRSecureStorage

- (instancetype)init {
  NSCache *cache = [[NSCache alloc] init];
  // Cache up to 5 installations.
  cache.countLimit = 5;
  return [self initWithService:@"com.firebase.FIRInstallations.installations" cache:cache];
}

- (instancetype)initWithService:(NSString *)service cache:(NSCache *)cache {
  self = [super init];
  if (self) {
    _keychainQueue = dispatch_queue_create(
        "com.firebase.FIRInstallations.FIRSecureStorage.Keychain", DISPATCH_QUEUE_SERIAL);
    _inMemoryCacheQueue = dispatch_queue_create(
        "com.firebase.FIRInstallations.FIRSecureStorage.InMemoryCache", DISPATCH_QUEUE_SERIAL);
    _service = [service copy];
    _inMemoryCache = cache;
  }
  return self;
}

#pragma mark - Public

- (FBLPromise<id<NSSecureCoding>> *)getObjectForKey:(NSString *)key
                                        objectClass:(Class)objectClass
                                        accessGroup:(nullable NSString *)accessGroup {
  return [FBLPromise onQueue:self.inMemoryCacheQueue
                          do:^id _Nullable {
                            // Return cached object or fail otherwise.
                            id object = [self.inMemoryCache objectForKey:key];
                            return object
                                       ?: [[NSError alloc]
                                              initWithDomain:FBLPromiseErrorDomain
                                                        code:FBLPromiseErrorCodeValidationFailure
                                                    userInfo:nil];
                          }]
      .recover(^id _Nullable(NSError *error) {
        // Look for the object in the keychain.
        return [self getObjectFromKeychainForKey:key
                                     objectClass:objectClass
                                     accessGroup:accessGroup];
      });
}

- (FBLPromise<NSNull *> *)setObject:(id<NSSecureCoding>)object
                             forKey:(NSString *)key
                        accessGroup:(nullable NSString *)accessGroup {
  return [FBLPromise onQueue:self.inMemoryCacheQueue
                          do:^id _Nullable {
                            // Save to the in-memory cache first.
                            [self.inMemoryCache setObject:object forKey:[key copy]];
                            return [NSNull null];
                          }]
      .thenOn(self.keychainQueue, ^id(id result) {
        // Then store the object to the keychain.
        NSDictionary *query = [self keychainQueryWithKey:key accessGroup:accessGroup];
        NSError *error;
        NSData *encodedObject = [self archiveDataForObject:object error:&error];
        if (!encodedObject) {
          return error;
        }

        if (![FIRInstallationsKeychainUtils setItem:encodedObject withQuery:query error:&error]) {
          return error;
        }

        return [NSNull null];
      });
}

- (FBLPromise<NSNull *> *)removeObjectForKey:(NSString *)key
                                 accessGroup:(nullable NSString *)accessGroup {
  return [FBLPromise onQueue:self.inMemoryCacheQueue
                          do:^id _Nullable {
                            [self.inMemoryCache removeObjectForKey:key];
                            return nil;
                          }]
      .thenOn(self.keychainQueue, ^id(id result) {
        NSDictionary *query = [self keychainQueryWithKey:key accessGroup:accessGroup];

        NSError *error;
        if (![FIRInstallationsKeychainUtils removeItemWithQuery:query error:&error]) {
          return error;
        }

        return [NSNull null];
      });
}

#pragma mark - Private

- (FBLPromise<id<NSSecureCoding>> *)getObjectFromKeychainForKey:(NSString *)key
                                                    objectClass:(Class)objectClass
                                                    accessGroup:(nullable NSString *)accessGroup {
  // Look for the object in the keychain.
  return [FBLPromise onQueue:self.keychainQueue
                          do:^id {
                            NSDictionary *query = [self keychainQueryWithKey:key
                                                                 accessGroup:accessGroup];
                            NSError *error;
                            NSData *encodedObject =
                                [FIRInstallationsKeychainUtils getItemWithQuery:query error:&error];

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
                          }]
      .thenOn(self.inMemoryCacheQueue,
              ^id<NSSecureCoding> _Nullable(id<NSSecureCoding> _Nullable object) {
                // Save object to the in-memory cache if exists and return the object.
                if (object) {
                  [self.inMemoryCache setObject:object forKey:[key copy]];
                }
                return object;
              });
}

- (void)resetInMemoryCache {
  [self.inMemoryCache removeAllObjects];
}

#pragma mark - Keychain

- (NSMutableDictionary<NSString *, id> *)keychainQueryWithKey:(NSString *)key
                                                  accessGroup:(nullable NSString *)accessGroup {
  NSMutableDictionary<NSString *, id> *query = [NSMutableDictionary dictionary];

  query[(__bridge NSString *)kSecClass] = (__bridge NSString *)kSecClassGenericPassword;
  query[(__bridge NSString *)kSecAttrService] = self.service;
  query[(__bridge NSString *)kSecAttrAccount] = key;

  if (accessGroup) {
    query[(__bridge NSString *)kSecAttrAccessGroup] = accessGroup;
  }

#if TARGET_OS_OSX
  if (self.keychainRef) {
    query[(__bridge NSString *)kSecUseKeychain] = (__bridge id)(self.keychainRef);
    query[(__bridge NSString *)kSecMatchSearchList] = @[ (__bridge id)(self.keychainRef) ];
  }
#endif  // TARGET_OSX

  return query;
}

- (nullable NSData *)archiveDataForObject:(id<NSSecureCoding>)object error:(NSError **)outError {
  NSData *archiveData;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    NSError *error;
    archiveData = [NSKeyedArchiver archivedDataWithRootObject:object
                                        requiringSecureCoding:YES
                                                        error:&error];
    if (error && outError) {
      *outError = [FIRInstallationsErrorUtil keyedArchiverErrorWithError:error];
    }
  } else {
    @try {
      NSMutableData *data = [NSMutableData data];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
#pragma clang diagnostic pop
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
    NSError *error;
    object = [NSKeyedUnarchiver unarchivedObjectOfClass:class fromData:data error:&error];
    if (error && outError) {
      *outError = [FIRInstallationsErrorUtil keyedArchiverErrorWithError:error];
    }
  } else {
    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
#pragma clang diagnostic pop
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

@end
