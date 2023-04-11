/*
 * Copyright 2023 Google LLC
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

#import <FirebaseFirestore/FIRAggregateField.h>
#import <FirebaseFirestore/FIRFieldPath.h>
#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/core/src/util/exception.h"

@interface FIRAggregateTests : FSTIntegrationTestCase
@end

@implementation FIRAggregateTests

- (void)testCountAggregateFieldQueryEquals {
  FIRCollectionReference* coll1 = [self collectionRefWithDocuments:@{}];
  FIRCollectionReference* coll1Same = [[coll1 firestore] collectionWithPath:[coll1 path]];

  FIRAggregateQuery* query1 = [coll1 aggregate:@[ [FIRAggregateField aggregateFieldForCount] ]];
  FIRAggregateQuery* query1Same =
      [coll1Same aggregate:@[ [FIRAggregateField aggregateFieldForCount] ]];
  FIRAggregateQuery* query1DiffAgg =
      [coll1Same aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];

  FIRCollectionReference* sub = [[coll1 documentWithPath:@"bar"] collectionWithPath:@"baz"];

  FIRAggregateQuery* query2 = [[[sub queryWhereField:@"a" isEqualTo:@1] queryLimitedTo:100]
      aggregate:@[ [FIRAggregateField aggregateFieldForCount] ]];
  FIRAggregateQuery* query2Same = [[[sub queryWhereField:@"a"
                                               isEqualTo:@1] queryLimitedTo:100] count];

  FIRAggregateQuery* query3 = [[[sub queryWhereField:@"b" isEqualTo:@1] queryOrderedByField:@"c"]
      aggregate:@[ [FIRAggregateField aggregateFieldForCount] ]];
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

  XCTAssertNotEqual([query1 hash], [query1DiffAgg hash]);
  XCTAssertNotEqual([query1 hash], [query2 hash]);
  XCTAssertNotEqual([query2 hash], [query3 hash]);
}

- (void)testSumAggregateFieldQueryEquals {
  FIRCollectionReference* coll1 = [self collectionRefWithDocuments:@{}];
  FIRCollectionReference* coll1Same = [[coll1 firestore] collectionWithPath:[coll1 path]];

  FIRAggregateQuery* query1 =
      [coll1 aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];
  FIRAggregateQuery* query1Same =
      [coll1Same aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];
  FIRAggregateQuery* query1WithFieldPath =
      [coll1Same aggregate:@[ [FIRAggregateField
                               aggregateFieldForSumOfFieldPath:[[FIRFieldPath alloc]
                                                                   initWithFields:@[ @"baz" ]]] ]];
  FIRAggregateQuery* query1DiffAgg =
      [coll1Same aggregate:@[ [FIRAggregateField aggregateFieldForCount] ]];

  FIRCollectionReference* sub = [[coll1 documentWithPath:@"bar"] collectionWithPath:@"baz"];
  FIRAggregateQuery* query2 = [[[sub queryWhereField:@"a" isEqualTo:@1] queryLimitedTo:100]
      aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];
  FIRAggregateQuery* query2Same = [[[sub queryWhereField:@"a" isEqualTo:@1] queryLimitedTo:100]
      aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];
  FIRAggregateQuery* query3 = [[[sub queryWhereField:@"b" isEqualTo:@1] queryOrderedByField:@"c"]
      aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];
  FIRAggregateQuery* query3Same = [[[sub queryWhereField:@"b"
                                               isEqualTo:@1] queryOrderedByField:@"c"]
      aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];

  XCTAssertEqualObjects(query1, query1Same);
  XCTAssertEqualObjects(query1, query1WithFieldPath);
  XCTAssertEqualObjects(query2, query2Same);
  XCTAssertEqualObjects(query3, query3Same);

  XCTAssertEqual([query1 hash], [query1Same hash]);
  XCTAssertEqual([query1 hash], [query1WithFieldPath hash]);
  XCTAssertEqual([query2 hash], [query2Same hash]);
  XCTAssertEqual([query3 hash], [query3Same hash]);

  XCTAssertFalse([query1 isEqual:nil]);
  XCTAssertFalse([query1 isEqual:@"string"]);
  XCTAssertFalse([query1 isEqual:query2]);
  XCTAssertFalse([query2 isEqual:query3]);

  XCTAssertNotEqual([query1 hash], [query1DiffAgg hash]);
  XCTAssertNotEqual([query1 hash], [query2 hash]);
  XCTAssertNotEqual([query2 hash], [query3 hash]);
}

- (void)testAverageAggregateFieldQueryEquals {
  FIRCollectionReference* coll1 = [self collectionRefWithDocuments:@{}];
  FIRCollectionReference* coll1Same = [[coll1 firestore] collectionWithPath:[coll1 path]];

  FIRAggregateQuery* query1 =
      [coll1 aggregate:@[ [FIRAggregateField aggregateFieldForAverageOfField:@"baz"] ]];
  FIRAggregateQuery* query1Same =
      [coll1Same aggregate:@[ [FIRAggregateField aggregateFieldForAverageOfField:@"baz"] ]];
  FIRAggregateQuery* query1WithFieldPath = [coll1Same aggregate:@[
    [FIRAggregateField
        aggregateFieldForAverageOfFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"baz" ]]]
  ]];
  FIRAggregateQuery* query1DiffAgg =
      [coll1Same aggregate:@[ [FIRAggregateField aggregateFieldForCount] ]];

  FIRCollectionReference* sub = [[coll1 documentWithPath:@"bar"] collectionWithPath:@"baz"];

  FIRAggregateQuery* query2 = [[[sub queryWhereField:@"a" isEqualTo:@1] queryLimitedTo:100]
      aggregate:@[ [FIRAggregateField aggregateFieldForAverageOfField:@"baz"] ]];
  FIRAggregateQuery* query2Same = [[[sub queryWhereField:@"a" isEqualTo:@1] queryLimitedTo:100]
      aggregate:@[ [FIRAggregateField aggregateFieldForAverageOfField:@"baz"] ]];

  FIRAggregateQuery* query3 = [[[sub queryWhereField:@"b" isEqualTo:@1] queryOrderedByField:@"c"]
      aggregate:@[ [FIRAggregateField aggregateFieldForAverageOfField:@"baz"] ]];
  FIRAggregateQuery* query3Same = [[[sub queryWhereField:@"b"
                                               isEqualTo:@1] queryOrderedByField:@"c"]
      aggregate:@[ [FIRAggregateField aggregateFieldForAverageOfField:@"baz"] ]];

  XCTAssertEqualObjects(query1, query1Same);
  XCTAssertEqualObjects(query1, query1WithFieldPath);
  XCTAssertEqualObjects(query2, query2Same);
  XCTAssertEqualObjects(query3, query3Same);

  XCTAssertEqual([query1 hash], [query1Same hash]);
  XCTAssertEqual([query1 hash], [query1WithFieldPath hash]);
  XCTAssertEqual([query2 hash], [query2Same hash]);
  XCTAssertEqual([query3 hash], [query3Same hash]);

  XCTAssertFalse([query1 isEqual:nil]);
  XCTAssertFalse([query1 isEqual:@"string"]);
  XCTAssertFalse([query1 isEqual:query2]);
  XCTAssertFalse([query2 isEqual:query3]);

  XCTAssertNotEqual([query1 hash], [query1DiffAgg hash]);
  XCTAssertNotEqual([query1 hash], [query2 hash]);
  XCTAssertNotEqual([query2 hash], [query3 hash]);
}

- (void)testAggregateFieldQueryNotEquals {
  FIRCollectionReference* coll = [self collectionRefWithDocuments:@{}];

  FIRAggregateQuery* query1 = [coll aggregate:@[ [FIRAggregateField aggregateFieldForCount] ]];
  FIRAggregateQuery* query2 =
      [coll aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];
  FIRAggregateQuery* query3 =
      [coll aggregate:@[ [FIRAggregateField aggregateFieldForAverageOfField:@"baz"] ]];

  XCTAssertNotEqualObjects(query1, query2);
  XCTAssertNotEqualObjects(query2, query3);
  XCTAssertNotEqualObjects(query3, query1);

  XCTAssertNotEqual([query1 hash], [query2 hash]);
  XCTAssertNotEqual([query2 hash], [query3 hash]);
  XCTAssertNotEqual([query3 hash], [query1 hash]);

  FIRQuery* baseQuery = [[[[coll documentWithPath:@"bar"] collectionWithPath:@"baz"]
      queryWhereField:@"a"
            isEqualTo:@1] queryLimitedTo:100];

  FIRAggregateQuery* query4 = [baseQuery aggregate:@[ [FIRAggregateField aggregateFieldForCount] ]];
  FIRAggregateQuery* query5 =
      [baseQuery aggregate:@[ [FIRAggregateField aggregateFieldForSumOfField:@"baz"] ]];
  FIRAggregateQuery* query6 =
      [baseQuery aggregate:@[ [FIRAggregateField aggregateFieldForAverageOfField:@"baz"] ]];

  XCTAssertNotEqualObjects(query4, query5);
  XCTAssertNotEqualObjects(query5, query6);
  XCTAssertNotEqualObjects(query6, query4);

  XCTAssertNotEqual([query4 hash], [query5 hash]);
  XCTAssertNotEqual([query5 hash], [query6 hash]);
  XCTAssertNotEqual([query6 hash], [query4 hash]);
}

// TODO(sum/avg) skip when running against production
- (void)testCanRunAggregateQuery {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForSumOfField:@"weight"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"weight"]
            ]]];

  // Count
  XCTAssertEqual([snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:2L]);
  XCTAssertEqual([snapshot count], [NSNumber numberWithLong:2L]);

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:150L], );
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"weight"]]
          doubleValue],
      99.6);

  // Average
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"pages"]],
      [NSNumber numberWithDouble:75.0]);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"weight"]]
          doubleValue],
      49.8);
}

// TODO(sum/avg) skip when running against production
- (void)testAggregateFieldQuerySnapshotEquality {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  FIRAggregateQuerySnapshot* snapshot1 =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForSumOfField:@"weight"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"weight"]
            ]]];

  FIRAggregateQuerySnapshot* snapshot2 =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForSumOfField:@"weight"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"weight"]
            ]]];

  // different aggregates
  FIRAggregateQuerySnapshot* snapshot3 =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForSumOfField:@"weight"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"]
            ]]];

  // different data set
  FIRAggregateQuerySnapshot* snapshot4 = [self
      readSnapshotForAggregate:[[testCollection queryWhereField:@"pages" isGreaterThan:@50]
                                   aggregate:@[
                                     [FIRAggregateField aggregateFieldForCount],
                                     [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
                                     [FIRAggregateField aggregateFieldForSumOfField:@"weight"],
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
                                     [FIRAggregateField
                                         aggregateFieldForAverageOfField:@"weight"]
                                   ]]];

  XCTAssertEqualObjects(snapshot1, snapshot2);
  XCTAssertNotEqualObjects(snapshot1, snapshot3);
  XCTAssertNotEqualObjects(snapshot1, snapshot4);
  XCTAssertNotEqualObjects(snapshot3, snapshot4);

  XCTAssertEqual([snapshot1 hash], [snapshot2 hash]);
  XCTAssertNotEqual([snapshot1 hash], [snapshot3 hash]);
  XCTAssertNotEqual([snapshot1 hash], [snapshot4 hash]);
  XCTAssertNotEqual([snapshot3 hash], [snapshot4 hash]);
}

// TODO(sum/avg) skip when running against production
- (void)testCanGetDuplicateAggregations {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"]
            ]]];

  // Count
  XCTAssertEqual([snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:2L]);

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:150L], );
}

// TODO(sum/avg) skip when running against production
- (void)testTerminateDoesNotCrashWithFlyingAggregateQuery {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  FIRAggregateQuery* aggQuery = [testCollection aggregate:@[
    [FIRAggregateField aggregateFieldForCount],
    [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
    [FIRAggregateField aggregateFieldForAverageOfField:@"pages"]
  ]];

  __block FIRAggregateQuerySnapshot* result;
  XCTestExpectation* expectation = [self expectationWithDescription:@"aggregate result"];
  [aggQuery aggregationWithSource:FIRAggregateSourceServer
                       completion:^(FIRAggregateQuerySnapshot* snapshot, NSError* error) {
                         XCTAssertNil(error);
                         result = snapshot;
                         [expectation fulfill];
                       }];

  [self awaitExpectation:expectation];

  // Count
  XCTAssertEqual([result valueForAggregation:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:2L]);

  // Sum
  XCTAssertEqual(
      [result valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:150L], );
}

// TODO(sum/avg) skip when running against production
- (void)testCanPerformMaxAggregations {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  // Max is 5, do not exceed
  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForSumOfField:@"weight"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"weight"]
            ]]];

  // Assert
  XCTAssertEqual([snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:2L]);
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:150L], );
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"weight"]]
          doubleValue],
      99.6);
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"pages"]],
      [NSNumber numberWithDouble:75.0]);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"weight"]]
          doubleValue],
      49.8);
}

// TODO(sum/avg) skip when running against production
- (void)testCannotPerformMoreThanMaxAggregations {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  // Max is 5, we're attempting 6. I also like to live dangerously.
  FIRAggregateQuery* query = [testCollection aggregate:@[
    [FIRAggregateField aggregateFieldForCount],
    [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
    [FIRAggregateField aggregateFieldForSumOfField:@"weight"],
    [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
    [FIRAggregateField aggregateFieldForAverageOfField:@"weight"],
    [FIRAggregateField aggregateFieldForAverageOfField:@"foo"]
  ]];

  __block NSError* result;
  XCTestExpectation* expectation = [self expectationWithDescription:@"aggregate result"];

  [query aggregationWithSource:FIRAggregateSourceServer
                    completion:^(FIRAggregateQuerySnapshot* snapshot, NSError* error) {
                      XCTAssertNil(snapshot);
                      result = error;
                      [expectation fulfill];
                    }];

  [self awaitExpectation:expectation];

  XCTAssertNotNil(result);
  XCTAssertTrue([[result localizedDescription] containsString:@"maximum number of aggregations"]);
}

// TODO(sum/avg) skip when running against production
- (void)testCanRunAggregateCollectionGroupQuery {
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
    [batch setData:@{@"x" : @2} forDocument:[self.db documentWithPath:path]];
  }

  XCTestExpectation* expectation = [self expectationWithDescription:@"commit"];
  [batch commitWithCompletion:^(NSError* error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectation:expectation];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[[self.db collectionGroupWithID:collectionGroup] aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"x"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"x"]
            ]]];
  // "cg-doc1", "cg-doc2", "cg-doc3", "cg-doc4", "cg-doc5",
  XCTAssertEqual([snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:5L]);
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"x"]],
      [NSNumber numberWithLong:10L]);
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"x"]],
      [NSNumber numberWithDouble:2.0]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAggregationsWhenNaNExistsForSomeFieldValues {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @5
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @4
    },
    @"c" : @{
      @"author" : @"authorC",
      @"title" : @"titleC",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : [NSNumber numberWithFloat:NAN]
    },
    @"d" : @{
      @"author" : @"authorD",
      @"title" : @"titleD",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @0
    }
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForSumOfField:@"rating"],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"year"]
            ]]];

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]],
      [NSNumber numberWithDouble:NAN]);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]]
          longValue],
      300L);

  // Average
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"rating"]],
      [NSNumber numberWithDouble:NAN]);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"year"]]
          doubleValue],
      2000.0);
}

// TODO(sum/avg) skip when running against production
- (void)testThrowsAnErrorWhenGettingTheResultOfAnUnrequestedAggregation {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"pages"] ]]];

  @try {
    [snapshot count];
    XCTAssertTrue(false, "Exception expected");
  } @catch (NSException* exception) {
    XCTAssertEqualObjects(exception.name, @"FIRInvalidArgumentException");
    XCTAssertEqualObjects(exception.reason,
                          @"'count()' was not requested in the aggregation query");
  }

  @
  try {
    [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"foo"]];
    XCTAssertTrue(false, "Exception expected");
  } @catch (NSException* exception) {
    XCTAssertEqualObjects(exception.name, @"FIRInvalidArgumentException");
    XCTAssertEqualObjects(exception.reason,
                          @"'sum(foo)' was not requested in the aggregation query");
  }

  @
  try {
    [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"pages"]];
    XCTAssertTrue(false, "Exception expected");
  } @catch (NSException* exception) {
    XCTAssertEqualObjects(exception.name, @"FIRInvalidArgumentException");
    XCTAssertEqualObjects(exception.reason,
                          @"'avg(pages)' was not requested in the aggregation query");
  }
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAggregationWhenUsingInOperator {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @5
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @4
    },
    @"c" : @{
      @"author" : @"authorC",
      @"title" : @"titleC",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @3
    },
    @"d" : @{
      @"author" : @"authorD",
      @"title" : @"titleD",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @0
    }
  }];

  FIRAggregateQuerySnapshot* snapshot = [self
      readSnapshotForAggregate:[[testCollection queryWhereField:@"rating" in:@[ @5, @3 ]]
                                   aggregate:@[
                                     [FIRAggregateField aggregateFieldForSumOfField:@"rating"],
                                     [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"rating"],
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
                                     [FIRAggregateField aggregateFieldForCount]
                                   ]]];

  // Count
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]] longValue], 2L);

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longValue],
      8L);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]]
          longValue],
      200L);

  // Average
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"rating"]]
          doubleValue],
      4.0);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"pages"]]
          doubleValue],
      100.0);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAggregationWhenUsingArrayContainsAnyOperator {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @[ @5, @1000 ]
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @[ @4 ]
    },
    @"c" : @{
      @"author" : @"authorC",
      @"title" : @"titleC",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @[ @2222, @3 ]
    },
    @"d" : @{
      @"author" : @"authorD",
      @"title" : @"titleD",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @[ @0 ]
    }
  }];

  FIRAggregateQuerySnapshot* snapshot = [self
      readSnapshotForAggregate:[[testCollection queryWhereField:@"rating"
                                               arrayContainsAny:@[ @5, @3 ]]
                                   aggregate:@[
                                     [FIRAggregateField aggregateFieldForSumOfField:@"rating"],
                                     [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"rating"],
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
                                     [FIRAggregateField aggregateFieldForCount]
                                   ]]];

  // Count
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]] longValue], 2L);

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longValue],
      0L);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]]
          longValue],
      200L);

  // Average
  XCTAssertEqualObjects(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"rating"]],
      [NSNull null]);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"pages"]]
          doubleValue],
      100.0);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAggregationsOnNestedMapValues {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"metadata" : @{@"pages" : @100, @"rating" : @{@"critic" : @2, @"user" : @5}}
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"metadata" : @{@"pages" : @50, @"rating" : @{@"critic" : @4, @"user" : @4}}
    },
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForSumOfField:@"metadata.pages"],
              [FIRAggregateField aggregateFieldForSumOfField:@"metadata.rating.user"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"metadata.pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"metadata.rating.critic"],
              [FIRAggregateField aggregateFieldForCount]
            ]]];

  // Count
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]] longValue], 2L);

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField
                                         aggregateFieldForSumOfField:@"metadata.pages"]] longValue],
      150L);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField
                                         aggregateFieldForSumOfField:@"metadata.rating.user"]]
          longValue],
      9);

  // Average
  XCTAssertEqual(
      [[snapshot
          valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"metadata.pages"]]
          doubleValue],
      75.0);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField
                                         aggregateFieldForAverageOfField:@"metadata.rating.critic"]]
          doubleValue],
      3.0);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumThatOverflowsMaxLong {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"rating" : [NSNumber numberWithLong:LLONG_MAX]
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"rating" : [NSNumber numberWithLong:LLONG_MAX]
    },
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"rating"] ]]];

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithLong:LLONG_MAX] doubleValue] +
          [[NSNumber numberWithLong:LLONG_MAX] doubleValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumThatCanOverflowLongValuesDuringAccumulation {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"rating" : [NSNumber numberWithLong:LLONG_MAX]
    },
    @"b" : @{@"author" : @"authorB", @"title" : @"titleB", @"rating" : [NSNumber numberWithLong:1]},
    @"c" :
        @{@"author" : @"authorC", @"title" : @"titleC", @"rating" : [NSNumber numberWithLong:-101]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"rating"] ]]];

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longLongValue],
      [[NSNumber numberWithLong:LLONG_MAX - 100] longLongValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumThatIsNegative {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"rating" : [NSNumber numberWithLong:LLONG_MAX]
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"rating" : [NSNumber numberWithLong:-LLONG_MAX]
    },
    @"c" :
        @{@"author" : @"authorC", @"title" : @"titleC", @"rating" : [NSNumber numberWithLong:-101]},
    @"d" : @{
      @"author" : @"authorD",
      @"title" : @"titleD",
      @"rating" : [NSNumber numberWithLong:-10000]
    }
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"rating"] ]]];

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longLongValue],
      [[NSNumber numberWithLong:-10101] longLongValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumThatIsPositiveInfinity {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"rating" : [NSNumber numberWithDouble:DBL_MAX]
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"rating" : [NSNumber numberWithDouble:DBL_MAX]
    }
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"rating"] ]]];

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]],
      [NSNumber numberWithDouble:INFINITY]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumThatIsNegativeInfinity {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"rating" : [NSNumber numberWithDouble:-DBL_MAX]
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"rating" : [NSNumber numberWithDouble:-DBL_MAX]
    }
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"rating"] ]]];

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]],
      [NSNumber numberWithDouble:-INFINITY]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumThatIsValidButCouldOverflowDuringAggregation {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]},
    @"b" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]},
    @"c" : @{@"rating" : [NSNumber numberWithDouble:-DBL_MAX]},
    @"d" : @{@"rating" : [NSNumber numberWithDouble:-DBL_MAX]},
    @"e" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]},
    @"f" : @{@"rating" : [NSNumber numberWithDouble:-DBL_MAX]},
    @"g" : @{@"rating" : [NSNumber numberWithDouble:-DBL_MAX]},
    @"h" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"rating"] ]]];

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longLongValue],
      [[NSNumber numberWithLong:0] longLongValue]);
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithLong:0] doubleValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumOverResultSetOfZeroDocuments {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"pages" isGreaterThan:@200]
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"pages"] ]]];

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:0L]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumOnlyOnNumericFields {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithLong:5]},
    @"b" : @{@"rating" : [NSNumber numberWithLong:4]},
    @"c" : @{@"rating" : @"3"},
    @"d" : @{@"rating" : [NSNumber numberWithLong:1]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"rating"]
            ]]];

  // Count
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]] longValue], 4L);

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longLongValue],
      [[NSNumber numberWithLong:10] longLongValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsSumOfMinIEEE754 {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:__DBL_DENORM_MIN__]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"rating"] ]]];

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithDouble:__DBL_DENORM_MIN__] doubleValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAverageOfVariousNumericTypes {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"x" : @1,
      @"intToInt" : [NSNumber numberWithLong:10],
      @"floatToInt" : [NSNumber numberWithDouble:10.5],
      @"mixedToInt" : [NSNumber numberWithLong:10],
      @"floatToFloat" : [NSNumber numberWithDouble:5.5],
      @"mixedToFloat" : [NSNumber numberWithDouble:8.6],
      @"intToFloat" : [NSNumber numberWithLong:10]
    },
    @"b" : @{
      @"intToInt" : [NSNumber numberWithLong:5],
      @"floatToInt" : [NSNumber numberWithDouble:9.5],
      @"mixedToInt" : [NSNumber numberWithDouble:9.5],
      @"floatToFloat" : [NSNumber numberWithDouble:4.5],
      @"mixedToFloat" : [NSNumber numberWithLong:9],
      @"intToFloat" : [NSNumber numberWithLong:9]
    },
    @"c" : @{
      @"intToInt" : [NSNumber numberWithLong:0],
      @"floatToInt" : @"ignore",
      @"mixedToInt" : [NSNumber numberWithDouble:10.5],
      @"floatToFloat" : [NSNumber numberWithDouble:3.5],
      @"mixedToFloat" : [NSNumber numberWithLong:10],
      @"intToFloat" : @"ignore"
    }
  }];

  NSArray* testCases = @[
    @{
      @"agg" : [FIRAggregateField aggregateFieldForAverageOfField:@"intToInt"],
      @"expected" : [NSNumber numberWithLong:5]
    },
    @{
      @"agg" : [FIRAggregateField aggregateFieldForAverageOfField:@"floatToInt"],
      @"expected" : [NSNumber numberWithLong:10]
    },
    @{
      @"agg" : [FIRAggregateField aggregateFieldForAverageOfField:@"mixedToInt"],
      @"expected" : [NSNumber numberWithLong:10]
    },
    @{
      @"agg" : [FIRAggregateField aggregateFieldForAverageOfField:@"floatToFloat"],
      @"expected" : [NSNumber numberWithDouble:4.5]
    },
    @{
      @"agg" : [FIRAggregateField aggregateFieldForAverageOfField:@"mixedToFloat"],
      @"expected" : [NSNumber numberWithDouble:9.2]
    },
    @{
      @"agg" : [FIRAggregateField aggregateFieldForAverageOfField:@"intToFloat"],
      @"expected" : [NSNumber numberWithDouble:9.5]
    }
  ];

  for (NSDictionary* testCase in testCases) {
    FIRAggregateQuerySnapshot* snapshot =
        [self readSnapshotForAggregate:[testCollection aggregate:@[ testCase[@"agg"] ]]];

    // Average
    XCTAssertEqual([[snapshot valueForAggregation:testCase[@"agg"]] longValue],
                   [testCase[@"expected"] longLongValue]);
    XCTAssertEqualWithAccuracy([[snapshot valueForAggregation:testCase[@"agg"]] doubleValue],
                               [testCase[@"expected"] doubleValue], 0.00000000000001);
  }
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAverageCausingUnderflow {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:__DBL_DENORM_MIN__]},
    @"b" : @{@"rating" : [NSNumber numberWithDouble:0]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"]
            ]]];

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithDouble:0] doubleValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAverageOfMinIEEE754 {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:__DBL_DENORM_MIN__]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"]
            ]]];

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithDouble:__DBL_DENORM_MIN__] doubleValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAverageOverflowIEEE754DuringAccumulation {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]},
    @"b" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"]
            ]]];

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithDouble:INFINITY] doubleValue]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAverageOverResultSetOfZeroDocuments {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"height" : @24.5,
      @"weight" : @24.1,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"height" : @25.5,
      @"weight" : @75.5,
      @"foo" : @1,
      @"bar" : @2,
      @"baz" : @3
    }
  }];

  FIRAggregateQuerySnapshot* snapshot = [self
      readSnapshotForAggregate:[[testCollection queryWhereField:@"pages" isGreaterThan:@200]
                                   aggregate:@[ [FIRAggregateField
                                                 aggregateFieldForAverageOfField:@"pages"] ]]];

  // Average
  XCTAssertEqual(
      [snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"pages"]],
      [NSNull null]);
}

// TODO(sum/avg) skip when running against production
- (void)testPerformsAverageOnlyOnNumericFields {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithLong:5]},
    @"b" : @{@"rating" : [NSNumber numberWithLong:4]},
    @"c" : @{@"rating" : @"3"},
    @"d" : @{@"rating" : [NSNumber numberWithLong:6]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"]
            ]]];

  // Count
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForCount]] longValue], 4L);

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregation:[FIRAggregateField aggregateFieldForAverageOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithDouble:5] doubleValue]);
}

@end
