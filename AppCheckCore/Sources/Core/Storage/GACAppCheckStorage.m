/*
 * Copyright 2020 Google LLC
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

#import "AppCheckCore/Sources/Core/Storage/GACAppCheckStorage.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import <GoogleUtilities/GULKeychainStorage.h>

#import "AppCheckCore/Sources/Core/Errors/GACAppCheckErrorUtil.h"
#import "AppCheckCore/Sources/Core/Storage/GACAppCheckStoredToken+GACAppCheckToken.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kKeychainService = @"com.google.app_check_core.token_storage";

@interface GACAppCheckStorage ()

@property(nonatomic, readonly) NSString *tokenKey;
@property(nonatomic, readonly) GULKeychainStorage *keychainStorage;
@property(nonatomic, readonly, nullable) NSString *accessGroup;

@end

@implementation GACAppCheckStorage

- (instancetype)initWithTokenKey:(NSString *)tokenKey
                 keychainStorage:(GULKeychainStorage *)keychainStorage
                     accessGroup:(nullable NSString *)accessGroup {
  self = [super init];
  if (self) {
    _tokenKey = [tokenKey copy];
    _keychainStorage = keychainStorage;
    _accessGroup = [accessGroup copy];
  }
  return self;
}

- (instancetype)initWithTokenKey:(NSString *)tokenKey accessGroup:(nullable NSString *)accessGroup {
  GULKeychainStorage *keychainStorage =
      [[GULKeychainStorage alloc] initWithService:kKeychainService];
  return [self initWithTokenKey:tokenKey keychainStorage:keychainStorage accessGroup:accessGroup];
}

- (FBLPromise<GACAppCheckToken *> *)getToken {
  return [self.keychainStorage getObjectForKey:[self tokenKey]
                                   objectClass:[GACAppCheckStoredToken class]
                                   accessGroup:self.accessGroup]
      .then(^GACAppCheckToken *(id<NSSecureCoding> storedToken) {
        if ([(NSObject *)storedToken isKindOfClass:[GACAppCheckStoredToken class]]) {
          return [(GACAppCheckStoredToken *)storedToken appCheckToken];
        } else {
          return nil;
        }
      })
      .recover(^NSError *(NSError *error) {
        return [GACAppCheckErrorUtil keychainErrorWithError:error];
      });
}

- (FBLPromise<NSNull *> *)setToken:(nullable GACAppCheckToken *)token {
  if (token) {
    return [self storeToken:token].recover(^NSError *(NSError *error) {
      return [GACAppCheckErrorUtil keychainErrorWithError:error];
    });
  } else {
    return [self.keychainStorage removeObjectForKey:[self tokenKey] accessGroup:self.accessGroup]
        .then(^id _Nullable(NSNull *_Nullable value) {
          return token;
        })
        .recover(^NSError *(NSError *error) {
          return [GACAppCheckErrorUtil keychainErrorWithError:error];
        });
  }
}

#pragma mark - Helpers

- (FBLPromise<NSNull *> *)storeToken:(nullable GACAppCheckToken *)token {
  GACAppCheckStoredToken *storedToken = [[GACAppCheckStoredToken alloc] init];
  [storedToken updateWithToken:token];
  return [self.keychainStorage setObject:storedToken
                                  forKey:[self tokenKey]
                             accessGroup:self.accessGroup]
      .then(^id _Nullable(NSNull *_Nullable value) {
        return token;
      });
}

@end

NS_ASSUME_NONNULL_END
