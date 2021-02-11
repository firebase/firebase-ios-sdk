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

#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeData.h"

@interface FPRMemoryGaugeDataTests : XCTestCase

@end

@implementation FPRMemoryGaugeDataTests

/** Validates that the instance creation works. */
- (void)testInstanceCreation {
  NSDate *date = [NSDate date];
  FPRMemoryGaugeData *gaugeData = [[FPRMemoryGaugeData alloc] initWithCollectionTime:date
                                                                            heapUsed:1024
                                                                       heapAvailable:4096];
  XCTAssertNotNil(gaugeData);
  XCTAssertEqualObjects(gaugeData.collectionTime, date);
  XCTAssertEqual(gaugeData.heapUsed, 1024);
  XCTAssertEqual(gaugeData.heapAvailable, 4096);
}

@end
