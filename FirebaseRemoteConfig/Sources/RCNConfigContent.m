#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigContent.h"

#import "googlemac/iPhone/Config/RemoteConfig/Source/FIRRemoteConfig.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigConstants.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigDBManager.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigDefines.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigValue_Internal.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNUserDefaultsManager.h"

#import "third_party/firebase/ios/Releases/FirebaseCore/Library/FIRApp.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIRLogger.h"

@implementation RCNConfigContent {
  /// Active config data that is currently used.
  NSMutableDictionary *_activeConfig;
  /// Pending config (aka Fetched config) data that is latest data from server that might or might
  /// not be applied.
  NSMutableDictionary *_fetchedConfig;
  /// Default config provided by user.
  NSMutableDictionary *_defaultConfig;
  /// DBManager
  RCNConfigDBManager *_DBManager;
  /// Current bundle identifier;
  NSString *_bundleIdentifier;
  /// Dispatch semaphore to block all config reads until we have read from the database. This only
  /// potentially blocks on the first read. Should be a no-wait for all subsequent reads once we
  /// have data read into memory from the database.
  dispatch_semaphore_t _configLoadFromDBSemaphore;
  /// Boolean indicating if initial DB load of fetched,active and default config has succeeded.
  BOOL _isConfigLoadFromDBCompleted;
  /// Boolean indicating that the load from database has initiated at least once.
  BOOL _isDatabaseLoadAlreadyInitiated;
  /// Manages user defaults per app:namespace.
  RCNUserDefaultsManager *_userDefaultsManager;
  /// Features and rollouts namespace. This is {firebaseAppid}_{firebaseNamespace}_features
  NSString *_featuresNamespace;
  // Feature information stored from a fetch response. Pending activation.
  NSMutableArray<NSString *> *_fetchedFeaturesInformation;
  // Activated and available feature information.
  NSMutableArray<NSString *> *_activatedFeaturesInformation;
  // Feature rollout information stored from a fetch response. Pending activation.
  NSMutableArray<id> *_fetchedRolloutInformation;
  // Feature rollout information stored from a fetch response. Pending activation.
  NSMutableArray<id> *_activatedRolloutInformation;
}

/// Default timeout when waiting to read data from database.
static const NSTimeInterval kDatabaseLoadTimeoutSecs = 30.0;

/// Singleton instance of RCNConfigContent.
+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static RCNConfigContent *sharedInstance;
  dispatch_once(&onceToken, ^{
    sharedInstance =
        [[RCNConfigContent alloc] initWithDBManager:[RCNConfigDBManager sharedInstance]];
  });
  return sharedInstance;
}

- (instancetype)init {
  NSAssert(NO, @"Invalid initializer.");
  return nil;
}

/// Designated initializer
- (instancetype)initWithDBManager:(RCNConfigDBManager *)DBManager {
  self = [super init];
  if (self) {
    _activeConfig = [[NSMutableDictionary alloc] init];
    _fetchedConfig = [[NSMutableDictionary alloc] init];
    _defaultConfig = [[NSMutableDictionary alloc] init];
    _fetchedFeaturesInformation = [[NSMutableArray alloc] init];
    _fetchedRolloutInformation = [[NSMutableArray alloc] init];
    _activatedFeaturesInformation = [[NSMutableArray alloc] init];
    _activatedRolloutInformation = [[NSMutableArray alloc] init];
    _bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (!_bundleIdentifier) {
      FIRLogNotice(kFIRLoggerRemoteConfig, @"I-RCN000038",
                   @"Main bundle identifier is missing. Remote Config might not work properly.");
      _bundleIdentifier = @"";
    }
    _DBManager = DBManager;
    _configLoadFromDBSemaphore = dispatch_semaphore_create(0);
    [self loadConfigFromTables];
  }
  return self;
}

// Blocking call that returns true/false once database load completes / times out.
// @return Initialization status.
- (BOOL)initializationSuccessful {
  RCN_MUST_NOT_BE_MAIN_THREAD();
  BOOL isDatabaseLoadSuccessful = [self checkAndWaitForInitialDatabaseLoad];
  return isDatabaseLoadSuccessful;
}

#pragma mark - update
/// This function is for copying dictionary when user set up a default config or when user clicks
/// activate. For now the DBSource can only be Active or Default.
- (void)copyFromDictionary:(NSDictionary *)fromDict
                  toSource:(RCNDBSource)DBSource
              forNamespace:(NSString *)FIRNamespace {
  // Make sure database load has completed.
  [self checkAndWaitForInitialDatabaseLoad];
  NSMutableDictionary *toDict;
  if (!fromDict) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000007",
                @"The source dictionary to copy from does not exist.");
    return;
  }
  FIRRemoteConfigSource source = FIRRemoteConfigSourceRemote;
  switch (DBSource) {
    case RCNDBSourceDefault:
      toDict = _defaultConfig;
      source = FIRRemoteConfigSourceDefault;
      break;
    case RCNDBSourceFetched:
      FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000008",
                    @"This shouldn't happen. Destination dictionary should never be pending type.");
      return;
    case RCNDBSourceActive:
      toDict = _activeConfig;
      source = FIRRemoteConfigSourceRemote;
      [toDict removeObjectForKey:FIRNamespace];
      break;
    default:
      toDict = _activeConfig;
      source = FIRRemoteConfigSourceRemote;
      [toDict removeObjectForKey:FIRNamespace];
      break;
  }

    // Completely wipe out DB first.
  [_DBManager deleteRecordFromMainTableWithNamespace:FIRNamespace
                                    bundleIdentifier:_bundleIdentifier
                                          fromSource:DBSource];

  // Handle features and feature rollouts if copying to active source.
  if (DBSource == RCNDBSourceActive) {
    [self activateFetchedFeaturesAndRolloutsInformationForNamespace:FIRNamespace];
  }

  toDict[FIRNamespace] = [[NSMutableDictionary alloc] init];
  NSDictionary *config = fromDict[FIRNamespace];
  for (NSString *key in config) {
    if (DBSource == FIRRemoteConfigSourceDefault) {
      NSObject *value = config[key];
      NSData *valueData;
      if ([value isKindOfClass:[NSData class]]) {
        valueData = (NSData *)value;
      } else if ([value isKindOfClass:[NSString class]]) {
        valueData = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
      } else if ([value isKindOfClass:[NSNumber class]]) {
        NSString *strValue = [(NSNumber *)value stringValue];
        valueData = [(NSString *)strValue dataUsingEncoding:NSUTF8StringEncoding];
      } else if ([value isKindOfClass:[NSDate class]]) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *strValue = [dateFormatter stringFromDate:(NSDate *)value];
        valueData = [(NSString *)strValue dataUsingEncoding:NSUTF8StringEncoding];
      } else {
        continue;
      }
      toDict[FIRNamespace][key] = [[FIRRemoteConfigValue alloc] initWithData:valueData
                                                                      source:source];
      NSArray *values = @[ _bundleIdentifier, FIRNamespace, key, valueData ];
      [self updateMainTableWithValues:values fromSource:DBSource];
    } else {
      // Copying to Active.
      FIRRemoteConfigValue *value = config[key];
      toDict[FIRNamespace][key] = [[FIRRemoteConfigValue alloc] initWithData:value.dataValue
                                                                      source:source];
      NSArray *values = @[ _bundleIdentifier, FIRNamespace, key, value.dataValue ];
      [self updateMainTableWithValues:values fromSource:DBSource];
    }
  }
}

- (void)activateFetchedFeaturesAndRolloutsInformationForNamespace:
    (NSString *)fullyQualifiedNamespace {
  // Delete any previous entries.
  [_DBManager deleteRecordFromFeaturesTableWithNamespace:fullyQualifiedNamespace
                                        bundleIdentifier:_bundleIdentifier
                                              fromSource:RCNDBSourceActive];

  // Copy features and rollouts info to the active table.
  NSError *error;
  NSData *fetchedFeaturesData = [NSJSONSerialization dataWithJSONObject:_fetchedFeaturesInformation
                                                                options:0
                                                                  error:&error];
  if (fetchedFeaturesData && !error) {
    NSArray *values =
        @[ _bundleIdentifier, fullyQualifiedNamespace, kRCNFeaturesKeyName, fetchedFeaturesData ];
    _activatedFeaturesInformation = _fetchedFeaturesInformation;
    [_DBManager insertFeaturesTableWithValues:values
                                   fromSource:RCNDBSourceActive
                            completionHandler:nil];
  } else {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000073", @"Could not serialize features data.");
  }

  // Rollouts.
  NSData *rolloutsData = [NSJSONSerialization dataWithJSONObject:_fetchedRolloutInformation
                                                         options:0
                                                           error:&error];
  if (rolloutsData && !error) {
    _activatedRolloutInformation = _fetchedRolloutInformation;
    NSArray *values =
        @[ _bundleIdentifier, fullyQualifiedNamespace, kRCNRolloutsKeyName, rolloutsData ];
    [_DBManager insertFeaturesTableWithValues:values
                                   fromSource:RCNDBSourceActive
                            completionHandler:nil];
  } else {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000074", @"Could not serialize rollouts data.");
  }
}

- (void)updateConfigContentWithResponse:(NSDictionary *)response
                           forNamespace:(NSString *)currentNamespace {
  // Make sure database load has completed.
  [self checkAndWaitForInitialDatabaseLoad];
  NSString *state = response[RCNFetchResponseKeyState];

  if (!state) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000049", @"State field in fetch response is nil.");
    return;
  }
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000059",
              @"Updating config content from Response for namespace:%@ with state: %@",
              currentNamespace, response[RCNFetchResponseKeyState]);

  if ([state isEqualToString:RCNFetchResponseKeyStateNoChange]) {
    [self handleNoChangeStateForConfigNamespace:currentNamespace];
    return;
  }

  /// Handle empty config state
  if ([state isEqualToString:RCNFetchResponseKeyStateEmptyConfig]) {
    [self handleEmptyConfigStateForConfigNamespace:currentNamespace];
    return;
  }

  /// Handle no template state.
  if ([state isEqualToString:RCNFetchResponseKeyStateNoTemplate]) {
    [self handleNoTemplateStateForConfigNamespace:currentNamespace];
    return;
  }

  /// Handle update state
  if ([state isEqualToString:RCNFetchResponseKeyStateUpdate]) {
    [self handleUpdateForFeatureKeys:response[RCNFetchResponseKeyEnabledFeatures]
                         andRollouts:response[RCNFetchResponseKeyActiveRollouts]
                        forNamespace:currentNamespace];
    [self handleUpdateStateForConfigNamespace:currentNamespace
                                  withEntries:response[RCNFetchResponseKeyEntries]];
    return;
  }
}

#pragma mark State handling
- (void)handleUpdateForFeatureKeys:(NSArray *)featureKeys
                       andRollouts:(NSArray *)rollouts
                      forNamespace:(NSString *)currentNamespace {
  // Clear before updating
  [_DBManager deleteAllRecordsFromFeaturesTableWithSource:RCNDBSourceFetched];

  // Store the fetched feature information.
  [_fetchedFeaturesInformation removeAllObjects];
  _fetchedFeaturesInformation = [featureKeys mutableCopy];
  _fetchedFeaturesInformation =
      _fetchedFeaturesInformation ? _fetchedFeaturesInformation : [[NSMutableArray alloc] init];
  NSError *error;
  NSData *fetchedFeaturesData = [NSJSONSerialization dataWithJSONObject:_fetchedFeaturesInformation
                                                                options:0
                                                                  error:&error];
  if (!fetchedFeaturesData || error) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000075",
                @"Could not get fetched feature serialized data.%@", currentNamespace);
  }
  NSArray *values =
      @[ _bundleIdentifier, currentNamespace, kRCNFeaturesKeyName, fetchedFeaturesData ];
  [_DBManager insertFeaturesTableWithValues:values
                                 fromSource:RCNDBSourceFetched
                          completionHandler:nil];

  // Store the fetched rollouts information.
  [_fetchedRolloutInformation removeAllObjects];
  _fetchedRolloutInformation = [rollouts mutableCopy];
  _fetchedRolloutInformation =
      _fetchedRolloutInformation ? _fetchedRolloutInformation : [[NSMutableArray alloc] init];
  NSData *fetchedRolloutData = [NSJSONSerialization dataWithJSONObject:_fetchedRolloutInformation
                                                               options:0
                                                                 error:&error];
  if (!fetchedRolloutData || error) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000076",
                @"Could not get fetched rollout serialized data.%@", currentNamespace);
  }
  values = @[ _bundleIdentifier, currentNamespace, kRCNRolloutsKeyName, fetchedRolloutData ];
  [_DBManager insertFeaturesTableWithValues:values
                                 fromSource:RCNDBSourceFetched
                          completionHandler:nil];
}

- (void)handleNoChangeStateForConfigNamespace:(NSString *)currentNamespace {
  if (!_fetchedConfig[currentNamespace]) {
    _fetchedConfig[currentNamespace] = [[NSMutableDictionary alloc] init];
  }
}

- (void)handleEmptyConfigStateForConfigNamespace:(NSString *)currentNamespace {
  if (_fetchedConfig[currentNamespace]) {
    [_fetchedConfig[currentNamespace] removeAllObjects];
  } else {
    // If namespace has empty status and it doesn't exist in _fetchedConfig, we will
    // still add an entry for that namespace. Even if it will not be persisted in database.
    // TODO(mandard): Add generics for all collection types.
    _fetchedConfig[currentNamespace] = [[NSMutableDictionary alloc] init];
  }
  [_DBManager deleteRecordFromMainTableWithNamespace:currentNamespace
                                    bundleIdentifier:_bundleIdentifier
                                          fromSource:RCNDBSourceFetched];
}

- (void)handleNoTemplateStateForConfigNamespace:(NSString *)currentNamespace {
  // Remove the namespace.
  [_fetchedConfig removeObjectForKey:currentNamespace];
  [_DBManager deleteRecordFromMainTableWithNamespace:currentNamespace
                                    bundleIdentifier:_bundleIdentifier
                                          fromSource:RCNDBSourceFetched];
}
- (void)handleUpdateStateForConfigNamespace:(NSString *)currentNamespace
                                withEntries:(NSDictionary *)entries {
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000058", @"Update config in DB for namespace:%@",
              currentNamespace);
  // Clear before updating
  [_DBManager deleteRecordFromMainTableWithNamespace:currentNamespace
                                    bundleIdentifier:_bundleIdentifier
                                          fromSource:RCNDBSourceFetched];
  if ([_fetchedConfig objectForKey:currentNamespace]) {
    [_fetchedConfig[currentNamespace] removeAllObjects];
  } else {
    _fetchedConfig[currentNamespace] = [[NSMutableDictionary alloc] init];
  }

  // Store the fetched config values.
  for (NSString *key in entries) {
    NSData *valueData = [entries[key] dataUsingEncoding:NSUTF8StringEncoding];
    if (!valueData) {
      continue;
    }
    _fetchedConfig[currentNamespace][key] =
        [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
    NSArray *values = @[ _bundleIdentifier, currentNamespace, key, valueData ];
    [self updateMainTableWithValues:values fromSource:RCNDBSourceFetched];
  }
}

#pragma mark - database

/// This method is only meant to be called at init time. The underlying logic will need to be
/// revaluated if the assumption changes at a later time.
- (void)loadConfigFromTables {
  if (!_DBManager) {
    return;
  }

  NSAssert(!_isDatabaseLoadAlreadyInitiated, @"Database load has already been initiated");
  _isDatabaseLoadAlreadyInitiated = true;

  [_DBManager
      loadWithBundleIdentifier:_bundleIdentifier
             completionHandler:^(BOOL success, NSDictionary *fetchedConfig,
                                 NSDictionary *activeConfig, NSDictionary *defaultConfig,
                                 NSDictionary<NSString *, id> *fetchedFeaturesAndRollouts,
                                 NSDictionary<NSString *, id> *activatedFeaturesAndRollouts) {
               _fetchedConfig = [fetchedConfig mutableCopy];
               _activeConfig = [activeConfig mutableCopy];
               _defaultConfig = [defaultConfig mutableCopy];
               // Fetched feature.
               NSData *fetchedFeatureData =
                   [fetchedFeaturesAndRollouts objectForKey:kRCNFeaturesKeyName];
               if (fetchedFeatureData) {
                 NSError *error;
                 _fetchedFeaturesInformation =
                     [[NSJSONSerialization JSONObjectWithData:fetchedFeatureData
                                                      options:0
                                                        error:&error] mutableCopy];
                 if (error) {
                   FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000077",
                               @"Could not deserialize fetched feature information.");
                 }
               }
               _fetchedFeaturesInformation = _fetchedFeaturesInformation
                                                 ? _fetchedFeaturesInformation
                                                 : [[NSMutableArray alloc] init];

               // Fetched rollout.
               NSData *fetchedRolloutData =
                   [fetchedFeaturesAndRollouts objectForKey:kRCNRolloutsKeyName];
               if (fetchedRolloutData) {
                 NSError *error;
                 _fetchedRolloutInformation =
                     [[NSJSONSerialization JSONObjectWithData:fetchedRolloutData
                                                      options:0
                                                        error:&error] mutableCopy];
                 if (error) {
                   FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000078",
                               @"Could not deserialize fetched rollouts information.");
                 }
               }
               _fetchedRolloutInformation = _fetchedRolloutInformation
                                                ? _fetchedRolloutInformation
                                                : [[NSMutableArray alloc] init];

               // Activated feature.
               NSData *activatedFeatureData =
                   [activatedFeaturesAndRollouts objectForKey:kRCNFeaturesKeyName];
               if (activatedFeatureData) {
                 NSError *error;
                 _activatedFeaturesInformation =
                     [[NSJSONSerialization JSONObjectWithData:activatedFeatureData
                                                      options:0
                                                        error:&error] mutableCopy];
                 if (error) {
                   FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000079",
                               @"Could not deserialize activated feature information.");
                 }
               }
               _activatedFeaturesInformation = _activatedFeaturesInformation
                                                   ? _activatedFeaturesInformation
                                                   : [[NSMutableArray alloc] init];

               // Activated rollout.
               NSData *activatedRolloutData =
                   [activatedFeaturesAndRollouts objectForKey:kRCNRolloutsKeyName];
               if (activatedRolloutData) {
                 NSError *error;
                 _activatedRolloutInformation =
                     [[NSJSONSerialization JSONObjectWithData:activatedRolloutData
                                                      options:0
                                                        error:&error] mutableCopy];
                 if (error) {
                   FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000080",
                               @"Could not deserialize activated feature information.");
                 }
               }
               _activatedRolloutInformation = _activatedRolloutInformation
                                                  ? _activatedRolloutInformation
                                                  : [[NSMutableArray alloc] init];
               dispatch_semaphore_signal(_configLoadFromDBSemaphore);
             }];
}

/// Update the current config result to main table.
/// @param values Values in a row to write to the table.
/// @param source The source the config data is coming from. It determines which table to write to.
- (void)updateMainTableWithValues:(NSArray *)values fromSource:(RCNDBSource)source {
  [_DBManager insertMainTableWithValues:values fromSource:source completionHandler:nil];
}
#pragma mark - getter/setter
- (NSDictionary *)fetchedConfig {
  /// If this is the first time reading the fetchedConfig, we might still be reading it from the
  /// database.
  [self checkAndWaitForInitialDatabaseLoad];
  return _fetchedConfig;
}

- (NSDictionary *)activeConfig {
  /// If this is the first time reading the activeConfig, we might still be reading it from the
  /// database.
  [self checkAndWaitForInitialDatabaseLoad];
  return _activeConfig;
}

- (NSDictionary *)defaultConfig {
  /// If this is the first time reading the fetchedConfig, we might still be reading it from the
  /// database.
  [self checkAndWaitForInitialDatabaseLoad];
  return _defaultConfig;
}

- (NSArray<NSString *> *)enabledFeatureKeys {
  /// If this is the first time reading the features, we might still be reading it from the
  /// database.
  [self checkAndWaitForInitialDatabaseLoad];
  return _activatedFeaturesInformation;
}

- (NSArray<NSString *> *)activeRollouts {
  /// If this is the first time reading the activeRollouts, we might still be reading it from the
  /// database.
  [self checkAndWaitForInitialDatabaseLoad];
  return _activatedRolloutInformation;
}

/// We load the database async at init time. Block all further calls to active/fetched/default
/// configs until load is done.
/// @return Database load completion status.
- (BOOL)checkAndWaitForInitialDatabaseLoad {
  /// Wait on semaphore until done. This should be a no-op for subsequent calls.
  if (!_isConfigLoadFromDBCompleted) {
    long result = dispatch_semaphore_wait(
        _configLoadFromDBSemaphore,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDatabaseLoadTimeoutSecs * NSEC_PER_SEC)));
    if (result != 0) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000048",
                  @"Timed out waiting for fetched config to be loaded from DB");
      return false;
    }
    _isConfigLoadFromDBCompleted = true;
  }
  return true;
}

@end
