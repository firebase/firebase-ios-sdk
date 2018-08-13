/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <FirebaseFirestore/FIRDocumentSnapshot.h>

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDocumentSnapshotTests : XCTestCase
@end

@implementation FIRDocumentSnapshotTests

- (void)testEquals {
  FIRDocumentSnapshot *base = FSTTestDocSnapshot("rooms/foo", 1, @{@"a" : @1}, NO, NO);
  FIRDocumentSnapshot *baseDup = FSTTestDocSnapshot("rooms/foo", 1, @{@"a" : @1}, NO, NO);
  FIRDocumentSnapshot *nilData = FSTTestDocSnapshot("rooms/foo", 1, nil, NO, NO);
  FIRDocumentSnapshot *nilDataDup = FSTTestDocSnapshot("rooms/foo", 1, nil, NO, NO);
  FIRDocumentSnapshot *differentPath = FSTTestDocSnapshot("rooms/bar", 1, @{@"a" : @1}, NO, NO);
  FIRDocumentSnapshot *differentData = FSTTestDocSnapshot("rooms/bar", 1, @{@"b" : @1}, NO, NO);
  FIRDocumentSnapshot *hasMutations = FSTTestDocSnapshot("rooms/bar", 1, @{@"a" : @1}, YES, NO);
  FIRDocumentSnapshot *fromCache = FSTTestDocSnapshot("rooms/bar", 1, @{@"a" : @1}, NO, YES);
  XCTAssertEqualObjects(base, baseDup);
  XCTAssertEqualObjects(nilData, nilDataDup);
  XCTAssertNotEqualObjects(base, nilData);
  XCTAssertNotEqualObjects(nilData, base);
  XCTAssertNotEqualObjects(base, differentPath);
  XCTAssertNotEqualObjects(base, differentData);
  XCTAssertNotEqualObjects(base, hasMutations);
  XCTAssertNotEqualObjects(base, fromCache);

  XCTAssertEqual([base hash], [baseDup hash]);
  XCTAssertEqual([nilData hash], [nilDataDup hash]);
  XCTAssertNotEqual([base hash], [nilData hash]);
  XCTAssertNotEqual([base hash], [differentPath hash]);
  XCTAssertNotEqual([base hash], [differentData hash]);
  XCTAssertNotEqual([base hash], [hasMutations hash]);
  XCTAssertNotEqual([base hash], [fromCache hash]);
}

@end

NS_ASSUME_NONNULL_END
