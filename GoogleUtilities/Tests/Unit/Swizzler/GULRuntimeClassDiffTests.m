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

@interface GULRuntimeClassDiffTests : XCTestCase

@end

@implementation GULRuntimeClassDiffTests

/** Tests various different permutations of diff hashes and equality. */
- (void)testHashAndEquality {
  GULRuntimeClassDiff *classDiff1 = [[GULRuntimeClassDiff alloc] init];
  classDiff1.aClass = [self class];
  GULRuntimeClassDiff *classDiff2 = [[GULRuntimeClassDiff alloc] init];
  classDiff2.aClass = [NSObject class];
  XCTAssertNotEqual([classDiff1 hash], [classDiff2 hash]);
  XCTAssertNotEqualObjects(classDiff1, classDiff2);

  classDiff2.aClass = [self class];
  XCTAssertEqual([classDiff1 hash], [classDiff2 hash]);
  XCTAssertEqualObjects(classDiff1, classDiff2);

  classDiff1.addedClassSelectors = [[NSSet alloc] initWithObjects:@"selector", nil];
  XCTAssertNotEqual([classDiff1 hash], [classDiff2 hash]);
  XCTAssertNotEqualObjects(classDiff1, classDiff2);

  classDiff2.addedClassSelectors = [[NSSet alloc] initWithObjects:@"selector", nil];
  XCTAssertEqual([classDiff1 hash], [classDiff2 hash]);
  XCTAssertEqualObjects(classDiff1, classDiff2);

  classDiff1.modifiedImps = [[NSSet alloc] initWithObjects:@"someImp", nil];
  XCTAssertNotEqual([classDiff1 hash], [classDiff2 hash]);
  XCTAssertNotEqualObjects(classDiff1, classDiff2);

  classDiff2.modifiedImps = [[NSSet alloc] initWithObjects:@"someImp", nil];
  XCTAssertEqual([classDiff1 hash], [classDiff2 hash]);
  XCTAssertEqualObjects(classDiff1, classDiff2);
}

@end
