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

#import "SEGContentManager.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseInstanceID/FIRInstanceID.h>
#import "FIRSegmentation.h"
#import "SEGDatabaseManager.h"
#import "SEGNetworkManager.h"
#import "SEGSegmentationConstants.h"

NSString *const kErrorDescription = @"ErrorDescription";

@interface SEGContentManager () {
  NSMutableDictionary<NSString *, id> *_associationData;
  NSString *_instanceIdentifier;
  NSString *_instanceIdentifierToken;
  SEGDatabaseManager *_databaseManager;
  SEGNetworkManager *_networkManager;
}
@end

@implementation SEGContentManager

+ (instancetype)sharedInstanceWithOptions:(FIROptions *)options {
  static dispatch_once_t onceToken;
  static SEGContentManager *sharedInstance;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[SEGContentManager alloc]
        initWithDatabaseManager:[SEGDatabaseManager sharedInstance]
                 networkManager:[[SEGNetworkManager alloc] initWithFIROptions:options]];
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

// TODO(dmandar) IID only supports default instance. Modify for FIS.
- (FIRInstanceID *)instanceIDForApp:(NSString *)firebaseApp {
  return [FIRInstanceID instanceID];
}

- (void)associateCustomInstallationIdentiferNamed:(NSString *)customInstallationID
                                      firebaseApp:(NSString *)firebaseApp
                                       completion:(SEGRequestCompletion)completionHandler {
  // Get the latest instance identifier
  if (![self instanceIDForApp:firebaseApp]) {
    completionHandler(NO, @{kErrorDescription : @"InstanceID SDK not available"});
  }
  __weak SEGContentManager *weakSelf = self;
  [[FIRInstanceID instanceID] instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result,
                                                      NSError *_Nullable error) {
    SEGContentManager *strongSelf = weakSelf;
    if (!strongSelf) {
      completionHandler(NO, @{kErrorDescription : @"Internal Error getting instance ID."});
      return;
    }

    if (!result || error) {
      NSString *errorMessage = @"Error getting instance ID.";
      if (error) {
        errorMessage = [errorMessage stringByAppendingString:error.description];
      }
      NSDictionary *errorDictionary = @{kErrorDescription : errorMessage};
      completionHandler(NO, errorDictionary);
      return;
    }

    strongSelf->_instanceIdentifier = result.instanceID;
    strongSelf->_instanceIdentifierToken = result.token;

    NSMutableDictionary<NSString *, NSString *> *appAssociationData =
        [[NSMutableDictionary alloc] init];
    [appAssociationData setObject:customInstallationID forKey:kSEGCustomInstallationIdentifierKey];
    [appAssociationData setObject:self->_instanceIdentifier
                           forKey:kSEGFirebaseInstallationIdentifierKey];
    [appAssociationData setObject:kSEGAssociationStatusPending forKey:kSEGAssociationStatusKey];
    [strongSelf->_associationData setObject:appAssociationData forKey:firebaseApp];

    // Update the database async.
    // TODO(mandard) The database write and corresponding completion handler needs to be wired up
    // once we support listening to FID changes.
    [strongSelf->_databaseManager insertMainTableApplicationNamed:firebaseApp
                                         customInstanceIdentifier:customInstallationID
                                       firebaseInstanceIdentifier:strongSelf->_instanceIdentifier
                                                associationStatus:kSEGAssociationStatusPending
                                                completionHandler:nil];

    // Send the change up to the backend. Also add the token.

    [strongSelf->_networkManager
        makeAssociationRequestToBackendWithData:appAssociationData
                                          token:strongSelf->_instanceIdentifierToken
                                     completion:^(BOOL status,
                                                  NSDictionary<NSString *, id> *result) {
                                       // TODO...log, update database.

                                       completionHandler(status, result);
                                     }];
  }];
}

@end
