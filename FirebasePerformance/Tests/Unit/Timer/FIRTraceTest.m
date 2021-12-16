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

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"
#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRTrace.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"
#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"

#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"

#import <OCMock/OCMock.h>

@interface FIRTraceTest : FPRTestCase

@end

@implementation FIRTraceTest

- (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
  [[FPRClient sharedInstance] disableInstrumentation];
}

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
  [[FPRClient sharedInstance] disableInstrumentation];
}

/** Validates that init with a valid name returns a trace. */
- (void)testInit {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  XCTAssertNotNil(trace);
}

/** Validates that init with an empty name throws exception. */
- (void)testInitWithEmptyName {
  XCTAssertThrows([[FIRTrace alloc] initWithName:@""]);
}

#pragma mark - Trace creation tests

/** Validates if trace creation fails when SDK flag is disabled in remote config. */
- (void)testTraceCreationWhenSDKFlagDisabled {
  FPRConfigurations *configurations = [FPRConfigurations sharedInstance];
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;
  configurations.remoteConfigFlags = configFlags;

  NSData *valueData = [@"false" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_enabled"];

  // Trigger the RC config fetch
  remoteConfig.lastFetchTime = nil;
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;
  [configFlags update];

  XCTAssertNil([[FIRTrace alloc] initWithName:@"Random"]);
}

/** Validates if trace creation succeeds when SDK flag is enabled in remote config. */
- (void)testTraceCreationWhenSDKFlagEnabled {
  FPRConfigurations *configurations = [FPRConfigurations sharedInstance];
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  [userDefaults setObject:@(TRUE) forKey:configKey];

  XCTAssertNotNil([[FIRTrace alloc] initWithName:@"Random"]);
}

/** Validates if trace creation fails when SDK flag is enabled in remote config, but data collection
 * disabled. */
- (void)testTraceCreationWhenSDKFlagEnabledWithDataCollectionDisabled {
  [[FIRPerformance sharedInstance] setDataCollectionEnabled:NO];
  FPRConfigurations *configurations = [FPRConfigurations sharedInstance];
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;

  NSData *valueData = [@"true" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_enabled"];

  XCTAssertNil([[FIRTrace alloc] initWithName:@"Random"]);
}

#pragma mark - Stages related testing

/** Validates that stages are created. */
- (void)testStaging {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace startStageNamed:@"1"];
  [trace startStageNamed:@"2"];
  [trace stop];
  XCTAssertEqual(trace.stages.count, 2);
}

/** Validates that stages are not created without calling a start on the trace. */
- (void)testStageWithoutStart {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace startStageNamed:@"1"];
  XCTAssertEqual(trace.stages.count, 0);
}

/** Validates that stages are not created without calling a start on the trace, but calling stop. */
- (void)testStageWithoutStartWithStop {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace startStageNamed:@"1"];
  [trace stop];
  XCTAssertEqual(trace.stages.count, 0);
}

/** Validates that stages are not created after calling stop on the trace. */
- (void)testStageAfterStop {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace startStageNamed:@"1"];
  [trace startStageNamed:@"2"];
  [trace stop];
  [trace startStageNamed:@"3"];
  XCTAssertEqual(trace.stages.count, 2);
}

/** Validates that stopping a stage does not trigger an event being sent to Fll */
- (void)testStageStopDoesNotTriggerEventSend {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  id mock = [OCMockObject partialMockForObject:[FPRClient sharedInstance]];
  OCMStub([mock logTrace:[OCMArg any]]).andDo(nil);
  [trace start];
  [trace startStageNamed:@"1"];
  [[mock reject] logTrace:trace.activeStage];
  [trace startStageNamed:@"2"];
  [trace stop];
}

/** Validates that stopping a trace does trigger an event being sent to Fll. */
- (void)testTraceStopDoesTriggerEventSend {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  id mock = [OCMockObject partialMockForObject:[FPRClient sharedInstance]];
  OCMStub([mock logTrace:[OCMArg any]]).andDo(nil);
  [trace start];
  [trace startStageNamed:@"1"];
  [trace startStageNamed:@"2"];
  [trace stop];
  OCMVerify([mock logTrace:trace]);
}

/** Validates that the name of the trace is dropped if its length is above max admissible length. */
- (void)testNameLengthMax {
  NSString *testName = [@"abc" stringByPaddingToLength:kFPRMaxNameLength + 1
                                            withString:@"-"
                                       startingAtIndex:0];
  XCTAssertThrows([[FIRTrace alloc] initWithName:testName]);
}

/** Validates that the name cannot have a prefix of underscore. */
- (void)testNamePrefixSrtipped {
  NSString *testName = [NSString stringWithFormat:@"%@test", kFPRInternalNamePrefix];
  XCTAssertThrows([[FIRTrace alloc] initWithName:testName]);
}

#pragma mark - Metric related testing

/** Validates that metric with greater than max length is not created on setMetric. */
- (void)testSetMetricNameLengthMax {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  NSString *testName = [@"abc" stringByPaddingToLength:kFPRMaxNameLength + 1
                                            withString:@"-"
                                       startingAtIndex:0];
  [trace start];
  [trace setIntValue:10 forMetric:testName];
  [trace stop];
  XCTAssertNil([trace.counters objectForKey:testName]);
}

/** Validates that metric with empty name is not created on setMetric. */
- (void)testSetOrIncrementMetricNameLengthZero {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  NSString *testName = @"";
  [trace start];
  [trace setIntValue:10 forMetric:testName];
  [trace incrementMetric:testName byInt:10];
  [trace stop];
  XCTAssertNil([trace.counters objectForKey:testName]);
}

/** Validates that metrics are not set when a trace is not started. */
- (void)testSetOrIncrementMetricWithoutStart {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setIntValue:10 forMetric:@"testing"];
  [trace incrementMetric:@"testing" byInt:10];
  [trace stop];
  XCTAssertNil([trace.counters objectForKey:@"testing"]);
}

/** Validates that calling get on a metric returns 0 if it hasnt been reviously set. */
- (void)testGetMetricWhenSetHasntBeenCalledReturnsZero {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  int64_t metricValue = [trace valueForIntMetric:@"testing"];
  [trace stop];
  XCTAssertEqual(metricValue, 0);
}

/** Validates that calling get on a metric without calling set doesn't create a new metric. */
- (void)testGetMetricWhenSetHasntBeenCalledDoesntCreateMetric {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace valueForIntMetric:@"testing"];
  [trace stop];
  id metricValue = [trace.counters objectForKey:@"testing"];
  XCTAssertNil(metricValue);
}

/** Tests that calling set multiple times on a metric results in it holding just the last value. */
- (void)testMultipleSetsOnAMetricResultInHoldingJustTheLastValue {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace setIntValue:10 forMetric:@"testing"];
  [trace setIntValue:100 forMetric:@"testing"];
  [trace stop];
  int64_t metricValue = [trace valueForIntMetric:@"testing"];
  XCTAssertEqual(metricValue, 100);
}

/** Validates that incrementing a metric that has been previously set increments previous value. */
- (void)testIncrementingAfterSettingMetric {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace setIntValue:10 forMetric:@"testing"];
  [trace incrementMetric:@"testing" byInt:25];
  [trace stop];
  int64_t metricValue = [trace valueForIntMetric:@"testing"];
  XCTAssertEqual(metricValue, 35);
}

/** Validates that calling setMetric on a trace also sets it on the active stage. */
- (void)testSetMetricCalledOnTraceAlsoSetsMetricOnStage {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace startStageNamed:@"stage 1"];
  [trace setIntValue:35 forMetric:@"testing"];
  [trace startStageNamed:@"stage 2"];
  [trace setIntValue:40 forMetric:@"testing"];
  [trace stop];
  XCTAssertEqual([trace valueForIntMetric:@"testing"], 40);
  for (FIRTrace *stage in trace.stages) {
    if ([stage.name isEqualToString:@"stage 1"]) {
      XCTAssertEqual([stage valueForIntMetric:@"testing"], 35);
    } else if ([stage.name isEqualToString:@"stage 2"]) {
      XCTAssertEqual([stage valueForIntMetric:@"testing"], 40);
    }
  }
}

/** Validates that deleting a metric deletes it. */
- (void)testDeleteMetricDeletesAMetric {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace setIntValue:1 forMetric:@"testing"];
  [trace deleteMetric:@"testing"];
  [trace stop];
  XCTAssertNil(trace.counters[@"testing"]);
}

/** Validates that deleting a metric doesnt affect other metrics. */
- (void)testDeleteMetricDoesntDeleteAnotherMetric {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace setIntValue:1 forMetric:@"testing"];
  [trace setIntValue:1 forMetric:@"testing2"];
  [trace deleteMetric:@"testing"];
  [trace stop];
  XCTAssertNil(trace.counters[@"testing"]);
  XCTAssertEqual([trace valueForIntMetric:@"testing2"], 1);
}

/** Validates that trying to delete a non-existent metric doesnt affect anything. */
- (void)testDeletingMetricThatDoesntExistDoesntDoAnything {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace setIntValue:1 forMetric:@"testing"];
  [trace deleteMetric:@"testing2"];
  [trace stop];
  XCTAssertEqual([trace valueForIntMetric:@"testing"], 1);
}

/** Tests deleting a metric also deletes it from the active stage if it exists. */
- (void)testDeleteMetricAlsoDeletesItFromActiveStage {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace startStageNamed:@"stage 1"];
  FIRTrace *activeStage = trace.activeStage;
  [trace setIntValue:1 forMetric:@"testing"];
  [trace setIntValue:1 forMetric:@"testing2"];
  [trace deleteMetric:@"testing"];
  [trace stop];
  XCTAssertEqual([trace valueForIntMetric:@"testing2"], 1);
  XCTAssertEqual([activeStage valueForIntMetric:@"testing2"], 1);
  XCTAssertNil(trace.counters[@"testing"]);
  XCTAssertNil(activeStage.counters[@"testing"]);
}

/** Tests that deleteMetric has no effect after the trace has been stopped. */
- (void)testDeleteMetricDoesNothingAfterTraceHasBeenStopped {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace setIntValue:1 forMetric:@"testing"];
  [trace stop];
  [trace deleteMetric:@"testing"];
  XCTAssertEqual([trace valueForIntMetric:@"testing"], 1);
}

#pragma mark - Metrics related testing

/** Validates that counters are incremented. */
- (void)testMetricNameLengthMax {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  NSString *testName = [@"abc" stringByPaddingToLength:kFPRMaxNameLength + 1
                                            withString:@"-"
                                       startingAtIndex:0];
  [trace start];
  [trace incrementMetric:testName byInt:5];
  [trace stop];
  XCTAssertNil([trace.counters objectForKey:testName]);
}

/** Validates that traces could start with a custom start time. */
- (void)testStartTraceWithStartTimeAndStageDefined {
  NSDate *traceStartTime = [NSDate date];
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"testTrace"];
  [trace startWithStartTime:traceStartTime];
  XCTAssertEqual(trace.startTimeSinceEpoch, [traceStartTime timeIntervalSince1970]);
  [trace startStageNamed:@"testStage" startTime:traceStartTime];
  [trace stop];
  XCTAssertEqual(trace.stages.count, 1);
  FIRTrace *stage = trace.stages.lastObject;
  XCTAssertEqual(stage.startTimeSinceEpoch, [traceStartTime timeIntervalSince1970]);
}

- (void)testMetrics {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace incrementMetric:@"testing" byInt:3];
  [trace incrementMetric:@"testing" byInt:2];
  [trace stop];
  NSUInteger metricValue = [[trace.counters objectForKey:@"testing"] integerValue];
  XCTAssertEqual(metricValue, 5);
}

/** Validates that metrics are not incremented when a trace is not started. */
- (void)testMetricsWithoutStart {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace incrementMetric:@"testing" byInt:3];
  [trace incrementMetric:@"testing" byInt:2];
  [trace stop];
  NSUInteger metricValue = [[trace.counters objectForKey:@"testing"] integerValue];
  XCTAssertEqual(metricValue, 0);
}

/** Validates that trace without complete data is invalid. */
- (void)testInvalidTraceValidationCheck {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace stop];
  XCTAssertFalse([trace isCompleteAndValid]);
}

/** Validates that valid traces with stages and metrics are marked as valid. */
- (void)testValidTraceWithStageAndMetrics {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace incrementMetric:@"counter 1" byInt:1];
  [trace incrementMetric:@"counter 2" byInt:1];
  [trace startStageNamed:@"1"];
  [trace incrementMetric:@"counter 1" byInt:1];
  [trace incrementMetric:@"counter 2" byInt:1];
  [trace startStageNamed:@"2"];
  [trace incrementMetric:@"counter 1" byInt:1];
  [trace incrementMetric:@"counter 2" byInt:1];
  [trace stop];
  XCTAssertTrue([trace isCompleteAndValid]);
}

/** Validates the value of background state when the app is backgrounded. */
- (void)testValidTraceWithBackgrounding {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  XCTAssertEqual(trace.backgroundTraceState, FPRTraceStateBackgroundAndForeground);
  [trace stop];
}

/** Validates the value of background state when trace is not started. */
- (void)testValidTraceWithoutStart {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  [trace stop];
  XCTAssertEqual(trace.backgroundTraceState, FPRTraceStateUnknown);
}

/** Validates the value of background state is available after trace is stopped. */
- (void)testBackgroundStateAfterTraceStop {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  [trace stop];
  XCTAssertEqual(trace.backgroundTraceState, FPRTraceStateBackgroundAndForeground);
}

/** Validates that stages do not have any valid background state. */
- (void)testValidTraceWithActiveStageHavingNoBackgroundState {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace startStageNamed:@"RandomStage"];
  [defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  [trace stop];
  XCTAssertEqual(trace.stages.count, 1);
  FIRTrace *activeStage = [trace.stages lastObject];
  XCTAssertEqual(activeStage.backgroundTraceState, FPRTraceStateUnknown);
}

/** Validates that internal trace names allow the reserved prefix value. */
- (void)testInternalTraceCreationWithInternalPrefix {
  FIRTrace *trace = [[FIRTrace alloc] initInternalTraceWithName:@"_Random"];
  XCTAssertNotNil(trace);
  NSString *metricName = @"_counter";
  [trace start];
  [trace startStageNamed:@"_1"];
  [trace incrementMetric:metricName byInt:5];
  [trace stop];

  XCTAssertEqual(trace.stages.count, 1);
  FIRTrace *stage1 = [trace.stages lastObject];
  XCTAssertEqual(stage1.name, @"_1");
  NSUInteger metricValue = [[trace.counters objectForKey:metricName] integerValue];
  XCTAssertEqual(metricValue, 5);
}

/** Validates if the metric is incremented if a trace is started but not stopped. */
- (void)testTraceStartedNotStoppedIncrementsAMetric {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  FIRTrace *activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  NSNumber *metric = [activeTrace.counters objectForKey:kFPRAppCounterNameTraceNotStopped];
  NSInteger metricValue = [metric integerValue];
  __weak FIRTrace *weakReferencedTrace;
  @autoreleasepool {
    FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
    weakReferencedTrace = trace;
    [trace start];
    [trace startStageNamed:@"1"];
  }

  XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation - Wait for 2s"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [expectation fulfill];
                   XCTAssertNil(weakReferencedTrace);
                 });
  [self waitForExpectationsWithTimeout:10.0 handler:nil];

  NSNumber *updatedMetric = [activeTrace.counters objectForKey:kFPRAppCounterNameTraceNotStopped];
  NSInteger updatedMetricValue = [updatedMetric integerValue];
  XCTAssertEqual(updatedMetricValue - metricValue, 1);
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
}

/** Validates if the metric is not incremented if a trace is started and stopped. */
- (void)testTraceStartedAndStoppedDoesNotIncrementAMetric {
  FIRTrace *activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  NSNumber *metric = [activeTrace.counters objectForKey:kFPRAppCounterNameTraceNotStopped];
  NSInteger metricValue = [metric integerValue];
  __weak FIRTrace *weakReferencedTrace;
  @autoreleasepool {
    FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
    weakReferencedTrace = trace;
    [trace start];
    [trace startStageNamed:@"1"];
    [trace stop];
  }
  NSNumber *updatedMetric = [activeTrace.counters objectForKey:kFPRAppCounterNameTraceNotStopped];
  NSInteger updatedMetricValue = [updatedMetric integerValue];
  XCTAssertEqual(updatedMetricValue - metricValue, 0);
}

#pragma mark - Custom attribute related testing

/** Validates if setting a valid attribute before calling start works. */
- (void)testSettingValidAttributeBeforeStart {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"bar" forAttribute:@"foo"];
  XCTAssertEqual([trace valueForAttribute:@"foo"], @"bar");
}

/** Validates if setting a valid attribute works between start/stop works. */
- (void)testSettingValidAttributeBetweenStartAndStop {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace setValue:@"bar" forAttribute:@"foo"];
  XCTAssertEqual([trace valueForAttribute:@"foo"], @"bar");
  [trace stop];
}

/** Validates if setting a valid attribute works after stop is a no-op. */
- (void)testSettingValidAttributeBetweenAfterStop {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace stop];
  [trace setValue:@"bar" forAttribute:@"foo"];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
}

/** Validates if attributes property access works. */
- (void)testReadingAttributesFromProperty {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  XCTAssertNotNil(trace.attributes);
  XCTAssertEqual(trace.attributes.count, 0);
  [trace setValue:@"bar" forAttribute:@"foo"];
  NSDictionary<NSString *, NSString *> *attributes = trace.attributes;
  XCTAssertEqual(attributes.allKeys.count, 1);
}

/** Validates if attributes property is immutable. */
- (void)testImmutablityOfAttributesProperty {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"bar" forAttribute:@"foo"];
  NSMutableDictionary<NSString *, NSString *> *attributes =
      (NSMutableDictionary<NSString *, NSString *> *)trace.attributes;
  XCTAssertThrows([attributes setValue:@"bar1" forKey:@"foo"]);
}

/** Validates if updating attribute value works. */
- (void)testUpdatingAttributeValue {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"bar" forAttribute:@"foo"];
  [trace setValue:@"baz" forAttribute:@"foo"];
  XCTAssertEqual([trace valueForAttribute:@"foo"], @"baz");
  [trace setValue:@"qux" forAttribute:@"foo"];
  XCTAssertEqual([trace valueForAttribute:@"foo"], @"qux");
}

/** Validates if removing attributes work before call to start. */
- (void)testRemovingAttributeBeforeStart {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"bar" forAttribute:@"foo"];
  [trace removeAttribute:@"foo"];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
  [trace removeAttribute:@"foo"];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
}

/** Validates if removing attributes work between start and stop calls. */
- (void)testRemovingAttributeBetweenStartStop {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"bar" forAttribute:@"foo"];
  [trace start];
  [trace removeAttribute:@"foo"];
  [trace stop];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
}

/** Validates if removing attributes is a no-op after stop. */
- (void)testRemovingAttributeBetweenAfterStop {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"bar" forAttribute:@"foo"];
  [trace start];
  [trace stop];
  [trace removeAttribute:@"foo"];
  XCTAssertEqual([trace valueForAttribute:@"foo"], @"bar");
}

/** Validates if removing non-existing attributes works. */
- (void)testRemovingNonExistingAttribute {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace removeAttribute:@"foo"];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
  [trace removeAttribute:@"foo"];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
}

/** Validates if using reserved prefix in attribute prefix will drop the attribute. */
- (void)testAttributeNamePrefixSrtipped {
  NSArray<NSString *> *reservedPrefix = @[ @"firebase_", @"google_", @"ga_" ];

  [reservedPrefix enumerateObjectsUsingBlock:^(NSString *prefix, NSUInteger idx, BOOL *stop) {
    NSString *attributeName = [NSString stringWithFormat:@"%@name", prefix];
    NSString *attributeValue = @"value";

    FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
    [trace setValue:attributeValue forAttribute:attributeName];
    XCTAssertNil([trace valueForAttribute:attributeName]);
  }];
}

/** Validates if long attribute names gets dropped. */
- (void)testMaxLengthForAttributeName {
  NSString *testName = [@"abc" stringByPaddingToLength:kFPRMaxAttributeNameLength + 1
                                            withString:@"-"
                                       startingAtIndex:0];
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"bar" forAttribute:testName];
  XCTAssertNil([trace valueForAttribute:testName]);
}

/** Validates if attribute names with illegal characters gets dropped. */
- (void)testIllegalCharactersInAttributeName {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"bar" forAttribute:@"foo_"];
  XCTAssertEqual([trace valueForAttribute:@"foo_"], @"bar");
  [trace setValue:@"bar" forAttribute:@"foo_$"];
  XCTAssertNil([trace valueForAttribute:@"foo_$"]);
  [trace setValue:@"bar" forAttribute:@"FOO_$"];
  XCTAssertNil([trace valueForAttribute:@"FOO_$"]);
  [trace setValue:@"bar" forAttribute:@"FOO_"];
  XCTAssertEqual([trace valueForAttribute:@"FOO_"], @"bar");
}

/** Validates if long attribute values gets truncated. */
- (void)testMaxLengthForAttributeValue {
  NSString *testValue = [@"abc" stringByPaddingToLength:kFPRMaxAttributeValueLength + 1
                                             withString:@"-"
                                        startingAtIndex:0];
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:testValue forAttribute:@"foo"];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
}

/** Validates if empty name or value of the attributes are getting dropped. */
- (void)testAttributesWithEmptyValues {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace setValue:@"" forAttribute:@"foo"];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
  [trace setValue:@"bar" forAttribute:@""];
  XCTAssertNil([trace valueForAttribute:@""]);
}

/** Validates if the limit the maximum number of attributes work. */
- (void)testMaximumNumberOfAttributes {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  for (int i = 0; i < kFPRMaxGlobalCustomAttributesCount; i++) {
    NSString *attributeName = [NSString stringWithFormat:@"dim%d", i];
    [trace setValue:@"bar" forAttribute:attributeName];
    XCTAssertEqual([trace valueForAttribute:attributeName], @"bar");
  }
  [trace setValue:@"bar" forAttribute:@"foo"];
  XCTAssertNil([trace valueForAttribute:@"foo"]);
}

/** Validates if removing old attributes and adding new attributes work. */
- (void)testRemovingAndAddingAttributes {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  for (int i = 0; i < kFPRMaxGlobalCustomAttributesCount; i++) {
    NSString *attributeName = [NSString stringWithFormat:@"dim%d", i];
    [trace setValue:@"bar" forAttribute:attributeName];
    XCTAssertEqual([trace valueForAttribute:attributeName], @"bar");
  }
  [trace removeAttribute:@"dim1"];
  [trace setValue:@"bar" forAttribute:@"foo"];
  XCTAssertEqual([trace valueForAttribute:@"foo"], @"bar");
}

/** Validates if every trace contains a session Id. */
- (void)testSessionId {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];

  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];

  [trace stop];
  XCTAssertNotNil(trace.sessions);
  XCTAssertTrue(trace.sessions.count > 0);
}

/** Validates if every trace contains multiple session Ids on changing app state. */
- (void)testMultipleSessionIds {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                               object:[UIApplication sharedApplication]];

  [defaultCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                               object:[UIApplication sharedApplication]];

  XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation - Wait for 2s"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [expectation fulfill];
                   [trace stop];
                   XCTAssertNotNil(trace.sessions);
                   XCTAssertTrue(trace.sessions.count >= 2);
                 });
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end
