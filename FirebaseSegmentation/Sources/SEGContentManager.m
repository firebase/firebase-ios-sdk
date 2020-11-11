// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebaseSegmentation/Sources/SEGContentManager.h"

#import "FirebaseCore/Sources/Private/FIRAppInternal.h"
#import "FirebaseInstallations/Source/Library/Public/FirebaseInstallations/FirebaseInstallations.h"
#import "FirebaseSegmentation/Sources/Public/FIRSegmentation.h"
#import "FirebaseSegmentation/Sources/SEGDatabaseManager.h"
#import "FirebaseSegmentation/Sources/SEGNetworkManager.h"

@implementation SEGContentManager {
  NSMutableDictionary<NSString *, id> *_associationData;
  NSString *_installationIdentifier;
  NSString *_installationIdentifierToken;
  SEGDatabaseManager *_databaseManager;
  SEGNetworkManager *_networkManager;
}

+ (instancetype)sharedInstanceWithOptions:(FIROptions *)options {
  static dispatch_once_t onceToken;
  static SEGContentManager *sharedInstance;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[SEGContentManager alloc]
        initWithDatabaseManager:[SEGDatabaseManager sharedInstance]
                 networkManager:[[SEGNetworkManager alloc] initWithOptions:options]];
  });
  return sharedInstance;
}

- (instancetype)initWithDatabaseManager:databaseManager networkManager:networkManager {
  self = [super init];
  if (self) {
    // Initialize the database manager.
    _databaseManager = databaseManager;

    // Initialize the network manager.
    _networkManager = networkManager;

    // Load all data from the database.
    [_databaseManager createOrOpenDatabaseWithCompletion:^(BOOL success, NSDictionary *result) {
      self->_associationData = [result mutableCopy];
    }];
    // TODO(dmandar) subscribe to FIS notifications once integrated.
  }
  return self;
}

- (FIRInstallations *)installationForApp:(NSString *)firebaseApp {
  return [FIRInstallations installationsWithApp:[FIRApp appNamed:firebaseApp]];
}

- (void)associateCustomInstallationIdentiferNamed:(NSString *)customInstallationID
                                      firebaseApp:(NSString *)firebaseApp
                                       completion:(SEGRequestCompletion)completionHandler {
  // Get the latest installation identifier
  FIRInstallations *installation = [self installationForApp:firebaseApp];
  if (installation == nil) {
    completionHandler(NO, @{kSEGErrorDescription : @"Firebase Installations SDK not available"});
  }
  __weak SEGContentManager *weakSelf = self;
  [installation installationIDWithCompletion:^(NSString *_Nullable identifier,
                                               NSError *_Nullable error) {
    SEGContentManager *strongSelf = weakSelf;
    if (!strongSelf) {
      completionHandler(NO, @{kSEGErrorDescription : @"Internal Error getting installation ID."});
      return;
    }

    [strongSelf associateInstallationWithLatestIdentifier:identifier
                                             installation:installation
                                     customizedIdentifier:customInstallationID
                                              firebaseApp:firebaseApp
                                                    error:error
                                               completion:completionHandler];
  }];
}

- (void)associateInstallationWithLatestIdentifier:(NSString *_Nullable)identifier
                                     installation:(FIRInstallations *)installation
                             customizedIdentifier:(NSString *)customInstallationID
                                      firebaseApp:(NSString *)firebaseApp
                                            error:(NSError *_Nullable)error
                                       completion:(SEGRequestCompletion)completionHandler {
  if (!identifier || error) {
    NSString *errorMessage = @"Error getting installation ID.";
    if (error) {
      errorMessage = [errorMessage stringByAppendingString:error.description];
    }
    NSDictionary *errorDictionary = @{kSEGErrorDescription : errorMessage};
    completionHandler(NO, errorDictionary);
    return;
  }

  _installationIdentifier = identifier;

  [installation authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                          NSError *_Nullable error) {
    [self associateInstallationWithToken:tokenResult
                    customizedIdentifier:customInstallationID
                             firebaseApp:firebaseApp
                                   error:error
                              completion:completionHandler];
  }];
}

- (void)associateInstallationWithToken:(FIRInstallationsAuthTokenResult *_Nullable)tokenResult
                  customizedIdentifier:(NSString *)customInstallationID
                           firebaseApp:(NSString *)firebaseApp
                                 error:(NSError *_Nullable)error
                            completion:(SEGRequestCompletion)completionHandler {
  if (!tokenResult || error) {
    NSString *errorMessage = @"Error getting AuthToken.";
    if (error) {
      errorMessage = [errorMessage stringByAppendingString:error.description];
    }
    NSDictionary *errorDictionary = @{kSEGErrorDescription : errorMessage};
    completionHandler(NO, errorDictionary);
    return;
  }
  _installationIdentifierToken = tokenResult.authToken;

  NSMutableDictionary<NSString *, NSString *> *appAssociationData =
      [[NSMutableDictionary alloc] init];
  appAssociationData[kSEGCustomInstallationIdentifierKey] = customInstallationID;
  appAssociationData[kSEGFirebaseInstallationIdentifierKey] = _installationIdentifier;
  appAssociationData[kSEGAssociationStatusKey] = kSEGAssociationStatusPending;
  _associationData[firebaseApp] = appAssociationData;

  // Update the database async.
  // TODO(mandard) The database write and corresponding completion handler needs to be wired up
  // once we support listening to FID changes.
  [_databaseManager insertMainTableApplicationNamed:firebaseApp
                           customInstanceIdentifier:customInstallationID
                         firebaseInstanceIdentifier:_installationIdentifier
                                  associationStatus:kSEGAssociationStatusPending
                                  completionHandler:nil];

  // Send the change up to the backend. Also add the token.
  [_networkManager
      makeAssociationRequestToBackendWithData:appAssociationData
                                        token:_installationIdentifierToken
                                   completion:^(BOOL status, NSDictionary<NSString *, id> *result) {
                                     // TODO: log, update database.
                                     completionHandler(status, result);
                                   }];
}

@end
