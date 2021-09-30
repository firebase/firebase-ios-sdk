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

#import "FirebasePerformance/Sources/Loggers/FPRGDTEvent.h"

#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"

@interface FPRGDTEventTest : XCTestCase

@end

@implementation FPRGDTEventTest

/** Tests the designated initializer. */
- (void)testInstanceCreation {
  firebase_perf_v1_PerfMetric metric = firebase_perf_v1_PerfMetric_init_default;
  FPRGDTEvent *event = [FPRGDTEvent gdtEventForPerfMetric:metric];

  XCTAssertNotNil(event);
}

/** Validate that the instance has transportBytes for default Perf Metric. */
- (void)testInstanceHasTransportBytesForDefaultPerfMetric {
  firebase_perf_v1_PerfMetric metric = firebase_perf_v1_PerfMetric_init_default;
  FPRGDTEvent *event = [FPRGDTEvent gdtEventForPerfMetric:metric];

  XCTAssertTrue([event transportBytes] > 0);
}

/** Validate that the instance has transportBytes for valid Perf Metric. */
- (void)testInstanceHasTransportBytesForValidPerfMetric {
  firebase_perf_v1_PerfMetric metric = [FPRTestUtils createRandomPerfMetric:@"t1"];
  FPRGDTEvent *event = [FPRGDTEvent gdtEventForPerfMetric:metric];

  XCTAssertTrue([event transportBytes] > 0);
}

@end
