// Copyright 2020 Google LLC
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

#import <GoogleUtilities/GULUserDefaults.h>

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"

#import "FirebasePerformance/Sources/FPRConsoleLogger.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#define ONE_DAY_SECONDS 24 * 60 * 60

static NSDate *FPRAppStartTime = nil;

typedef NS_ENUM(NSInteger, FPRConfigValueType) {
  // Config value type String.
  FPRConfigValueTypeString,
  // Config value type Bool.
  FPRConfigValueTypeBool,
  // Config value type Integer.
  FPRConfigValueTypeInteger,
  // Config value type Float.
  FPRConfigValueTypeFloat,
};

@interface FPRRemoteConfigFlags ()

/** @brief Represents if a fetch is currently in progress. */
@property(atomic) BOOL fetchInProgress;

/** @brief Dictionary of different config keys and value types. */
@property(nonatomic) NSDictionary<NSString *, NSNumber *> *configKeys;

/** @brief Last time the configs were cached. */
@property(nonatomic) NSDate *lastCachedTime;

@end

@implementation FPRRemoteConfigFlags

+ (void)load {
  FPRAppStartTime = [NSDate date];
}

+ (nullable instancetype)sharedInstance {
  static FPRRemoteConfigFlags *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfigWithFIRNamespace:@"fireperf"
                                                                    app:[FIRApp defaultApp]];
    instance = [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:rc];
  });
  return instance;
}

- (instancetype)initWithRemoteConfig:(FIRRemoteConfig *)config {
  self = [super init];
  if (self) {
    _fprRemoteConfig = config;
    _userDefaults = [FPRConfigurations sharedInstance].userDefaults;
    self.fetchInProgress = NO;

    // Set the overall delay to 5+random(25) making the config fetch delay at a max of 30 seconds
    self.applicationStartTime = FPRAppStartTime;
    self.appStartConfigFetchDelayInSeconds =
        kFPRMinAppStartConfigFetchDelayInSeconds + arc4random_uniform(25);

    NSMutableDictionary<NSString *, NSNumber *> *keysToCache =
        [[NSMutableDictionary<NSString *, NSNumber *> alloc] init];
    [keysToCache setObject:@(FPRConfigValueTypeInteger) forKey:@"fpr_log_source"];
    [keysToCache setObject:@(FPRConfigValueTypeBool) forKey:@"fpr_enabled"];
    [keysToCache setObject:@(FPRConfigValueTypeString) forKey:@"fpr_disabled_ios_versions"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger) forKey:@"fpr_rl_time_limit_sec"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger) forKey:@"fpr_rl_trace_event_count_fg"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger) forKey:@"fpr_rl_trace_event_count_bg"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger)
                    forKey:@"fpr_rl_network_request_event_count_fg"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger)
                    forKey:@"fpr_rl_network_request_event_count_bg"];
    [keysToCache setObject:@(FPRConfigValueTypeFloat) forKey:@"fpr_vc_trace_sampling_rate"];
    [keysToCache setObject:@(FPRConfigValueTypeFloat)
                    forKey:@"fpr_vc_network_request_sampling_rate"];
    [keysToCache setObject:@(FPRConfigValueTypeFloat) forKey:@"fpr_vc_session_sampling_rate"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger)
                    forKey:@"fpr_session_gauge_cpu_capture_frequency_fg_ms"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger)
                    forKey:@"fpr_session_gauge_cpu_capture_frequency_bg_ms"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger)
                    forKey:@"fpr_session_gauge_memory_capture_frequency_fg_ms"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger)
                    forKey:@"fpr_session_gauge_memory_capture_frequency_bg_ms"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger) forKey:@"fpr_session_max_duration_min"];
    [keysToCache setObject:@(FPRConfigValueTypeInteger) forKey:@"fpr_prewarm_detection"];
    self.configKeys = [keysToCache copy];

    [self update];
  }
  return self;
}

- (void)update {
  // If a fetch is already happening, do not attempt a fetch.
  if (self.fetchInProgress) {
    return;
  }

  NSTimeInterval timeIntervalSinceLastFetch =
      [self.fprRemoteConfig.lastFetchTime timeIntervalSinceNow];
  NSTimeInterval timeSinceAppStart = [self.applicationStartTime timeIntervalSinceNow];
  if ((ABS(timeSinceAppStart) > self.appStartConfigFetchDelayInSeconds) &&
      (!self.fprRemoteConfig.lastFetchTime ||
       ABS(timeIntervalSinceLastFetch) > kFPRConfigFetchIntervalInSeconds)) {
    self.fetchInProgress = YES;
    [self.fprRemoteConfig
        fetchAndActivateWithCompletionHandler:^(FIRRemoteConfigFetchAndActivateStatus status,
                                                NSError *_Nullable error) {
          self.lastFetchStatus = self.fprRemoteConfig.lastFetchStatus;
          if (status == FIRRemoteConfigFetchAndActivateStatusError) {
            FPRLogError(kFPRConfigurationFetchFailure, @"Unable to fetch configurations.");
          } else {
            self.lastFetchedTime = self.fprRemoteConfig.lastFetchTime;
            // If a fetch was successful,
            // 1. Clear the old cache
            [self resetCache];
            // 2. Cache the new config values
            [self cacheConfigValues];
          }
          self.fetchInProgress = NO;
        }];
  } else if (self.fprRemoteConfig.lastFetchTime) {
    // Update the last fetched time to know that remote config fetch has happened in the past.
    self.lastFetchedTime = self.fprRemoteConfig.lastFetchTime;
  }
}

#pragma mark - Util methods.

- (void)resetCache {
  [self.configKeys
      enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *valueType, BOOL *stop) {
        NSString *cacheKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, key];
        [self.userDefaults removeObjectForKey:cacheKey];
      }];
}

- (void)cacheConfigValues {
  [self.configKeys
      enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *valueType, BOOL *stop) {
        FIRRemoteConfigValue *rcValue = [self.fprRemoteConfig configValueForKey:key];

        // Cache only values that comes from remote.
        if (rcValue != nil && rcValue.source == FIRRemoteConfigSourceRemote) {
          FPRConfigValueType configValueType = [valueType integerValue];
          NSString *cacheKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, key];

          if (configValueType == FPRConfigValueTypeInteger) {
            NSInteger integerValue = [[rcValue numberValue] integerValue];
            [self.userDefaults setInteger:integerValue forKey:cacheKey];
          } else if (configValueType == FPRConfigValueTypeFloat) {
            float floatValue = [[rcValue numberValue] floatValue];
            [self.userDefaults setFloat:floatValue forKey:cacheKey];
          } else if (configValueType == FPRConfigValueTypeBool) {
            BOOL boolValue = [rcValue boolValue];
            [self.userDefaults setBool:boolValue forKey:cacheKey];
          } else if (configValueType == FPRConfigValueTypeString) {
            NSString *stringValue = [rcValue stringValue];
            [self.userDefaults setObject:stringValue forKey:cacheKey];
          }

          self.lastCachedTime = [NSDate date];
        }
      }];
}

- (id)cachedValueForConfigFlag:(NSString *)configFlag {
  // If the cached value is too old, return nil.
  if (ABS([self.lastFetchedTime timeIntervalSinceNow]) > 7 * ONE_DAY_SECONDS) {
    return nil;
  }

  NSString *cacheKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, configFlag];
  id cachedValueObject = [self.userDefaults objectForKey:cacheKey];
  return cachedValueObject;
}

#pragma mark - Config value fetch methods.

- (NSString *)getStringValueForFlag:(NSString *)flagName defaultValue:(NSString *)defaultValue {
  id cachedValueObject = [self cachedValueForConfigFlag:flagName];
  if ([cachedValueObject isKindOfClass:[NSString class]]) {
    return (NSString *)cachedValueObject;
  }

  return defaultValue;
}

- (int)getIntValueForFlag:(NSString *)flagName defaultValue:(int)defaultValue {
  id cachedValueObject = [self cachedValueForConfigFlag:flagName];
  if (cachedValueObject) {
    return [cachedValueObject intValue];
  }

  return defaultValue;
}

- (float)getFloatValueForFlag:(NSString *)flagName defaultValue:(float)defaultValue {
  id cachedValueObject = [self cachedValueForConfigFlag:flagName];
  if (cachedValueObject) {
    return [cachedValueObject floatValue];
  }

  return defaultValue;
}

- (BOOL)getBoolValueForFlag:(NSString *)flagName defaultValue:(BOOL)defaultValue {
  id cachedValueObject = [self cachedValueForConfigFlag:flagName];
  if (cachedValueObject) {
    return [cachedValueObject boolValue];
  }

  return defaultValue;
}

#pragma mark - Configuration methods.

- (int)logSourceWithDefaultValue:(int)logSource {
  return [self getIntValueForFlag:@"fpr_log_source" defaultValue:logSource];
}

- (BOOL)performanceSDKEnabledWithDefaultValue:(BOOL)sdkEnabled {
  /* Order of preference:
   * 1. If remote config fetch was a failure, return NO.
   * 2. If the fetch was successful, but RC does not have the value (not a remote value),
   *    return YES.
   * 3. Else, use the value from RC.
   */

  if (self.lastFetchStatus == FIRRemoteConfigFetchStatusFailure) {
    return NO;
  }

  return [self getBoolValueForFlag:@"fpr_enabled" defaultValue:sdkEnabled];
}

- (NSSet<NSString *> *)sdkDisabledVersionsWithDefaultValue:(NSSet<NSString *> *)sdkVersions {
  NSMutableSet<NSString *> *disabledVersions = [[NSMutableSet<NSString *> alloc] init];

  NSString *sdkVersionsString = [[self getStringValueForFlag:@"fpr_disabled_ios_versions"
                                                defaultValue:@""]
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if (sdkVersionsString.length > 0) {
    NSArray<NSString *> *sdkVersionStrings = [sdkVersionsString componentsSeparatedByString:@";"];
    for (NSString *sdkVersionString in sdkVersionStrings) {
      NSString *trimmedString = [sdkVersionString
          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      if (trimmedString.length > 0) {
        [disabledVersions addObject:trimmedString];
      }
    }
  } else {
    return sdkVersions;
  }

  return [disabledVersions copy];
}

#pragma mark - Rate limiting flags

- (int)rateLimitTimeDurationWithDefaultValue:(int)durationInSeconds {
  return [self getIntValueForFlag:@"fpr_rl_time_limit_sec" defaultValue:durationInSeconds];
}

- (int)rateLimitTraceCountInForegroundWithDefaultValue:(int)eventCount {
  return [self getIntValueForFlag:@"fpr_rl_trace_event_count_fg" defaultValue:eventCount];
}

- (int)rateLimitTraceCountInBackgroundWithDefaultValue:(int)eventCount {
  return [self getIntValueForFlag:@"fpr_rl_trace_event_count_bg" defaultValue:eventCount];
}

- (int)rateLimitNetworkRequestCountInForegroundWithDefaultValue:(int)eventCount {
  return [self getIntValueForFlag:@"fpr_rl_network_request_event_count_fg" defaultValue:eventCount];
}

- (int)rateLimitNetworkRequestCountInBackgroundWithDefaultValue:(int)eventCount {
  return [self getIntValueForFlag:@"fpr_rl_network_request_event_count_bg" defaultValue:eventCount];
}

#pragma mark - Sampling flags

- (float)traceSamplingRateWithDefaultValue:(float)samplingRate {
  return [self getFloatValueForFlag:@"fpr_vc_trace_sampling_rate" defaultValue:samplingRate];
}

- (float)networkRequestSamplingRateWithDefaultValue:(float)samplingRate {
  return [self getFloatValueForFlag:@"fpr_vc_network_request_sampling_rate"
                       defaultValue:samplingRate];
}

#pragma mark - Session flags

- (float)sessionSamplingRateWithDefaultValue:(float)samplingRate {
  return [self getFloatValueForFlag:@"fpr_vc_session_sampling_rate" defaultValue:samplingRate];
}

- (int)sessionGaugeCPUCaptureFrequencyInForegroundWithDefaultValue:(int)defaultFrequency {
  return [self getIntValueForFlag:@"fpr_session_gauge_cpu_capture_frequency_fg_ms"
                     defaultValue:defaultFrequency];
}

- (int)sessionGaugeCPUCaptureFrequencyInBackgroundWithDefaultValue:(int)defaultFrequency {
  return [self getIntValueForFlag:@"fpr_session_gauge_cpu_capture_frequency_bg_ms"
                     defaultValue:defaultFrequency];
}

- (int)sessionGaugeMemoryCaptureFrequencyInForegroundWithDefaultValue:(int)defaultFrequency {
  return [self getIntValueForFlag:@"fpr_session_gauge_memory_capture_frequency_fg_ms"
                     defaultValue:defaultFrequency];
}

- (int)sessionGaugeMemoryCaptureFrequencyInBackgroundWithDefaultValue:(int)defaultFrequency {
  return [self getIntValueForFlag:@"fpr_session_gauge_memory_capture_frequency_bg_ms"
                     defaultValue:defaultFrequency];
}

- (int)sessionMaxDurationWithDefaultValue:(int)maxDurationInMinutes {
  return [self getIntValueForFlag:@"fpr_session_max_duration_min"
                     defaultValue:maxDurationInMinutes];
}

@end
