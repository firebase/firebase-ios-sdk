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
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeCollector+Private.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeCollector.h"

#import <OCMock/OCMock.h>
#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeConfigurations.h"

extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

@interface FPRMemoryGaugeCollectorTests : XCTestCase <FPRMemoryGaugeCollectorDelegate>

/** Tracker for the number of times a delegate is called. */
@property(nonatomic) NSInteger delegateCalled;

/** Fake configurations flags. */
@property(nonatomic) FPRFakeConfigurations *configurations;

@end

@implementation FPRMemoryGaugeCollectorTests

- (void)setUp {
  [super setUp];
  self.delegateCalled = 0;

  self.configurations =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceRemoteConfig];
  [self.configurations setDataCollectionEnabled:YES];
  [self.configurations setInstrumentationEnabled:YES];
  [self.configurations setMemorySamplingFrequencyInForegroundInMS:100];
  [self.configurations setMemorySamplingFrequencyInBackgroundInMS:0];
}

/** Validates if the instance creation is successful. */
- (void)testInstanceCreation {
  FPRMemoryGaugeCollector *collector = [[FPRMemoryGaugeCollector alloc] initWithDelegate:self];
  XCTAssertNotNil(collector);
  XCTAssertNotNil(collector.delegate);
}

/** Validates that the delegate call back works after measuring memory metric. */
- (void)testDelegateCallback {
  FPRMemoryGaugeCollector *collector = [[FPRMemoryGaugeCollector alloc] initWithDelegate:self];
  XCTAssertFalse(self.delegateCalled);
  [collector collectMetric];
  XCTAssertTrue(self.delegateCalled == 1);
}

/** Validate if the memory gauge metric collection has necessary fields */
- (void)testMemoryMetricData {
  FPRMemoryGaugeData *gaugeData = fprCollectMemoryMetric();
  XCTAssertNotNil(gaugeData);
  XCTAssertNotNil(gaugeData.collectionTime);
}

/** Validates the performance of the memory measurement. */
- (void)testPerformanceMemoryGaugeCollection {
  FPRMemoryGaugeCollector *collector = [[FPRMemoryGaugeCollector alloc] initWithDelegate:self];
  uint64_t processTimeNs = dispatch_benchmark(1000, ^{
    [collector collectMetric];
  });
  // Ensure that memory measurement is less than 500 microseconds every run.
  XCTAssertTrue(processTimeNs < 500000);
}

/** Validate zero value of the frequency of memory data sampling. */
- (void)testZeroFrequencyOfMemoryCollection {
  [self.configurations setMemorySamplingFrequencyInForegroundInMS:0];
  [self.configurations setMemorySamplingFrequencyInBackgroundInMS:0];

  FPRMemoryGaugeCollector *collector = [[FPRMemoryGaugeCollector alloc] initWithDelegate:self];
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
  [self.configurations setMemorySamplingFrequencyInForegroundInMS:100];
  [self.configurations setMemorySamplingFrequencyInBackgroundInMS:0];

  FPRMemoryGaugeCollector *collector = [[FPRMemoryGaugeCollector alloc] initWithDelegate:self];
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
  [self.configurations setMemorySamplingFrequencyInForegroundInMS:100];
  [self.configurations setMemorySamplingFrequencyInBackgroundInMS:200];

  FPRMemoryGaugeCollector *collector = [[FPRMemoryGaugeCollector alloc] initWithDelegate:self];
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

#pragma mark - FPRMemoryGaugeCollectorDelegate methods

- (void)memoryGaugeCollector:(FPRMemoryGaugeCollector *)collector
                   gaugeData:(FPRMemoryGaugeData *)gaugeData {
  self.delegateCalled++;
}

@end
