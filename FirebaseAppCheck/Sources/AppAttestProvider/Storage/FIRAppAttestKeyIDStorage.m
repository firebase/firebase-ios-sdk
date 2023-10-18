/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestKeyIDStorage.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import <GoogleUtilities/GULKeychainStorage.h>

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

static NSString *const kKeychainService = @"com.firebase.app_check.app_attest_key_id_storage";

@interface FIRAppAttestKeyIDStorage ()

@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) NSString *appID;
@property(nonatomic, readonly) GULKeychainStorage *keychainStorage;
@property(nonatomic, readonly, nullable) NSString *accessGroup;

@end

@implementation FIRAppAttestKeyIDStorage

- (instancetype)initWithAppName:(NSString *)appName
                          appID:(NSString *)appID
                keychainStorage:(GULKeychainStorage *)keychainStorage
                    accessGroup:(nullable NSString *)accessGroup {
  self = [super init];
  if (self) {
    _appName = [appName copy];
    _appID = [appID copy];
    _keychainStorage = keychainStorage;
    _accessGroup = [accessGroup copy];
  }
  return self;
}

- (instancetype)initWithAppName:(NSString *)appName
                          appID:(NSString *)appID
                    accessGroup:(nullable NSString *)accessGroup {
  GULKeychainStorage *keychainStorage =
      [[GULKeychainStorage alloc] initWithService:kKeychainService];
  return [self initWithAppName:appName
                         appID:appID
               keychainStorage:keychainStorage
                   accessGroup:accessGroup];
}

- (nonnull FBLPromise<NSString *> *)setAppAttestKeyID:(nullable NSString *)keyID {
  if (keyID) {
    return [self storeAppAttestKeyID:keyID].recover(^NSError *(NSError *error) {
      return [FIRAppCheckErrorUtil keychainErrorWithError:error];
    });
  } else {
    return [self.keychainStorage removeObjectForKey:[self keyIDStorageKey]
                                        accessGroup:self.accessGroup]
        .then(^id _Nullable(NSNull *_Nullable value) {
          return nil;
        })
        .recover(^NSError *(NSError *error) {
          return [FIRAppCheckErrorUtil keychainErrorWithError:error];
        });
  }
}

- (nonnull FBLPromise<NSString *> *)getAppAttestKeyID {
  return [self.keychainStorage getObjectForKey:[self keyIDStorageKey]
                                   objectClass:[NSString class]
                                   accessGroup:self.accessGroup]
      .then(^NSString *(id<NSSecureCoding> storedKeyID) {
        NSString *keyID = (NSString *)storedKeyID;
        if ([keyID isKindOfClass:[NSString class]]) {
          return keyID;
        } else {
          return nil;
        }
      })
      .recover(^NSError *(NSError *error) {
        return [FIRAppCheckErrorUtil appAttestKeyIDNotFound];
      });
}

#pragma mark - Helpers

- (FBLPromise<NSString *> *)storeAppAttestKeyID:(nullable NSString *)keyID {
  return [self.keychainStorage setObject:keyID
                                  forKey:[self keyIDStorageKey]
                             accessGroup:self.accessGroup]
      .then(^id _Nullable(NSNull *_Nullable value) {
        return keyID;
      });
}

- (NSString *)keyIDStorageKey {
  return [[self class] keyIDStorageKeyForAppName:self.appName appID:self.appID];
}

+ (NSString *)keyIDStorageKeyForAppName:(NSString *)appName appID:(NSString *)appID {
  return [NSString stringWithFormat:@"app_attest_keyID.%@.%@", appName, appID];
}

@end
