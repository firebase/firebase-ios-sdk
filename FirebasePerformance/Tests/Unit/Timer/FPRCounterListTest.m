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

#import "FirebasePerformance/Sources/FIRPerformance+Internal.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"
#import "FirebasePerformance/Sources/Timer/FPRCounterList.h"

@interface FPRCounterListTest : XCTestCase

@end

@implementation FPRCounterListTest

+ (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
  [[FPRClient sharedInstance] disableInstrumentation];
}

+ (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
  [[FPRClient sharedInstance] disableInstrumentation];
}

/** Validates counterlist object creation. */
- (void)testInit {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  XCTAssertNotNil(counterList);
}

/** Validates the initial state of counter list. */
- (void)testInitialState {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  XCTAssertTrue(counterList.counters.count == 0);
}

/** Validates that the counter values are incremented correctly. */
- (void)testCounters {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList incrementCounterNamed:@"testing" by:1];
  [counterList incrementCounterNamed:@"testing" by:5];
  [counterList incrementCounterNamed:@"testing 2" by:1];
  NSUInteger counterValue1 = [[counterList.counters objectForKey:@"testing"] integerValue];
  XCTAssertEqual(counterValue1, 6);

  NSUInteger counterValue2 = [[counterList.counters objectForKey:@"testing 2"] integerValue];
  XCTAssertEqual(counterValue2, 1);

  NSUInteger counterValue3 = [[counterList.counters objectForKey:@"Random"] integerValue];
  XCTAssertEqual(counterValue3, 0);
}

/** Tests that metrics are set correctly. */
- (void)testSetMetric {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList setIntValue:10 forMetric:@"testing"];
  [counterList setIntValue:12 forMetric:@"testing 2"];
  int64_t metricValue1 = [[counterList.counters objectForKey:@"testing"] longLongValue];
  XCTAssertEqual(metricValue1, 10);

  int64_t metricValue2 = [[counterList.counters objectForKey:@"testing 2"] longLongValue];
  XCTAssertEqual(metricValue2, 12);
}

/** Tests that metrics are incremented correctly. */
- (void)testIncrementMetric {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList setIntValue:10 forMetric:@"testing"];
  [counterList incrementMetric:@"testing" byInt:10];
  int64_t metricValue1 = [[counterList.counters objectForKey:@"testing"] longLongValue];
  XCTAssertEqual(metricValue1, 20);
}

/** Tests getting metric after having set it. */
- (void)testGetMetric {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList setIntValue:10 forMetric:@"testing"];
  [counterList incrementMetric:@"testing" byInt:10];
  XCTAssertEqual([counterList valueForIntMetric:@"testing"], 20);
}

/** Validates deleting a non existent metric doesnt affect other metrics. */
- (void)testDeleteNonExistentMetricDoesntAffectOtherMetrics {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList setIntValue:10 forMetric:@"testing"];
  [counterList deleteMetric:@"testing2"];
  XCTAssertEqual([counterList valueForIntMetric:@"testing"], 10);
}

/** Validates deleteMetric deletes a metric. */
- (void)testDeleteExistingMetric {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList setIntValue:10 forMetric:@"testing"];
  [counterList deleteMetric:@"testing"];
  XCTAssertEqual([counterList valueForIntMetric:@"testing"], 0);
  XCTAssertNil(counterList.counters[@"testing"]);
}

/** Validates deleting existing metric only deletes that metric. */
- (void)testDeleteExistingMetricDoesntDeleteOtherMetric {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList setIntValue:10 forMetric:@"testing"];
  [counterList setIntValue:10 forMetric:@"testing2"];
  [counterList deleteMetric:@"testing"];
  XCTAssertNil(counterList.counters[@"testing"]);
  XCTAssertEqual([counterList valueForIntMetric:@"testing2"], 10);
}

/** Validates passing nil to metricName doesn't do anything. */
- (void)testDeleteMetricWithNilNameDoesntDoAnything {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList setIntValue:10 forMetric:@"testing"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  [counterList deleteMetric:nil];
#pragma clang diagnostic pop
  XCTAssertEqual([counterList valueForIntMetric:@"testing"], 10);
}

/** Validates that the counters are valid when then have valid data. */
- (void)testCounterValidity {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList incrementCounterNamed:@"testing" by:1];
  [counterList incrementCounterNamed:@"testing" by:1];
  [counterList incrementCounterNamed:@"testing 2" by:1];
  [counterList setIntValue:-44 forMetric:@"testing"];
  XCTAssertTrue([counterList isValid]);
}

/** Validates if the counter increment with negative value reduces the value. */
- (void)testCounterIncrementWithNegativeValue {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList incrementCounterNamed:@"testing" by:5];
  [counterList incrementCounterNamed:@"testing" by:-1];
  NSUInteger counterValue1 = [[counterList.counters objectForKey:@"testing"] integerValue];
  XCTAssertEqual(counterValue1, 4);
}

/** Validates if the counter initialize with negative value works. */
- (void)testCounterInitializeWithNegativeValue {
  FPRCounterList *counterList = [[FPRCounterList alloc] init];
  [counterList incrementCounterNamed:@"testing" by:-1];
  NSUInteger counterValue1 = [[counterList.counters objectForKey:@"testing"] integerValue];
  XCTAssertEqual(counterValue1, -1);
}

@end
