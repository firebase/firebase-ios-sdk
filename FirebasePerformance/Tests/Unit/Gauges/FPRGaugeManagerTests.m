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

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager+Private.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector+Private.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"

#import <OCMock/OCMock.h>
#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"

@interface FPRGaugeManagerTests : FPRTestCase

@end

@implementation FPRGaugeManagerTests

- (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
}

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
}

/* Verify if the instance creation works. */
- (void)testInstanceCreation {
  XCTAssertNotNil([[FPRGaugeManager alloc] initWithGauges:FPRGaugeNone]);
}

/* Verify the default behaviour of the instance. */
- (void)testDefaultValuesOfInstance {
  FPRGaugeManager *manager = [[FPRGaugeManager alloc] initWithGauges:FPRGaugeNone];
  XCTAssertTrue(manager.activeGauges == FPRGaugeNone);
}

/* Verify if gauge collection is disabled when SDK flag is disabled in remote config. */
- (void)testGaugeCollectionEnabledWhenSDKFlagEnabled {
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

  [FPRGaugeManager sharedInstance].isColdStart = NO;
  XCTAssertFalse([FPRGaugeManager sharedInstance].gaugeCollectionEnabled);
}

/* Verify if gauge collection is enabled when SDK flag is enabled in remote config. */
- (void)testGaugeCollectionDisabledWhenSDKFlagDisabled {
  FPRConfigurations *configurations = [FPRConfigurations sharedInstance];
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;

  GULUserDefaults *_Nonnull userDefaults = [[GULUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  [userDefaults setObject:@(TRUE) forKey:configKey];

  [FPRGaugeManager sharedInstance].isColdStart = NO;
  XCTAssertTrue([FPRGaugeManager sharedInstance].gaugeCollectionEnabled);
}

/* Verify if starting to collect gauges API works. */
- (void)testStartCollectingGauges {
  FPRGaugeManager *manager = [FPRGaugeManager sharedInstance];
  [manager startCollectingGauges:FPRGaugeCPU forSessionId:@"abc"];
  XCTAssertTrue((manager.activeGauges & FPRGaugeCPU) == 1);
  XCTAssertTrue((manager.activeGauges & FPRGaugeMemory) == 0);
  XCTAssertNotNil(manager.cpuGaugeCollector);
  XCTAssertNil(manager.memoryGaugeCollector);
  [manager stopCollectingGauges:manager.activeGauges];
}

/* Verify if stopping to collect gauges API works. */
- (void)testStopCollectingGauges {
  FPRGaugeManager *manager = [FPRGaugeManager sharedInstance];
  [manager startCollectingGauges:FPRGaugeCPU | FPRGaugeMemory forSessionId:@"abc"];
  XCTAssertTrue((manager.activeGauges & FPRGaugeCPU) == FPRGaugeCPU);
  XCTAssertTrue((manager.activeGauges & FPRGaugeMemory) == FPRGaugeMemory);
  XCTAssertNotNil(manager.cpuGaugeCollector);
  XCTAssertNotNil(manager.memoryGaugeCollector);

  [manager stopCollectingGauges:FPRGaugeCPU];
  XCTAssertTrue((manager.activeGauges & FPRGaugeCPU) == FPRGaugeNone);
  XCTAssertTrue((manager.activeGauges & FPRGaugeMemory) == FPRGaugeMemory);
  XCTAssertNil(manager.cpuGaugeCollector);
  XCTAssertNotNil(manager.memoryGaugeCollector);

  [manager startCollectingGauges:FPRGaugeMemory forSessionId:@"abc"];
  XCTAssertTrue((manager.activeGauges & FPRGaugeCPU) == FPRGaugeNone);
  XCTAssertTrue((manager.activeGauges & FPRGaugeMemory) == FPRGaugeMemory);
  XCTAssertNil(manager.cpuGaugeCollector);
  XCTAssertNotNil(manager.memoryGaugeCollector);

  [manager stopCollectingGauges:manager.activeGauges];
}

/* Verify if collection of all gauges work. */
- (void)testCollectAllGauges {
  FPRGaugeManager *manager = [FPRGaugeManager sharedInstance];
  [manager startCollectingGauges:FPRGaugeCPU | FPRGaugeMemory forSessionId:@"abc"];
  id cpuMock = [OCMockObject partialMockForObject:manager.cpuGaugeCollector];
  id memoryMock = [OCMockObject partialMockForObject:manager.memoryGaugeCollector];
  OCMStub([cpuMock collectMetric]);
  OCMStub([memoryMock collectMetric]);
  [manager collectAllGauges];
  OCMVerify([cpuMock collectMetric]);
  OCMVerify([memoryMock collectMetric]);
  [manager stopCollectingGauges:manager.activeGauges];
  [cpuMock stopMocking];
  [memoryMock stopMocking];
}

/* Validate if the batching of events work. */
- (void)testBatchingOfGaugeEvents {
  FPRGaugeManager *manager = [FPRGaugeManager sharedInstance];
  id mock = [OCMockObject partialMockForObject:manager];
  OCMExpect([mock prepareAndDispatchCollectedGaugeDataWithSessionId:@"abc"]).andDo(nil);
  [manager startCollectingGauges:FPRGaugeCPU forSessionId:@"abc"];
  [manager.cpuGaugeCollector stopCollecting];
  for (int i = 0; i < kGaugeDataBatchSize; i++) {
    [manager.cpuGaugeCollector collectMetric];
  }
  dispatch_barrier_sync(manager.gaugeDataProtectionQueue, ^{
    OCMVerifyAll(mock);
    [mock stopMocking];
  });
}

/* Validate if the batching of events does not happen when minimum number of events are not met. */
- (void)testBatchingOfGaugeEventsDoesNotHappenLessThanBatchSize {
  FPRGaugeManager *manager = [FPRGaugeManager sharedInstance];
  id mock = [OCMockObject partialMockForObject:manager];
  [manager startCollectingGauges:FPRGaugeCPU forSessionId:@"abc"];
  [manager.cpuGaugeCollector stopCollecting];
  OCMReject([mock prepareAndDispatchCollectedGaugeDataWithSessionId:@"abc"]);
  for (int i = 0; i < kGaugeDataBatchSize - 1; i++) {
    [manager.cpuGaugeCollector collectMetric];
  }
  dispatch_barrier_sync(manager.gaugeDataProtectionQueue, ^{
    OCMVerifyAll(mock);
    [mock stopMocking];
  });
}

@end
