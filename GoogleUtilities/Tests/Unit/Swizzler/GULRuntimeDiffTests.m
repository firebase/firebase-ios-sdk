// Copyright 2018 Google LLC
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

#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeClassDiff.h"
#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeDiff.h"

@interface GULRuntimeDiffTests : XCTestCase

@end

@implementation GULRuntimeDiffTests

/** Tests various different permutations of diff hashes and equality. */
- (void)testHashAndEquality {
  GULRuntimeDiff *runtimeDiff1 = [[GULRuntimeDiff alloc] init];
  GULRuntimeDiff *runtimeDiff2 = [[GULRuntimeDiff alloc] init];
  XCTAssertEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertEqualObjects(runtimeDiff1, runtimeDiff2);

  runtimeDiff1.addedClasses = [[NSSet alloc] initWithObjects:@"FakeClass", nil];
  XCTAssertNotEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertNotEqualObjects(runtimeDiff1, runtimeDiff2);

  runtimeDiff2.addedClasses = [[NSSet alloc] initWithObjects:@"FakeClass", nil];
  XCTAssertEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertEqualObjects(runtimeDiff1, runtimeDiff2);

  runtimeDiff1.removedClasses = [[NSSet alloc] initWithObjects:@"FakeClass", nil];
  XCTAssertNotEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertNotEqualObjects(runtimeDiff1, runtimeDiff2);

  runtimeDiff2.removedClasses = [[NSSet alloc] initWithObjects:@"FakeClass", nil];
  XCTAssertEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertEqualObjects(runtimeDiff1, runtimeDiff2);

  runtimeDiff2.classDiffs = [[NSSet alloc] init];
  XCTAssertEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertEqualObjects(runtimeDiff1, runtimeDiff2);

  runtimeDiff1.classDiffs = [[NSSet alloc] init];
  XCTAssertEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertEqualObjects(runtimeDiff1, runtimeDiff2);

  GULRuntimeClassDiff *classDiff1 = [[GULRuntimeClassDiff alloc] init];
  classDiff1.aClass = [self class];
  classDiff1.addedClassSelectors = [[NSSet alloc] initWithObjects:@"selector", nil];

  GULRuntimeClassDiff *classDiff2 = [[GULRuntimeClassDiff alloc] init];
  classDiff2.aClass = [self class];
  classDiff2.addedClassSelectors = [[NSSet alloc] initWithObjects:@"selector2", nil];

  runtimeDiff1.classDiffs = [runtimeDiff1.classDiffs setByAddingObject:classDiff1];
  XCTAssertNotEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertNotEqualObjects(runtimeDiff1, runtimeDiff2);

  runtimeDiff2.classDiffs = [runtimeDiff2.classDiffs setByAddingObject:classDiff1];
  XCTAssertEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertEqualObjects(runtimeDiff1, runtimeDiff2);

  runtimeDiff1.classDiffs = [runtimeDiff1.classDiffs setByAddingObject:classDiff2];
  XCTAssertNotEqual([runtimeDiff1 hash], [runtimeDiff2 hash]);
  XCTAssertNotEqualObjects(runtimeDiff1, runtimeDiff2);
}

@end
