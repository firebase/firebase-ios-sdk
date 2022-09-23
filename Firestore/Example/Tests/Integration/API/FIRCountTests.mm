/*
 * Copyright 2022 Google LLC
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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRAggregateQuery+Internal.h"
#import "Firestore/Source/API/FIRAggregateQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

@interface FIRCountTests : FSTIntegrationTestCase
@end

@implementation FIRCountTests

- (void)testCanRunCountQuery {
  // TODO(b/246758022): Remove this (and below) once COUNT is release for the backend.
  if (![FSTIntegrationTestCase isRunningAgainstEmulator]) {
    return;
  }

  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"}
  }];

  FIRAggregateQuerySnapshot* snapshot = [self readSnapshotForAggregate:[testCollection count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:3L]);
}

- (void)testCanRunCountWithFilters {
  if (![FSTIntegrationTestCase isRunningAgainstEmulator]) {
    return;
  }

  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k" isEqualTo:@"b"] count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:1L]);
}

- (void)testCanRunCountWithOrderBys {
  if (![FSTIntegrationTestCase isRunningAgainstEmulator]) {
    return;
  }

  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"},
    @"d" : @{@"absent" : @"d"},
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[[testCollection queryOrderedByField:@"k"] count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:3L]);
}

- (void)testTerminateDoesNotCrashWithFlyingCountQuery {
  if (![FSTIntegrationTestCase isRunningAgainstEmulator]) {
    return;
  }

  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"},
  }];

  [[testCollection count]
      aggregationWithSource:FIRAggregateSourceServer
                 completion:^(FIRAggregateQuerySnapshot* snapshot, NSError* error) {
                   (void)snapshot;
                   (void)error;
                 }];
  [self terminateFirestore:testCollection.firestore];
}

- (void)testCanRunCollectionGroupCountQuery {
  if (![FSTIntegrationTestCase isRunningAgainstEmulator]) {
    return;
  }

  NSString* collectionGroup =
      [NSString stringWithFormat:@"%@%@", @"b",
                                 [self.db collectionWithPath:@"foo"].documentWithAutoID.documentID];
  NSArray* docPathFormats = @[
    @"abc/123/%@/cg-doc1", @"abc/123/%@/cg-doc2", @"%@/cg-doc3", @"%@/cg-doc4",
    @"def/456/%@/cg-doc5", @"%@/virtual-doc/nested-coll/not-cg-doc", @"x%@/not-cg-doc",
    @"%@x/not-cg-doc", @"abc/123/%@x/not-cg-doc", @"abc/123/x%@/not-cg-doc", @"abc/%@"
  ];

  FIRWriteBatch* batch = self.db.batch;
  for (NSString* format in docPathFormats) {
    NSString* path = [NSString stringWithFormat:format, collectionGroup];
    [batch setData:@{@"x" : @"a"} forDocument:[self.db documentWithPath:path]];
  }

  XCTestExpectation* expectation = [self expectationWithDescription:@"commit"];
  [batch commitWithCompletion:^(NSError* error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectation:expectation];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[[self.db collectionGroupWithID:collectionGroup] count]];
  // "cg-doc1", "cg-doc2", "cg-doc3", "cg-doc4", "cg-doc5",
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:5L]);
}

- (void)testCanRunCountWithFiltersAndLimits {
  if (![FSTIntegrationTestCase isRunningAgainstEmulator]) {
    return;
  }

  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"a"},
    @"c" : @{@"k" : @"a"},
    @"d" : @{@"k" : @"d"},
  }];

  FIRAggregateQuerySnapshot* snapshot = [self
      readSnapshotForAggregate:[[[testCollection queryLimitedTo:2] queryWhereField:@"k"
                                                                         isEqualTo:@"a"] count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:2L]);

  snapshot = [self readSnapshotForAggregate:[[[testCollection queryLimitedToLast:2]
                                                queryWhereField:@"k"
                                                      isEqualTo:@"a"] count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:2L]);

  snapshot = [self readSnapshotForAggregate:[[[testCollection queryLimitedToLast:1000]
                                                queryWhereField:@"k"
                                                      isEqualTo:@"d"] count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:1L]);
}

- (void)testCanRunCountOnNonExistentCollection {
  if (![FSTIntegrationTestCase isRunningAgainstEmulator]) {
    return;
  }

  FIRCollectionReference* testCollection = [self collectionRef];

  FIRAggregateQuerySnapshot* snapshot = [self readSnapshotForAggregate:[testCollection count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:0L]);

  snapshot = [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k"
                                                                   isEqualTo:@"a"] count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:0L]);
}

- (void)testFailWithoutNetwork {
  if (![FSTIntegrationTestCase isRunningAgainstEmulator]) {
    return;
  }

  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"}
  }];

  [self disableNetwork];

  [[testCollection count]
      aggregationWithSource:FIRAggregateSourceServer
                 completion:^(FIRAggregateQuerySnapshot* snapshot, NSError* error) {
                   (void)snapshot;
                   XCTAssertNotNil(error);
                 }];

  [self enableNetwork];
  FIRAggregateQuerySnapshot* snapshot = [self readSnapshotForAggregate:[testCollection count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:3L]);
}

@end
