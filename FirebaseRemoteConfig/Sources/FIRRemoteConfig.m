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

#import <FirebaseRemoteConfig/FIRRemoteConfig.h>

#import <FirebaseABTesting/FIRExperimentController.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import "FirebaseRemoteConfig/Sources/FIRRemoteConfigComponent.h"
#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigExperiment.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"
#import "FirebaseRemoteConfig/Sources/RCNDevice.h"

/// Remote Config Error Domain.
/// TODO: Rename according to obj-c style for constants.
NSString *const FIRRemoteConfigErrorDomain = @"com.google.remoteconfig.ErrorDomain";
/// Remote Config Error Info End Time Seconds;
NSString *const FIRRemoteConfigThrottledEndTimeInSecondsKey = @"error_throttled_end_time_seconds";
/// Remote Config Developer Mode Key
static NSString *const kRemoteConfigDeveloperKey = @"_rcn_developer";
/// Minimum required time interval between fetch requests made to the backend.
static NSString *const kRemoteConfigMinimumFetchIntervalKey = @"_rcn_minimum_fetch_interval";
/// Timeout value for waiting on a fetch response.
static NSString *const kRemoteConfigFetchTimeoutKey = @"_rcn_fetch_timeout";

@interface FIRRemoteConfigSettings () {
  BOOL _developerModeEnabled;
}
@end

// Implementations depend upon multiple deprecated APIs
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation FIRRemoteConfigSettings
- (instancetype)initWithDeveloperModeEnabled:(BOOL)developerModeEnabled {
  self = [self init];
  if (self) {
    _developerModeEnabled = developerModeEnabled;
  }
  return self;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _developerModeEnabled = NO;
    _minimumFetchInterval = RCNDefaultMinimumFetchInterval;
    _fetchTimeout = RCNHTTPDefaultConnectionTimeout;
  }
  return self;
}

- (BOOL)isDeveloperModeEnabled {
  return _developerModeEnabled;
}

@end

@implementation FIRRemoteConfig {
  /// All the config content.
  RCNConfigContent *_configContent;
  RCNConfigDBManager *_DBManager;
  RCNConfigSettings *_settings;
  RCNConfigFetch *_configFetch;
  RCNConfigExperiment *_configExperiment;
  dispatch_queue_t _queue;
  NSString *_appName;
}

static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, FIRRemoteConfig *> *>
    *RCInstances;

+ (nonnull FIRRemoteConfig *)remoteConfigWithApp:(FIRApp *_Nonnull)firebaseApp {
  return [FIRRemoteConfig remoteConfigWithFIRNamespace:FIRNamespaceGoogleMobilePlatform
                                                   app:firebaseApp];
}

+ (nonnull FIRRemoteConfig *)remoteConfigWithFIRNamespace:(NSString *_Nonnull)firebaseNamespace {
  if (![FIRApp isDefaultAppConfigured]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000047",
                @"FIRApp not configured. Please make sure you have called [FIRApp configure]");
    // TODO: Maybe throw an exception here? That'd be a breaking change though, but at this point
    // RC can't work as expected.
  }

  return [FIRRemoteConfig remoteConfigWithFIRNamespace:firebaseNamespace app:[FIRApp defaultApp]];
}

+ (nonnull FIRRemoteConfig *)remoteConfigWithFIRNamespace:(NSString *_Nonnull)firebaseNamespace
                                                      app:(FIRApp *_Nonnull)firebaseApp {
  // Use the provider to generate and return instances of FIRRemoteConfig for this specific app and
  // namespace. This will ensure the app is configured before Remote Config can return an instance.
  id<FIRRemoteConfigProvider> provider =
      FIR_COMPONENT(FIRRemoteConfigProvider, firebaseApp.container);
  return [provider remoteConfigForNamespace:firebaseNamespace];
}

+ (FIRRemoteConfig *)remoteConfig {
  // If the default app is not configured at this point, warn the developer.
  if (![FIRApp isDefaultAppConfigured]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000047",
                @"FIRApp not configured. Please make sure you have called [FIRApp configure]");
    // TODO: Maybe throw an exception here? That'd be a breaking change though, but at this point
    // RC can't work as expected.
  }

  return [FIRRemoteConfig remoteConfigWithFIRNamespace:FIRNamespaceGoogleMobilePlatform
                                                   app:[FIRApp defaultApp]];
}

/// Singleton instance of serial queue for queuing all incoming RC calls.
+ (dispatch_queue_t)sharedRemoteConfigSerialQueue {
  static dispatch_once_t onceToken;
  static dispatch_queue_t sharedRemoteConfigQueue;
  dispatch_once(&onceToken, ^{
    sharedRemoteConfigQueue =
        dispatch_queue_create(RCNRemoteConfigQueueLabel, DISPATCH_QUEUE_SERIAL);
  });
  return sharedRemoteConfigQueue;
}

/// Designated initializer
- (instancetype)initWithAppName:(NSString *)appName
                     FIROptions:(FIROptions *)options
                      namespace:(NSString *)FIRNamespace
                      DBManager:(RCNConfigDBManager *)DBManager
                  configContent:(RCNConfigContent *)configContent
                      analytics:(nullable id<FIRAnalyticsInterop>)analytics {
  self = [super init];
  if (self) {
    _appName = appName;
    _DBManager = DBManager;
    // The fully qualified Firebase namespace is namespace:firappname.
    _FIRNamespace = [NSString stringWithFormat:@"%@:%@", FIRNamespace, appName];

    // Initialize RCConfigContent if not already.
    _configContent = configContent;
    _settings = [[RCNConfigSettings alloc] initWithDatabaseManager:_DBManager
                                                         namespace:_FIRNamespace
                                                   firebaseAppName:appName
                                                       googleAppID:options.googleAppID];

    FIRExperimentController *experimentController = [FIRExperimentController sharedInstance];
    _configExperiment = [[RCNConfigExperiment alloc] initWithDBManager:_DBManager
                                                  experimentController:experimentController];
    /// Serial queue for read and write lock.
    _queue = [FIRRemoteConfig sharedRemoteConfigSerialQueue];

    // Initialize with default config settings.
    [self setDefaultConfigSettings];
    _configFetch = [[RCNConfigFetch alloc] initWithContent:_configContent
                                                 DBManager:_DBManager
                                                  settings:_settings
                                                 analytics:analytics
                                                experiment:_configExperiment
                                                     queue:_queue
                                                 namespace:_FIRNamespace
                                                   options:options];

    [_settings loadConfigFromMetadataTable];
  }
  return self;
}

// Initialize with default config settings.
- (void)setDefaultConfigSettings {
  // Set the default config settings.
  self->_settings.fetchTimeout = RCNHTTPDefaultConnectionTimeout;
  self->_settings.minimumFetchInterval = RCNDefaultMinimumFetchInterval;
}

- (void)ensureInitializedWithCompletionHandler:
    (nonnull FIRRemoteConfigInitializationCompletion)completionHandler {
  __weak FIRRemoteConfig *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    FIRRemoteConfig *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    BOOL initializationSuccess = [self->_configContent initializationSuccessful];
    NSError *error = nil;
    if (!initializationSuccess) {
      error = [[NSError alloc]
          initWithDomain:FIRRemoteConfigErrorDomain
                    code:FIRRemoteConfigErrorInternalError
                userInfo:@{NSLocalizedDescriptionKey : @"Timed out waiting for database load."}];
    }
    completionHandler(error);
  });
}

#pragma mark - fetch

- (void)fetchWithCompletionHandler:(FIRRemoteConfigFetchCompletion)completionHandler {
  [self fetchWithExpirationDuration:_settings.minimumFetchInterval
                  completionHandler:completionHandler];
}

- (void)fetchWithExpirationDuration:(NSTimeInterval)expirationDuration
                  completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler {
  FIRRemoteConfigFetchCompletion completionHandlerCopy = nil;
  if (completionHandler) {
    completionHandlerCopy = [completionHandler copy];
  }
  [_configFetch fetchAllConfigsWithExpirationDuration:expirationDuration
                                    completionHandler:completionHandlerCopy];
}

#pragma mark - fetchAndActivate

- (void)fetchAndActivateWithCompletionHandler:
    (FIRRemoteConfigFetchAndActivateCompletion)completionHandler {
  __weak FIRRemoteConfig *weakSelf = self;
  FIRRemoteConfigFetchCompletion fetchCompletion =
      ^(FIRRemoteConfigFetchStatus fetchStatus, NSError *error) {
        FIRRemoteConfig *strongSelf = weakSelf;
        if (!strongSelf) {
          return;
        }
        // Fetch completed. We are being called on the main queue.
        // If fetch is successful, try to activate the fetched config
        bool didActivate = false;
        if (fetchStatus == FIRRemoteConfigFetchStatusSuccess && !error) {
          didActivate = [strongSelf activateFetched];
        }
        if (completionHandler) {
          FIRRemoteConfigFetchAndActivateStatus status = FIRRemoteConfigFetchAndActivateStatusError;
          if (fetchStatus == FIRRemoteConfigFetchStatusSuccess) {
            status = didActivate ? FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote
                                 : FIRRemoteConfigFetchAndActivateStatusSuccessUsingPreFetchedData;
          } else {
            status = FIRRemoteConfigFetchAndActivateStatusError;
          }
          // Pass along the fetch error e.g. throttled.
          completionHandler(status, error);
        }
      };
  [self fetchWithCompletionHandler:fetchCompletion];
}

#pragma mark - apply

- (BOOL)activateFetched {
  // TODO: We block on the async activate to complete. This method is deprecated and needs
  // to be removed at the next possible breaking change.
  __block dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block BOOL didActivate = NO;
  [self activateWithCompletionHandler:^(NSError *_Nullable error) {
    didActivate = error ? false : true;
    dispatch_semaphore_signal(semaphore);
  }];
  dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  return didActivate;
}

- (void)activateWithCompletionHandler:(FIRRemoteConfigActivateCompletion)completionHandler {
  __weak FIRRemoteConfig *weakSelf = self;
  void (^applyBlock)(void) = ^(void) {
    FIRRemoteConfig *strongSelf = weakSelf;
    if (!strongSelf) {
      NSError *error = [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                           code:FIRRemoteConfigErrorInternalError
                                       userInfo:@{@"ActivationFailureReason" : @"Internal Error."}];
      if (completionHandler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          completionHandler(error);
        });
      }
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000068", @"Internal error activating config.");
      return;
    }
    // If Fetched Config is no fresher than Active Config.
    if (strongSelf->_settings.lastFetchTimeInterval == 0 ||
        strongSelf->_settings.lastFetchTimeInterval <=
            strongSelf->_settings.lastApplyTimeInterval) {
      FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000069",
                    @"Most recently fetched config is already activated.");
      NSError *error = [NSError
          errorWithDomain:FIRRemoteConfigErrorDomain
                     code:FIRRemoteConfigErrorInternalError
                 userInfo:@{
                   @"ActivationFailureReason" : @"Most recently fetched config is already activated"
                 }];
      if (completionHandler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          completionHandler(error);
        });
      }
      return;
    }
    [strongSelf->_configContent copyFromDictionary:self->_configContent.fetchedConfig
                                          toSource:RCNDBSourceActive
                                      forNamespace:self->_FIRNamespace];
    [strongSelf updateExperiments];
    strongSelf->_settings.lastApplyTimeInterval = [[NSDate date] timeIntervalSince1970];
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000069", @"Config activated.");
    if (completionHandler) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completionHandler(nil);
      });
    }
  };
  dispatch_async(_queue, applyBlock);
}

- (void)updateExperiments {
  [self->_configExperiment updateExperiments];
}

#pragma mark - helpers
- (NSString *)fullyQualifiedNamespace:(NSString *)namespace {
  // If this is already a fully qualified namespace, return.
  if ([namespace rangeOfString:@":"].location != NSNotFound) {
    return namespace;
  }
  NSString *fullyQualifiedNamespace = [NSString stringWithFormat:@"%@:%@", namespace, _appName];
  return fullyQualifiedNamespace;
}

#pragma mark - Get Config Result

- (FIRRemoteConfigValue *)objectForKeyedSubscript:(NSString *)key {
  return [self configValueForKey:key];
}

- (FIRRemoteConfigValue *)configValueForKey:(NSString *)key {
  return [self configValueForKey:key namespace:_FIRNamespace];
}

- (FIRRemoteConfigValue *)configValueForKey:(NSString *)key namespace:(NSString *)aNamespace {
  if (!key || !aNamespace) {
    return [[FIRRemoteConfigValue alloc] initWithData:[NSData data]
                                               source:FIRRemoteConfigSourceStatic];
  }
  NSString *FQNamespace = [self fullyQualifiedNamespace:aNamespace];

  __block FIRRemoteConfigValue *value;
  dispatch_sync(_queue, ^{
    value = self->_configContent.activeConfig[FQNamespace][key];
    if (value) {
      if (value.source != FIRRemoteConfigSourceRemote) {
        FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000001",
                    @"Key %@ should come from source:%zd instead coming from source: %zd.", key,
                    (long)FIRRemoteConfigSourceRemote, (long)value.source);
      }
      return;
    }
    value = self->_configContent.defaultConfig[FQNamespace][key];
    if (value) {
      return;
    }

    value = [[FIRRemoteConfigValue alloc] initWithData:[NSData data]
                                                source:FIRRemoteConfigSourceStatic];
  });
  return value;
}

- (FIRRemoteConfigValue *)configValueForKey:(NSString *)key source:(FIRRemoteConfigSource)source {
  return [self configValueForKey:key namespace:_FIRNamespace source:source];
}

- (FIRRemoteConfigValue *)configValueForKey:(NSString *)key
                                  namespace:(NSString *)aNamespace
                                     source:(FIRRemoteConfigSource)source {
  if (!key || !aNamespace) {
    return [[FIRRemoteConfigValue alloc] initWithData:[NSData data]
                                               source:FIRRemoteConfigSourceStatic];
  }
  NSString *FQNamespace = [self fullyQualifiedNamespace:aNamespace];

  __block FIRRemoteConfigValue *value;
  dispatch_sync(_queue, ^{
    if (source == FIRRemoteConfigSourceRemote) {
      value = self->_configContent.activeConfig[FQNamespace][key];
    } else if (source == FIRRemoteConfigSourceDefault) {
      value = self->_configContent.defaultConfig[FQNamespace][key];
    } else {
      value = [[FIRRemoteConfigValue alloc] initWithData:[NSData data]
                                                  source:FIRRemoteConfigSourceStatic];
    }
  });
  return value;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained[])stackbuf
                                    count:(NSUInteger)len {
  __block NSUInteger localValue;
  dispatch_sync(_queue, ^{
    localValue =
        [self->_configContent.activeConfig[self->_FIRNamespace] countByEnumeratingWithState:state
                                                                                    objects:stackbuf
                                                                                      count:len];
  });
  return localValue;
}

#pragma mark - Properties

/// Last fetch completion time.
- (NSDate *)lastFetchTime {
  __block NSDate *fetchTime;
  dispatch_sync(_queue, ^{
    NSTimeInterval lastFetchTime = self->_settings.lastFetchTimeInterval;
    fetchTime = [NSDate dateWithTimeIntervalSince1970:lastFetchTime];
  });
  return fetchTime;
}

- (FIRRemoteConfigFetchStatus)lastFetchStatus {
  __block FIRRemoteConfigFetchStatus currentStatus;
  dispatch_sync(_queue, ^{
    currentStatus = self->_settings.lastFetchStatus;
  });
  return currentStatus;
}

- (NSArray *)allKeysFromSource:(FIRRemoteConfigSource)source {
  return [self allKeysFromSource:source namespace:_FIRNamespace];
}

- (NSArray *)allKeysFromSource:(FIRRemoteConfigSource)source namespace:(NSString *)aNamespace {
  __block NSArray *keys = [[NSArray alloc] init];
  dispatch_sync(_queue, ^{
    if (!aNamespace) {
      return;
    }
    NSString *FQNamespace = [self fullyQualifiedNamespace:aNamespace];
    switch (source) {
      case FIRRemoteConfigSourceDefault:
        if (self->_configContent.defaultConfig[FQNamespace]) {
          keys = [[self->_configContent.defaultConfig[FQNamespace] allKeys] copy];
        }
        break;
      case FIRRemoteConfigSourceRemote:
        if (self->_configContent.activeConfig[FQNamespace]) {
          keys = [[self->_configContent.activeConfig[FQNamespace] allKeys] copy];
        }
        break;
      default:
        break;
    }
  });
  return keys;
}

- (nonnull NSSet *)keysWithPrefix:(nullable NSString *)prefix {
  return [self keysWithPrefix:prefix namespace:_FIRNamespace];
}

- (nonnull NSSet *)keysWithPrefix:(nullable NSString *)prefix
                        namespace:(nullable NSString *)aNamespace {
  __block NSMutableSet *keys = [[NSMutableSet alloc] init];
  __block NSString *namespaceToCheck = aNamespace;
  dispatch_sync(_queue, ^{
    if (!namespaceToCheck.length) {
      return;
    }
    NSString *FQNamespace = [self fullyQualifiedNamespace:namespaceToCheck];
    if (self->_configContent.activeConfig[FQNamespace]) {
      NSArray *allKeys = [self->_configContent.activeConfig[FQNamespace] allKeys];
      if (!prefix.length) {
        keys = [NSMutableSet setWithArray:allKeys];
      } else {
        for (NSString *key in allKeys) {
          if ([key hasPrefix:prefix]) {
            [keys addObject:key];
          }
        }
      }
    }
  });
  return [keys copy];
}

#pragma mark - Defaults

- (void)setDefaults:(NSDictionary<NSString *, NSObject *> *)defaults {
  [self setDefaults:defaults namespace:_FIRNamespace];
}

- (void)setDefaults:(NSDictionary<NSString *, NSObject *> *)defaultConfig
          namespace:(NSString *)aNamespace {
  if (!aNamespace) {
    FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000036", @"The namespace cannot be empty or nil.");
    return;
  }
  NSString *FQNamespace = [self fullyQualifiedNamespace:aNamespace];
  NSDictionary *defaultConfigCopy = [[NSDictionary alloc] init];
  if (defaultConfig) {
    defaultConfigCopy = [defaultConfig copy];
  }
  void (^setDefaultsBlock)(void) = ^(void) {
    NSDictionary *namespaceToDefaults = @{FQNamespace : defaultConfigCopy};
    [self->_configContent copyFromDictionary:namespaceToDefaults
                                    toSource:RCNDBSourceDefault
                                forNamespace:FQNamespace];
    self->_settings.lastSetDefaultsTimeInterval = [[NSDate date] timeIntervalSince1970];
  };
  dispatch_async(_queue, setDefaultsBlock);
}

- (FIRRemoteConfigValue *)defaultValueForKey:(NSString *)key {
  return [self defaultValueForKey:key namespace:_FIRNamespace];
}

- (FIRRemoteConfigValue *)defaultValueForKey:(NSString *)key namespace:(NSString *)aNamespace {
  if (!key || !aNamespace) {
    return nil;
  }
  NSString *FQNamespace = [self fullyQualifiedNamespace:aNamespace];
  __block FIRRemoteConfigValue *value;
  dispatch_sync(_queue, ^{
    NSDictionary *defaultConfig = self->_configContent.defaultConfig;
    value = defaultConfig[FQNamespace][key];
    if (value) {
      if (value.source != FIRRemoteConfigSourceDefault) {
        FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000002",
                    @"Key %@ should come from source:%zd instead coming from source: %zd", key,
                    (long)FIRRemoteConfigSourceDefault, (long)value.source);
      }
    }
  });
  return value;
}

- (void)setDefaultsFromPlistFileName:(nullable NSString *)fileName {
  return [self setDefaultsFromPlistFileName:fileName namespace:_FIRNamespace];
}

- (void)setDefaultsFromPlistFileName:(nullable NSString *)fileName
                           namespace:(nullable NSString *)namespace {
  if (!namespace || namespace.length == 0) {
    FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000036", @"The namespace cannot be empty or nil.");
    return;
  }
  NSString *FQNamespace = [self fullyQualifiedNamespace:namespace];
  if (!fileName || fileName.length == 0) {
    FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000037",
                  @"The plist file '%@' could not be found by Remote Config.", fileName);
    return;
  }
  NSArray *bundles = @[ [NSBundle mainBundle], [NSBundle bundleForClass:[self class]] ];

  for (NSBundle *bundle in bundles) {
    NSString *plistFile = [bundle pathForResource:fileName ofType:@"plist"];
    // Use the first one we find.
    if (plistFile) {
      NSDictionary *defaultConfig = [[NSDictionary alloc] initWithContentsOfFile:plistFile];
      if (defaultConfig) {
        [self setDefaults:defaultConfig namespace:FQNamespace];
      }
      return;
    }
  }
  FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000037",
                @"The plist file '%@' could not be found by Remote Config.", fileName);
}

#pragma mark - custom variables

- (FIRRemoteConfigSettings *)configSettings {
  __block BOOL developerModeEnabled = NO;
  __block NSTimeInterval minimumFetchInterval = RCNDefaultMinimumFetchInterval;
  __block NSTimeInterval fetchTimeout = RCNHTTPDefaultConnectionTimeout;
  dispatch_sync(_queue, ^{
    developerModeEnabled = [self->_settings.customVariables[kRemoteConfigDeveloperKey] boolValue];
    minimumFetchInterval = self->_settings.minimumFetchInterval;
    fetchTimeout = self->_settings.fetchTimeout;
  });
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000066",
              @"Successfully read configSettings. Developer Mode: %@, Minimum Fetch Interval:%f, "
              @"Fetch timeout: %f",
              developerModeEnabled ? @"true" : @"false", minimumFetchInterval, fetchTimeout);
  FIRRemoteConfigSettings *settings =
      [[FIRRemoteConfigSettings alloc] initWithDeveloperModeEnabled:developerModeEnabled];
  settings.minimumFetchInterval = minimumFetchInterval;
  settings.fetchTimeout = fetchTimeout;
  /// The NSURLSession needs to be recreated whenever the fetch timeout may be updated.
  [_configFetch recreateNetworkSession];
  return settings;
}

- (void)setConfigSettings:(FIRRemoteConfigSettings *)configSettings {
  void (^setConfigSettingsBlock)(void) = ^(void) {
    if (!configSettings) {
      return;
    }

    NSDictionary *settingsToSave = @{
      kRemoteConfigDeveloperKey : @(configSettings.isDeveloperModeEnabled),
    };
    self->_settings.customVariables = settingsToSave;
    self->_settings.minimumFetchInterval = configSettings.minimumFetchInterval;
    self->_settings.fetchTimeout = configSettings.fetchTimeout;
    /// The NSURLSession needs to be recreated whenever the fetch timeout may be updated.
    [self->_configFetch recreateNetworkSession];
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000067",
                @"Successfully set configSettings. Developer Mode: %@, Minimum Fetch Interval:%f, "
                @"Fetch timeout:%f",
                configSettings.isDeveloperModeEnabled ? @"true" : @"false",
                configSettings.minimumFetchInterval, configSettings.fetchTimeout);
  };
  dispatch_async(_queue, setConfigSettingsBlock);
}

#pragma clang diagnostic push  // "-Wdeprecated-declarations"

@end
