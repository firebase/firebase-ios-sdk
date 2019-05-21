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

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FIRQueryTests : FSTIntegrationTestCase
@end

@implementation FIRQueryTests

- (void)testLimitQueries {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a"},
    @"b" : @{@"k" : @"b"},
    @"c" : @{@"k" : @"c"}

  }];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[collRef queryLimitedTo:2]];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ @{@"k" : @"a"}, @{@"k" : @"b"} ]));
}

- (void)testLimitQueriesWithDescendingSortOrder {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1},
    @"c" : @{@"k" : @"c", @"sort" : @1},
    @"d" : @{@"k" : @"d", @"sort" : @2},

  }];
  FIRQuerySnapshot *snapshot =
      [self readDocumentSetForRef:[[collRef queryOrderedByField:@"sort"
                                                     descending:YES] queryLimitedTo:2]];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot),
                        (@[ @{@"k" : @"d", @"sort" : @2}, @{@"k" : @"c", @"sort" : @1} ]));
}

- (void)testKeyOrderIsDescendingForDescendingInequality {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"foo" : @42},
    @"b" : @{@"foo" : @42.0},
    @"c" : @{@"foo" : @42},
    @"d" : @{@"foo" : @21},
    @"e" : @{@"foo" : @21.0},
    @"f" : @{@"foo" : @66},
    @"g" : @{@"foo" : @66.0},
  }];
  FIRQuerySnapshot *snapshot =
      [self readDocumentSetForRef:[[collRef queryWhereField:@"foo"
                                              isGreaterThan:@21] queryOrderedByField:@"foo"
                                                                          descending:YES]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(snapshot), (@[ @"g", @"f", @"c", @"b", @"a" ]));
}

- (void)testUnaryFilterQueries {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"null" : [NSNull null], @"nan" : @(NAN)},
    @"b" : @{@"null" : [NSNull null], @"nan" : @0},
    @"c" : @{@"null" : @NO, @"nan" : @(NAN)}
  }];

  FIRQuerySnapshot *results =
      [self readDocumentSetForRef:[[collRef queryWhereField:@"null"
                                                  isEqualTo:[NSNull null]] queryWhereField:@"nan"
                                                                                 isEqualTo:@(NAN)]];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(results),
                        (@[ @{@"null" : [NSNull null], @"nan" : @(NAN)} ]));
}

- (void)testQueryWithFieldPaths {
  FIRCollectionReference *collRef = [self
      collectionRefWithDocuments:@{@"a" : @{@"a" : @1}, @"b" : @{@"a" : @2}, @"c" : @{@"a" : @3}}];

  FIRQuery *query = [collRef queryWhereFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"a" ]]
                                      isLessThan:@3];
  query = [query queryOrderedByFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"a" ]]
                              descending:YES];

  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:query];

  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(snapshot), (@[ @"b", @"a" ]));
}

- (void)testQueryWithPredicate {
  FIRCollectionReference *collRef = [self
      collectionRefWithDocuments:@{@"a" : @{@"a" : @1}, @"b" : @{@"a" : @2}, @"c" : @{@"a" : @3}}];

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"a < 3"];
  FIRQuery *query = [collRef queryFilteredUsingPredicate:predicate];
  query = [query queryOrderedByFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"a" ]]
                              descending:YES];

  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:query];

  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(snapshot), (@[ @"b", @"a" ]));
}

- (void)testFilterOnInfinity {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"inf" : @(INFINITY)},
    @"b" : @{@"inf" : @(-INFINITY)}
  }];

  FIRQuerySnapshot *results = [self readDocumentSetForRef:[collRef queryWhereField:@"inf"
                                                                         isEqualTo:@(INFINITY)]];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(results), (@[ @{@"inf" : @(INFINITY)} ]));
}

- (void)testCanExplicitlySortByDocumentID {
  NSDictionary *testDocs = @{
    @"a" : @{@"key" : @"a"},
    @"b" : @{@"key" : @"b"},
    @"c" : @{@"key" : @"c"},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  // Ideally this would be descending to validate it's different than
  // the default, but that requires an extra index
  FIRQuerySnapshot *docs =
      [self readDocumentSetForRef:[collection queryOrderedByFieldPath:[FIRFieldPath documentID]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(docs),
                        (@[ testDocs[@"a"], testDocs[@"b"], testDocs[@"c"] ]));
}

- (void)testCanQueryByDocumentID {
  NSDictionary *testDocs = @{
    @"aa" : @{@"key" : @"aa"},
    @"ab" : @{@"key" : @"ab"},
    @"ba" : @{@"key" : @"ba"},
    @"bb" : @{@"key" : @"bb"},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];
  FIRQuerySnapshot *docs =
      [self readDocumentSetForRef:[collection queryWhereFieldPath:[FIRFieldPath documentID]
                                                        isEqualTo:@"ab"]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(docs), (@[ testDocs[@"ab"] ]));
}

- (void)testCanQueryByDocumentIDs {
  NSDictionary *testDocs = @{
    @"aa" : @{@"key" : @"aa"},
    @"ab" : @{@"key" : @"ab"},
    @"ba" : @{@"key" : @"ba"},
    @"bb" : @{@"key" : @"bb"},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];
  FIRQuerySnapshot *docs =
      [self readDocumentSetForRef:[collection queryWhereFieldPath:[FIRFieldPath documentID]
                                                        isEqualTo:@"ab"]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(docs), (@[ testDocs[@"ab"] ]));

  docs = [self readDocumentSetForRef:[[collection queryWhereFieldPath:[FIRFieldPath documentID]
                                                        isGreaterThan:@"aa"]
                                         queryWhereFieldPath:[FIRFieldPath documentID]
                                         isLessThanOrEqualTo:@"ba"]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(docs), (@[ testDocs[@"ab"], testDocs[@"ba"] ]));
}

- (void)testCanQueryByDocumentIDsUsingRefs {
  NSDictionary *testDocs = @{
    @"aa" : @{@"key" : @"aa"},
    @"ab" : @{@"key" : @"ab"},
    @"ba" : @{@"key" : @"ba"},
    @"bb" : @{@"key" : @"bb"},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];
  FIRQuerySnapshot *docs = [self
      readDocumentSetForRef:[collection queryWhereFieldPath:[FIRFieldPath documentID]
                                                  isEqualTo:[collection documentWithPath:@"ab"]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(docs), (@[ testDocs[@"ab"] ]));

  docs = [self
      readDocumentSetForRef:[[collection queryWhereFieldPath:[FIRFieldPath documentID]
                                               isGreaterThan:[collection documentWithPath:@"aa"]]
                                queryWhereFieldPath:[FIRFieldPath documentID]
                                isLessThanOrEqualTo:[collection documentWithPath:@"ba"]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(docs), (@[ testDocs[@"ab"], testDocs[@"ba"] ]));
}

- (void)testWatchSurvivesNetworkDisconnect {
  XCTestExpectation *testExpectiation =
      [self expectationWithDescription:@"testWatchSurvivesNetworkDisconnect"];

  FIRCollectionReference *collectionRef = [self collectionRef];
  FIRDocumentReference *docRef = [collectionRef documentWithAutoID];

  FIRFirestore *firestore = collectionRef.firestore;

  [collectionRef
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:^(FIRQuerySnapshot *snapshot, NSError *error) {
                                             XCTAssertNil(error);
                                             if (!snapshot.empty && !snapshot.metadata.fromCache) {
                                               [testExpectiation fulfill];
                                             }
                                           }];

  [firestore disableNetworkWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [docRef setData:@{@"foo" : @"bar"}];
    [firestore enableNetworkWithCompletion:^(NSError *error) {
      XCTAssertNil(error);
    }];
  }];

  [self awaitExpectations];
}

- (void)testQueriesFireFromCacheWhenOffline {
  NSDictionary *testDocs = @{
    @"a" : @{@"foo" : @1},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  id<FIRListenerRegistration> registration = [collection
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"initial event"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), @[ @{@"foo" : @1} ]);
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  [self disableNetwork];
  querySnap = [self.eventAccumulator awaitEventWithName:@"offline event with isFromCache=YES"];
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  [self enableNetwork];
  querySnap = [self.eventAccumulator awaitEventWithName:@"back online event with isFromCache=NO"];
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  [registration remove];
}

- (void)testCanHaveMultipleMutationsWhileOffline {
  FIRCollectionReference *col = [self collectionRef];

  // set a few docs to known values
  NSDictionary *initialDocs = @{@"doc1" : @{@"key1" : @"value1"}, @"doc2" : @{@"key2" : @"value2"}};
  [self writeAllDocuments:initialDocs toCollection:col];

  // go offline for the rest of this test
  [self disableNetwork];

  // apply *multiple* mutations while offline
  [[col documentWithPath:@"doc1"] setData:@{@"key1b" : @"value1b"}];
  [[col documentWithPath:@"doc2"] setData:@{@"key2b" : @"value2b"}];

  FIRQuerySnapshot *result = [self readDocumentSetForRef:col];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), (@[
                          @{@"key1b" : @"value1b"},
                          @{@"key2b" : @"value2b"},
                        ]));
}

- (void)testArrayContainsQueries {
  NSDictionary *testDocs = @{
    @"a" : @{@"array" : @[ @42 ]},
    @"b" : @{@"array" : @[ @"a", @42, @"c" ]},
    @"c" : @{@"array" : @[ @41.999, @"42", @{@"a" : @[ @42 ]} ]},
    @"d" : @{@"array" : @[ @42 ], @"array2" : @[ @"bingo" ]}
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  // Search for 42
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                                         arrayContains:@42]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          @{@"array" : @[ @42 ]}, @{@"array" : @[ @"a", @42, @"c" ]},
                          @{@"array" : @[ @42 ], @"array2" : @[ @"bingo" ]}
                        ]));

  // NOTE: The backend doesn't currently support null, NaN, objects, or arrays, so there isn't much
  // of anything else interesting to test.
}

- (void)testCollectionGroupQueries {
  // Use .document() to get a random collection group name to use but ensure it starts with 'b'
  // for predictable ordering.
  NSString *collectionGroup = [NSString
      stringWithFormat:@"b%@", [[self.db collectionWithPath:@"foo"] documentWithAutoID].documentID];

  NSArray *docPaths = @[
    @"abc/123/${collectionGroup}/cg-doc1", @"abc/123/${collectionGroup}/cg-doc2",
    @"${collectionGroup}/cg-doc3", @"${collectionGroup}/cg-doc4",
    @"def/456/${collectionGroup}/cg-doc5", @"${collectionGroup}/virtual-doc/nested-coll/not-cg-doc",
    @"x${collectionGroup}/not-cg-doc", @"${collectionGroup}x/not-cg-doc",
    @"abc/123/${collectionGroup}x/not-cg-doc", @"abc/123/x${collectionGroup}/not-cg-doc",
    @"abc/${collectionGroup}"
  ];

  FIRWriteBatch *batch = [self.db batch];
  for (NSString *docPath in docPaths) {
    NSString *path = [docPath stringByReplacingOccurrencesOfString:@"${collectionGroup}"
                                                        withString:collectionGroup];
    [batch setData:@{@"x" : @1} forDocument:[self.db documentWithPath:path]];
  }
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  FIRQuerySnapshot *querySnapshot =
      [self readDocumentSetForRef:[self.db collectionGroupWithID:collectionGroup]];
  NSArray<NSString *> *ids = FIRQuerySnapshotGetIDs(querySnapshot);
  XCTAssertEqualObjects(ids, (@[ @"cg-doc1", @"cg-doc2", @"cg-doc3", @"cg-doc4", @"cg-doc5" ]));
}

- (void)testCollectionGroupQueriesWithStartAtEndAtWithArbitraryDocumentIDs {
  // Use .document() to get a random collection group name to use but ensure it starts with 'b'
  // for predictable ordering.
  NSString *collectionGroup = [NSString
      stringWithFormat:@"b%@", [[self.db collectionWithPath:@"foo"] documentWithAutoID].documentID];

  NSArray *docPaths = @[
    @"a/a/${collectionGroup}/cg-doc1", @"a/b/a/b/${collectionGroup}/cg-doc2",
    @"a/b/${collectionGroup}/cg-doc3", @"a/b/c/d/${collectionGroup}/cg-doc4",
    @"a/c/${collectionGroup}/cg-doc5", @"${collectionGroup}/cg-doc6", @"a/b/nope/nope"
  ];

  FIRWriteBatch *batch = [self.db batch];
  for (NSString *docPath in docPaths) {
    NSString *path = [docPath stringByReplacingOccurrencesOfString:@"${collectionGroup}"
                                                        withString:collectionGroup];
    [batch setData:@{@"x" : @1} forDocument:[self.db documentWithPath:path]];
  }
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  FIRQuerySnapshot *querySnapshot = [self
      readDocumentSetForRef:[[[[self.db collectionGroupWithID:collectionGroup]
                                queryOrderedByFieldPath:[FIRFieldPath documentID]]
                                queryStartingAfterValues:@[ @"a/b" ]]
                                queryEndingBeforeValues:@[
                                  [NSString stringWithFormat:@"a/b/%@/cg-doc3", collectionGroup]
                                ]]];

  NSArray<NSString *> *ids = FIRQuerySnapshotGetIDs(querySnapshot);
  XCTAssertEqualObjects(ids, (@[ @"cg-doc2" ]));
}

- (void)testCollectionGroupQueriesWithWhereFiltersOnArbitraryDocumentIDs {
  // Use .document() to get a random collection group name to use but ensure it starts with 'b'
  // for predictable ordering.
  NSString *collectionGroup = [NSString
      stringWithFormat:@"b%@", [[self.db collectionWithPath:@"foo"] documentWithAutoID].documentID];

  NSArray *docPaths = @[
    @"a/a/${collectionGroup}/cg-doc1", @"a/b/a/b/${collectionGroup}/cg-doc2",
    @"a/b/${collectionGroup}/cg-doc3", @"a/b/c/d/${collectionGroup}/cg-doc4",
    @"a/c/${collectionGroup}/cg-doc5", @"${collectionGroup}/cg-doc6", @"a/b/nope/nope"
  ];

  FIRWriteBatch *batch = [self.db batch];
  for (NSString *docPath in docPaths) {
    NSString *path = [docPath stringByReplacingOccurrencesOfString:@"${collectionGroup}"
                                                        withString:collectionGroup];
    [batch setData:@{@"x" : @1} forDocument:[self.db documentWithPath:path]];
  }
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  FIRQuerySnapshot *querySnapshot = [self
      readDocumentSetForRef:[[[self.db collectionGroupWithID:collectionGroup]
                                   queryWhereFieldPath:[FIRFieldPath documentID]
                                isGreaterThanOrEqualTo:@"a/b"]
                                queryWhereFieldPath:[FIRFieldPath documentID]
                                         isLessThan:[NSString stringWithFormat:@"a/b/%@/cg-doc3",
                                                                               collectionGroup]]];

  NSArray<NSString *> *ids = FIRQuerySnapshotGetIDs(querySnapshot);
  XCTAssertEqualObjects(ids, (@[ @"cg-doc2" ]));
}

@end
