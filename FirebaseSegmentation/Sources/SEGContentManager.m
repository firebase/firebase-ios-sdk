#import "SEGContentManager.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseInstanceID/FIRInstanceID.h>
#import "FIRSegmentation.h"
#import "SEGDatabaseManager.h"
#import "SEGNetworkManager.h"
#import "SEGSegmentationConstants.h"

@interface SEGContentManager () {
  NSMutableDictionary<NSString *, id> *_associationData;
  NSString *_instanceIdentifier;
  NSString *_instanceIdentifierToken;
  SEGDatabaseManager *_databaseManager;
  SEGNetworkManager *_networkManager;
}
@end

@implementation SEGContentManager

+ (instancetype)sharedInstanceWithFIROptions:(FIROptions *)options {
  static dispatch_once_t onceToken;
  static SEGContentManager *sharedInstance;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[SEGContentManager alloc] initWithFIROptions:options];
  });
  return sharedInstance;
}

- (instancetype)initWithFIROptions:(FIROptions *)options {
  self = [super init];
  if (self) {
    // Initialize the database manager.
    _databaseManager = [SEGDatabaseManager sharedInstance];

    // Initialize the network manager.
    _networkManager = [[SEGNetworkManager alloc] initWithFIROptions:options];

    NSAssert(_databaseManager != nil, @"Segmentation database could not be initialized");

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
    completionHandler(NO, @{@"ErrorDescription" : @"InstanceID SDK not available"});
  }
  __weak SEGContentManager *weakSelf = self;
  [[FIRInstanceID instanceID] instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result,
                                                      NSError *_Nullable error) {
    SEGContentManager *strongSelf = weakSelf;
    if (!strongSelf) {
      completionHandler(NO, @{@"ErrorDescription" : @"Internal Error getting instance ID."});
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
