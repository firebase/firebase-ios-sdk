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

#import <FirebaseFirestore/FIRQuerySnapshot.h>

#import <XCTest/XCTest.h>

#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRQuerySnapshotTests : XCTestCase
@end

@implementation FIRQuerySnapshotTests

- (void)testEquals {
  FIRQuerySnapshot *foo = FSTTestQuerySnapshot(@"foo", @{}, @{ @"a" : @{@"a" : @1} }, YES, NO);
  FIRQuerySnapshot *fooDup = FSTTestQuerySnapshot(@"foo", @{}, @{ @"a" : @{@"a" : @1} }, YES, NO);
  FIRQuerySnapshot *differentPath = FSTTestQuerySnapshot(@"bar", @{},
                                                         @{ @"a" : @{@"a" : @1} }, YES, NO);
  FIRQuerySnapshot *differentDoc = FSTTestQuerySnapshot(@"foo",
                                                        @{ @"a" : @{@"b" : @1} }, @{}, YES, NO);
  FIRQuerySnapshot *noPendingWrites = FSTTestQuerySnapshot(@"foo", @{},
                                                           @{ @"a" : @{@"a" : @1} }, NO, NO);
  FIRQuerySnapshot *fromCache = FSTTestQuerySnapshot(@"foo", @{},
                                                     @{ @"a" : @{@"a" : @1} }, YES, YES);
  XCTAssertEqualObjects(foo, fooDup);
  XCTAssertNotEqualObjects(foo, differentPath);
  XCTAssertNotEqualObjects(foo, differentDoc);
  XCTAssertNotEqualObjects(foo, noPendingWrites);
  XCTAssertNotEqualObjects(foo, fromCache);

  XCTAssertEqual([foo hash], [fooDup hash]);
  XCTAssertNotEqual([foo hash], [differentPath hash]);
  XCTAssertNotEqual([foo hash], [differentDoc hash]);
  XCTAssertNotEqual([foo hash], [noPendingWrites hash]);
  XCTAssertNotEqual([foo hash], [fromCache hash]);
}

@end

NS_ASSUME_NONNULL_END
