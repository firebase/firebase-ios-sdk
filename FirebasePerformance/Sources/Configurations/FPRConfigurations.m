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

#import <UIKit/UIKit.h>

#import <GoogleUtilities/GULUserDefaults.h>

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

FPRConfigName kFPRConfigDataCollectionEnabled = @"dataCollectionEnabled";

FPRConfigName kFPRConfigInstrumentationEnabled = @"instrumentationEnabled";

NSString *const kFPRConfigInstrumentationUserPreference =
    @"com.firebase.performanceInsrumentationEnabled";
NSString *const kFPRConfigInstrumentationPlistKey = @"firebase_performance_instrumentation_enabled";

NSString *const kFPRConfigCollectionUserPreference = @"com.firebase.performanceCollectionEnabled";
NSString *const kFPRConfigCollectionPlistKey = @"firebase_performance_collection_enabled";

NSString *const kFPRDiagnosticsUserPreference = @"FPRDiagnosticsLocal";
NSString *const kFPRDiagnosticsEnabledPlistKey = @"FPRDiagnosticsLocal";

NSString *const kFPRConfigCollectionDeactivationPlistKey =
    @"firebase_performance_collection_deactivated";

NSString *const kFPRConfigLogSource = @"com.firebase.performanceLogSource";

@implementation FPRConfigurations

static dispatch_once_t gSharedInstanceToken;

+ (instancetype)sharedInstance {
  static FPRConfigurations *instance = nil;
  dispatch_once(&gSharedInstanceToken, ^{
    FPRConfigurationSource sources = FPRConfigurationSourceRemoteConfig;
    instance = [[FPRConfigurations alloc] initWithSources:sources];
  });
  return instance;
}

+ (void)reset {
  // TODO(b/120032990): Reset the singletons that this singleton uses.
  gSharedInstanceToken = 0;
  [[GULUserDefaults standardUserDefaults]
      removeObjectForKey:kFPRConfigInstrumentationUserPreference];
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kFPRConfigCollectionUserPreference];
}

- (instancetype)initWithSources:(FPRConfigurationSource)source {
  self = [super init];
  if (self) {
    _sources = source;
    [self setupRemoteConfigFlags];

    // Register for notifications to update configs.
    [self registerForNotifications];

    self.FIRAppClass = [FIRApp class];
    self.userDefaults = [GULUserDefaults standardUserDefaults];
    self.infoDictionary = [NSBundle mainBundle].infoDictionary;
    self.mainBundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
    self.updateQueue = dispatch_queue_create("com.google.perf.configUpdate", DISPATCH_QUEUE_SERIAL);
  }

  return self;
}

- (void)registerForNotifications {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(update)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
}

/** Searches the main bundle and the bundle from bundleForClass: info dictionaries for the key and
 *  returns the first result.
 *
 * @param key The key to search the info dictionaries for.
 * @return The first object found in the info dictionary of the main bundle and bundleForClass:.
 */
- (nullable id)objectForInfoDictionaryKey:(NSString *)key {
  // If the config infoDictionary has been set to a new dictionary, only use the original dictionary
  // instead of the new dictionary.
  if (self.infoDictionary != [NSBundle mainBundle].infoDictionary) {
    return self.infoDictionary[key];  // nullable.
  }
  NSArray<NSBundle *> *bundles = @[ [NSBundle mainBundle], [NSBundle bundleForClass:[self class]] ];
  for (NSBundle *bundle in bundles) {
    id object = [bundle objectForInfoDictionaryKey:key];
    if (object) {
      return object;  // nonnull.
    }
  }
  return nil;
}

- (void)update {
  dispatch_async(self.updateQueue, ^{
    if (!self.remoteConfigFlags) {
      [self setupRemoteConfigFlags];
    }
    [self.remoteConfigFlags update];
  });
}

/**
 * Sets up the remote config flags instance based on 3 different factors:
 * 1. Is the firebase app configured?
 * 2. Is the remote config source enabled?
 * 3. If the Remote Config flags instance exists already?
 */
- (void)setupRemoteConfigFlags {
  if (!self.remoteConfigFlags && [self.FIRAppClass isDefaultAppConfigured] &&
      (self.sources & FPRConfigurationSourceRemoteConfig) == FPRConfigurationSourceRemoteConfig) {
    self.remoteConfigFlags = [FPRRemoteConfigFlags sharedInstance];
  }
}

#pragma mark - Overridden Properties

- (void)setDataCollectionEnabled:(BOOL)dataCollectionEnabled {
  [self.userDefaults setBool:dataCollectionEnabled forKey:kFPRConfigCollectionUserPreference];
}

// The data collection flag is determined by this order:
//   1. A plist flag for permanently disabling data collection
//   2. The runtime flag (GULUserDefaults)
//   3. A plist flag for enabling/disabling (overridable)
//   4. The global data collection switch from Core.
- (BOOL)isDataCollectionEnabled {
  /**
   * Perf only works with the default app, so validate it exists then use the value from the global
   * data collection from the default app as the base value if no other values are set.
   */
  if (![self.FIRAppClass isDefaultAppConfigured]) {
    return NO;
  }

  BOOL dataCollectionPreference = [self.FIRAppClass defaultApp].isDataCollectionDefaultEnabled;

  // Check if data collection is permanently disabled by plist. If so, disable data collection.
  id dataCollectionDeactivationObject =
      [self objectForInfoDictionaryKey:kFPRConfigCollectionDeactivationPlistKey];
  if (dataCollectionDeactivationObject) {
    BOOL dataCollectionDeactivated = [dataCollectionDeactivationObject boolValue];
    if (dataCollectionDeactivated) {
      return NO;
    }
  }
  /**
   * Check if the performance collection preference key is available in GULUserDefaults.
   * If it exists - Just honor that and return that value.
   * If it does not exist - Check if firebase_performance_collection_enabled exists in Info.plist.
   * If it exists - honor that and return that value.
   * If not - return YES stating performance collection is enabled.
   */
  id dataCollectionPreferenceObject =
      [self.userDefaults objectForKey:kFPRConfigCollectionUserPreference];
  if (dataCollectionPreferenceObject) {
    dataCollectionPreference = [dataCollectionPreferenceObject boolValue];
  } else {
    dataCollectionPreferenceObject = [self objectForInfoDictionaryKey:kFPRConfigCollectionPlistKey];
    if (dataCollectionPreferenceObject) {
      dataCollectionPreference = [dataCollectionPreferenceObject boolValue];
    }
  }

  return dataCollectionPreference;
}

- (void)setInstrumentationEnabled:(BOOL)instrumentationEnabled {
  [self.userDefaults setBool:instrumentationEnabled forKey:kFPRConfigInstrumentationUserPreference];
}

- (BOOL)isInstrumentationEnabled {
  BOOL instrumentationPreference = YES;

  id instrumentationPreferenceObject =
      [self.userDefaults objectForKey:kFPRConfigInstrumentationUserPreference];

  /**
   * Check if the performance instrumentation preference key is available in GULUserDefaults.
   * If it exists - Just honor that and return that value.
   * If not - Check if firebase_performance_instrumentation_enabled exists in Info.plist.
   * If it exists - honor that and return that value.
   * If not - return YES stating performance instrumentation is enabled.
   */
  if (instrumentationPreferenceObject) {
    instrumentationPreference = [instrumentationPreferenceObject boolValue];
  } else {
    instrumentationPreferenceObject =
        [self objectForInfoDictionaryKey:kFPRConfigInstrumentationPlistKey];
    if (instrumentationPreferenceObject) {
      instrumentationPreference = [instrumentationPreferenceObject boolValue];
    }
  }

  return instrumentationPreference;
}

#pragma mark - Fireperf SDK configurations.

- (BOOL)sdkEnabled {
  BOOL enabled = YES;
  if (self.remoteConfigFlags) {
    enabled = [self.remoteConfigFlags performanceSDKEnabledWithDefaultValue:enabled];
  }

  // Check if the current version is one of the disabled versions.
  if ([[self sdkDisabledVersions] containsObject:[NSString stringWithUTF8String:kFPRSDKVersion]]) {
    enabled = NO;
  }

  // If there is a plist override, honor that value.
  // NOTE: PList override should ideally be used only for tests and not for production.
  id plistObject = [self objectForInfoDictionaryKey:@"firebase_performance_sdk_enabled"];
  if (plistObject) {
    enabled = [plistObject boolValue];
  }

  return enabled;
}

- (BOOL)diagnosticsEnabled {
  BOOL enabled = NO;

  /**
   * Check if the diagnostics preference key is available in GULUserDefaults.
   * If it exists - Just honor that and return that value.
   * If not - Check if firebase_performance_instrumentation_enabled exists in Info.plist.
   * If it exists - honor that and return that value.
   * If not - return NO stating diagnostics is disabled.
   */
  id diagnosticsEnabledPreferenceObject =
      [self.userDefaults objectForKey:kFPRDiagnosticsUserPreference];

  if (diagnosticsEnabledPreferenceObject) {
    enabled = [diagnosticsEnabledPreferenceObject boolValue];
  } else {
    id diagnosticsEnabledObject = [self objectForInfoDictionaryKey:kFPRDiagnosticsEnabledPlistKey];
    if (diagnosticsEnabledObject) {
      enabled = [diagnosticsEnabledObject boolValue];
    }
  }

  return enabled;
}

- (NSSet<NSString *> *)sdkDisabledVersions {
  NSMutableSet<NSString *> *disabledVersions = [[NSMutableSet<NSString *> alloc] init];

  if (self.remoteConfigFlags) {
    NSSet<NSString *> *sdkDisabledVersions =
        [self.remoteConfigFlags sdkDisabledVersionsWithDefaultValue:[disabledVersions copy]];
    if (sdkDisabledVersions.count > 0) {
      [disabledVersions addObjectsFromArray:[sdkDisabledVersions allObjects]];
    }
  }

  return [disabledVersions copy];
}

- (int)logSource {
  /**
   * Order of preference of returning the log source.
   * If it is an autopush build (based on environment variable), always return
   * LogRequest_LogSource_FireperfAutopush (461). If there is a recent value of remote config fetch,
   * honor that value. If logSource cached value (GULUserDefaults value) exists, honor that.
   * Fallback to the default value LogRequest_LogSource_Fireperf (462).
   */
  int logSource = 462;

  NSDictionary<NSString *, NSString *> *environment = [NSProcessInfo processInfo].environment;
  if (environment[@"FPR_AUTOPUSH_ENV"] != nil &&
      [environment[@"FPR_AUTOPUSH_ENV"] isEqualToString:@"1"]) {
    logSource = 461;
  } else {
    if (self.remoteConfigFlags) {
      logSource = [self.remoteConfigFlags logSourceWithDefaultValue:462];
    }
  }

  return logSource;
}

- (PrewarmDetectionMode)prewarmDetectionMode {
  PrewarmDetectionMode mode = PrewarmDetectionModeActivePrewarm;
  if (self.remoteConfigFlags) {
    mode = [self.remoteConfigFlags getIntValueForFlag:@"fpr_prewarm_detection"
                                         defaultValue:(int)mode];
  }
  return mode;
}

#pragma mark - Log sampling configurations.

- (float)logTraceSamplingRate {
  float samplingRate = 1.0f;
  if (self.remoteConfigFlags) {
    float rcSamplingRate = [self.remoteConfigFlags traceSamplingRateWithDefaultValue:samplingRate];
    if (rcSamplingRate >= 0) {
      samplingRate = rcSamplingRate;
    }
  }
  return samplingRate;
}

- (float)logNetworkSamplingRate {
  float samplingRate = 1.0f;
  if (self.remoteConfigFlags) {
    float rcSamplingRate =
        [self.remoteConfigFlags networkRequestSamplingRateWithDefaultValue:samplingRate];
    if (rcSamplingRate >= 0) {
      samplingRate = rcSamplingRate;
    }
  }
  return samplingRate;
}

#pragma mark - Traces rate limiting configurations.

- (uint32_t)foregroundEventCount {
  uint32_t eventCount = 300;
  if (self.remoteConfigFlags) {
    eventCount =
        [self.remoteConfigFlags rateLimitTraceCountInForegroundWithDefaultValue:eventCount];
  }
  return eventCount;
}

- (uint32_t)foregroundEventTimeLimit {
  uint32_t timeLimit = 600;
  if (self.remoteConfigFlags) {
    timeLimit = [self.remoteConfigFlags rateLimitTimeDurationWithDefaultValue:timeLimit];
  }

  uint32_t timeLimitInMinutes = timeLimit / 60;
  return timeLimitInMinutes;
}

- (uint32_t)backgroundEventCount {
  uint32_t eventCount = 30;
  if (self.remoteConfigFlags) {
    eventCount =
        [self.remoteConfigFlags rateLimitTraceCountInBackgroundWithDefaultValue:eventCount];
  }
  return eventCount;
}

- (uint32_t)backgroundEventTimeLimit {
  uint32_t timeLimit = 600;
  if (self.remoteConfigFlags) {
    timeLimit = [self.remoteConfigFlags rateLimitTimeDurationWithDefaultValue:timeLimit];
  }

  uint32_t timeLimitInMinutes = timeLimit / 60;
  return timeLimitInMinutes;
}

#pragma mark - Network requests rate limiting configurations.

- (uint32_t)foregroundNetworkEventCount {
  uint32_t eventCount = 700;
  if (self.remoteConfigFlags) {
    eventCount = [self.remoteConfigFlags
        rateLimitNetworkRequestCountInForegroundWithDefaultValue:eventCount];
  }
  return eventCount;
}

- (uint32_t)foregroundNetworkEventTimeLimit {
  uint32_t timeLimit = 600;
  if (self.remoteConfigFlags) {
    timeLimit = [self.remoteConfigFlags rateLimitTimeDurationWithDefaultValue:timeLimit];
  }

  uint32_t timeLimitInMinutes = timeLimit / 60;
  return timeLimitInMinutes;
}

- (uint32_t)backgroundNetworkEventCount {
  uint32_t eventCount = 70;
  if (self.remoteConfigFlags) {
    eventCount = [self.remoteConfigFlags
        rateLimitNetworkRequestCountInBackgroundWithDefaultValue:eventCount];
  }
  return eventCount;
}

- (uint32_t)backgroundNetworkEventTimeLimit {
  uint32_t timeLimit = 600;
  if (self.remoteConfigFlags) {
    timeLimit = [self.remoteConfigFlags rateLimitTimeDurationWithDefaultValue:timeLimit];
  }

  uint32_t timeLimitInMinutes = timeLimit / 60;
  return timeLimitInMinutes;
}

#pragma mark - Sessions feature related configurations.

- (float_t)sessionsSamplingPercentage {
  float samplingPercentage = 1.0f;  // One Percent.
  if (self.remoteConfigFlags) {
    float rcSamplingRate =
        [self.remoteConfigFlags sessionSamplingRateWithDefaultValue:(samplingPercentage / 100)];
    if (rcSamplingRate >= 0) {
      samplingPercentage = rcSamplingRate * 100;
    }
  }

  id plistObject = [self objectForInfoDictionaryKey:@"sessionsSamplingPercentage"];
  if (plistObject) {
    samplingPercentage = [plistObject floatValue];
  }
  return samplingPercentage;
}

- (uint32_t)maxSessionLengthInMinutes {
  uint32_t sessionLengthInMinutes = 240;
  if (self.remoteConfigFlags) {
    sessionLengthInMinutes =
        [self.remoteConfigFlags sessionMaxDurationWithDefaultValue:sessionLengthInMinutes];
  }

  // If the session max length gets set to 0, default it to 240 minutes.
  if (sessionLengthInMinutes == 0) {
    return 240;
  }
  return sessionLengthInMinutes;
}

- (uint32_t)cpuSamplingFrequencyInForegroundInMS {
  uint32_t samplingFrequency = 100;
  if (self.remoteConfigFlags) {
    samplingFrequency = [self.remoteConfigFlags
        sessionGaugeCPUCaptureFrequencyInForegroundWithDefaultValue:samplingFrequency];
  }
  return samplingFrequency;
}

- (uint32_t)cpuSamplingFrequencyInBackgroundInMS {
  uint32_t samplingFrequency = 0;
  if (self.remoteConfigFlags) {
    samplingFrequency = [self.remoteConfigFlags
        sessionGaugeCPUCaptureFrequencyInBackgroundWithDefaultValue:samplingFrequency];
  }
  return samplingFrequency;
}

- (uint32_t)memorySamplingFrequencyInForegroundInMS {
  uint32_t samplingFrequency = 100;
  if (self.remoteConfigFlags) {
    samplingFrequency = [self.remoteConfigFlags
        sessionGaugeMemoryCaptureFrequencyInForegroundWithDefaultValue:samplingFrequency];
  }
  return samplingFrequency;
}

- (uint32_t)memorySamplingFrequencyInBackgroundInMS {
  uint32_t samplingFrequency = 0;
  if (self.remoteConfigFlags) {
    samplingFrequency = [self.remoteConfigFlags
        sessionGaugeMemoryCaptureFrequencyInBackgroundWithDefaultValue:samplingFrequency];
  }
  return samplingFrequency;
}

@end
