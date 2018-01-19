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

#import <FirebaseFirestore/FIRSnapshotMetadata.h>

#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRSnapshotMetadataTests : XCTestCase
@end

@implementation FIRSnapshotMetadataTests

- (void)testEquals {
  FIRSnapshotMetadata *foo =
      [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:YES fromCache:YES];
  FIRSnapshotMetadata *fooDup =
      [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:YES fromCache:YES];
  FIRSnapshotMetadata *bar =
      [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:YES fromCache:NO];
  FIRSnapshotMetadata *baz =
      [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:NO fromCache:YES];
  XCTAssertEqualObjects(foo, fooDup);
  XCTAssertNotEqualObjects(foo, bar);
  XCTAssertNotEqualObjects(foo, baz);
  XCTAssertNotEqualObjects(bar, baz);

  XCTAssertEqual([foo hash], [fooDup hash]);
  XCTAssertNotEqual([foo hash], [bar hash]);
  XCTAssertNotEqual([foo hash], [baz hash]);
  XCTAssertNotEqual([bar hash], [baz hash]);
}

@end

NS_ASSUME_NONNULL_END
