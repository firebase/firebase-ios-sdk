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

#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"

#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"
#import "FirebaseRemoteConfig/Sources/RCNDevice.h"
#import "FirebaseRemoteConfig/Sources/RCNUserDefaultsManager.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "GoogleUtilities/Environment/Private/GULAppEnvironmentUtil.h"

static NSString *const kRCNGroupPrefix = @"frc.group.";
static NSString *const kRCNUserDefaultsKeyNamelastETag = @"lastETag";
static NSString *const kRCNUserDefaultsKeyNameLastSuccessfulFetchTime = @"lastSuccessfulFetchTime";
static const int kRCNExponentialBackoffMinimumInterval = 60 * 2;       // 2 mins.
static const int kRCNExponentialBackoffMaximumInterval = 60 * 60 * 4;  // 4 hours.

@interface RCNConfigSettings () {
  /// A list of successful fetch timestamps in seconds.
  NSMutableArray *_successFetchTimes;
  /// A list of failed fetch timestamps in seconds.
  NSMutableArray *_failureFetchTimes;
  /// Device conditions since last successful fetch from the backend. Device conditions including
  /// app
  /// version, iOS version, device localte, language, GMP project ID and Game project ID. Used for
  /// determing whether to throttle.
  NSMutableDictionary *_deviceContext;
  /// Custom variables (aka App context digest). This is the pending custom variables request before
  /// fetching.
  NSMutableDictionary *_customVariables;
  /// Cached internal metadata from internal metadata table. It contains customized information such
  /// as HTTP connection timeout, HTTP read timeout, success/failure throttling rate and time
  /// interval. Client has the default value of each parameters, they are only saved in
  /// internalMetadata if they have been customize by developers.
  NSMutableDictionary *_internalMetadata;
  /// Last fetch status.
  FIRRemoteConfigFetchStatus _lastFetchStatus;
  /// Last fetch Error.
  FIRRemoteConfigError _lastFetchError;
  /// The time of last apply timestamp.
  NSTimeInterval _lastApplyTimeInterval;
  /// The time of last setDefaults timestamp.
  NSTimeInterval _lastSetDefaultsTimeInterval;
  /// The database manager.
  RCNConfigDBManager *_DBManager;
  // The namespace for this instance.
  NSString *_FIRNamespace;
  // The Google App ID of the configured FIRApp.
  NSString *_googleAppID;
  /// The user defaults manager scoped to this RC instance of FIRApp and namespace.
  RCNUserDefaultsManager *_userDefaultsManager;
  /// The timestamp of last eTag update.
  NSTimeInterval _lastETagUpdateTime;
}
@end

@implementation RCNConfigSettings

- (instancetype)initWithDatabaseManager:(RCNConfigDBManager *)manager
                              namespace:(NSString *)FIRNamespace
                        firebaseAppName:(NSString *)appName
                            googleAppID:(NSString *)googleAppID {
  self = [super init];
  if (self) {
    _FIRNamespace = FIRNamespace;
    _googleAppID = googleAppID;
    _bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (!_bundleIdentifier) {
      FIRLogNotice(kFIRLoggerRemoteConfig, @"I-RCN000038",
                   @"Main bundle identifier is missing. Remote Config might not work properly.");
      _bundleIdentifier = @"";
    }
    _minimumFetchInterval = RCNDefaultMinimumFetchInterval;
    _deviceContext = [[NSMutableDictionary alloc] init];
    _customVariables = [[NSMutableDictionary alloc] init];
    _successFetchTimes = [[NSMutableArray alloc] init];
    _failureFetchTimes = [[NSMutableArray alloc] init];
    _DBManager = manager;

    _internalMetadata = [[_DBManager loadInternalMetadataTable] mutableCopy];
    if (!_internalMetadata) {
      _internalMetadata = [[NSMutableDictionary alloc] init];
    }
    _userDefaultsManager = [[RCNUserDefaultsManager alloc] initWithAppName:appName
                                                                  bundleID:_bundleIdentifier
                                                                 namespace:_FIRNamespace];

    // Check if the config database is new. If so, clear the configs saved in userDefaults.
    if ([_DBManager isNewDatabase]) {
      FIRLogNotice(kFIRLoggerRemoteConfig, @"I-RCN000072",
                   @"New config database created. Resetting user defaults.");
      [_userDefaultsManager resetUserDefaults];
    }

    _isFetchInProgress = NO;
  }
  return self;
}

#pragma mark - read from / update userDefaults
- (NSString *)lastETag {
  return [_userDefaultsManager lastETag];
}

- (void)setLastETag:(NSString *)lastETag {
  [self setLastETagUpdateTime:[[NSDate date] timeIntervalSince1970]];
  [_userDefaultsManager setLastETag:lastETag];
}

- (void)setLastETagUpdateTime:(NSTimeInterval)lastETagUpdateTime {
  [_userDefaultsManager setLastETagUpdateTime:lastETagUpdateTime];
}

- (NSTimeInterval)lastFetchTimeInterval {
  return _userDefaultsManager.lastFetchTime;
}

- (NSTimeInterval)lastETagUpdateTime {
  return _userDefaultsManager.lastETagUpdateTime;
}

// TODO: Update logic for app extensions as required.
- (void)updateLastFetchTimeInterval:(NSTimeInterval)lastFetchTimeInterval {
  _userDefaultsManager.lastFetchTime = lastFetchTimeInterval;
}

#pragma mark - load from DB
- (NSDictionary *)loadConfigFromMetadataTable {
  NSDictionary *metadata = [[_DBManager loadMetadataWithBundleIdentifier:_bundleIdentifier] copy];
  if (metadata) {
    // TODO: Remove (all metadata in general) once ready to
    // migrate to user defaults completely.
    if (metadata[RCNKeyDeviceContext]) {
      self->_deviceContext = [metadata[RCNKeyDeviceContext] mutableCopy];
    }
    if (metadata[RCNKeyAppContext]) {
      self->_customVariables = [metadata[RCNKeyAppContext] mutableCopy];
    }
    if (metadata[RCNKeySuccessFetchTime]) {
      self->_successFetchTimes = [metadata[RCNKeySuccessFetchTime] mutableCopy];
    }
    if (metadata[RCNKeyFailureFetchTime]) {
      self->_failureFetchTimes = [metadata[RCNKeyFailureFetchTime] mutableCopy];
    }
    if (metadata[RCNKeyLastFetchStatus]) {
      self->_lastFetchStatus =
          (FIRRemoteConfigFetchStatus)[metadata[RCNKeyLastFetchStatus] intValue];
    }
    if (metadata[RCNKeyLastFetchError]) {
      self->_lastFetchError = (FIRRemoteConfigError)[metadata[RCNKeyLastFetchError] intValue];
    }
    if (metadata[RCNKeyLastApplyTime]) {
      self->_lastApplyTimeInterval = [metadata[RCNKeyLastApplyTime] doubleValue];
    }
    if (metadata[RCNKeyLastFetchStatus]) {
      self->_lastSetDefaultsTimeInterval = [metadata[RCNKeyLastSetDefaultsTime] doubleValue];
    }
  }
  return metadata;
}

#pragma mark - update DB/cached

// Update internal metadata content to cache and DB.
- (void)updateInternalContentWithResponse:(NSDictionary *)response {
  // Remove all the keys with current pakcage name.
  [_DBManager deleteRecordWithBundleIdentifier:_bundleIdentifier isInternalDB:YES];

  for (NSString *key in _internalMetadata.allKeys) {
    if ([key hasPrefix:_bundleIdentifier]) {
      [_internalMetadata removeObjectForKey:key];
    }
  }

  for (NSString *entry in response) {
    NSData *val = [response[entry] dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *values = @[ entry, val ];
    _internalMetadata[entry] = response[entry];
    [self updateInternalMetadataTableWithValues:values];
  }
}

- (void)updateInternalMetadataTableWithValues:(NSArray *)values {
  [_DBManager insertInternalMetadataTableWithValues:values completionHandler:nil];
}

/// If the last fetch was not successful, update the (exponential backoff) period that we wait until
/// fetching again. Any subsequent fetch requests will be checked and allowed only if past this
/// throttle end time.
- (void)updateExponentialBackoffTime {
  // If not in exponential backoff mode, reset the retry interval.
  if (_lastFetchStatus == FIRRemoteConfigFetchStatusSuccess) {
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000057",
                @"Throttling: Entering exponential backoff mode.");
    _exponentialBackoffRetryInterval = kRCNExponentialBackoffMinimumInterval;
  } else {
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000057",
                @"Throttling: Updating throttling interval.");
    // Double the retry interval until we hit the truncated exponential backoff. More info here:
    // https://cloud.google.com/storage/docs/exponential-backoff
    _exponentialBackoffRetryInterval =
        ((_exponentialBackoffRetryInterval * 2) < kRCNExponentialBackoffMaximumInterval)
            ? _exponentialBackoffRetryInterval * 2
            : _exponentialBackoffRetryInterval;
  }

  // Randomize the next retry interval.
  int randomPlusMinusInterval = ((arc4random() % 2) == 0) ? -1 : 1;
  NSTimeInterval randomizedRetryInterval =
      _exponentialBackoffRetryInterval +
      (0.5 * _exponentialBackoffRetryInterval * randomPlusMinusInterval);
  _exponentialBackoffThrottleEndTime =
      [[NSDate date] timeIntervalSince1970] + randomizedRetryInterval;
}

- (void)updateMetadataWithFetchSuccessStatus:(BOOL)fetchSuccess {
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000056", @"Updating metadata with fetch result.");
  if (!fetchSuccess) {
    [self updateExponentialBackoffTime];
  }

  [self updateFetchTimeWithSuccessFetch:fetchSuccess];
  _lastFetchStatus =
      fetchSuccess ? FIRRemoteConfigFetchStatusSuccess : FIRRemoteConfigFetchStatusFailure;
  _lastFetchError = fetchSuccess ? FIRRemoteConfigErrorUnknown : FIRRemoteConfigErrorInternalError;
  if (fetchSuccess) {
    [self updateLastFetchTimeInterval:[[NSDate date] timeIntervalSince1970]];
    // Note: We expect the googleAppID to always be available.
    _deviceContext = FIRRemoteConfigDeviceContextWithProjectIdentifier(_googleAppID);
  }

  [self updateMetadataTable];
}

- (void)updateFetchTimeWithSuccessFetch:(BOOL)isSuccessfulFetch {
  NSTimeInterval epochTimeInterval = [[NSDate date] timeIntervalSince1970];
  if (isSuccessfulFetch) {
    [_successFetchTimes addObject:@(epochTimeInterval)];
  } else {
    [_failureFetchTimes addObject:@(epochTimeInterval)];
  }
}

- (void)updateMetadataTable {
  [_DBManager deleteRecordWithBundleIdentifier:_bundleIdentifier isInternalDB:NO];
  NSError *error;
  // Objects to be serialized cannot be invalid.
  if (!_bundleIdentifier) {
    return;
  }
  if (![NSJSONSerialization isValidJSONObject:_customVariables]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000028",
                @"Invalid custom variables to be serialized.");
    return;
  }
  if (![NSJSONSerialization isValidJSONObject:_deviceContext]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000029",
                @"Invalid device context to be serialized.");
    return;
  }

  if (![NSJSONSerialization isValidJSONObject:_successFetchTimes]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000031",
                @"Invalid success fetch times to be serialized.");
    return;
  }
  if (![NSJSONSerialization isValidJSONObject:_failureFetchTimes]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000032",
                @"Invalid failure fetch times to be serialized.");
    return;
  }
  NSData *serializedAppContext = [NSJSONSerialization dataWithJSONObject:_customVariables
                                                                 options:NSJSONWritingPrettyPrinted
                                                                   error:&error];
  NSData *serializedDeviceContext =
      [NSJSONSerialization dataWithJSONObject:_deviceContext
                                      options:NSJSONWritingPrettyPrinted
                                        error:&error];
  // The digestPerNamespace is not used and only meant for backwards DB compatibility.
  NSData *serializedDigestPerNamespace =
      [NSJSONSerialization dataWithJSONObject:@{} options:NSJSONWritingPrettyPrinted error:&error];
  NSData *serializedSuccessTime = [NSJSONSerialization dataWithJSONObject:_successFetchTimes
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];
  NSData *serializedFailureTime = [NSJSONSerialization dataWithJSONObject:_failureFetchTimes
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];

  if (!serializedDigestPerNamespace || !serializedDeviceContext || !serializedAppContext ||
      !serializedSuccessTime || !serializedFailureTime) {
    return;
  }

  NSDictionary *columnNameToValue = @{
    RCNKeyBundleIdentifier : _bundleIdentifier,
    RCNKeyFetchTime : @(self.lastFetchTimeInterval),
    RCNKeyDigestPerNamespace : serializedDigestPerNamespace,
    RCNKeyDeviceContext : serializedDeviceContext,
    RCNKeyAppContext : serializedAppContext,
    RCNKeySuccessFetchTime : serializedSuccessTime,
    RCNKeyFailureFetchTime : serializedFailureTime,
    RCNKeyLastFetchStatus : [NSString stringWithFormat:@"%ld", (long)_lastFetchStatus],
    RCNKeyLastFetchError : [NSString stringWithFormat:@"%ld", (long)_lastFetchError],
    RCNKeyLastApplyTime : @(_lastApplyTimeInterval),
    RCNKeyLastSetDefaultsTime : @(_lastSetDefaultsTimeInterval)
  };

  [_DBManager insertMetadataTableWithValues:columnNameToValue completionHandler:nil];
}

#pragma mark - fetch request

/// Returns a fetch request with the latest device and config change.
/// Whenever user issues a fetch api call, collect the latest request.
- (NSString *)nextRequestWithUserProperties:(NSDictionary *)userProperties {
  // Note: We only set user properties as mentioned in the new REST API Design doc
  NSString *ret = [NSString stringWithFormat:@"{"];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@"app_instance_id:'%@'",
                                                                _configInstallationsIdentifier]];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", app_instance_id_token:'%@'",
                                                                _configInstallationsToken]];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", app_id:'%@'", _googleAppID]];

  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", country_code:'%@'",
                                                                FIRRemoteConfigDeviceCountry()]];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", language_code:'%@'",
                                                                FIRRemoteConfigDeviceLocale()]];
  ret = [ret
      stringByAppendingString:[NSString stringWithFormat:@", platform_version:'%@'",
                                                         [GULAppEnvironmentUtil systemVersion]]];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", time_zone:'%@'",
                                                                FIRRemoteConfigTimezone()]];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", package_name:'%@'",
                                                                _bundleIdentifier]];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", app_version:'%@'",
                                                                FIRRemoteConfigAppVersion()]];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", app_build:'%@'",
                                                                FIRRemoteConfigAppBuildVersion()]];
  ret = [ret stringByAppendingString:[NSString stringWithFormat:@", sdk_version:'%@'",
                                                                FIRRemoteConfigPodVersion()]];

  if (userProperties && userProperties.count > 0) {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userProperties
                                                       options:0
                                                         error:&error];
    if (!error) {
      ret = [ret
          stringByAppendingString:[NSString
                                      stringWithFormat:@", analytics_user_properties:%@",
                                                       [[NSString alloc]
                                                           initWithData:jsonData
                                                               encoding:NSUTF8StringEncoding]]];
    }
  }
  ret = [ret stringByAppendingString:@"}"];
  return ret;
}

#pragma mark - getter/setter

- (void)setLastFetchError:(FIRRemoteConfigError)lastFetchError {
  if (_lastFetchError != lastFetchError) {
    _lastFetchError = lastFetchError;
    [_DBManager updateMetadataWithOption:RCNUpdateOptionFetchStatus
                                  values:@[ @(_lastFetchStatus), @(_lastFetchError) ]
                       completionHandler:nil];
  }
}

- (NSArray *)successFetchTimes {
  return [_successFetchTimes copy];
}

- (NSArray *)failureFetchTimes {
  return [_failureFetchTimes copy];
}

- (NSDictionary *)customVariables {
  return [_customVariables copy];
}

- (NSDictionary *)internalMetadata {
  return [_internalMetadata copy];
}

- (NSDictionary *)deviceContext {
  return [_deviceContext copy];
}

- (void)setCustomVariables:(NSDictionary *)customVariables {
  _customVariables = [[NSMutableDictionary alloc] initWithDictionary:customVariables];
  [self updateMetadataTable];
}

- (void)setMinimumFetchInterval:(NSTimeInterval)minimumFetchInterval {
  if (minimumFetchInterval < 0) {
    _minimumFetchInterval = 0;
  } else {
    _minimumFetchInterval = minimumFetchInterval;
  }
}

- (void)setFetchTimeout:(NSTimeInterval)fetchTimeout {
  if (fetchTimeout <= 0) {
    _fetchTimeout = RCNHTTPDefaultConnectionTimeout;
  } else {
    _fetchTimeout = fetchTimeout;
  }
}

- (void)setLastApplyTimeInterval:(NSTimeInterval)lastApplyTimestamp {
  _lastApplyTimeInterval = lastApplyTimestamp;
  [_DBManager updateMetadataWithOption:RCNUpdateOptionApplyTime
                                values:@[ @(lastApplyTimestamp) ]
                     completionHandler:nil];
}

- (void)setLastSetDefaultsTimeInterval:(NSTimeInterval)lastSetDefaultsTimestamp {
  _lastSetDefaultsTimeInterval = lastSetDefaultsTimestamp;
  [_DBManager updateMetadataWithOption:RCNUpdateOptionDefaultTime
                                values:@[ @(lastSetDefaultsTimestamp) ]
                     completionHandler:nil];
}

#pragma mark Throttling

- (BOOL)hasMinimumFetchIntervalElapsed:(NSTimeInterval)minimumFetchInterval {
  if (self.lastFetchTimeInterval == 0) return YES;

  // Check if last config fetch is within minimum fetch interval in seconds.
  NSTimeInterval diffInSeconds = [[NSDate date] timeIntervalSince1970] - self.lastFetchTimeInterval;
  return diffInSeconds > minimumFetchInterval;
}

- (BOOL)shouldThrottle {
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  return ((self.lastFetchTimeInterval > 0) &&
          (_lastFetchStatus != FIRRemoteConfigFetchStatusSuccess) &&
          (_exponentialBackoffThrottleEndTime - now > 0));
}

@end
