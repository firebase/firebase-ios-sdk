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

#import <FirebaseCore/FIRAppInternal.h>

#import "FIRInstallationsAPIService.h"
#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsIIDStore.h"
#import "FIRInstallationsItem.h"
#import "FIRInstallationsLogger.h"
#import "FIRInstallationsSingleOperationPromiseCache.h"
#import "FIRInstallationsStore.h"
#import "FIRInstallationsStoredAuthToken.h"
#import "FIRSecureStorage.h"

const NSNotificationName FIRInstallationIDDidChangeNotification =
    @"FIRInstallationIDDidChangeNotification";
NSString *const kFIRInstallationIDDidChangeNotificationAppNameKey =
    @"FIRInstallationIDDidChangeNotification";

NSTimeInterval const kFIRInstallationsTokenExpirationThreshold = 60 * 60;  // 1 hour.

@interface FIRInstallationsIDController ()
@property(nonatomic, readonly) NSString *appID;
@property(nonatomic, readonly) NSString *appName;

@property(nonatomic, readonly) FIRInstallationsStore *installationsStore;
@property(nonatomic, readonly) FIRInstallationsIIDStore *IIDStore;

@property(nonatomic, readonly) FIRInstallationsAPIService *APIService;

@property(nonatomic, readonly) FIRInstallationsSingleOperationPromiseCache<FIRInstallationsItem *>
    *getInstallationPromiseCache;
@property(nonatomic, readonly)
    FIRInstallationsSingleOperationPromiseCache<FIRInstallationsItem *> *authTokenPromiseCache;
@property(nonatomic, readonly) FIRInstallationsSingleOperationPromiseCache<FIRInstallationsItem *>
    *authTokenForcingRefreshPromiseCache;
@property(nonatomic, readonly)
    FIRInstallationsSingleOperationPromiseCache<NSNull *> *deleteInstallationPromiseCache;
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
  FIRInstallationsIIDStore *IIDStore = [[FIRInstallationsIIDStore alloc] init];

  return [self initWithGoogleAppID:appID
                           appName:appName
                installationsStore:installationsStore
                        APIService:apiService
                          IIDStore:IIDStore];
}

/// The initializer is supposed to be used by tests to inject `installationsStore`.
- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                 installationsStore:(FIRInstallationsStore *)installationsStore
                         APIService:(FIRInstallationsAPIService *)APIService
                           IIDStore:(FIRInstallationsIIDStore *)IIDStore {
  self = [super init];
  if (self) {
    _appID = appID;
    _appName = appName;
    _installationsStore = installationsStore;
    _APIService = APIService;
    _IIDStore = IIDStore;

    __weak FIRInstallationsIDController *weakSelf = self;

    _getInstallationPromiseCache = [[FIRInstallationsSingleOperationPromiseCache alloc]
        initWithNewOperationHandler:^FBLPromise *_Nonnull {
          FIRInstallationsIDController *strongSelf = weakSelf;
          return [strongSelf createGetInstallationItemPromise];
        }];

    _authTokenPromiseCache = [[FIRInstallationsSingleOperationPromiseCache alloc]
        initWithNewOperationHandler:^FBLPromise *_Nonnull {
          FIRInstallationsIDController *strongSelf = weakSelf;
          return [strongSelf installationWithValidAuthTokenForcingRefresh:NO];
        }];

    _authTokenForcingRefreshPromiseCache = [[FIRInstallationsSingleOperationPromiseCache alloc]
        initWithNewOperationHandler:^FBLPromise *_Nonnull {
          FIRInstallationsIDController *strongSelf = weakSelf;
          return [strongSelf installationWithValidAuthTokenForcingRefresh:YES];
        }];

    _deleteInstallationPromiseCache = [[FIRInstallationsSingleOperationPromiseCache alloc]
        initWithNewOperationHandler:^FBLPromise *_Nonnull {
          FIRInstallationsIDController *strongSelf = weakSelf;
          return [strongSelf createDeleteInstallationPromise];
        }];
  }
  return self;
}

#pragma mark - Get Installation.

- (FBLPromise<FIRInstallationsItem *> *)getInstallationItem {
  return [self.getInstallationPromiseCache getExistingPendingOrCreateNewPromise];
}

- (FBLPromise<FIRInstallationsItem *> *)createGetInstallationItemPromise {
  FIRLogDebug(kFIRLoggerInstallations,
              kFIRInstallationsMessageCodeNewGetInstallationOperationCreated, @"%s, appName: %@",
              __PRETTY_FUNCTION__, self.appName);

  FBLPromise<FIRInstallationsItem *> *installationItemPromise =
      [self getStoredInstallation].recover(^id(NSError *error) {
        return [self createAndSaveFID];
      });

  // Initiate registration process on success if needed, but return the installation without waiting
  // for it.
  installationItemPromise.then(^id(FIRInstallationsItem *installation) {
    [self getAuthTokenForcingRefresh:NO];
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
  return [self migrateOrGenerateFID]
      .then(^FBLPromise<FIRInstallationsItem *> *(NSString *FID) {
        return [self createAndSaveInstallationWithFID:FID];
      })
      .then(^FIRInstallationsItem *(FIRInstallationsItem *installation) {
        [self postFIDDidChangeNotification];
        return installation;
      });
}

- (FBLPromise<FIRInstallationsItem *> *)createAndSaveInstallationWithFID:(NSString *)FID {
  FIRInstallationsItem *installation = [[FIRInstallationsItem alloc] initWithAppID:self.appID
                                                                   firebaseAppName:self.appName];
  installation.firebaseInstallationID = FID;
  installation.registrationStatus = FIRInstallationStatusUnregistered;

  return [self.installationsStore saveInstallation:installation].then(^id(NSNull *result) {
    return installation;
  });
}

- (FBLPromise<NSString *> *)migrateOrGenerateFID {
  if (![self isDefaultApp]) {
    // Existing IID should be used only for default FirebaseApp.
    return [FBLPromise resolvedWith:[FIRInstallationsItem generateFID]];
  }

  return [self.IIDStore existingIID].recover(^NSString *(NSError *error) {
    return [FIRInstallationsItem generateFID];
  });
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
      // Registration required. Proceed.
      break;
  }

  return [self.APIService registerInstallation:installation]
      .then(^id(FIRInstallationsItem *registeredInstallation) {
        // Expected successful result: @[FIRInstallationsItem *registeredInstallation, NSNull]
        return [FBLPromise all:@[
          registeredInstallation, [self.installationsStore saveInstallation:registeredInstallation]
        ]];
      })
      .then(^FIRInstallationsItem *(NSArray *result) {
        FIRInstallationsItem *registeredInstallation = result.firstObject;
        // Server may respond with a different FID if the sent one cannot be accepted.
        if (![registeredInstallation.firebaseInstallationID
                isEqualToString:installation.firebaseInstallationID]) {
          [self postFIDDidChangeNotification];
        }
        return registeredInstallation;
      });
}

#pragma mark - Auth Token

- (FBLPromise<FIRInstallationsItem *> *)getAuthTokenForcingRefresh:(BOOL)forceRefresh {
  if (forceRefresh) {
    return [self.authTokenForcingRefreshPromiseCache getExistingPendingOrCreateNewPromise];
  } else {
    return [self.authTokenPromiseCache getExistingPendingOrCreateNewPromise];
  }
}

- (FBLPromise<FIRInstallationsItem *> *)installationWithValidAuthTokenForcingRefresh:
    (BOOL)forceRefresh {
  FIRLogDebug(kFIRLoggerInstallations, kFIRInstallationsMessageCodeNewGetAuthTokenOperationCreated,
              @"-[FIRInstallationsIDController installationWithValidAuthTokenForcingRefresh:%@], "
              @"appName: %@",
              @(forceRefresh), self.appName);

  return [self getInstallationItem]
      .then(^FBLPromise<FIRInstallationsItem *> *(FIRInstallationsItem *installation) {
        return [self registerInstallationIfNeeded:installation];
      })
      .then(^id(FIRInstallationsItem *registeredInstallation) {
        BOOL isTokenExpiredOrExpiresSoon =
            [registeredInstallation.authToken.expirationDate timeIntervalSinceDate:[NSDate date]] <
            kFIRInstallationsTokenExpirationThreshold;
        if (forceRefresh || isTokenExpiredOrExpiresSoon) {
          return [self refreshAuthTokenForInstallation:registeredInstallation];
        } else {
          return registeredInstallation;
        }
      })
      .catch(^void(NSError *error){
          // TODO: Handle the errors.
      });
}

- (FBLPromise<FIRInstallationsItem *> *)refreshAuthTokenForInstallation:
    (FIRInstallationsItem *)installation {
  return [FBLPromise attempts:1
      delay:1
      condition:^BOOL(NSInteger remainingAttempts, NSError *_Nonnull error) {
        return [FIRInstallationsErrorUtil isAPIError:error withHTTPCode:500];
      }
      retry:^id _Nullable {
        return [self.APIService refreshAuthTokenForInstallation:installation];
      }];
}

#pragma mark - Delete FID

- (FBLPromise<NSNull *> *)deleteInstallation {
  return [self.deleteInstallationPromiseCache getExistingPendingOrCreateNewPromise];
}

- (FBLPromise<NSNull *> *)createDeleteInstallationPromise {
  FIRLogDebug(kFIRLoggerInstallations,
              kFIRInstallationsMessageCodeNewDeleteInstallationOperationCreated, @"%s, appName: %@",
              __PRETTY_FUNCTION__, self.appName);

  // Check for ongoing requests first, if there is no a request, then check local storage for
  // existing installation.
  FBLPromise<FIRInstallationsItem *> *currentInstallationPromise =
      [self mostRecentInstallationOperation] ?: [self getStoredInstallation];

  return currentInstallationPromise
      .then(^id(FIRInstallationsItem *installation) {
        return [self sendDeleteInstallationRequestIfNeeded:installation];
      })
      .then(^id(FIRInstallationsItem *installation) {
        // Remove the installation from the local storage.
        return [self.installationsStore removeInstallationForAppID:installation.appID
                                                           appName:installation.firebaseAppName];
      })
      .then(^FBLPromise<NSNull *> *(NSNull *result) {
        return [self deleteExistingIIDIfNeeded];
      })
      .then(^NSNull *(NSNull *result) {
        [self postFIDDidChangeNotification];
        return result;
      });
}

- (FBLPromise<FIRInstallationsItem *> *)sendDeleteInstallationRequestIfNeeded:
    (FIRInstallationsItem *)installation {
  switch (installation.registrationStatus) {
    case FIRInstallationStatusUnknown:
    case FIRInstallationStatusUnregistered:
      // The installation is not registered, so it is safe to be deleted as is, so return early.
      return [FBLPromise resolvedWith:installation];
      break;

    case FIRInstallationStatusRegistered:
      // Proceed to de-register the installation on the server.
      break;
  }

  return [self.APIService deleteInstallation:installation].recover(^id(NSError *APIError) {
    if ([FIRInstallationsErrorUtil isAPIError:APIError withHTTPCode:404]) {
      // The installation was not found on the server.
      // Return success.
      return installation;
    } else {
      // Re-throw the error otherwise.
      return APIError;
    }
  });
}

- (FBLPromise<NSNull *> *)deleteExistingIIDIfNeeded {
  if ([self isDefaultApp]) {
    return [self.IIDStore deleteExistingIID];
  } else {
    return [FBLPromise resolvedWith:[NSNull null]];
  }
}

- (nullable FBLPromise<FIRInstallationsItem *> *)mostRecentInstallationOperation {
  return [self.authTokenForcingRefreshPromiseCache getExistingPendingPromise]
             ?: [self.authTokenPromiseCache getExistingPendingPromise]
                    ?: [self.getInstallationPromiseCache getExistingPendingPromise];
}

#pragma mark - Notifications

- (void)postFIDDidChangeNotification {
  [[NSNotificationCenter defaultCenter]
      postNotificationName:FIRInstallationIDDidChangeNotification
                    object:nil
                  userInfo:@{kFIRInstallationIDDidChangeNotificationAppNameKey : self.appName}];
}

#pragma mark - Default App

- (BOOL)isDefaultApp {
  return [self.appName isEqualToString:kFIRDefaultAppName];
}

@end
