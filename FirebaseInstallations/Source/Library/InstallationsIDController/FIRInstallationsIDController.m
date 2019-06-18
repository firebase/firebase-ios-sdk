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
#import "FIRInstallationsAuthTokenResultInternal.h"
#import "FIRInstallationsItem.h"
#import "FIRInstallationsSingleOperationPromiseCache.h"
#import "FIRInstallationsStore.h"
#import "FIRInstallationsStoredAuthToken.h"
#import "FIRSecureStorage.h"

NSTimeInterval const kFIRInstallationsTokenExpirationThreshold = 60 * 60;  // 1 hour.

@interface FIRInstallationsIDController ()
@property(nonatomic, readonly) NSString *appID;
@property(nonatomic, readonly) NSString *appName;

@property(nonatomic, readonly) FIRInstallationsStore *installationsStore;

@property(nonatomic, readonly) FIRInstallationsAPIService *APIService;

@property(nonatomic, readonly) FIRInstallationsSingleOperationPromiseCache<FIRInstallationsItem *>
    *getInstallationPromiseCache;
@property(nonatomic, readonly)
    FIRInstallationsSingleOperationPromiseCache<FIRInstallationsAuthTokenResult *>
        *authTokenPromiseCache;
@property(nonatomic, readonly)
    FIRInstallationsSingleOperationPromiseCache<FIRInstallationsAuthTokenResult *>
        *authTokenForcingRefreshPromiseCache;
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

    __weak FIRInstallationsIDController *weakSelf = self;

    _getInstallationPromiseCache = [[FIRInstallationsSingleOperationPromiseCache alloc]
        initWithNewOperationHandler:^FBLPromise *_Nonnull {
          FIRInstallationsIDController *strongSelf = weakSelf;
          return [strongSelf createGetInstallationItemPromise];
        }];

    _authTokenPromiseCache = [[FIRInstallationsSingleOperationPromiseCache alloc]
        initWithNewOperationHandler:^FBLPromise *_Nonnull {
          FIRInstallationsIDController *strongSelf = weakSelf;
          return [strongSelf createAuthTokenPromiseForcingRefresh:NO];
        }];

    _authTokenForcingRefreshPromiseCache = [[FIRInstallationsSingleOperationPromiseCache alloc]
        initWithNewOperationHandler:^FBLPromise *_Nonnull {
          FIRInstallationsIDController *strongSelf = weakSelf;
          return [strongSelf createAuthTokenPromiseForcingRefresh:YES];
        }];
  }
  return self;
}

#pragma mark - Get Installation.

- (FBLPromise<FIRInstallationsItem *> *)getInstallationItem {
  return [self.getInstallationPromiseCache getExistingPendingOrCreateNewPromise];
}

- (FBLPromise<FIRInstallationsItem *> *)createGetInstallationItemPromise {
  FBLPromise<FIRInstallationsItem *> *installationItemPromise =
      [self getStoredInstallation]
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

- (FBLPromise<FIRInstallationsItem *> *)getStoredInstallation {
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

  return [self.APIService registerInstallation:installation].then(
      ^id(FIRInstallationsItem *registredInstallation) {
        return [self.installationsStore saveInstallation:registredInstallation];
      });
}

#pragma mark - Auth Token

- (FBLPromise<FIRInstallationsAuthTokenResult *> *)createAuthTokenPromiseForcingRefresh:
    (BOOL)forceRefresh {
  return [self installationWithValidAuthTokenForcingRefresh:forceRefresh].then(
      ^FIRInstallationsAuthTokenResult *(FIRInstallationsItem *installation) {
        FIRInstallationsAuthTokenResult *result = [[FIRInstallationsAuthTokenResult alloc]
             initWithToken:installation.authToken.token
            expirationDate:installation.authToken.expirationDate];
        return result;
      });
}

// TODO: Guarantee a single request at the time.
- (FBLPromise<FIRInstallationsAuthTokenResult *> *)getAuthTokenForcingRefresh:(BOOL)forceRefresh {
  if (forceRefresh) {
    return [self.authTokenForcingRefreshPromiseCache getExistingPendingOrCreateNewPromise];
  } else {
    return [self.authTokenPromiseCache getExistingPendingOrCreateNewPromise];
  }
}

- (FBLPromise<FIRInstallationsItem *> *)installationWithValidAuthTokenForcingRefresh:
    (BOOL)forceRefresh {
  return [self getInstallationItem]
      .then(^FBLPromise<FIRInstallationsItem *> *(FIRInstallationsItem *installstion) {
        return [self registerInstallationIfNeeded:installstion];
      })
      .then(^id(FIRInstallationsItem *registeredInstallstion) {
        BOOL isTokenExpiredOrExpiresSoon =
            [registeredInstallstion.authToken.expirationDate timeIntervalSinceDate:[NSDate date]] <
            kFIRInstallationsTokenExpirationThreshold;
        if (forceRefresh || isTokenExpiredOrExpiresSoon) {
          return [self.APIService refreshAuthTokenForInstallation:registeredInstallstion];
        } else {
          return registeredInstallstion;
        }
      })
      .catch(^void(NSError *error){
          // TODO: Handle the errors.
      });
}

@end
