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

@interface FIRCountTests : FSTIntegrationTestCase
@end

@implementation FIRCountTests

- (void)testAggregateQueryEquals {
  FIRCollectionReference* coll1 = [self collectionRefWithDocuments:@{}];
  FIRCollectionReference* coll1Same = [[coll1 firestore] collectionWithPath:[coll1 path]];
  FIRAggregateQuery* query1 = [coll1 count];
  FIRAggregateQuery* query1Same = [coll1Same count];

  FIRCollectionReference* sub = [[coll1 documentWithPath:@"bar"] collectionWithPath:@"baz"];
  FIRAggregateQuery* query2 = [[[sub queryWhereField:@"a" isEqualTo:@1] queryLimitedTo:100] count];
  FIRAggregateQuery* query2Same = [[[sub queryWhereField:@"a"
                                               isEqualTo:@1] queryLimitedTo:100] count];
  FIRAggregateQuery* query3 = [[[sub queryWhereField:@"b"
                                           isEqualTo:@1] queryOrderedByField:@"c"] count];
  FIRAggregateQuery* query3Same = [[[sub queryWhereField:@"b"
                                               isEqualTo:@1] queryOrderedByField:@"c"] count];

  XCTAssertEqualObjects(query1, query1Same);
  XCTAssertEqualObjects(query2, query2Same);
  XCTAssertEqualObjects(query3, query3Same);

  XCTAssertEqual([query1 hash], [query1Same hash]);
  XCTAssertEqual([query2 hash], [query2Same hash]);
  XCTAssertEqual([query3 hash], [query3Same hash]);

  XCTAssertFalse([query1 isEqual:nil]);
  XCTAssertFalse([query1 isEqual:@"string"]);
  XCTAssertFalse([query1 isEqual:query2]);
  XCTAssertFalse([query2 isEqual:query3]);

  XCTAssertNotEqual([query1 hash], [query2 hash]);
  XCTAssertNotEqual([query2 hash], [query3 hash]);
}

- (void)testCanRunCountQuery {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"}
  }];

  FIRAggregateQuerySnapshot* snapshot = [self readSnapshotForAggregate:[testCollection count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:3L]);
}

- (void)testCanRunAggregateQuery {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @1},
    @"b" : @{@"k" : @2},
    @"c" : @{@"k" : @3}
  }];
    
  FIRAggregateQuerySnapshot* snapshot = [self readSnapshotForAggregate:[testCollection aggregate:@[[FIRAggregateField aggregateFieldForCount], [FIRAggregateField aggregateFieldForSumOfField:@"k"], [FIRAggregateField aggregateFieldForAverageOfField:@"k"]]]];
    XCTAssertEqual([snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]], [NSNumber numberWithLong:3L]);
    XCTAssertEqual([snapshot count], [NSNumber numberWithLong:3L]);
    XCTAssertEqual([snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"k"]], [NSNumber numberWithLong:6L]);
    XCTAssertEqual([snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"k"]], [NSNumber numberWithDouble:2.0]);
}

- (void)testCanRunCountWithFilters {
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

- (void)testSnapshotEquals {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"}
  }];

  FIRAggregateQuerySnapshot* snapshot1 =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k" isEqualTo:@"b"] count]];
  FIRAggregateQuerySnapshot* snapshot1Same =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k" isEqualTo:@"b"] count]];

  FIRAggregateQuerySnapshot* snapshot2 =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k" isEqualTo:@"a"] count]];
  [self writeDocumentRef:[testCollection documentWithPath:@"d"] data:@{@"k" : @"a"}];
  FIRAggregateQuerySnapshot* snapshot2Different =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k" isEqualTo:@"a"] count]];

  FIRAggregateQuerySnapshot* snapshot3 =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k" isEqualTo:@"b"] count]];
  FIRAggregateQuerySnapshot* snapshot3Different =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k" isEqualTo:@"c"] count]];

  XCTAssertEqualObjects(snapshot1, snapshot1Same);
  XCTAssertEqual([snapshot1 hash], [snapshot1Same hash]);
  XCTAssertEqualObjects([snapshot1 query], [[testCollection queryWhereField:@"k"
                                                                  isEqualTo:@"b"] count]);

  XCTAssertNotEqualObjects(snapshot1, nil);
  XCTAssertNotEqualObjects(snapshot1, @"string");
  XCTAssertNotEqualObjects(snapshot1, snapshot2);
  XCTAssertNotEqual([snapshot1 hash], [snapshot2 hash]);
  XCTAssertNotEqualObjects(snapshot2, snapshot2Different);
  XCTAssertNotEqual([snapshot2 hash], [snapshot2Different hash]);
  XCTAssertNotEqualObjects(snapshot3, snapshot3Different);
  XCTAssertNotEqual([snapshot3 hash], [snapshot3Different hash]);
}

- (void)testTerminateDoesNotCrashWithFlyingCountQuery {
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
  FIRCollectionReference* testCollection = [self collectionRef];

  FIRAggregateQuerySnapshot* snapshot = [self readSnapshotForAggregate:[testCollection count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:0L]);

  snapshot = [self readSnapshotForAggregate:[[testCollection queryWhereField:@"k"
                                                                   isEqualTo:@"a"] count]];
  XCTAssertEqual(snapshot.count, [NSNumber numberWithLong:0L]);
}

- (void)testFailWithoutNetwork {
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
