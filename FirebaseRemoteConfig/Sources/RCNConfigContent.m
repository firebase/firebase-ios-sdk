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

#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"

#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDefines.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

@implementation RCNConfigContent {
  /// Active config data that is currently used.
  NSMutableDictionary *_activeConfig;
  /// Pending config (aka Fetched config) data that is latest data from server that might or might
  /// not be applied.
  NSMutableDictionary *_fetchedConfig;
  /// Default config provided by user.
  NSMutableDictionary *_defaultConfig;
  /// Active Personalization metadata that is currently used.
  NSDictionary *_activePersonalization;
  /// Pending Personalization metadata that is latest data from server that might or might not be
  /// applied.
  NSDictionary *_fetchedPersonalization;
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
    _activePersonalization = [[NSDictionary alloc] init];
    _fetchedPersonalization = [[NSDictionary alloc] init];
    _bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (!_bundleIdentifier) {
      FIRLogNotice(kFIRLoggerRemoteConfig, @"I-RCN000038",
                   @"Main bundle identifier is missing. Remote Config might not work properly.");
      _bundleIdentifier = @"";
    }
    _DBManager = DBManager;
    // Waits for both config and Personalization data to load.
    _configLoadFromDBSemaphore = dispatch_semaphore_create(1);
    [self loadConfigFromMainTable];
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

#pragma mark - database

/// This method is only meant to be called at init time. The underlying logic will need to be
/// revaluated if the assumption changes at a later time.
- (void)loadConfigFromMainTable {
  if (!_DBManager) {
    return;
  }

  NSAssert(!_isDatabaseLoadAlreadyInitiated, @"Database load has already been initiated");
  _isDatabaseLoadAlreadyInitiated = true;

  [_DBManager
      loadMainWithBundleIdentifier:_bundleIdentifier
                 completionHandler:^(BOOL success, NSDictionary *fetchedConfig,
                                     NSDictionary *activeConfig, NSDictionary *defaultConfig) {
                   self->_fetchedConfig = [fetchedConfig mutableCopy];
                   self->_activeConfig = [activeConfig mutableCopy];
                   self->_defaultConfig = [defaultConfig mutableCopy];
                   dispatch_semaphore_signal(self->_configLoadFromDBSemaphore);
                 }];

  [_DBManager loadPersonalizationWithCompletionHandler:^(
                  BOOL success, NSDictionary *fetchedPersonalization,
                  NSDictionary *activePersonalization, NSDictionary *defaultConfig) {
    self->_fetchedPersonalization = [fetchedPersonalization copy];
    self->_activePersonalization = [activePersonalization copy];
    dispatch_semaphore_signal(self->_configLoadFromDBSemaphore);
  }];
}

/// Update the current config result to main table.
/// @param values Values in a row to write to the table.
/// @param source The source the config data is coming from. It determines which table to write to.
- (void)updateMainTableWithValues:(NSArray *)values fromSource:(RCNDBSource)source {
  [_DBManager insertMainTableWithValues:values fromSource:source completionHandler:nil];
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
      FIRRemoteConfigValue *value = config[key];
      toDict[FIRNamespace][key] = [[FIRRemoteConfigValue alloc] initWithData:value.dataValue
                                                                      source:source];
      NSArray *values = @[ _bundleIdentifier, FIRNamespace, key, value.dataValue ];
      [self updateMainTableWithValues:values fromSource:DBSource];
    }
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
    [self handleUpdateStateForConfigNamespace:currentNamespace
                                  withEntries:response[RCNFetchResponseKeyEntries]];
    [self handleUpdatePersonalization:response[RCNFetchResponseKeyPersonalizationMetadata]];
    return;
  }
}

- (void)activatePersonalization {
  _activePersonalization = _fetchedPersonalization;
  [_DBManager insertOrUpdatePersonalizationConfig:_activePersonalization
                                       fromSource:RCNDBSourceActive];
}

#pragma mark State handling
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
    // TODO: Add generics for all collection types.
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

- (void)handleUpdatePersonalization:(NSDictionary *)metadata {
  if (!metadata) {
    return;
  }
  _fetchedPersonalization = metadata;
  [_DBManager insertOrUpdatePersonalizationConfig:metadata fromSource:RCNDBSourceFetched];
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

- (NSDictionary *)getConfigAndMetadataForNamespace:(NSString *)FIRNamespace {
  /// If this is the first time reading the active metadata, we might still be reading it from the
  /// database.
  [self checkAndWaitForInitialDatabaseLoad];
  return @{
    RCNFetchResponseKeyEntries : _activeConfig[FIRNamespace],
    RCNFetchResponseKeyPersonalizationMetadata : _activePersonalization
  };
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
