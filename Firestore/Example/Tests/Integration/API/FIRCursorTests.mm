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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/Public/FirebaseCore/FIRTimestamp.h"

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FIRCursorTests : FSTIntegrationTestCase
@end

@implementation FIRCursorTests

- (void)testCanPageThroughItems {
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"v" : @"a"},
    @"b" : @{@"v" : @"b"},
    @"c" : @{@"v" : @"c"},
    @"d" : @{@"v" : @"d"},
    @"e" : @{@"v" : @"e"},
    @"f" : @{@"v" : @"f"}
  }];

  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[testCollection queryLimitedTo:2]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ @{@"v" : @"a"}, @{@"v" : @"b"} ]));

  FIRDocumentSnapshot *lastDoc = snapshot.documents.lastObject;
  snapshot = [self
      readDocumentSetForRef:[[testCollection queryLimitedTo:3] queryStartingAfterDocument:lastDoc]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot),
                        (@[ @{@"v" : @"c"}, @{@"v" : @"d"}, @{@"v" : @"e"} ]));

  lastDoc = snapshot.documents.lastObject;
  snapshot = [self
      readDocumentSetForRef:[[testCollection queryLimitedTo:1] queryStartingAfterDocument:lastDoc]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), @[ @{@"v" : @"f"} ]);

  lastDoc = snapshot.documents.lastObject;
  snapshot = [self
      readDocumentSetForRef:[[testCollection queryLimitedTo:3] queryStartingAfterDocument:lastDoc]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), @[]);
}

- (void)testCanBeCreatedFromDocuments {
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"v" : @"a", @"sort" : @1.0},
    @"b" : @{@"v" : @"b", @"sort" : @2.0},
    @"c" : @{@"v" : @"c", @"sort" : @2.0},
    @"d" : @{@"v" : @"d", @"sort" : @2.0},
    @"e" : @{@"v" : @"e", @"sort" : @0.0},
    @"f" : @{@"v" : @"f", @"nosort" : @1.0}  // should not show up
  }];

  FIRQuery *query = [testCollection queryOrderedByField:@"sort"];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:[testCollection documentWithPath:@"c"]];

  XCTAssertTrue(snapshot.exists);
  FIRQuerySnapshot *querySnapshot =
      [self readDocumentSetForRef:[query queryStartingAtDocument:snapshot]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshot),
                        (@[ @{@"v" : @"c", @"sort" : @2.0}, @{@"v" : @"d", @"sort" : @2.0} ]));

  querySnapshot = [self readDocumentSetForRef:[query queryEndingBeforeDocument:snapshot]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshot), (@[
                          @{@"v" : @"e", @"sort" : @0.0}, @{@"v" : @"a", @"sort" : @1.0},
                          @{@"v" : @"b", @"sort" : @2.0}
                        ]));
}

- (void)testCanBeCreatedFromValues {
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"v" : @"a", @"sort" : @1.0},
    @"b" : @{@"v" : @"b", @"sort" : @2.0},
    @"c" : @{@"v" : @"c", @"sort" : @2.0},
    @"d" : @{@"v" : @"d", @"sort" : @2.0},
    @"e" : @{@"v" : @"e", @"sort" : @0.0},
    @"f" : @{@"v" : @"f", @"nosort" : @1.0}  // should not show up
  }];

  FIRQuery *query = [testCollection queryOrderedByField:@"sort"];
  FIRQuerySnapshot *querySnapshot =
      [self readDocumentSetForRef:[query queryStartingAtValues:@[ @2.0 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshot), (@[
                          @{@"v" : @"b", @"sort" : @2.0}, @{@"v" : @"c", @"sort" : @2.0},
                          @{@"v" : @"d", @"sort" : @2.0}
                        ]));

  querySnapshot = [self readDocumentSetForRef:[query queryEndingBeforeValues:@[ @2.0 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshot),
                        (@[ @{@"v" : @"e", @"sort" : @0.0}, @{@"v" : @"a", @"sort" : @1.0} ]));
}

- (void)testCanBeCreatedUsingDocumentId {
  NSDictionary *testDocs = @{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"},
    @"d" : @{@"k" : @"d"},
    @"e" : @{@"k" : @"e"}
  };
  FIRCollectionReference *writer = [[[[self firestore] collectionWithPath:@"parent-collection"]
      documentWithAutoID] collectionWithPath:@"sub-collection"];
  [self writeAllDocuments:testDocs toCollection:writer];

  FIRCollectionReference *reader = [[self firestore] collectionWithPath:writer.path];
  FIRQuerySnapshot *querySnapshot =
      [self readDocumentSetForRef:[[[reader queryOrderedByFieldPath:[FIRFieldPath documentID]]
                                      queryStartingAtValues:@[ @"b" ]]
                                      queryEndingBeforeValues:@[ @"d" ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshot),
                        (@[ @{@"k" : @"b"}, @{@"k" : @"c"} ]));
}

- (void)testCanBeUsedWithReferenceValues {
  FIRFirestore *db = [self firestore];

  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"1a", @"ref" : [db documentWithPath:@"1/a"]},
    @"b" : @{@"k" : @"1b", @"ref" : [db documentWithPath:@"1/b"]},
    @"c" : @{@"k" : @"2a", @"ref" : [db documentWithPath:@"2/a"]},
    @"d" : @{@"k" : @"2b", @"ref" : [db documentWithPath:@"2/b"]},
    @"e" : @{@"k" : @"3a", @"ref" : [db documentWithPath:@"3/a"]},
  }];
  FIRQuery *query = [testCollection queryOrderedByField:@"ref"];
  FIRQuerySnapshot *querySnapshot = [self
      readDocumentSetForRef:[[query queryStartingAfterValues:@[ [db documentWithPath:@"1/a"] ]]
                                queryEndingAtValues:@[ [db documentWithPath:@"2/b"] ]]];
  NSMutableArray<NSString *> *actual = [NSMutableArray array];
  [querySnapshot.documents
      enumerateObjectsUsingBlock:^(FIRDocumentSnapshot *_Nonnull doc, NSUInteger, BOOL *) {
        [actual addObject:doc.data[@"k"]];
      }];
  XCTAssertEqualObjects(actual, (@[ @"1b", @"2a", @"2b" ]));
}

- (void)testCanBeUsedInDescendingQueries {
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"v" : @"a", @"sort" : @1.0},
    @"b" : @{@"v" : @"b", @"sort" : @2.0},
    @"c" : @{@"v" : @"c", @"sort" : @2.0},
    @"d" : @{@"v" : @"d", @"sort" : @3.0},
    @"e" : @{@"v" : @"e", @"sort" : @0.0},
    @"f" : @{@"v" : @"f", @"nosort" : @1.0}  // should not show up
  }];
  FIRQuery *query = [[testCollection queryOrderedByField:@"sort" descending:YES]
      queryOrderedByFieldPath:[FIRFieldPath documentID]
                   descending:YES];

  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[query queryStartingAtValues:@[ @2.0 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          @{@"v" : @"c", @"sort" : @2.0}, @{@"v" : @"b", @"sort" : @2.0},
                          @{@"v" : @"a", @"sort" : @1.0}, @{@"v" : @"e", @"sort" : @0.0}
                        ]));

  snapshot = [self readDocumentSetForRef:[query queryEndingBeforeValues:@[ @2.0 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ @{@"v" : @"d", @"sort" : @3.0} ]));
}

FIRTimestamp *TimestampWithMicros(int64_t seconds, int32_t micros) {
  // Firestore only supports microsecond resolution, so use a microsecond as a minimum value for
  // nanoseconds.
  return [FIRTimestamp timestampWithSeconds:seconds nanoseconds:micros * 1000];
}

- (void)testTimestampsCanBePassedToQueriesAsLimits {
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"timestamp" : TimestampWithMicros(100, 2)},
    @"b" : @{@"timestamp" : TimestampWithMicros(100, 5)},
    @"c" : @{@"timestamp" : TimestampWithMicros(100, 3)},
    @"d" : @{@"timestamp" : TimestampWithMicros(100, 1)},
    // Number of microseconds deliberately repeated.
    @"e" : @{@"timestamp" : TimestampWithMicros(100, 5)},
    @"f" : @{@"timestamp" : TimestampWithMicros(100, 4)},
  }];
  FIRQuery *query = [testCollection queryOrderedByField:@"timestamp"];
  FIRQuerySnapshot *querySnapshot =
      [self readDocumentSetForRef:[[query queryStartingAfterValues:@[ TimestampWithMicros(100, 2) ]]
                                      queryEndingAtValues:@[ TimestampWithMicros(100, 5) ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(querySnapshot), (@[ @"c", @"f", @"b", @"e" ]));
}

- (void)testTimestampsCanBePassedToQueriesInWhereClause {
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"timestamp" : TimestampWithMicros(100, 7),
    },
    @"b" : @{
      @"timestamp" : TimestampWithMicros(100, 4),
    },
    @"c" : @{
      @"timestamp" : TimestampWithMicros(100, 8),
    },
    @"d" : @{
      @"timestamp" : TimestampWithMicros(100, 5),
    },
    @"e" : @{
      @"timestamp" : TimestampWithMicros(100, 6),
    }
  }];

  FIRQuerySnapshot *querySnapshot =
      [self readDocumentSetForRef:[[testCollection queryWhereField:@"timestamp"
                                            isGreaterThanOrEqualTo:TimestampWithMicros(100, 5)]
                                      queryWhereField:@"timestamp"
                                           isLessThan:TimestampWithMicros(100, 8)]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(querySnapshot), (@[ @"d", @"e", @"a" ]));
}

- (void)testTimestampsAreTruncatedToMicroseconds {
  FIRTimestamp *nanos = [FIRTimestamp timestampWithSeconds:0 nanoseconds:123456789];
  FIRTimestamp *micros = [FIRTimestamp timestampWithSeconds:0 nanoseconds:123456000];
  FIRTimestamp *millis = [FIRTimestamp timestampWithSeconds:0 nanoseconds:123000000];
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"timestamp" : nanos},
  }];

  FIRQuerySnapshot *querySnapshot =
      [self readDocumentSetForRef:[testCollection queryWhereField:@"timestamp" isEqualTo:nanos]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(querySnapshot), (@[ @"a" ]));

  // Because Timestamp should have been truncated to microseconds, the microsecond timestamp
  // should be considered equal to the nanosecond one.
  querySnapshot = [self readDocumentSetForRef:[testCollection queryWhereField:@"timestamp"
                                                                    isEqualTo:micros]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(querySnapshot), (@[ @"a" ]));

  // The truncation is just to the microseconds, however, so the millisecond timestamp should be
  // treated as different and thus the query should return no results.
  querySnapshot = [self readDocumentSetForRef:[testCollection queryWhereField:@"timestamp"
                                                                    isEqualTo:millis]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(querySnapshot), (@[]));
}

@end
