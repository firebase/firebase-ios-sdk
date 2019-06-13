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

@property(nonatomic, readonly) FIRInstallationsAPIService *APIService;

@property(atomic, strong, nullable) FBLPromise<FIRInstallationsItem *> *registrationPromise;
@end

@implementation FIRInstallationsIDController

- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                             APIKey:(NSString *)APIKey
                          projectID:(NSString *)projectID {
  FIRSecureStorage *secureStorage = [[FIRSecureStorage alloc] init];
  FIRInstallationsStore *installationsStore =
      [[FIRInstallationsStore alloc] initWithSecureStorage:secureStorage accessGroup:nil];
  FIRInstallationsAPIService *apiService =
      [[FIRInstallationsAPIService alloc] initWithAPIKey:APIKey projectID:projectID];
  return [self initWithGoogleAppID:appID
                           appName:appName
                installationsStore:installationsStore
                        APIService:apiService];
}

/// The initializer is supposed to be used by tests to inject `installationsStore`.
- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                 installationsStore:(FIRInstallationsStore *)installationsStore
                         APIService:(FIRInstallationsAPIService *)APIService {
  self = [super init];
  if (self) {
    _appID = appID;
    _appName = appName;
    _installationsStore = installationsStore;
    _APIService = APIService;
  }
  return self;
}

- (FBLPromise<FIRInstallationsItem *> *)getInstallationItem {
  FBLPromise<FIRInstallationsItem *> *installationItemPromise =
      [self getStoredFID]
          .recover(^id(NSError *error) {
            return [self migrateIID];
          })
          .recover(^id(NSError *error) {
            // TODO: Are the cases when we should not create a new FID?
            return [self createAndSaveFID];
          });

  // Initiate registration process on success if needed, but return the instalation without waiting
  // for it.
  installationItemPromise.then(^id(FIRInstallationsItem *installation) {
    [self registerInstallationIfNeeded:installation];
    return nil;
  });

  return installationItemPromise;
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

#pragma mark - FID registration

- (FBLPromise<FIRInstallationsItem *> *)registerInstallationIfNeeded:
    (FIRInstallationsItem *)installation {
  switch (installation.registrationStatus) {
    case FIRInstallationStatusRegistered:
      // Already registered. Do nothing.
      return [FBLPromise resolvedWith:installation];

    case FIRInstallationStatusUnknown:
    case FIRInstallationStatusUnregistered:
    case FIRInstallationStatusRegistrationInProgress:
      // Registration required. Proceed.
      break;
  }

  // TODO: Check if installations match.
  if (self.registrationPromise) {
    return self.registrationPromise;
  }

  self.registrationPromise = [self.APIService registerInstallation:installation].then(
      ^id(FIRInstallationsItem *registredInstallation) {
        return [self.installationsStore saveInstallation:registredInstallation];
      });

  // Clean self.registrationPromise on finish.
  self.registrationPromise
      .then(^id _Nullable(FIRInstallationsItem *_Nullable value) {
        self.registrationPromise = nil;
        return nil;
      })
      .catch(^(NSError *_Nonnull error) {
        self.registrationPromise = nil;
      });

  return self.registrationPromise;
}

@end
