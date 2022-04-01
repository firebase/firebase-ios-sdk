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

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"

static NSInteger const kLogSource = 462;  // LogRequest_LogSource_Fireperf

@interface FPRRemoteConfigFlagsTest : XCTestCase

@end

@implementation FPRRemoteConfigFlagsTest

/** Validates if the instance creation works. */
- (void)testInstanceCreation {
  XCTAssertNotNil([FPRRemoteConfigFlags sharedInstance]);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertNotNil([[FPRRemoteConfigFlags alloc] initWithRemoteConfig:nil]);
#pragma clang diagnostic pop
}

/** Validate the singleton nature of the object. */
- (void)testObjectEquality {
  XCTAssertEqual([FPRRemoteConfigFlags sharedInstance], [FPRRemoteConfigFlags sharedInstance]);
}

- (void)testCacheResetAfterEverySuccessfulFetch {
  // Initializate the remote config and config flags
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configFlags.userDefaults = [[NSUserDefaults alloc] init];

  // Provide expected remote config values
  FIRRemoteConfigValue *boolRCValueFromRemote =
      [[FIRRemoteConfigValue alloc] initWithData:[@"true" dataUsingEncoding:NSUTF8StringEncoding]
                                          source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:boolRCValueFromRemote forKey:@"fpr_enabled"];

  FIRRemoteConfigValue *floatRCValueFromRemote =
      [[FIRRemoteConfigValue alloc] initWithData:[@"0.1" dataUsingEncoding:NSUTF8StringEncoding]
                                          source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:floatRCValueFromRemote
                                forKey:@"fpr_vc_session_sampling_rate"];

  // Trigger the RC config fetch
  remoteConfig.fetchStatus = FIRRemoteConfigFetchStatusSuccess;
  remoteConfig.lastFetchTime = nil;
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;
  [configFlags update];

  // Verify the expected remote config values
  NSString *fprEnabledConfigKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  XCTAssertNotNil([configFlags.userDefaults objectForKey:fprEnabledConfigKey]);
  XCTAssertEqual([[configFlags.userDefaults objectForKey:fprEnabledConfigKey] boolValue], true);

  NSString *fprSamplingConfigKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_vc_session_sampling_rate"];
  XCTAssertNotNil([configFlags.userDefaults objectForKey:fprSamplingConfigKey]);
  XCTAssertEqualWithAccuracy(
      [[configFlags.userDefaults objectForKey:fprSamplingConfigKey] floatValue], 0.1, 0.001);

  // Provide another expected remote config values (different than what was previously provided)
  [remoteConfig.configValues removeAllObjects];

  FIRRemoteConfigValue *floatRCValueFromRemote2 =
      [[FIRRemoteConfigValue alloc] initWithData:[@"0.2" dataUsingEncoding:NSUTF8StringEncoding]
                                          source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:floatRCValueFromRemote2
                                forKey:@"fpr_vc_session_sampling_rate"];

  // Retrigger the RC config fetch
  remoteConfig.fetchStatus = FIRRemoteConfigFetchStatusSuccess;
  remoteConfig.lastFetchTime = nil;
  [configFlags update];

  // Verify the new expected remote config values
  XCTAssertNil([configFlags.userDefaults objectForKey:fprEnabledConfigKey]);

  XCTAssertNotNil([configFlags.userDefaults objectForKey:fprSamplingConfigKey]);
  XCTAssertEqualWithAccuracy(
      [[configFlags.userDefaults objectForKey:fprSamplingConfigKey] floatValue], 0.2, 0.001);
}

/** Validate the configuration update happens. */
- (void)testConfigUpdate {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusNoFetchYet;
  remoteConfig.lastFetchTime = nil;

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  remoteConfig.fetchStatus = FIRRemoteConfigFetchStatusSuccess;
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;
  [configFlags update];
  XCTAssertNotNil(configFlags.lastFetchedTime);
}

/** Validate the configuration update does not happen during app start. */
- (void)testConfigFetchDoesNotHappenDuringAppStart {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchTime = nil;

  NSTimeInterval appStartConfigFetchDelay = 5.0;
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  remoteConfig.lastFetchTime = nil;
  configFlags.lastFetchedTime = nil;
  configFlags.applicationStartTime = [NSDate date];
  configFlags.appStartConfigFetchDelayInSeconds = appStartConfigFetchDelay;
  configFlags.lastFetchStatus = FIRRemoteConfigFetchStatusNoFetchYet;

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Dummy expectation to wait for the fetch delay."];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)((appStartConfigFetchDelay - 2) * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [configFlags update];
        [expectation fulfill];
        XCTAssertTrue(configFlags.lastFetchStatus == FIRRemoteConfigFetchStatusNoFetchYet);
      });
  [self waitForExpectationsWithTimeout:(appStartConfigFetchDelay) handler:nil];
}

/** Validate the configuration update happens after a delay during app start. */
- (void)testConfigFetchAfterDelayDuringAppStart {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchTime = nil;

  NSTimeInterval appStartConfigFetchDelay = 3.0;
  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  remoteConfig.lastFetchTime = nil;
  configFlags.lastFetchedTime = nil;
  configFlags.applicationStartTime = [NSDate date];
  configFlags.appStartConfigFetchDelayInSeconds = appStartConfigFetchDelay;
  configFlags.lastFetchStatus = FIRRemoteConfigFetchStatusNoFetchYet;

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Dummy expectation to wait for the fetch delay."];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)((appStartConfigFetchDelay + 2) * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [configFlags update];
        [expectation fulfill];
        XCTAssertTrue(configFlags.lastFetchStatus == FIRRemoteConfigFetchStatusSuccess);
      });
  [self waitForExpectationsWithTimeout:(appStartConfigFetchDelay + 3) handler:nil];
}

/** Validate the configuration update does not happen immediately after fetching. */
- (void)testConfigUpdateDoesNotHappenImmediately {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusNoFetchYet;
  remoteConfig.lastFetchTime = nil;

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  remoteConfig.fetchStatus = FIRRemoteConfigFetchStatusSuccess;
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;
  [configFlags update];
  XCTAssertNotNil(configFlags.lastFetchedTime);

  // Try updating the flags again and make sure last fetched time has not changed.
  NSDate *lastFetchedTime = remoteConfig.lastFetchTime;
  NSDate *lastActivatedTime = configFlags.lastFetchedTime;
  [configFlags update];
  XCTAssertEqualWithAccuracy([lastFetchedTime timeIntervalSinceReferenceDate],
                             [remoteConfig.lastFetchTime timeIntervalSinceReferenceDate], 0.1);
  XCTAssertEqualWithAccuracy([lastActivatedTime timeIntervalSinceReferenceDate],
                             [configFlags.lastFetchedTime timeIntervalSinceReferenceDate], 0.1);
}

/** Validate the configuration update does not happen immediately after fetching. */
- (void)testConfigUpdateHappensIfIntialFetchHasNotHappened {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusNoFetchYet;
  remoteConfig.lastFetchTime = nil;

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  remoteConfig.fetchStatus = FIRRemoteConfigFetchStatusSuccess;
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;
  [configFlags update];
  XCTAssertNotNil(configFlags.lastFetchedTime);

  // Try updating the flags again and make sure last fetched time has not changed.
  NSDate *lastFetchedTime = remoteConfig.lastFetchTime;
  [configFlags update];
  XCTAssertEqualObjects(lastFetchedTime, remoteConfig.lastFetchTime);
}

/** Validate the configuration fetch does not happen immediately on initialization. */
- (void)testConfigFetchHappensDoesNotHappenImmediately {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusNoFetchYet;
  remoteConfig.lastFetchTime = nil;

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  // Setting the status to success. Calling update on the config flags should trigger updation of
  // fetch time. Fetch would trigger activation.
  remoteConfig.fetchStatus = FIRRemoteConfigFetchStatusSuccess;
  NSDate *lastActivatedTime = configFlags.lastFetchedTime;
  [configFlags update];
  XCTAssert([configFlags.lastFetchedTime timeIntervalSinceDate:lastActivatedTime] == 0);
}

/** Validate the configuration fetch happens after initial delay. */
- (void)testConfigFetchHappensAfterDelay {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];
  remoteConfig.lastFetchStatus = FIRRemoteConfigFetchStatusNoFetchYet;
  remoteConfig.lastFetchTime = nil;

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;

  remoteConfig.fetchStatus = FIRRemoteConfigFetchStatusSuccess;
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Dummy expectation to wait for the fetch delay."];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW,
                    (int64_t)((kFPRMinAppStartConfigFetchDelayInSeconds + 5) * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [configFlags update];
        [expectation fulfill];
        XCTAssertNotNil(configFlags.lastFetchedTime);
        XCTAssertNotNil(remoteConfig.lastFetchTime);
      });
  [self waitForExpectationsWithTimeout:(kFPRMinAppStartConfigFetchDelayInSeconds + 6) handler:nil];
}

#pragma mark - App config related tests

/** Validates if the fetch for the SDK enabled config happens from cache, else return default value.
 */
- (void)testConfigFetchForSDKEnabledFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  [userDefaults setObject:@(false) forKey:configKey];
  XCTAssertEqual([configFlags performanceSDKEnabledWithDefaultValue:true], false);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags performanceSDKEnabledWithDefaultValue:true], true);
}

/** Validates if the caching works for SDK enabled remote config. */
- (void)testConfigCacheForSDKEnabled {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"false" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_enabled"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags performanceSDKEnabledWithDefaultValue:true], true);
  [configFlags resetCache];

  valueData = [@"false" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_enabled"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags performanceSDKEnabledWithDefaultValue:true], false);
  [configFlags resetCache];

  valueData = [@"false" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_enabled"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags performanceSDKEnabledWithDefaultValue:true], true);
  [configFlags resetCache];
}

/** Validates if the fetch for the log source config happens from cache, else return default value.
 */
- (void)testConfigFetchForLogSourceFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_log_source"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configFlags logSourceWithDefaultValue:kLogSource], 100);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags logSourceWithDefaultValue:kLogSource], kLogSource);
}

/** Validates if the caching works  for log source remote config. */
- (void)testConfigCacheForLogSource {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_log_source"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags logSourceWithDefaultValue:kLogSource], kLogSource);
  [configFlags resetCache];

  valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_log_source"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags logSourceWithDefaultValue:kLogSource], 100);
  [configFlags resetCache];

  valueData = [@"200" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_log_source"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags logSourceWithDefaultValue:kLogSource], kLogSource);
  [configFlags resetCache];
}

#pragma mark - Rate limiting configs related tests.

/** Validates if the fetch for the rate limit duration config happens from cache, else return
 * default value. */
- (void)testConfigFetchForRateLimitDurationFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_time_limit_sec"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configFlags rateLimitTimeDurationWithDefaultValue:200], 100);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags rateLimitTimeDurationWithDefaultValue:200], 200);
}

/** Validates if the caching works  for rate limit duration remote config. */
- (void)testConfigCacheForRateLimitDuration {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_time_limit_sec"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTimeDurationWithDefaultValue:200], 200);
  [configFlags resetCache];

  valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_time_limit_sec"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTimeDurationWithDefaultValue:200], 100);
  [configFlags resetCache];

  valueData = [@"200" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_time_limit_sec"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTimeDurationWithDefaultValue:200], 200);
  [configFlags resetCache];
}

/** Validates if the fetch for the trace count in foreground config happens from cache, else return
 * default value. */
- (void)testConfigFetchForTraceEventCountInForegroundFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_trace_event_count_fg"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configFlags rateLimitTraceCountInForegroundWithDefaultValue:200], 100);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags rateLimitTraceCountInForegroundWithDefaultValue:200], 200);
}

/** Validates if the caching works  for trace event count in foreground remote config. */
- (void)testConfigCacheForTraceEventCountInForeground {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_trace_event_count_fg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTraceCountInForegroundWithDefaultValue:200], 200);
  [configFlags resetCache];

  valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_trace_event_count_fg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTraceCountInForegroundWithDefaultValue:200], 100);
  [configFlags resetCache];

  valueData = [@"200" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_trace_event_count_fg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTraceCountInForegroundWithDefaultValue:200], 200);
  [configFlags resetCache];
}

/** Validates if the fetch for the trace count in foreground config happens from cache, else return
 * default value. */
- (void)testConfigFetchForTraceEventCountInBackgroundFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_trace_event_count_bg"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configFlags rateLimitTraceCountInBackgroundWithDefaultValue:200], 100);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags rateLimitTraceCountInBackgroundWithDefaultValue:200], 200);
}

/** Validates if the caching works  for trace event count in foreground remote config. */
- (void)testConfigCacheForTraceEventCountInBackground {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_trace_event_count_bg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTraceCountInBackgroundWithDefaultValue:200], 200);
  [configFlags resetCache];

  valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_trace_event_count_bg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTraceCountInBackgroundWithDefaultValue:200], 100);
  [configFlags resetCache];

  valueData = [@"200" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_trace_event_count_bg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitTraceCountInBackgroundWithDefaultValue:200], 200);
  [configFlags resetCache];
}

/** Validates if the fetch for the network trace count in foreground config happens from cache, else
 * return default value. */
- (void)testConfigFetchForNetworkTraceEventCountInForegroundFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString
      stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_network_request_event_count_fg"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInForegroundWithDefaultValue:200], 100);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInForegroundWithDefaultValue:200], 200);
}

/** Validates if the caching works  for network trace event count in foreground remote config. */
- (void)testConfigCacheForNetworkTraceEventCountInForeground {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_network_request_event_count_fg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInForegroundWithDefaultValue:200], 200);
  [configFlags resetCache];

  valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_network_request_event_count_fg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInForegroundWithDefaultValue:200], 100);
  [configFlags resetCache];

  valueData = [@"200" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_network_request_event_count_fg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInForegroundWithDefaultValue:200], 200);
  [configFlags resetCache];
}

/** Validates if the fetch for the trace count in foreground config happens from cache, else return
 * default value. */
- (void)testConfigFetchForNetworkTraceEventCountInBackgroundFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString
      stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_rl_network_request_event_count_bg"];
  [userDefaults setObject:@(100) forKey:configKey];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInBackgroundWithDefaultValue:200], 100);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInBackgroundWithDefaultValue:200], 200);
}

/** Validates if the caching works  for trace event count in foreground remote config. */
- (void)testConfigCacheForNetworkTraceEventCountInBackground {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_network_request_event_count_bg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInBackgroundWithDefaultValue:200], 200);
  [configFlags resetCache];

  valueData = [@"100" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_network_request_event_count_bg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInBackgroundWithDefaultValue:200], 100);
  [configFlags resetCache];

  valueData = [@"200" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_rl_network_request_event_count_bg"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags rateLimitNetworkRequestCountInBackgroundWithDefaultValue:200], 200);
  [configFlags resetCache];
}

#pragma mark - Sampling configs related tests.

/** Validates if the fetch for the trace sampling rate config happens from cache, else return
 * default value. */
- (void)testConfigFetchForTraceSamplingRateFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_vc_trace_sampling_rate"];
  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configFlags traceSamplingRateWithDefaultValue:100], 1);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags traceSamplingRateWithDefaultValue:100], 100);
}

/** Validates if the caching works  for trace sampling rate remote config. */
- (void)testConfigCacheForTraceSamplingRate {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_trace_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags traceSamplingRateWithDefaultValue:100], 100);
  [configFlags resetCache];

  valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_trace_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags traceSamplingRateWithDefaultValue:100], 1);
  [configFlags resetCache];

  valueData = [@"2" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_trace_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags traceSamplingRateWithDefaultValue:100], 100);
  [configFlags resetCache];
}

/** Validates if the fetch for the network sampling rate config happens from cache, else return
 * default value. */
- (void)testConfigFetchForNetworkSamplingRateFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString
      stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_vc_network_request_sampling_rate"];
  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configFlags networkRequestSamplingRateWithDefaultValue:100], 1);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags networkRequestSamplingRateWithDefaultValue:100], 100);
}

/** Validates if the caching works  for network sampling rate remote config. */
- (void)testConfigCacheForNetworkSamplingRate {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_network_request_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags networkRequestSamplingRateWithDefaultValue:100], 100);
  [configFlags resetCache];

  valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_network_request_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags networkRequestSamplingRateWithDefaultValue:100], 1);
  [configFlags resetCache];

  valueData = [@"2" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_network_request_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags networkRequestSamplingRateWithDefaultValue:100], 100);
  [configFlags resetCache];
}

#pragma mark - Session related configs tests.

/** Validates if the fetch for the session sampling rate config happens from cache, else return
 * default value. */
- (void)testConfigFetchForSessionSamplingRateFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_vc_session_sampling_rate"];
  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configFlags sessionSamplingRateWithDefaultValue:100], 1);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags sessionSamplingRateWithDefaultValue:100], 100);
}

/** Validates if the caching works  for network sampling rate remote config. */
- (void)testConfigCacheForSessionSamplingRate {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_session_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionSamplingRateWithDefaultValue:100], 100);
  [configFlags resetCache];

  valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_session_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionSamplingRateWithDefaultValue:100], 1);
  [configFlags resetCache];

  valueData = [@"2" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_vc_session_sampling_rate"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionSamplingRateWithDefaultValue:100], 100);
  [configFlags resetCache];
}

/** Validates if the fetch for the CPU collection frequency in foreground config happens from cache,
 * else return default value. */
- (void)testConfigFetchForCPUGaugeCollectionFrequencyInForegroundFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix,
                                 @"fpr_session_gauge_cpu_capture_frequency_fg_ms"];
  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInForegroundWithDefaultValue:100], 1);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInForegroundWithDefaultValue:100],
                 100);
}

/** Validates if the caching works  for CPU collection frequency in foreground. */
- (void)testConfigCacheForCPUGaugeCollectionFrequencyInForeground {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_cpu_capture_frequency_fg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInForegroundWithDefaultValue:100],
                 100);
  [configFlags resetCache];

  valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_cpu_capture_frequency_fg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInForegroundWithDefaultValue:100], 1);
  [configFlags resetCache];

  valueData = [@"2" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_cpu_capture_frequency_fg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInForegroundWithDefaultValue:100],
                 100);
  [configFlags resetCache];
}

/** Validates if the fetch for the CPU collection frequency in background config happens from cache,
 * else return default value. */
- (void)testConfigFetchForCPUGaugeCollectionFrequencyInBackgroundFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix,
                                 @"fpr_session_gauge_cpu_capture_frequency_bg_ms"];
  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInBackgroundWithDefaultValue:100], 1);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInBackgroundWithDefaultValue:100],
                 100);
}

/** Validates if the caching works  for CPU collection frequency in foreground. */
- (void)testConfigCacheForCPUGaugeCollectionFrequencyInBackground {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_cpu_capture_frequency_bg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInBackgroundWithDefaultValue:100],
                 100);
  [configFlags resetCache];

  valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_cpu_capture_frequency_bg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInBackgroundWithDefaultValue:100], 1);
  [configFlags resetCache];

  valueData = [@"2" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_cpu_capture_frequency_bg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeCPUCaptureFrequencyInBackgroundWithDefaultValue:100],
                 100);
  [configFlags resetCache];
}

/** Validates if the fetch for the memory collection frequency in foreground config happens from
 * cache, else return default value. */
- (void)testConfigFetchForMemoryGaugeCollectionFrequencyInForegroundFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix,
                                 @"fpr_session_gauge_memory_capture_frequency_fg_ms"];
  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInForegroundWithDefaultValue:100],
                 1);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInForegroundWithDefaultValue:100],
                 100);
}

/** Validates if the caching works  for memory collection frequency in foreground. */
- (void)testConfigCacheForMemoryGaugeCollectionFrequencyInForeground {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_memory_capture_frequency_fg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInForegroundWithDefaultValue:100],
                 100);
  [configFlags resetCache];

  valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_memory_capture_frequency_fg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInForegroundWithDefaultValue:100],
                 1);
  [configFlags resetCache];

  valueData = [@"2" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_memory_capture_frequency_fg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInForegroundWithDefaultValue:100],
                 100);
  [configFlags resetCache];
}

/** Validates if the fetch for the memory collection frequency in background config happens from
 * cache, else return default value. */
- (void)testConfigFetchForMemoryGaugeCollectionFrequencyInBackgroundFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix,
                                 @"fpr_session_gauge_memory_capture_frequency_bg_ms"];
  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInBackgroundWithDefaultValue:100],
                 1);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInBackgroundWithDefaultValue:100],
                 100);
}

/** Validates if the caching works  for CPU collection frequency in foreground. */
- (void)testConfigCacheForMemoryGaugeCollectionFrequencyInBackground {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_memory_capture_frequency_bg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInBackgroundWithDefaultValue:100],
                 100);
  [configFlags resetCache];

  valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_memory_capture_frequency_bg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInBackgroundWithDefaultValue:100],
                 1);
  [configFlags resetCache];

  valueData = [@"2" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value
                                forKey:@"fpr_session_gauge_memory_capture_frequency_bg_ms"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionGaugeMemoryCaptureFrequencyInBackgroundWithDefaultValue:100],
                 100);
  [configFlags resetCache];
}

/** Validates if the fetch for the session max duration config happens from cache, else return
 * default value. */
- (void)testConfigFetchForSessionMaxDurationFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_session_max_duration_min"];
  [userDefaults setObject:@(1) forKey:configKey];
  XCTAssertEqual([configFlags sessionMaxDurationWithDefaultValue:100], 1);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqual([configFlags sessionMaxDurationWithDefaultValue:100], 100);
}

/** Validates if the caching works  for session max duration. */
- (void)testConfigCacheForSessionMaxDuration {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  [configFlags resetCache];
  NSData *valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_session_max_duration_min"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionMaxDurationWithDefaultValue:100], 100);
  [configFlags resetCache];

  valueData = [@"1" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_session_max_duration_min"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionMaxDurationWithDefaultValue:100], 1);
  [configFlags resetCache];

  valueData = [@"2" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_session_max_duration_min"];
  [configFlags cacheConfigValues];
  XCTAssertEqual([configFlags sessionMaxDurationWithDefaultValue:100], 100);
  [configFlags resetCache];
}

/** Validates if the fetch for the SDK disabled versions config happens from cache, else return
 * default value. */
- (void)testConfigFetchForSDKDisabledVersionsFromCache {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSSet<NSString *> *versionSet =
      [[NSSet<NSString *> alloc] initWithObjects:@"1.0.2", @"1.0.3", nil];
  NSSet<NSString *> *emptySet = [[NSSet<NSString *> alloc] init];

  NSString *configKey =
      [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_disabled_ios_versions"];
  [userDefaults setObject:@"1.0.2;1.0.3" forKey:configKey];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], versionSet);

  [userDefaults removeObjectForKey:configKey];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], emptySet);
}

/** Validates if the caching works  for SDK disabled versions. */
- (void)testConfigCacheForSDKDisabledVersions {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *sdkVersions = @"1.0.2;1.0.3";
  NSSet<NSString *> *versionSet =
      [[NSSet<NSString *> alloc] initWithObjects:@"1.0.2", @"1.0.3", nil];
  NSSet<NSString *> *emptySet = [[NSSet<NSString *> alloc] init];
  NSData *valueData = [sdkVersions dataUsingEncoding:NSUTF8StringEncoding];

  [configFlags resetCache];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceStatic];
  [remoteConfig.configValues setObject:value forKey:@"fpr_disabled_ios_versions"];
  [configFlags cacheConfigValues];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], emptySet);
  [configFlags resetCache];

  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_disabled_ios_versions"];
  [configFlags cacheConfigValues];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], versionSet);
  [configFlags resetCache];

  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceDefault];
  [remoteConfig.configValues setObject:value forKey:@"fpr_disabled_ios_versions"];
  [configFlags cacheConfigValues];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], emptySet);
  [configFlags resetCache];
}

/** Validates if performance disabled version are fetched from remote config with wildcards, else
 * return a default value. */
- (void)testConfigFetchForPerformanceDisabledVersionsWithWildcard {
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *sdkVersions = @" 1.0.2 ; 1.0.3 ";
  NSSet<NSString *> *versionSet =
      [[NSSet<NSString *> alloc] initWithObjects:@"1.0.2", @"1.0.3", nil];
  NSSet<NSString *> *emptySet = [[NSSet<NSString *> alloc] init];
  NSData *valueData = [sdkVersions dataUsingEncoding:NSUTF8StringEncoding];

  [configFlags resetCache];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_disabled_ios_versions"];
  [configFlags cacheConfigValues];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], versionSet);
  [configFlags resetCache];

  valueData = [@" " dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_disabled_ios_versions"];
  [configFlags cacheConfigValues];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], emptySet);
  [configFlags resetCache];

  valueData = [@"1.0.2;1.0.3;;" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_disabled_ios_versions"];
  [configFlags cacheConfigValues];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], versionSet);
  [configFlags resetCache];

  valueData = [@";1.0.2;1.0.3;;" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_disabled_ios_versions"];
  [configFlags cacheConfigValues];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], versionSet);
  [configFlags resetCache];

  valueData = [@";;" dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_disabled_ios_versions"];
  [configFlags cacheConfigValues];
  XCTAssertEqualObjects([configFlags sdkDisabledVersionsWithDefaultValue:emptySet], emptySet);
  [configFlags resetCache];
}

@end
