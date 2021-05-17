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

#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestArtifactStorage.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import <GoogleUtilities/GULKeychainStorage.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kKeychainService = @"com.firebase.app_check.app_attest_artifact_storage";

@interface FIRAppAttestArtifactStorage ()

@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) NSString *appID;
@property(nonatomic, readonly) GULKeychainStorage *keychainStorage;
@property(nonatomic, readonly, nullable) NSString *accessGroup;

@end

@implementation FIRAppAttestArtifactStorage

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

- (FBLPromise<NSData *> *)getArtifactForKey:(NSString *)keyID {
  return [self.keychainStorage getObjectForKey:[self artifactKey]
                                   objectClass:[NSData class]
                                   accessGroup:self.accessGroup]
      .then(^NSData *(id<NSSecureCoding> storedArtifact) {
        if ([(NSObject *)storedArtifact isKindOfClass:[NSData class]]) {
          return (NSData *)storedArtifact;
        } else {
          return nil;
        }
      });
}

- (FBLPromise<NSData *> *)setArtifact:(nullable NSData *)artifact forKey:(nonnull NSString *)keyID {
  if (artifact) {
    return [self.keychainStorage setObject:artifact
                                    forKey:[self artifactKey]
                               accessGroup:self.accessGroup]
        .then(^id _Nullable(NSNull *_Nullable value) {
          return artifact;
        });
  } else {
    return [self.keychainStorage removeObjectForKey:[self artifactKey] accessGroup:self.accessGroup]
        .then(^id _Nullable(NSNull *_Nullable value) {
          return nil;
        });
  }
}

- (NSString *)artifactKey {
  return
      [NSString stringWithFormat:@"app_check_app_attest_artifact.%@.%@", self.appName, self.appID];
}

@end

NS_ASSUME_NONNULL_END
