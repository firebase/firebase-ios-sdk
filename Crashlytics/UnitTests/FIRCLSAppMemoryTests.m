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

#import "Crashlytics/Crashlytics/Components/FIRCLSAppMemory.h"

@interface FIRCLSAppMemoryTests : XCTestCase
@end

@implementation FIRCLSAppMemoryTests

static FIRCLSAppMemory *AppMemoryLevel(uint64_t footprint, uint64_t limit) {
  return [[FIRCLSAppMemory alloc] initWithFootprint:footprint
                                          remaining:limit - footprint
                                           pressure:FIRCLSAppMemoryPressureNormal];
}

- (void)testSerialize {
  FIRCLSAppMemory *const appMemory = AppMemoryLevel(50, 100);
  NSDictionary<NSString *, id> *const actual = [appMemory serialize];

  XCTAssertEqual(appMemory.footprint,
                 ((NSNumber *)actual[@"memory_footprint"]).unsignedLongLongValue);
  XCTAssertEqual(appMemory.remaining,
                 ((NSNumber *)actual[@"memory_remaining"]).unsignedLongLongValue);
  XCTAssertEqual(appMemory.limit, ((NSNumber *)actual[@"memory_limit"]).unsignedLongLongValue);
  XCTAssertEqual(appMemory.level, FIRCLSAppMemoryLevelFromString(actual[@"memory_level"]));
  XCTAssertEqual(appMemory.pressure, FIRCLSAppMemoryPressureFromString(actual[@"memory_pressure"]));
}

- (void)testLevelCalculations {
  XCTAssertEqual(AppMemoryLevel(0, 100).level, FIRCLSAppMemoryLevelNormal);
  XCTAssertEqual(AppMemoryLevel(25, 100).level, FIRCLSAppMemoryLevelWarn);
  XCTAssertEqual(AppMemoryLevel(50, 100).level, FIRCLSAppMemoryLevelUrgent);
  XCTAssertEqual(AppMemoryLevel(75, 100).level, FIRCLSAppMemoryLevelCritical);
  XCTAssertEqual(AppMemoryLevel(95, 100).level, FIRCLSAppMemoryLevelTerminal);
}

@end
