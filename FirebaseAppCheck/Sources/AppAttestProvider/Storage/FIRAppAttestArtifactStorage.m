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

#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestStoredArtifact.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

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
                                   objectClass:[FIRAppAttestStoredArtifact class]
                                   accessGroup:self.accessGroup]
      .then(^NSData *(id<NSSecureCoding> storedArtifact) {
        FIRAppAttestStoredArtifact *artifact = (FIRAppAttestStoredArtifact *)storedArtifact;
        if ([artifact isKindOfClass:[FIRAppAttestStoredArtifact class]] &&
            [artifact.keyID isEqualToString:keyID]) {
          return artifact.artifact;
        } else {
          return nil;
        }
      })
      .recover(^NSError *(NSError *error) {
        return [FIRAppCheckErrorUtil keychainErrorWithError:error];
      });
}

- (FBLPromise<NSData *> *)setArtifact:(nullable NSData *)artifact forKey:(nonnull NSString *)keyID {
  if (artifact) {
    return [self storeArtifact:artifact forKey:keyID].recover(^NSError *(NSError *error) {
      return [FIRAppCheckErrorUtil keychainErrorWithError:error];
    });
  } else {
    return [self.keychainStorage removeObjectForKey:[self artifactKey] accessGroup:self.accessGroup]
        .then(^id _Nullable(NSNull *_Nullable value) {
          return nil;
        })
        .recover(^NSError *(NSError *error) {
          return [FIRAppCheckErrorUtil keychainErrorWithError:error];
        });
  }
}

#pragma mark - Helpers

- (FBLPromise<NSData *> *)storeArtifact:(nullable NSData *)artifact
                                 forKey:(nonnull NSString *)keyID {
  FIRAppAttestStoredArtifact *storedArtifact =
      [[FIRAppAttestStoredArtifact alloc] initWithKeyID:keyID artifact:artifact];
  return [self.keychainStorage setObject:storedArtifact
                                  forKey:[self artifactKey]
                             accessGroup:self.accessGroup]
      .then(^id _Nullable(NSNull *_Nullable value) {
        return artifact;
      });
}

- (NSString *)artifactKey {
  return
      [NSString stringWithFormat:@"app_check_app_attest_artifact.%@.%@", self.appName, self.appID];
}

@end

NS_ASSUME_NONNULL_END
