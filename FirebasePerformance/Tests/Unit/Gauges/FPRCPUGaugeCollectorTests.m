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
#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector+Private.h"
#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector.h"

#import <OCMock/OCMock.h>
#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeConfigurations.h"

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

@interface FPRCPUGaugeCollectorTests : XCTestCase <FPRCPUGaugeCollectorDelegate>

/** Tracker for the number of times a delegate is called. */
@property(nonatomic) NSInteger delegateCalled;

/** Fake configurations flags. */
@property(nonatomic) FPRFakeConfigurations *configurations;

@end

@implementation FPRCPUGaugeCollectorTests

- (void)setUp {
  [super setUp];
  self.delegateCalled = 0;

  self.configurations =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];
  [self.configurations setDataCollectionEnabled:YES];
  [self.configurations setInstrumentationEnabled:YES];
  [self.configurations setCpuSamplingFrequencyInForegroundInMS:100];
  [self.configurations setCpuSamplingFrequencyInBackgroundInMS:0];
}

/** Validates if the instance creation is successful. */
- (void)testInstanceCreation {
  FPRCPUGaugeCollector *collector = [[FPRCPUGaugeCollector alloc] initWithDelegate:self];
  XCTAssertNotNil(collector);
  XCTAssertNotNil(collector.delegate);
}

/** Validates that the delegate call back works after measuring CPU metric. */
- (void)testDelegateCallback {
  FPRCPUGaugeCollector *collector = [[FPRCPUGaugeCollector alloc] initWithDelegate:self];
  XCTAssertFalse(self.delegateCalled);
  [collector collectMetric];
  XCTAssertTrue(self.delegateCalled == 1);
}

/** Validate if the CPU gauge metric collection has necessary fields */
- (void)testCPUMetricData {
  FPRCPUGaugeData *gaugeData = fprCollectCPUMetric();
  XCTAssertNotNil(gaugeData);
  XCTAssertNotNil(gaugeData.collectionTime);
}

/** Validates the performance of the CPU measurement. */
- (void)testPerformanceCPUGaugeCollection {
  FPRCPUGaugeCollector *collector = [[FPRCPUGaugeCollector alloc] initWithDelegate:self];
  uint64_t processTimeNs = dispatch_benchmark(1000, ^{
    [collector collectMetric];
  });
  // Ensure that CPU measurement is less than 500 microseconds every run.
  XCTAssertTrue(processTimeNs < 500000);
}

/** Validate zero value of the frequency of CPU data sampling. */
- (void)testZeroFrequencyOfCPUCollection {
  FPRCPUGaugeCollector *collector = [[FPRCPUGaugeCollector alloc] initWithDelegate:self];
  [self.configurations setCpuSamplingFrequencyInForegroundInMS:0];
  [self.configurations setCpuSamplingFrequencyInBackgroundInMS:0];

  collector.configurations = self.configurations;

  id mock = [OCMockObject partialMockForObject:collector];
  OCMStub([mock collectMetric]);
  [[mock reject] collectMetric];
  [collector updateSamplingFrequencyForApplicationState:FPRApplicationStateBackground];
  [collector updateSamplingFrequencyForApplicationState:FPRApplicationStateForeground];
  [mock verify];
}

/** Validate if the change in application state honors the right frequency. */
- (void)testChangingApplicationStateHonorsUpdatedFrequency {
  [self.configurations setCpuSamplingFrequencyInForegroundInMS:100];
  [self.configurations setCpuSamplingFrequencyInBackgroundInMS:0];
  FPRCPUGaugeCollector *collector = [[FPRCPUGaugeCollector alloc] initWithDelegate:self];
  collector.configurations = self.configurations;

  [collector updateSamplingFrequencyForApplicationState:FPRApplicationStateForeground];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Dummy expectation to wait 3 seconds"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [expectation fulfill];
                   XCTAssertTrue(self.delegateCalled > 15);
                 });
  [self waitForExpectationsWithTimeout:3.0 handler:nil];
}

/** Validate if the change in application state is honored. */
- (void)testChangingApplicationStateHonorsChangeInApplicationState {
  [self.configurations setCpuSamplingFrequencyInForegroundInMS:100];
  [self.configurations setCpuSamplingFrequencyInBackgroundInMS:200];

  FPRCPUGaugeCollector *collector = [[FPRCPUGaugeCollector alloc] initWithDelegate:self];
  collector.configurations = self.configurations;
  [collector updateSamplingFrequencyForApplicationState:FPRApplicationStateForeground];

  __block NSInteger numberOfTimesDelegateCalled = 0;
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Dummy expectation to wait 3 seconds"];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        numberOfTimesDelegateCalled = self.delegateCalled;
        [collector updateSamplingFrequencyForApplicationState:FPRApplicationStateBackground];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                         [expectation fulfill];
                         NSLog(@"Delegate called %d times", (int)self.delegateCalled);
                         XCTAssertTrue(self.delegateCalled - numberOfTimesDelegateCalled > 3);
                       });
      });
  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - FPRCPUGaugeCollectorDelegate methods

- (void)cpuGaugeCollector:(FPRCPUGaugeCollector *)collector gaugeData:(FPRCPUGaugeData *)gaugeData {
  self.delegateCalled++;
}

@end
