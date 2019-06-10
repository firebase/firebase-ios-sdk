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

#import "FIRInstallationsIDController.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FIRInstallationsAPIService.h"
#import "FIRInstallationsItem.h"
#import "FIRInstallationsStore.h"
#import "FIRSecureStorage.h"

@interface FIRInstallationsIDController ()
@property(nonatomic, readonly) NSString *appID;
@property(nonatomic, readonly) NSString *appName;

@property(nonatomic, readonly) FIRInstallationsStore *installationsStore;

// TODO: Use FIRInstallationsAPIService to register installation.
//@property(nonatomic, readonly) FIRInstallationsAPIService *APIService;
@end

@implementation FIRInstallationsIDController

- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                             APIKey:(NSString *)APIKey {
  FIRSecureStorage *secureStorage = [[FIRSecureStorage alloc] init];
  FIRInstallationsStore *installationsStore =
      [[FIRInstallationsStore alloc] initWithSecureStorage:secureStorage accessGroup:nil];
  return [self initWithGoogleAppID:appID
                           appName:appName
                            APIKey:APIKey
                installationsStore:installationsStore];
}

/// The initializer is supposed to be used by tests to inject `installationsStore`.
- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                             APIKey:(NSString *)APIKey
                 installationsStore:(FIRInstallationsStore *)installationsStore {
  self = [super init];
  if (self) {
    _appID = appID;
    _appName = appName;
    _installationsStore = installationsStore;
  }
  return self;
}

- (FBLPromise<FIRInstallationsItem *> *)getInstallationItem {
  return [self getStoredFID]
      .recover(^id(NSError *error) {
        return [self migrateIID];
      })
      .recover(^id(NSError *error) {
        // TODO: Are the cases when we should not create a new FID?
        return [self createAndSaveFID];
      });
}

- (FBLPromise<FIRInstallationsItem *> *)getStoredFID {
  return [self.installationsStore installationForAppID:self.appID appName:self.appName].validate(
      ^BOOL(FIRInstallationsItem *installation) {
        BOOL isValid = NO;
        switch (installation.registrationStatus) {
          case FIRInstallationStatusUnregistered:
          case FIRInstallationStatusRegistrationInProgress:
          case FIRInstallationStatusRegistered:
            isValid = YES;
            break;

          case FIRInstallationStatusUnknown:
            isValid = NO;
            break;
        }

        return isValid;
      });
}

- (FBLPromise<FIRInstallationsItem *> *)createAndSaveFID {
  FIRInstallationsItem *installation = [[FIRInstallationsItem alloc] initWithAppID:self.appID
                                                                   firebaseAppName:self.appName];
  installation.firebaseInstallationID = [FIRInstallationsItem generateFID];
  installation.registrationStatus = FIRInstallationStatusUnregistered;

  return [self.installationsStore saveInstallation:installation].then(^id(NSNull *result) {
    return installation;
  });
}

- (FBLPromise<FIRInstallationsItem *> *)migrateIID {
  // TODO: Implement.
  FBLPromise *promise = [FBLPromise pendingPromise];
  [promise reject:[NSError errorWithDomain:@"FIRInstallationsIDController" code:-1 userInfo:nil]];
  return promise;
}

@end
