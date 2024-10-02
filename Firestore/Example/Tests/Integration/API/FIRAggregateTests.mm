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
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"]
            ]]];

  // Count
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:2L]);
  XCTAssertEqual([snapshot count], [NSNumber numberWithLong:2L]);

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:150L], );

  // Average
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField
                                                      aggregateFieldForAverageOfField:@"pages"]],
                 [NSNumber numberWithDouble:75.0]);
}

- (void)testCanRunEmptyAggregateQuery {
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

  FIRAggregateQuery* emptyQuery = [testCollection aggregate:@[]];

  __block NSError* result;
  XCTestExpectation* expectation = [self expectationWithDescription:@"aggregate result"];

  [emptyQuery aggregationWithSource:FIRAggregateSourceServer
                         completion:^(FIRAggregateQuerySnapshot* snapshot, NSError* error) {
                           XCTAssertNil(snapshot);
                           result = error;
                           [expectation fulfill];
                         }];

  [self awaitExpectation:expectation];

  XCTAssertNotNil(result);
  XCTAssertTrue([[result localizedDescription] containsString:@"Aggregations can not be empty"]);
}

// (TODO:b/283101111): Try thread sanitizer to see if timeout on Github Actions is gone.
#if !defined(THREAD_SANITIZER)
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
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"]
            ]]];

  FIRAggregateQuerySnapshot* snapshot2 =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"]
            ]]];

  // different aggregates
  FIRAggregateQuerySnapshot* snapshot3 =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"weight"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"weight"]
            ]]];

  // different data set
  FIRAggregateQuerySnapshot* snapshot4 =
      [self readSnapshotForAggregate:[[testCollection queryWhereField:@"pages" isGreaterThan:@50]
                                         aggregate:@[
                                           [FIRAggregateField aggregateFieldForCount],
                                           [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
                                           [FIRAggregateField
                                               aggregateFieldForAverageOfField:@"pages"]
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
#endif  // #if !defined(THREAD_SANITIZER)

- (void)testAggregateOnFieldNameWithMaxLength {
  // The longest field name and alias allowed is 1500 bytes or 1499 characters.
  NSString* longField = [@"" stringByPaddingToLength:1499
                                          withString:@"0123456789"
                                     startingAtIndex:0];

  FIRCollectionReference* testCollection =
      [self collectionRefWithDocuments:@{@"a" : @{longField : @1}, @"b" : @{longField : @2}}];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:longField] ]]];

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:longField]],
      [NSNumber numberWithLong:3], );
}

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
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:2L]);

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:150L], );
}

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
  XCTAssertEqual([result valueForAggregateField:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:2L]);

  // Sum
  XCTAssertEqual(
      [result valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:150L], );
}

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
                          @"'count()' was not requested in the aggregation query.");
  }

  @
  try {
    [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"foo"]];
    XCTAssertTrue(false, "Exception expected");
  } @catch (NSException* exception) {
    XCTAssertEqualObjects(exception.name, @"FIRInvalidArgumentException");
    XCTAssertEqualObjects(exception.reason,
                          @"'sum(foo)' was not requested in the aggregation query.");
  }

  @
  try {
    [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForAverageOfField:@"pages"]];
    XCTAssertTrue(false, "Exception expected");
  } @catch (NSException* exception) {
    XCTAssertEqualObjects(exception.name, @"FIRInvalidArgumentException");
    XCTAssertEqualObjects(exception.reason,
                          @"'avg(pages)' was not requested in the aggregation query.");
  }
}

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
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"rating"],
                                     [FIRAggregateField aggregateFieldForCount]
                                   ]]];

  // Count
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]] longValue], 2L);

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longValue],
      8L);

  // Average
  XCTAssertEqual([[snapshot valueForAggregateField:[FIRAggregateField
                                                       aggregateFieldForAverageOfField:@"rating"]]
                     doubleValue],
                 4.0);
}

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
              [FIRAggregateField aggregateFieldForAverageOfField:@"metadata.pages"],
              [FIRAggregateField aggregateFieldForCount]
            ]]];

  // Count
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]] longValue], 2L);

  // Sum
  XCTAssertEqual(
      [[snapshot
          valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"metadata.pages"]]
          longValue],
      150L);

  // Average
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField
                                            aggregateFieldForAverageOfField:@"metadata.pages"]]
          doubleValue],
      75.0);
}

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
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithLong:LLONG_MAX] doubleValue] +
          [[NSNumber numberWithLong:LLONG_MAX] doubleValue]);
}

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
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longLongValue],
      [[NSNumber numberWithLong:LLONG_MAX - 100] longLongValue]);
}

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
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longLongValue],
      [[NSNumber numberWithLong:-10101] longLongValue]);
}

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
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]],
      [NSNumber numberWithDouble:INFINITY]);
}

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
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]],
      [NSNumber numberWithDouble:-INFINITY]);
}

- (void)testPerformsSumThatIsValidButCouldOverflowDuringAggregation {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]},
    @"b" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]},
    @"c" : @{@"rating" : [NSNumber numberWithDouble:-DBL_MAX]},
    @"d" : @{@"rating" : [NSNumber numberWithDouble:-DBL_MAX]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection
                                         aggregate:@[ [FIRAggregateField
                                                       aggregateFieldForSumOfField:@"rating"] ]]];

  // Sum
  long long ratingL =
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longLongValue];
  XCTAssertTrue(ratingL == [[NSNumber numberWithDouble:-INFINITY] longLongValue] || ratingL == 0 ||
                ratingL == [[NSNumber numberWithDouble:INFINITY] longLongValue]);

  double ratingD =
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          doubleValue];
  XCTAssertTrue(ratingD == -INFINITY || ratingD == 0 || ratingD == INFINITY);
}

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
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:0L]);
}

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
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]] longValue], 4L);

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longLongValue],
      [[NSNumber numberWithLong:10] longLongValue]);
}

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
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          doubleValue],
      [[NSNumber numberWithDouble:__DBL_DENORM_MIN__] doubleValue]);
}

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
    XCTAssertEqual([[snapshot valueForAggregateField:testCase[@"agg"]] longValue],
                   [testCase[@"expected"] longLongValue]);
    XCTAssertEqualWithAccuracy([[snapshot valueForAggregateField:testCase[@"agg"]] doubleValue],
                               [testCase[@"expected"] doubleValue], 0.00000000000001);
  }
}

- (void)testPerformsAverageCausingUnderflow {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:__DBL_DENORM_MIN__]},
    @"b" : @{@"rating" : [NSNumber numberWithDouble:0]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"]
            ]]];

  // Average
  XCTAssertEqual([[snapshot valueForAggregateField:[FIRAggregateField
                                                       aggregateFieldForAverageOfField:@"rating"]]
                     doubleValue],
                 [[NSNumber numberWithDouble:0] doubleValue]);
}

- (void)testPerformsAverageOfMinIEEE754 {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:__DBL_DENORM_MIN__]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"]
            ]]];

  // Average
  XCTAssertEqual([[snapshot valueForAggregateField:[FIRAggregateField
                                                       aggregateFieldForAverageOfField:@"rating"]]
                     doubleValue],
                 [[NSNumber numberWithDouble:__DBL_DENORM_MIN__] doubleValue]);
}

- (void)testPerformsAverageOverflowIEEE754DuringAccumulation {
  FIRCollectionReference* testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]},
    @"b" : @{@"rating" : [NSNumber numberWithDouble:DBL_MAX]}
  }];

  FIRAggregateQuerySnapshot* snapshot =
      [self readSnapshotForAggregate:[testCollection aggregate:@[
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"]
            ]]];

  // Average
  XCTAssertEqual([[snapshot valueForAggregateField:[FIRAggregateField
                                                       aggregateFieldForAverageOfField:@"rating"]]
                     doubleValue],
                 [[NSNumber numberWithDouble:INFINITY] doubleValue]);
}

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
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField
                                                      aggregateFieldForAverageOfField:@"pages"]],
                 [NSNull null]);
}

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
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]] longValue], 4L);

  // Average
  XCTAssertEqual([[snapshot valueForAggregateField:[FIRAggregateField
                                                       aggregateFieldForAverageOfField:@"rating"]]
                     doubleValue],
                 [[NSNumber numberWithDouble:5] doubleValue]);
}

- (void)testFailWithMessageWithConsoleLinkIfMissingIndex {
  XCTSkipIf([FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test when running against the Firestore emulator because the Firestore "
            "emulator does not use indexes and never fails with a 'missing index' error.");

  FIRCollectionReference* testCollection = [self collectionRef];
  FIRQuery* compositeIndexQuery = [[testCollection queryWhereField:@"field1"
                                                         isEqualTo:@42] queryWhereField:@"field2"
                                                                             isLessThan:@99];
  FIRAggregateQuery* compositeIndexAggregateQuery = [compositeIndexQuery aggregate:@[
    [FIRAggregateField aggregateFieldForCount],
    [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
    [FIRAggregateField aggregateFieldForAverageOfField:@"pages"]
  ]];

  XCTestExpectation* queryCompletion = [self expectationWithDescription:@"query"];
  [compositeIndexAggregateQuery
      aggregationWithSource:FIRAggregateSourceServer
                 completion:^(FIRAggregateQuerySnapshot* snapshot, NSError* error) {
                   XCTAssertNotNil(error);
                   if (error) {
                     NSString* errorDescription = [error localizedDescription];
                     XCTAssertTrue([errorDescription.lowercaseString containsString:@"index"],
                                   "The NSError should have contained the word 'index' "
                                   "(case-insensitive), but got: %@",
                                   errorDescription);
                     // TODO(b/316359394) Remove this check for the default databases once
                     // cl/582465034 is rolled out to production.
                     if ([[FSTIntegrationTestCase databaseID] isEqualToString:@"(default)"]) {
                       XCTAssertTrue(
                           [errorDescription containsString:@"https://console.firebase.google.com"],
                           "The NSError should have contained the string "
                           "'https://console.firebase.google.com', but got: %@",
                           errorDescription);
                     }
                   }
                   XCTAssertNil(snapshot);
                   [queryCompletion fulfill];
                 }];
  [self awaitExpectations];
}
@end
