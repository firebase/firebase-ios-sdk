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

#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"
#import "Crashlytics/Shared/FIRCLSConstants.h"
#import "Crashlytics/Shared/FIRCLSNetworking/FIRCLSURLBuilder.h"

NSString *const CreatedAtKey = @"created_at";
NSString *const GoogleAppIDKey = @"google_app_id";
NSString *const BuildInstanceID = @"build_instance_id";
NSString *const AppVersion = @"app_version";
NSString *const FirebaseCrashlyticsMachDefaultBehaviorKey =
    @"FirebaseCrashlyticsMachDefaultBehavior";

#pragma mark - Value Validation

// Settings are downloaded from the server, cached to disk and read early during launch, before
// Crashlytics can report crashes. Values with an unexpected type or range are ignored in favor of
// the defaults so that a malformed payload can't crash or misconfigure the SDK.

static NSDictionary<NSString *, id> *FIRCLSSettingsDictionaryValue(id value) {
  return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static BOOL FIRCLSSettingsBoolValue(id value, BOOL defaultValue) {
  if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
    return [value boolValue];
  }

  return defaultValue;
}

// Returns YES if the value is a finite, non-negative number.
static BOOL FIRCLSSettingsIsValidNumber(id value, NSString *key) {
  if (value == nil) {
    return NO;
  }

  if ([value isKindOfClass:[NSNumber class]]) {
    double doubleValue = [value doubleValue];
    if (isfinite(doubleValue) && doubleValue >= 0) {
      return YES;
    }
  }

  FIRCLSDebugLog(@"[Crashlytics:Settings] Ignoring invalid value for %@: %@", key, value);
  return NO;
}

static double FIRCLSSettingsDoubleValue(id value, NSString *key, double defaultValue) {
  if (!FIRCLSSettingsIsValidNumber(value, key)) {
    return defaultValue;
  }

  return [value doubleValue];
}

static uint32_t FIRCLSSettingsUInt32Value(id value, NSString *key, uint32_t defaultValue) {
  if (!FIRCLSSettingsIsValidNumber(value, key)) {
    return defaultValue;
  }

  // Clamp rather than truncate values that don't fit.
  if ([value doubleValue] >= UINT32_MAX) {
    return UINT32_MAX;
  }

  return [value unsignedIntValue];
}

@interface FIRCLSSettings ()

@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;

@property(nonatomic, strong) NSDictionary<NSString *, id> *settingsDictionary;

@property(nonatomic) BOOL isCacheKeyExpired;

@property(nonatomic) dispatch_queue_t deletionQueue;

@end

@implementation FIRCLSSettings

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                         appIDModel:(FIRCLSApplicationIdentifierModel *)appIDModel
                            appInfo:(NSDictionary *)appInfo {
  return
      [self initWithFileManager:fileManager
                     appIDModel:appIDModel
                        appInfo:appInfo
                  deletionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
}

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                         appIDModel:(FIRCLSApplicationIdentifierModel *)appIDModel
                            appInfo:(NSDictionary *)appInfo
                      deletionQueue:(dispatch_queue_t)deletionQueue {
  self = [super init];
  if (!self) {
    return nil;
  }

  // Configure the Mach exception message receiving behavior from Info.plist the mach exception
  // message receiving behavior
  self.machExceptionDefaultBehavior = false;
  id crashlyticsMachDefaultBehavior =
      [appInfo objectForKey:FirebaseCrashlyticsMachDefaultBehaviorKey];
  if ([crashlyticsMachDefaultBehavior isKindOfClass:[NSString class]] ||
      [crashlyticsMachDefaultBehavior isKindOfClass:[NSNumber class]]) {
    self.machExceptionDefaultBehavior = [crashlyticsMachDefaultBehavior boolValue];
  }

  _fileManager = fileManager;
  _appIDModel = appIDModel;

  _settingsDictionary = nil;
  _isCacheKeyExpired = NO;

  _deletionQueue = deletionQueue;

  return self;
}

#pragma mark - Public Methods

- (void)reloadFromCacheWithGoogleAppID:(NSString *)googleAppID
                      currentTimestamp:(NSTimeInterval)currentTimestamp {
  NSString *settingsFilePath = self.fileManager.settingsFilePath;

  NSData *data = [self.fileManager dataWithContentsOfFile:settingsFilePath];

  if (!data) {
    FIRCLSDebugLog(@"[Crashlytics:Settings] No settings were cached");

    return;
  }

  NSError *error = nil;
  id settingsObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

  if (![settingsObject isKindOfClass:[NSDictionary class]]) {
    if (settingsObject) {
      FIRCLSErrorLog(@"Settings file data is not a dictionary");
    } else {
      FIRCLSErrorLog(@"Could not load settings file data with error: %@",
                     error.localizedDescription);
    }

    // Attempt to remove it, in case it's messed up
    [self deleteCachedSettings];
    return;
  }

  @synchronized(self) {
    _settingsDictionary = settingsObject;
  }

  NSDictionary<NSString *, id> *cacheKey = [self loadCacheKey];
  if (!cacheKey) {
    FIRCLSErrorLog(@"Could not load settings cache key");

    [self deleteCachedSettings];
    return;
  }

  id cachedGoogleAppID = cacheKey[GoogleAppIDKey];
  if (![cachedGoogleAppID isKindOfClass:[NSString class]] ||
      ![cachedGoogleAppID isEqual:googleAppID]) {
    FIRCLSDebugLog(
        @"[Crashlytics:Settings] Invalidating settings cache because Google App ID changed");

    [self deleteCachedSettings];
    return;
  }

  id cacheCreatedAtValue = cacheKey[CreatedAtKey];
  NSTimeInterval cacheCreatedAt = [cacheCreatedAtValue isKindOfClass:[NSNumber class]]
                                      ? [cacheCreatedAtValue unsignedIntValue]
                                      : 0;
  NSTimeInterval cacheDurationSeconds = self.cacheDurationSeconds;
  if (currentTimestamp > (cacheCreatedAt + cacheDurationSeconds)) {
    FIRCLSDebugLog(@"[Crashlytics:Settings] Settings TTL expired");

    @synchronized(self) {
      self.isCacheKeyExpired = YES;
    }
  }

  id cacheBuildInstanceID = cacheKey[BuildInstanceID];
  if (![cacheBuildInstanceID isKindOfClass:[NSString class]] ||
      ![cacheBuildInstanceID isEqual:self.appIDModel.buildInstanceID]) {
    FIRCLSDebugLog(@"[Crashlytics:Settings] Settings expired because build instance changed");

    @synchronized(self) {
      self.isCacheKeyExpired = YES;
    }
  }

  id cacheAppVersion = cacheKey[AppVersion];
  if (![cacheAppVersion isKindOfClass:[NSString class]] ||
      ![cacheAppVersion isEqual:self.appIDModel.synthesizedVersion]) {
    FIRCLSDebugLog(@"[Crashlytics:Settings] Settings expired because app version changed");

    @synchronized(self) {
      self.isCacheKeyExpired = YES;
    }
  }
}

- (void)cacheSettingsWithGoogleAppID:(NSString *)googleAppID
                    currentTimestamp:(NSTimeInterval)currentTimestamp {
  NSNumber *createdAtTimestamp = [NSNumber numberWithDouble:currentTimestamp];
  NSDictionary *cacheKey = @{
    CreatedAtKey : createdAtTimestamp,
    GoogleAppIDKey : googleAppID,
    BuildInstanceID : self.appIDModel.buildInstanceID,
    AppVersion : self.appIDModel.synthesizedVersion,
  };

  NSError *error = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:cacheKey
                                                     options:kNilOptions
                                                       error:&error];

  if (!jsonData) {
    FIRCLSErrorLog(@"Could not create settings cache key with error: %@",
                   error.localizedDescription);

    return;
  }

  if ([self.fileManager fileExistsAtPath:self.fileManager.settingsCacheKeyPath]) {
    [self.fileManager removeItemAtPath:self.fileManager.settingsCacheKeyPath];
  }
  [self.fileManager createFileAtPath:self.fileManager.settingsCacheKeyPath
                            contents:jsonData
                          attributes:nil];

  // If Settings were expired before, they should no longer be expired after this.
  // This may be set back to YES if reloading from the cache fails
  @synchronized(self) {
    self.isCacheKeyExpired = NO;
  }

  [self reloadFromCacheWithGoogleAppID:googleAppID currentTimestamp:currentTimestamp];
}

#pragma mark - Convenience Methods

- (NSDictionary *)loadCacheKey {
  NSData *cacheKeyData =
      [self.fileManager dataWithContentsOfFile:self.fileManager.settingsCacheKeyPath];

  if (!cacheKeyData) {
    return nil;
  }

  NSError *error = nil;
  id cacheKey = [NSJSONSerialization JSONObjectWithData:cacheKeyData
                                                options:NSJSONReadingAllowFragments
                                                  error:&error];
  if (![cacheKey isKindOfClass:[NSDictionary class]]) {
    return nil;
  }

  return cacheKey;
}

- (void)deleteCachedSettings {
  __weak FIRCLSSettings *weakSelf = self;
  dispatch_async(_deletionQueue, ^{
    __strong FIRCLSSettings *strongSelf = weakSelf;
    if ([strongSelf.fileManager fileExistsAtPath:strongSelf.fileManager.settingsFilePath]) {
      [strongSelf.fileManager removeItemAtPath:strongSelf.fileManager.settingsFilePath];
    }
    if ([strongSelf.fileManager fileExistsAtPath:strongSelf.fileManager.settingsCacheKeyPath]) {
      [strongSelf.fileManager removeItemAtPath:strongSelf.fileManager.settingsCacheKeyPath];
    }
  });

  @synchronized(self) {
    self.isCacheKeyExpired = YES;
    _settingsDictionary = nil;
  }
}

- (NSDictionary<NSString *, id> *)settingsDictionary {
  @synchronized(self) {
    return _settingsDictionary;
  }
}

#pragma mark - Settings Groups

- (NSDictionary<NSString *, id> *)appSettings {
  return FIRCLSSettingsDictionaryValue(self.settingsDictionary[@"app"]);
}

- (NSDictionary<NSString *, id> *)sessionSettings {
  return FIRCLSSettingsDictionaryValue(self.settingsDictionary[@"session"]);
}

- (NSDictionary<NSString *, id> *)featuresSettings {
  return FIRCLSSettingsDictionaryValue(self.settingsDictionary[@"features"]);
}

- (NSDictionary<NSString *, id> *)fabricSettings {
  return FIRCLSSettingsDictionaryValue(self.settingsDictionary[@"fabric"]);
}

#pragma mark - Caching

- (BOOL)isCacheExpired {
  if (!self.settingsDictionary) {
    return YES;
  }

  @synchronized(self) {
    return self.isCacheKeyExpired;
  }
}

- (uint32_t)cacheDurationSeconds {
  id fetchedCacheDuration = self.settingsDictionary[@"cache_duration"];
  return FIRCLSSettingsUInt32Value(fetchedCacheDuration, @"cache_duration", 60 * 60);
}

#pragma mark - On / Off Switches

- (BOOL)errorReportingEnabled {
  return FIRCLSSettingsBoolValue([self featuresSettings][@"collect_logged_exceptions"], YES);
}

- (BOOL)customExceptionsEnabled {
  // Right now, recording custom exceptions from the API and
  // automatically capturing non-fatal errors go hand in hand
  return [self errorReportingEnabled];
}

- (BOOL)collectReportsEnabled {
  return FIRCLSSettingsBoolValue([self featuresSettings][@"collect_reports"], YES);
}

- (BOOL)metricKitCollectionEnabled {
  return FIRCLSSettingsBoolValue([self featuresSettings][@"collect_metric_kit"], NO);
}

#pragma mark - Optional Limit Overrides

- (uint32_t)errorLogBufferSize {
  return [self logBufferSize];
}

- (uint32_t)logBufferSize {
  return FIRCLSSettingsUInt32Value([self sessionSettings][@"log_buffer_size"], @"log_buffer_size",
                                   64 * 1000);
}

- (uint32_t)maxCustomExceptions {
  return FIRCLSSettingsUInt32Value([self sessionSettings][@"max_custom_exception_events"],
                                   @"max_custom_exception_events", 8);
}

- (uint32_t)maxCustomKeys {
  return FIRCLSSettingsUInt32Value([self sessionSettings][@"max_custom_key_value_pairs"],
                                   @"max_custom_key_value_pairs", 64);
}

#pragma mark - On Demand Reporting Parameters

- (double)onDemandUploadRate {
  return FIRCLSSettingsDoubleValue(self.settingsDictionary[@"on_demand_upload_rate_per_minute"],
                                   @"on_demand_upload_rate_per_minute",
                                   10);  // on-demand uploads allowed per minute
}

- (double)onDemandBackoffBase {
  return FIRCLSSettingsDoubleValue(self.settingsDictionary[@"on_demand_backoff_base"],
                                   @"on_demand_backoff_base",
                                   1.5);  // base of exponent for exponential backoff
}

- (uint32_t)onDemandBackoffStepDuration {
  uint32_t defaultValue = 6;  // step duration for exponential backoff
  uint32_t value =
      FIRCLSSettingsUInt32Value(self.settingsDictionary[@"on_demand_backoff_step_duration_seconds"],
                                @"on_demand_backoff_step_duration_seconds", defaultValue);

  // The step duration is used as a divisor when calculating the backoff, so it can't be zero.
  return value > 0 ? value : defaultValue;
}

- (BOOL)onDemandThreadSuspensionEnabled {
  return FIRCLSSettingsBoolValue(
      self.settingsDictionary[@"on_demand_thread_recording_suspension_enabled"], YES);
}
@end
