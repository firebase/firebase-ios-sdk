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

#import <XCTest/XCTest.h>

#import <GoogleUtilities/GULUserDefaults.h>

#import "FirebasePerformance/Sources/Common/FPRConstants.h"

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"

@interface FPRConfigurationsTest : XCTestCase

@end

@implementation FPRConfigurationsTest

- (GULUserDefaults *_Nonnull)makeEmptyUserDefaults {
  return [[GULUserDefaults alloc] init];
}

/** Validates if instance creation works. */
- (void)testInstanceCreation {
  XCTAssertNotNil([[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceNone]);
  XCTAssertNotNil([FPRConfigurations sharedInstance]);
}

/** Validates if singleton nature of the object works. */
- (void)testSingletonNature {
  XCTAssertEqualObjects([FPRConfigurations sharedInstance], [FPRConfigurations sharedInstance]);
}

/** Validates for the default value for the configurations. */
- (void)testDefaultValuesOfConfigs {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceNone];

#if defined(FPR_AUTOPUSH_ENDPOINT)
  XCTAssertEqual([configurations logSource], 461);
#else
  XCTAssertEqual([configurations logSource], 462);
#endif

  XCTAssertEqual([configurations diagnosticsEnabled], NO);
  XCTAssertEqual([configurations logTraceSamplingRate], 1.0);
  XCTAssertEqual([configurations logNetworkSamplingRate], 1.0);
  XCTAssertEqual([configurations foregroundEventCount], 300);
  XCTAssertEqual([configurations foregroundEventTimeLimit], 10);
  XCTAssertEqual([configurations backgroundEventCount], 30);
  XCTAssertEqual([configurations backgroundEventTimeLimit], 10);
  XCTAssertEqual([configurations foregroundNetworkEventCount], 700);
  XCTAssertEqual([configurations foregroundNetworkEventTimeLimit], 10);
  XCTAssertEqual([configurations backgroundNetworkEventCount], 70);
  XCTAssertEqual([configurations backgroundNetworkEventTimeLimit], 10);

  XCTAssertEqual([configurations sessionsSamplingPercentage], 1.0);
  XCTAssertEqual([configurations maxSessionLengthInMinutes], 240);
  XCTAssertEqual([configurations cpuSamplingFrequencyInForegroundInMS], 100.0);
  XCTAssertEqual([configurations cpuSamplingFrequencyInBackgroundInMS], 0.0);

  XCTAssertEqual([configurations memorySamplingFrequencyInForegroundInMS], 100.0);
  XCTAssertEqual([configurations memorySamplingFrequencyInBackgroundInMS], 0.0);
}

/** Validates if overrides work for diagnostics enabled. */
- (void)testOverridesForDiagnosticsEnabled {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configurations.userDefaults = userDefaults;

  XCTAssertFalse(configurations.diagnosticsEnabled);

  [userDefaults setBool:YES forKey:@"FPRDiagnosticsLocal"];
  XCTAssertTrue(configurations.diagnosticsEnabled);

  [userDefaults setBool:NO forKey:@"FPRDiagnosticsLocal"];
  XCTAssertFalse(configurations.diagnosticsEnabled);
}

/** Validates if Firebase Remote Config overrides work for trace sampling rate. */
- (void)testTraceSamplingRateRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_vc_trace_sampling_rate"];
  [userDefaults setObject:@(0.25) forKey:configKey];
  XCTAssertEqual([configurations logTraceSamplingRate], 0.25);

  [userDefaults setObject:@(1.0) forKey:configKey];
  XCTAssertEqual([configurations logTraceSamplingRate], 1.0);
  [configFlags resetCache];
}

/** Validates if Firebase Remote Config overrides work for network request sampling rate. */
- (void)testNetworkRequestSamplingRateRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSString *configKey = [NSString
      stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_vc_network_request_sampling_rate"];
  [userDefaults setObject:@(0.25) forKey:configKey];
  XCTAssertEqual([configurations logNetworkSamplingRate], 0.25);

  [userDefaults setObject:@(1.0) forKey:configKey];
  XCTAssertEqual([configurations logNetworkSamplingRate], 1.0);
  [configFlags resetCache];
}

/** Validates if Firebase Remote Config overrides work for session sampling rate. */
- (void)testSessionSamplingRateRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_vc_session_sampling_rate"];
  [userDefaults setObject:@(0.25) forKey:configKey];
  XCTAssertEqual([configurations sessionsSamplingPercentage], 25.00);

  [userDefaults setObject:@(1.0) forKey:configKey];
  XCTAssertEqual([configurations sessionsSamplingPercentage], 100.0);
  [configFlags resetCache];
}

/** Validates if Plist overrides work for session sampling rate. */
- (void)testSessionSamplingRatePlistOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_vc_session_sampling_rate"];
  [userDefaults setObject:@(0.25) forKey:configKey];
  XCTAssertEqual([configurations sessionsSamplingPercentage], 25.00);

  NSDictionary<NSString *, id> *infoDictionary = configurations.infoDictionary;
  configurations.infoDictionary = @{@"sessionsSamplingPercentage" : @(1.00)};
  XCTAssertEqual([configurations sessionsSamplingPercentage], 1.00);
  configurations.infoDictionary = infoDictionary;

  XCTAssertEqual([configurations sessionsSamplingPercentage], 25.00);
  [configFlags resetCache];
}

/** Validates if Firebase Remote Config overrides work for log source. */
- (void)testLogSourceRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_log_source"];
  [userDefaults setObject:@(100) forKey:configKey];
#if defined(FPR_AUTOPUSH_ENDPOINT)
  XCTAssertEqual([configurations logSource], 461);
#else
  XCTAssertEqual([configurations logSource], 100);
#endif

  [userDefaults setObject:@(200) forKey:configKey];
#if defined(FPR_AUTOPUSH_ENDPOINT)
  XCTAssertEqual([configurations logSource], 461);
#else
  XCTAssertEqual([configurations logSource], 200);
#endif

  [configFlags resetCache];
}

/** Validates if a resolve of disabled SDK version works. */
- (void)testDisabledSDKVersionsConfigResolveSuccessful {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusSuccess;
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSSet<NSString *> *versionSet =
      [[NSSet<NSString *> alloc] initWithObjects:@"1.0.2", @"1.0.3", nil];
  NSSet<NSString *> *emptySet = [[NSSet<NSString *> alloc] init];

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_disabled_ios_versions"];
  [userDefaults setObject:@"1.0.2;1.0.3" forKey:configKey];

  XCTAssertEqualObjects([configurations sdkDisabledVersions], versionSet);
  [userDefaults setObject:@"" forKey:configKey];
  XCTAssertEqualObjects([configurations sdkDisabledVersions], emptySet);

  [configFlags resetCache];
}

/** Validates if SDK version based disabling is honored. */
- (void)testDisabledSDKVersionsDisablesSDK {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusSuccess;
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  [userDefaults setObject:@(TRUE) forKey:configKey];

  XCTAssertEqual([configurations sdkEnabled], TRUE);

  NSString *disableVersionsConfigKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_disabled_ios_versions"];
  [userDefaults setObject:[NSString stringWithUTF8String:kFPRSDKVersion]
                   forKey:disableVersionsConfigKey];

  XCTAssertEqual([configurations sdkEnabled], FALSE);

  [configFlags resetCache];
}

/** Validates if Firebase Remote Config overrides work for SDK enabled. */
- (void)testSDKEnabledFlag {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusSuccess;
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  [userDefaults setObject:@(TRUE) forKey:configKey];

  XCTAssertEqual([configurations sdkEnabled], TRUE);

  [userDefaults setObject:@(FALSE) forKey:configKey];
  XCTAssertEqual([configurations sdkEnabled], FALSE);

  [configFlags resetCache];
}

/** Validates if Plist overrides work for SDK Enabled flag. */
- (void)testPlistOverridesSDKEnabledFlag {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusSuccess;
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  [userDefaults setObject:@(FALSE) forKey:configKey];
  XCTAssertEqual([configurations sdkEnabled], FALSE);

  NSDictionary<NSString *, id> *infoDictionary = configurations.infoDictionary;
  configurations.infoDictionary = @{@"firebase_performance_sdk_enabled" : @(TRUE)};
  XCTAssertEqual([configurations sdkEnabled], TRUE);
  configurations.infoDictionary = infoDictionary;

  [configFlags resetCache];
}

/** Validates if remote config overrides work for foreground rate limiting for traces. */
- (void)testForegroundRateLimitingTraceCountRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_trace_event_count_fg"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configurations foregroundEventCount], 100);

  [userDefaults setObject:@(200) forKey:configKey];
  XCTAssertEqual([configurations foregroundEventCount], 200);
  [configFlags resetCache];
}

/** Validates if remote config overrides work for background rate limiting for traces. */
- (void)testBackgroundRateLimitingTraceCountRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_trace_event_count_bg"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configurations backgroundEventCount], 100);

  [userDefaults setObject:@(200) forKey:configKey];
  XCTAssertEqual([configurations backgroundEventCount], 200);
  [configFlags resetCache];
}

/** Validates if remote config overrides work for foreground rate limiting for network requests. */
- (void)testForegroundRateLimitingNetworkCountRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString
      stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_network_request_event_count_fg"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configurations foregroundNetworkEventCount], 100);

  [userDefaults setObject:@(200) forKey:configKey];
  XCTAssertEqual([configurations foregroundNetworkEventCount], 200);
  [configFlags resetCache];
}

/** Validates if remote config overrides work for background rate limiting for network requests. */
- (void)testBackgroundRateLimitingNetworkCountRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString
      stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_network_request_event_count_bg"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configurations backgroundNetworkEventCount], 100);

  [userDefaults setObject:@(200) forKey:configKey];
  XCTAssertEqual([configurations backgroundNetworkEventCount], 200);
  [configFlags resetCache];
}

/** Validates if remote config overrides work for rate limiting time duration. */
- (void)testRateLimitingDurationRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_time_limit_sec"];
  [userDefaults setObject:@(300) forKey:configKey];
  XCTAssertEqual([configurations foregroundEventTimeLimit], 5);
  XCTAssertEqual([configurations backgroundEventTimeLimit], 5);
  XCTAssertEqual([configurations foregroundNetworkEventTimeLimit], 5);
  XCTAssertEqual([configurations backgroundNetworkEventTimeLimit], 5);

  [userDefaults setObject:@(900) forKey:configKey];
  XCTAssertEqual([configurations foregroundEventTimeLimit], 15);
  XCTAssertEqual([configurations backgroundEventTimeLimit], 15);
  XCTAssertEqual([configurations foregroundNetworkEventTimeLimit], 15);
  XCTAssertEqual([configurations backgroundNetworkEventTimeLimit], 15);
  [configFlags resetCache];
}

/** Validates if remote config overrides work for gauge collecction frequency. */
- (void)testGaugeCollectionFrequencyRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKeyCPUFg =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix,
                                 @"fpr_session_gauge_cpu_capture_frequency_fg_ms"];
  NSString *configKeyCPUBg =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix,
                                 @"fpr_session_gauge_cpu_capture_frequency_bg_ms"];
  NSString *configKeyMemoryFg =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix,
                                 @"fpr_session_gauge_memory_capture_frequency_fg_ms"];
  NSString *configKeyMemoryBg =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix,
                                 @"fpr_session_gauge_memory_capture_frequency_bg_ms"];
  [userDefaults setObject:@(100) forKey:configKeyCPUFg];
  [userDefaults setObject:@(200) forKey:configKeyCPUBg];
  [userDefaults setObject:@(300) forKey:configKeyMemoryFg];
  [userDefaults setObject:@(400) forKey:configKeyMemoryBg];

  XCTAssertEqual([configurations cpuSamplingFrequencyInForegroundInMS], 100);
  XCTAssertEqual([configurations cpuSamplingFrequencyInBackgroundInMS], 200);
  XCTAssertEqual([configurations memorySamplingFrequencyInForegroundInMS], 300);
  XCTAssertEqual([configurations memorySamplingFrequencyInBackgroundInMS], 400);

  [userDefaults setObject:@(10) forKey:configKeyCPUFg];
  [userDefaults setObject:@(20) forKey:configKeyCPUBg];
  [userDefaults setObject:@(30) forKey:configKeyMemoryFg];
  [userDefaults setObject:@(40) forKey:configKeyMemoryBg];

  XCTAssertEqual([configurations cpuSamplingFrequencyInForegroundInMS], 10);
  XCTAssertEqual([configurations cpuSamplingFrequencyInBackgroundInMS], 20);
  XCTAssertEqual([configurations memorySamplingFrequencyInForegroundInMS], 30);
  XCTAssertEqual([configurations memorySamplingFrequencyInBackgroundInMS], 40);

  [configFlags resetCache];
}

/** Validates if remote config overrides work for sessions max length duration. */
- (void)testSessionMaxLengthDurationRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_session_max_duration_min"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configurations maxSessionLengthInMinutes], 100);

  [userDefaults setObject:@(200) forKey:configKey];
  XCTAssertEqual([configurations maxSessionLengthInMinutes], 200);
  [configFlags resetCache];
}

- (void)testPrewarmDetectionRemoteConfigOverrides {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];

  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];

  GULUserDefaults *_Nonnull userDefaults = [self makeEmptyUserDefaults];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_prewarm_detection"];
  [userDefaults setObject:@(0) forKey:configKey];
  XCTAssertEqual([configurations prewarmDetectionMode], 0);

  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configurations prewarmDetectionMode], 1);

  [userDefaults setObject:@(2) forKey:configKey];
  XCTAssertEqual([configurations prewarmDetectionMode], 2);
  [configFlags resetCache];
}

#pragma mark - Malformed remote config values

/** Creates configurations backed by fake remote config flags and empty user defaults. */
- (FPRConfigurations *)makeConfigurationsWithRemoteConfig:(FPRFakeRemoteConfig *)remoteConfig {
  FPRConfigurations *configurations =
      [[FPRConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;
  configFlags.lastFetchedTime = [NSDate date];
  configFlags.userDefaults = [self makeEmptyUserDefaults];
  [configFlags resetCache];
  return configurations;
}

- (NSString *)cacheKeyForFlag:(NSString *)flag {
  return [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, flag];
}

/** Validates that rate limiting durations under one minute fall back to the default. */
- (void)testRateLimitingDurationInvalidRemoteConfigValuesFallBackToDefault {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRConfigurations *configurations = [self makeConfigurationsWithRemoteConfig:remoteConfig];
  GULUserDefaults *userDefaults = configurations.remoteConfigFlags.userDefaults;
  NSString *configKey = [self cacheKeyForFlag:@"fpr_rl_time_limit_sec"];

  for (id value in @[ @(0), @(30), @(59), @(-600), @(INT_MIN), @"garbage" ]) {
    [userDefaults setObject:value forKey:configKey];
    XCTAssertEqual([configurations foregroundEventTimeLimit], 10, @"value: %@", value);
    XCTAssertEqual([configurations backgroundEventTimeLimit], 10, @"value: %@", value);
    XCTAssertEqual([configurations foregroundNetworkEventTimeLimit], 10, @"value: %@", value);
    XCTAssertEqual([configurations backgroundNetworkEventTimeLimit], 10, @"value: %@", value);
  }

  // Smallest valid value.
  [userDefaults setObject:@(60) forKey:configKey];
  XCTAssertEqual([configurations foregroundEventTimeLimit], 1);
  [configurations.remoteConfigFlags resetCache];
}

/** Validates that negative rate limiting event counts fall back to the defaults. */
- (void)testRateLimitingCountsNegativeRemoteConfigValuesFallBackToDefault {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRConfigurations *configurations = [self makeConfigurationsWithRemoteConfig:remoteConfig];
  GULUserDefaults *userDefaults = configurations.remoteConfigFlags.userDefaults;

  for (id value in @[ @(-1), @(INT_MIN), @"-100" ]) {
    [userDefaults setObject:value forKey:[self cacheKeyForFlag:@"fpr_rl_trace_event_count_fg"]];
    [userDefaults setObject:value forKey:[self cacheKeyForFlag:@"fpr_rl_trace_event_count_bg"]];
    [userDefaults setObject:value
                     forKey:[self cacheKeyForFlag:@"fpr_rl_network_request_event_count_fg"]];
    [userDefaults setObject:value
                     forKey:[self cacheKeyForFlag:@"fpr_rl_network_request_event_count_bg"]];

    XCTAssertEqual([configurations foregroundEventCount], 300, @"value: %@", value);
    XCTAssertEqual([configurations backgroundEventCount], 30, @"value: %@", value);
    XCTAssertEqual([configurations foregroundNetworkEventCount], 700, @"value: %@", value);
    XCTAssertEqual([configurations backgroundNetworkEventCount], 70, @"value: %@", value);
  }

  // Zero is a valid value that drops all events.
  [userDefaults setObject:@(0) forKey:[self cacheKeyForFlag:@"fpr_rl_trace_event_count_fg"]];
  XCTAssertEqual([configurations foregroundEventCount], 0);
  [configurations.remoteConfigFlags resetCache];
}

/** Validates that negative gauge capture frequencies fall back to the defaults. */
- (void)testGaugeCollectionFrequencyNegativeRemoteConfigValuesFallBackToDefault {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRConfigurations *configurations = [self makeConfigurationsWithRemoteConfig:remoteConfig];
  GULUserDefaults *userDefaults = configurations.remoteConfigFlags.userDefaults;

  NSArray<NSString *> *flags = @[
    @"fpr_session_gauge_cpu_capture_frequency_fg_ms",
    @"fpr_session_gauge_cpu_capture_frequency_bg_ms",
    @"fpr_session_gauge_memory_capture_frequency_fg_ms",
    @"fpr_session_gauge_memory_capture_frequency_bg_ms"
  ];

  for (id value in @[ @(-1), @(INT_MIN), @"-50" ]) {
    for (NSString *flag in flags) {
      [userDefaults setObject:value forKey:[self cacheKeyForFlag:flag]];
    }
    XCTAssertEqual([configurations cpuSamplingFrequencyInForegroundInMS], 100, @"value: %@", value);
    XCTAssertEqual([configurations cpuSamplingFrequencyInBackgroundInMS], 0, @"value: %@", value);
    XCTAssertEqual([configurations memorySamplingFrequencyInForegroundInMS], 100, @"value: %@",
                   value);
    XCTAssertEqual([configurations memorySamplingFrequencyInBackgroundInMS], 0, @"value: %@",
                   value);
  }

  // Zero is a valid value that disables gauge collection.
  for (NSString *flag in flags) {
    [userDefaults setObject:@(0) forKey:[self cacheKeyForFlag:flag]];
  }
  XCTAssertEqual([configurations cpuSamplingFrequencyInForegroundInMS], 0);
  XCTAssertEqual([configurations memorySamplingFrequencyInForegroundInMS], 0);
  [configurations.remoteConfigFlags resetCache];
}

/** Validates that zero or negative max session durations fall back to the default. */
- (void)testSessionMaxLengthInvalidRemoteConfigValuesFallBackToDefault {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRConfigurations *configurations = [self makeConfigurationsWithRemoteConfig:remoteConfig];
  GULUserDefaults *userDefaults = configurations.remoteConfigFlags.userDefaults;
  NSString *configKey = [self cacheKeyForFlag:@"fpr_session_max_duration_min"];

  for (id value in @[ @(0), @(-1), @(INT_MIN), @"garbage" ]) {
    [userDefaults setObject:value forKey:configKey];
    XCTAssertEqual([configurations maxSessionLengthInMinutes], 240, @"value: %@", value);
  }
  [configurations.remoteConfigFlags resetCache];
}

/** Validates that NaN or negative sampling rates fall back to the defaults. */
- (void)testSamplingRatesInvalidRemoteConfigValuesFallBackToDefault {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRConfigurations *configurations = [self makeConfigurationsWithRemoteConfig:remoteConfig];
  GULUserDefaults *userDefaults = configurations.remoteConfigFlags.userDefaults;

  for (id value in @[ @(NAN), @(-0.5), @"-0.5" ]) {
    [userDefaults setObject:value forKey:[self cacheKeyForFlag:@"fpr_vc_trace_sampling_rate"]];
    [userDefaults setObject:value
                     forKey:[self cacheKeyForFlag:@"fpr_vc_network_request_sampling_rate"]];
    [userDefaults setObject:value forKey:[self cacheKeyForFlag:@"fpr_vc_session_sampling_rate"]];
    XCTAssertEqual([configurations logTraceSamplingRate], 1.0, @"value: %@", value);
    XCTAssertEqual([configurations logNetworkSamplingRate], 1.0, @"value: %@", value);
    XCTAssertEqual([configurations sessionsSamplingPercentage], 1.0, @"value: %@", value);
  }
  [configurations.remoteConfigFlags resetCache];
}

/** Validates that cached values of unexpected types are ignored instead of crashing. */
- (void)testCachedValuesOfUnexpectedTypeFallBackToDefaults {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusSuccess;
  FPRConfigurations *configurations = [self makeConfigurationsWithRemoteConfig:remoteConfig];
  configurations.remoteConfigFlags.lastFetchStatus = FIRRemoteConfigFetchStatusSuccess;
  GULUserDefaults *userDefaults = configurations.remoteConfigFlags.userDefaults;

  NSArray<NSString *> *flags = @[
    @"fpr_log_source",
    @"fpr_enabled",
    @"fpr_disabled_ios_versions",
    @"fpr_rl_time_limit_sec",
    @"fpr_rl_trace_event_count_fg",
    @"fpr_rl_trace_event_count_bg",
    @"fpr_rl_network_request_event_count_fg",
    @"fpr_rl_network_request_event_count_bg",
    @"fpr_vc_trace_sampling_rate",
    @"fpr_vc_network_request_sampling_rate",
    @"fpr_vc_session_sampling_rate",
    @"fpr_session_gauge_cpu_capture_frequency_fg_ms",
    @"fpr_session_gauge_cpu_capture_frequency_bg_ms",
    @"fpr_session_gauge_memory_capture_frequency_fg_ms",
    @"fpr_session_gauge_memory_capture_frequency_bg_ms",
    @"fpr_session_max_duration_min",
    @"fpr_prewarm_detection",
  ];
  NSArray *malformedValues = @[
    [@"garbage" dataUsingEncoding:NSUTF8StringEncoding], @[ @1, @2 ], @{@"key" : @"value"},
    [NSDate date]
  ];

  for (id value in malformedValues) {
    for (NSString *flag in flags) {
      [userDefaults setObject:value forKey:[self cacheKeyForFlag:flag]];
    }

#if defined(FPR_AUTOPUSH_ENDPOINT)
    XCTAssertEqual([configurations logSource], 461);
#else
    XCTAssertEqual([configurations logSource], 462);
#endif
    XCTAssertTrue([configurations sdkEnabled]);
    XCTAssertEqualObjects([configurations sdkDisabledVersions], [NSSet set]);
    XCTAssertEqual([configurations logTraceSamplingRate], 1.0);
    XCTAssertEqual([configurations logNetworkSamplingRate], 1.0);
    XCTAssertEqual([configurations foregroundEventCount], 300);
    XCTAssertEqual([configurations foregroundEventTimeLimit], 10);
    XCTAssertEqual([configurations backgroundEventCount], 30);
    XCTAssertEqual([configurations backgroundEventTimeLimit], 10);
    XCTAssertEqual([configurations foregroundNetworkEventCount], 700);
    XCTAssertEqual([configurations foregroundNetworkEventTimeLimit], 10);
    XCTAssertEqual([configurations backgroundNetworkEventCount], 70);
    XCTAssertEqual([configurations backgroundNetworkEventTimeLimit], 10);
    XCTAssertEqual([configurations sessionsSamplingPercentage], 1.0);
    XCTAssertEqual([configurations maxSessionLengthInMinutes], 240);
    XCTAssertEqual([configurations cpuSamplingFrequencyInForegroundInMS], 100);
    XCTAssertEqual([configurations cpuSamplingFrequencyInBackgroundInMS], 0);
    XCTAssertEqual([configurations memorySamplingFrequencyInForegroundInMS], 100);
    XCTAssertEqual([configurations memorySamplingFrequencyInBackgroundInMS], 0);
    XCTAssertEqual([configurations prewarmDetectionMode], PrewarmDetectionModeActivePrewarm);
  }
  [configurations.remoteConfigFlags resetCache];
}

/** Validates that malformed values fetched from remote config are cached and resolved safely. */
- (void)testMalformedFetchedRemoteConfigValuesResolveToDefaults {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRConfigurations *configurations = [self makeConfigurationsWithRemoteConfig:remoteConfig];
  FPRRemoteConfigFlags *configFlags = configurations.remoteConfigFlags;

  NSDictionary<NSString *, NSData *> *remoteValues = @{
    @"fpr_rl_time_limit_sec" : [@"abc" dataUsingEncoding:NSUTF8StringEncoding],
    @"fpr_rl_trace_event_count_fg" : [@"-5" dataUsingEncoding:NSUTF8StringEncoding],
    @"fpr_rl_network_request_event_count_fg" : [@"-7.5" dataUsingEncoding:NSUTF8StringEncoding],
    @"fpr_vc_trace_sampling_rate" : [@"-0.5" dataUsingEncoding:NSUTF8StringEncoding],
    @"fpr_vc_network_request_sampling_rate" : [@"" dataUsingEncoding:NSUTF8StringEncoding],
    @"fpr_session_gauge_cpu_capture_frequency_fg_ms" :
        [@"-100" dataUsingEncoding:NSUTF8StringEncoding],
    @"fpr_session_max_duration_min" : [@"-10" dataUsingEncoding:NSUTF8StringEncoding],
    // Invalid UTF-8.
    @"fpr_disabled_ios_versions" : [NSData dataWithBytes:(const char[]){(char)0xFF, (char)0xFE}
                                                  length:2],
  };
  [remoteValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSData *data, BOOL *stop) {
    [remoteConfig.configValues
        setObject:[[FIRRemoteConfigValue alloc] initWithData:data
                                                      source:FIRRemoteConfigSourceRemote]
           forKey:key];
  }];

  remoteConfig.fetchStatus = FIRRemoteConfigFetchStatusSuccess;
  remoteConfig.lastFetchTime = nil;
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;
  [configFlags update];

  XCTAssertEqual([configurations foregroundEventTimeLimit], 10);
  XCTAssertEqual([configurations foregroundEventCount], 300);
  XCTAssertEqual([configurations foregroundNetworkEventCount], 700);
  XCTAssertEqual([configurations logTraceSamplingRate], 1.0);
  // An empty value parses to a sampling rate of 0, which is a valid value.
  XCTAssertEqual([configurations logNetworkSamplingRate], 0.0);
  XCTAssertEqual([configurations cpuSamplingFrequencyInForegroundInMS], 100);
  XCTAssertEqual([configurations maxSessionLengthInMinutes], 240);
  XCTAssertEqualObjects([configurations sdkDisabledVersions], [NSSet set]);
  [configFlags resetCache];
}

@end
