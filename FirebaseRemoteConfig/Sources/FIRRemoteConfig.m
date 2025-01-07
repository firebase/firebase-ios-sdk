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

#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"

#import "FirebaseABTesting/Sources/Private/FirebaseABTestingInternal.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Sources/FIRRemoteConfigComponent.h"
#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigExperiment.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigRealtime.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"
#import "FirebaseRemoteConfig/Sources/RCNDevice.h"
#import "FirebaseRemoteConfig/Sources/RCNPersonalization.h"

/// Remote Config Error Domain.
/// TODO: Rename according to obj-c style for constants.
NSString *const FIRRemoteConfigErrorDomain = @"com.google.remoteconfig.ErrorDomain";
// Remote Config Custom Signals Error Domain
NSString *const FIRRemoteConfigCustomSignalsErrorDomain =
    @"com.google.remoteconfig.customsignals.ErrorDomain";
// Remote Config Realtime Error Domain
NSString *const FIRRemoteConfigUpdateErrorDomain = @"com.google.remoteconfig.update.ErrorDomain";
/// Remote Config Error Info End Time Seconds;
NSString *const FIRRemoteConfigThrottledEndTimeInSecondsKey = @"error_throttled_end_time_seconds";
/// Minimum required time interval between fetch requests made to the backend.
static NSString *const kRemoteConfigMinimumFetchIntervalKey = @"_rcn_minimum_fetch_interval";
/// Timeout value for waiting on a fetch response.
static NSString *const kRemoteConfigFetchTimeoutKey = @"_rcn_fetch_timeout";
/// Notification when config is successfully activated
const NSNotificationName FIRRemoteConfigActivateNotification =
    @"FIRRemoteConfigActivateNotification";
static NSNotificationName FIRRolloutsStateDidChangeNotificationName =
    @"FIRRolloutsStateDidChangeNotification";
/// Maximum allowed length for a custom signal key (in characters).
static const NSUInteger FIRRemoteConfigCustomSignalsMaxKeyLength = 250;
/// Maximum allowed length for a string value in custom signals (in characters).
static const NSUInteger FIRRemoteConfigCustomSignalsMaxStringValueLength = 500;
/// Maximum number of custom signals allowed.
static const NSUInteger FIRRemoteConfigCustomSignalsMaxCount = 100;

/// Listener for the get methods.
typedef void (^FIRRemoteConfigListener)(NSString *_Nonnull, NSDictionary *_Nonnull);

@implementation FIRRemoteConfigSettings

- (instancetype)init {
  self = [super init];
  if (self) {
    _minimumFetchInterval = RCNDefaultMinimumFetchInterval;
    _fetchTimeout = RCNHTTPDefaultConnectionTimeout;
  }
  return self;
}

@end

@implementation FIRRemoteConfig {
  /// All the config content.
  RCNConfigContent *_configContent;
  RCNConfigDBManager *_DBManager;
  RCNConfigSettings *_settings;
  RCNConfigFetch *_configFetch;
  RCNConfigExperiment *_configExperiment;
  RCNConfigRealtime *_configRealtime;
  dispatch_queue_t _queue;
  NSString *_appName;
  NSMutableArray *_listeners;
}

static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, FIRRemoteConfig *> *>
    *RCInstances;

+ (nonnull FIRRemoteConfig *)remoteConfigWithApp:(FIRApp *_Nonnull)firebaseApp {
  return [FIRRemoteConfig
      remoteConfigWithFIRNamespace:FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform
                               app:firebaseApp];
}

+ (nonnull FIRRemoteConfig *)remoteConfigWithFIRNamespace:(NSString *_Nonnull)firebaseNamespace {
  if (![FIRApp isDefaultAppConfigured]) {
    [NSException raise:@"FIRAppNotConfigured"
                format:@"The default `FirebaseApp` instance must be configured before the "
                       @"default Remote Config instance can be initialized. One way to ensure this "
                       @"is to call `FirebaseApp.configure()` in the App Delegate's "
                       @"`application(_:didFinishLaunchingWithOptions:)` or the `@main` struct's "
                       @"initializer in SwiftUI."];
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
    [NSException raise:@"FIRAppNotConfigured"
                format:@"The default `FirebaseApp` instance must be configured before the "
                       @"default Remote Config instance can be initialized. One way to ensure this "
                       @"is to call `FirebaseApp.configure()` in the App Delegate's "
                       @"`application(_:didFinishLaunchingWithOptions:)` or the `@main` struct's "
                       @"initializer in SwiftUI."];
  }

  return [FIRRemoteConfig
      remoteConfigWithFIRNamespace:FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform
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

    _configRealtime = [[RCNConfigRealtime alloc] init:_configFetch
                                             settings:_settings
                                            namespace:_FIRNamespace
                                              options:options];

    [_settings loadConfigFromMetadataTable];

    if (analytics) {
      _listeners = [[NSMutableArray alloc] init];
      RCNPersonalization *personalization =
          [[RCNPersonalization alloc] initWithAnalytics:analytics];
      [self addListener:^(NSString *key, NSDictionary *config) {
        [personalization logArmActive:key config:config];
      }];
    }
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

/// Adds a listener that will be called whenever one of the get methods is called.
/// @param listener Function that takes in the parameter key and the config.
- (void)addListener:(nonnull FIRRemoteConfigListener)listener {
  @synchronized(_listeners) {
    [_listeners addObject:listener];
  }
}

- (void)callListeners:(NSString *)key config:(NSDictionary *)config {
  @synchronized(_listeners) {
    for (FIRRemoteConfigListener listener in _listeners) {
      dispatch_async(_queue, ^{
        listener(key, config);
      });
    }
  }
}

- (void)setCustomSignals:(nonnull NSDictionary<NSString *, NSObject *> *)customSignals
          withCompletion:(void (^_Nullable)(NSError *_Nullable error))completionHandler {
  void (^setCustomSignalsBlock)(void) = ^{
    // Validate value type, and key and value length
    for (NSString *key in customSignals) {
      NSObject *value = customSignals[key];
      if (![value isKindOfClass:[NSNull class]] && ![value isKindOfClass:[NSString class]] &&
          ![value isKindOfClass:[NSNumber class]]) {
        if (completionHandler) {
          dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error =
                [NSError errorWithDomain:FIRRemoteConfigCustomSignalsErrorDomain
                                    code:FIRRemoteConfigCustomSignalsErrorInvalidValueType
                                userInfo:@{
                                  NSLocalizedDescriptionKey :
                                      @"Invalid value type. Must be NSString, NSNumber or NSNull"
                                }];
            completionHandler(error);
          });
        }
        return;
      }

      if (key.length > FIRRemoteConfigCustomSignalsMaxKeyLength ||
          ([value isKindOfClass:[NSString class]] &&
           [(NSString *)value length] > FIRRemoteConfigCustomSignalsMaxStringValueLength)) {
        if (completionHandler) {
          dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError
                errorWithDomain:FIRRemoteConfigCustomSignalsErrorDomain
                           code:FIRRemoteConfigCustomSignalsErrorLimitExceeded
                       userInfo:@{
                         NSLocalizedDescriptionKey : [NSString
                             stringWithFormat:@"Custom signal keys and string values must be "
                                              @"%lu and %lu characters or less respectively.",
                                              FIRRemoteConfigCustomSignalsMaxKeyLength,
                                              FIRRemoteConfigCustomSignalsMaxStringValueLength]
                       }];
            completionHandler(error);
          });
        }
        return;
      }
    }

    // Merge new signals with existing ones, overwriting existing keys.
    // Also, remove entries where the new value is null.
    NSMutableDictionary<NSString *, NSString *> *newCustomSignals =
        [[NSMutableDictionary alloc] initWithDictionary:self->_settings.customSignals];

    for (NSString *key in customSignals) {
      NSObject *value = customSignals[key];
      if (![value isKindOfClass:[NSNull class]]) {
        NSString *stringValue = [value isKindOfClass:[NSNumber class]]
                                    ? [(NSNumber *)value stringValue]
                                    : (NSString *)value;
        [newCustomSignals setObject:stringValue forKey:key];
      } else {
        [newCustomSignals removeObjectForKey:key];
      }
    }

    // Check the size limit.
    if (newCustomSignals.count > FIRRemoteConfigCustomSignalsMaxCount) {
      if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
          NSError *error = [NSError
              errorWithDomain:FIRRemoteConfigCustomSignalsErrorDomain
                         code:FIRRemoteConfigCustomSignalsErrorLimitExceeded
                     userInfo:@{
                       NSLocalizedDescriptionKey : [NSString
                           stringWithFormat:@"Custom signals count exceeds the limit of %lu.",
                                            FIRRemoteConfigCustomSignalsMaxCount]
                     }];
          completionHandler(error);
        });
      }
      return;
    }

    // Update only if there are changes.
    if (![newCustomSignals isEqualToDictionary:self->_settings.customSignals]) {
      self->_settings.customSignals = newCustomSignals;
    }
    // Log the keys of the updated custom signals.
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000078", @"Keys of updated custom signals: %@",
                [newCustomSignals allKeys]);

    if (completionHandler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(nil);
      });
    }
  };
  dispatch_async(_queue, setCustomSignalsBlock);
}

#pragma mark - fetch

- (void)fetchWithCompletionHandler:(FIRRemoteConfigFetchCompletion)completionHandler {
  dispatch_async(_queue, ^{
    [self fetchWithExpirationDuration:self->_settings.minimumFetchInterval
                    completionHandler:completionHandler];
  });
}

- (void)fetchWithExpirationDuration:(NSTimeInterval)expirationDuration
                  completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler {
  FIRRemoteConfigFetchCompletion completionHandlerCopy = nil;
  if (completionHandler) {
    completionHandlerCopy = [completionHandler copy];
  }
  [_configFetch fetchConfigWithExpirationDuration:expirationDuration
                                completionHandler:completionHandlerCopy];
}

#pragma mark - fetchAndActivate

- (void)fetchAndActivateWithCompletionHandler:
    (FIRRemoteConfigFetchAndActivateCompletion)completionHandler {
  __weak FIRRemoteConfig *weakSelf = self;
  FIRRemoteConfigFetchCompletion fetchCompletion =
      ^(FIRRemoteConfigFetchStatus fetchStatus, NSError *fetchError) {
        FIRRemoteConfig *strongSelf = weakSelf;
        if (!strongSelf) {
          return;
        }
        // Fetch completed. We are being called on the main queue.
        // If fetch is successful, try to activate the fetched config
        if (fetchStatus == FIRRemoteConfigFetchStatusSuccess && !fetchError) {
          [strongSelf activateWithCompletion:^(BOOL changed, NSError *_Nullable activateError) {
            if (completionHandler) {
              FIRRemoteConfigFetchAndActivateStatus status =
                  activateError ? FIRRemoteConfigFetchAndActivateStatusSuccessUsingPreFetchedData
                                : FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote;
              dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(status, nil);
              });
            }
          }];
        } else if (completionHandler) {
          FIRRemoteConfigFetchAndActivateStatus status =
              fetchStatus == FIRRemoteConfigFetchStatusSuccess
                  ? FIRRemoteConfigFetchAndActivateStatusSuccessUsingPreFetchedData
                  : FIRRemoteConfigFetchAndActivateStatusError;
          dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(status, fetchError);
          });
        }
      };
  [self fetchWithCompletionHandler:fetchCompletion];
}

#pragma mark - activate

typedef void (^FIRRemoteConfigActivateChangeCompletion)(BOOL changed, NSError *_Nullable error);

- (void)activateWithCompletion:(FIRRemoteConfigActivateChangeCompletion)completion {
  __weak FIRRemoteConfig *weakSelf = self;
  void (^applyBlock)(void) = ^(void) {
    FIRRemoteConfig *strongSelf = weakSelf;
    if (!strongSelf) {
      NSError *error = [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                           code:FIRRemoteConfigErrorInternalError
                                       userInfo:@{@"ActivationFailureReason" : @"Internal Error."}];
      if (completion) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          completion(NO, error);
        });
      }
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000068", @"Internal error activating config.");
      return;
    }
    // Check if the last fetched config has already been activated. Fetches with no data change are
    // ignored.
    if (strongSelf->_settings.lastETagUpdateTime == 0 ||
        strongSelf->_settings.lastETagUpdateTime <= strongSelf->_settings.lastApplyTimeInterval) {
      FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000069",
                  @"Most recently fetched config is already activated.");
      if (completion) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          completion(NO, nil);
        });
      }
      return;
    }
    [strongSelf->_configContent copyFromDictionary:self->_configContent.fetchedConfig
                                          toSource:RCNDBSourceActive
                                      forNamespace:self->_FIRNamespace];
    strongSelf->_settings.lastApplyTimeInterval = [[NSDate date] timeIntervalSince1970];
    // New config has been activated at this point
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000069", @"Config activated.");
    [strongSelf->_configContent activatePersonalization];
    // Update last active template version number in setting and userDefaults.
    [strongSelf->_settings updateLastActiveTemplateVersion];
    // Update activeRolloutMetadata
    [strongSelf->_configContent activateRolloutMetadata:^(BOOL success) {
      if (success) {
        [self notifyRolloutsStateChange:strongSelf->_configContent.activeRolloutMetadata
                          versionNumber:strongSelf->_settings.lastActiveTemplateVersion];
      }
    }];

    // Update experiments only for 3p namespace
    NSString *namespace = [strongSelf->_FIRNamespace
        substringToIndex:[strongSelf->_FIRNamespace rangeOfString:@":"].location];
    if ([namespace isEqualToString:FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform]) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self notifyConfigHasActivated];
      });
      [strongSelf->_configExperiment updateExperimentsWithHandler:^(NSError *_Nullable error) {
        if (completion) {
          dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(YES, nil);
          });
        }
      }];
    } else {
      if (completion) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          completion(YES, nil);
        });
      }
    }
  };
  dispatch_async(_queue, applyBlock);
}

- (void)notifyConfigHasActivated {
  // Need a valid google app name.
  if (!_appName) {
    return;
  }
  // The Remote Config Swift SDK will be listening for this notification so it can tell SwiftUI to
  // update the UI.
  NSDictionary *appInfoDict = @{kFIRAppNameKey : _appName};
  [[NSNotificationCenter defaultCenter] postNotificationName:FIRRemoteConfigActivateNotification
                                                      object:self
                                                    userInfo:appInfoDict];
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

- (FIRRemoteConfigValue *)defaultValueForFullyQualifiedNamespace:(NSString *)namespace
                                                             key:(NSString *)key {
  FIRRemoteConfigValue *value = self->_configContent.defaultConfig[namespace][key];
  if (!value) {
    value = [[FIRRemoteConfigValue alloc]
        initWithData:[NSData data]
              source:(FIRRemoteConfigSource)FIRRemoteConfigSourceStatic];
  }
  return value;
}

#pragma mark - Get Config Result

- (FIRRemoteConfigValue *)objectForKeyedSubscript:(NSString *)key {
  return [self configValueForKey:key];
}

- (FIRRemoteConfigValue *)configValueForKey:(NSString *)key {
  if (!key) {
    return [[FIRRemoteConfigValue alloc] initWithData:[NSData data]
                                               source:FIRRemoteConfigSourceStatic];
  }
  NSString *FQNamespace = [self fullyQualifiedNamespace:_FIRNamespace];
  __block FIRRemoteConfigValue *value;
  dispatch_sync(_queue, ^{
    value = self->_configContent.activeConfig[FQNamespace][key];
    if (value) {
      if (value.source != FIRRemoteConfigSourceRemote) {
        FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000001",
                    @"Key %@ should come from source:%zd instead coming from source: %zd.", key,
                    (long)FIRRemoteConfigSourceRemote, (long)value.source);
      }
      [self callListeners:key
                   config:[self->_configContent getConfigAndMetadataForNamespace:FQNamespace]];
      return;
    }
    value = [self defaultValueForFullyQualifiedNamespace:FQNamespace key:key];
  });
  return value;
}

- (FIRRemoteConfigValue *)configValueForKey:(NSString *)key source:(FIRRemoteConfigSource)source {
  if (!key) {
    return [[FIRRemoteConfigValue alloc] initWithData:[NSData data]
                                               source:FIRRemoteConfigSourceStatic];
  }
  NSString *FQNamespace = [self fullyQualifiedNamespace:_FIRNamespace];

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
  __block NSArray *keys = [[NSArray alloc] init];
  dispatch_sync(_queue, ^{
    NSString *FQNamespace = [self fullyQualifiedNamespace:self->_FIRNamespace];
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
  __block NSMutableSet *keys = [[NSMutableSet alloc] init];
  dispatch_sync(_queue, ^{
    NSString *FQNamespace = [self fullyQualifiedNamespace:self->_FIRNamespace];
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

- (void)setDefaults:(NSDictionary<NSString *, NSObject *> *)defaultConfig {
  NSString *FQNamespace = [self fullyQualifiedNamespace:_FIRNamespace];
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
  NSString *FQNamespace = [self fullyQualifiedNamespace:_FIRNamespace];
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
        [self setDefaults:defaultConfig];
      }
      return;
    }
  }
  FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000037",
                @"The plist file '%@' could not be found by Remote Config.", fileName);
}

#pragma mark - custom variables

- (FIRRemoteConfigSettings *)configSettings {
  __block NSTimeInterval minimumFetchInterval = RCNDefaultMinimumFetchInterval;
  __block NSTimeInterval fetchTimeout = RCNHTTPDefaultConnectionTimeout;
  dispatch_sync(_queue, ^{
    minimumFetchInterval = self->_settings.minimumFetchInterval;
    fetchTimeout = self->_settings.fetchTimeout;
  });
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000066",
              @"Successfully read configSettings. Minimum Fetch Interval:%f, "
              @"Fetch timeout: %f",
              minimumFetchInterval, fetchTimeout);
  FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
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

    self->_settings.minimumFetchInterval = configSettings.minimumFetchInterval;
    self->_settings.fetchTimeout = configSettings.fetchTimeout;
    /// The NSURLSession needs to be recreated whenever the fetch timeout may be updated.
    [self->_configFetch recreateNetworkSession];
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000067",
                @"Successfully set configSettings. Minimum Fetch Interval:%f, "
                @"Fetch timeout:%f",
                configSettings.minimumFetchInterval, configSettings.fetchTimeout);
  };
  dispatch_async(_queue, setConfigSettingsBlock);
}

#pragma mark - Realtime

- (FIRConfigUpdateListenerRegistration *)addOnConfigUpdateListener:
    (void (^_Nonnull)(FIRRemoteConfigUpdate *update, NSError *_Nullable error))listener {
  return [self->_configRealtime addConfigUpdateListener:listener];
}

#pragma mark - Rollout

- (void)addRemoteConfigInteropSubscriber:(id<FIRRolloutsStateSubscriber>)subscriber {
  [[NSNotificationCenter defaultCenter]
      addObserverForName:FIRRolloutsStateDidChangeNotificationName
                  object:self
                   queue:nil
              usingBlock:^(NSNotification *_Nonnull notification) {
                FIRRolloutsState *rolloutsState =
                    notification.userInfo[FIRRolloutsStateDidChangeNotificationName];
                [subscriber rolloutsStateDidChange:rolloutsState];
              }];
  // Send active rollout metadata stored in persistence while app launched if there is activeConfig
  NSString *fullyQualifiedNamespace = [self fullyQualifiedNamespace:_FIRNamespace];
  NSDictionary<NSString *, NSDictionary *> *activeConfig = self->_configContent.activeConfig;
  if (activeConfig[fullyQualifiedNamespace] && activeConfig[fullyQualifiedNamespace].count > 0) {
    [self notifyRolloutsStateChange:self->_configContent.activeRolloutMetadata
                      versionNumber:self->_settings.lastActiveTemplateVersion];
  }
}

- (void)notifyRolloutsStateChange:(NSArray<NSDictionary *> *)rolloutMetadata
                    versionNumber:(NSString *)versionNumber {
  NSArray<FIRRolloutAssignment *> *rolloutsAssignments =
      [self rolloutsAssignmentsWith:rolloutMetadata versionNumber:versionNumber];
  FIRRolloutsState *rolloutsState =
      [[FIRRolloutsState alloc] initWithAssignmentList:rolloutsAssignments];
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000069",
              @"Send rollouts state notification with name %@ to RemoteConfigInterop.",
              FIRRolloutsStateDidChangeNotificationName);
  [[NSNotificationCenter defaultCenter]
      postNotificationName:FIRRolloutsStateDidChangeNotificationName
                    object:self
                  userInfo:@{FIRRolloutsStateDidChangeNotificationName : rolloutsState}];
}

- (NSArray<FIRRolloutAssignment *> *)rolloutsAssignmentsWith:
                                         (NSArray<NSDictionary *> *)rolloutMetadata
                                               versionNumber:(NSString *)versionNumber {
  NSMutableArray<FIRRolloutAssignment *> *rolloutsAssignments = [[NSMutableArray alloc] init];
  NSString *FQNamespace = [self fullyQualifiedNamespace:_FIRNamespace];
  for (NSDictionary *metadata in rolloutMetadata) {
    NSString *rolloutId = metadata[RCNFetchResponseKeyRolloutID];
    NSString *variantID = metadata[RCNFetchResponseKeyVariantID];
    NSArray<NSString *> *affectedParameterKeys = metadata[RCNFetchResponseKeyAffectedParameterKeys];
    if (rolloutId && variantID && affectedParameterKeys) {
      for (NSString *key in affectedParameterKeys) {
        FIRRemoteConfigValue *value = self->_configContent.activeConfig[FQNamespace][key];
        if (!value) {
          value = [self defaultValueForFullyQualifiedNamespace:FQNamespace key:key];
        }
        FIRRolloutAssignment *assignment =
            [[FIRRolloutAssignment alloc] initWithRolloutId:rolloutId
                                                  variantId:variantID
                                            templateVersion:[versionNumber longLongValue]
                                               parameterKey:key
                                             parameterValue:value.stringValue];
        [rolloutsAssignments addObject:assignment];
      }
    }
  }
  return rolloutsAssignments;
}
@end
