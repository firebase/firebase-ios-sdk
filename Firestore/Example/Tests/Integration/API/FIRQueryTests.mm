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
#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Example/Tests/Util/FSTTestingHooks.h"

// TODO(MIEQ) update these imports with public imports when aggregate types are public
#import "Firestore/Source/API/FIRAggregateQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

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

- (void)testLimitToLastMustAlsoHaveExplicitOrderBy {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{}];
  FIRQuery *query = [collRef queryLimitedToLast:2];
  FSTAssertThrows([query getDocumentsWithCompletion:^(FIRQuerySnapshot *, NSError *){
                  }],
                  @"limit(toLast:) queries require specifying at least one OrderBy() clause.");
}

// Two queries that mapped to the same target ID are referred to as
// "mirror queries". An example for a mirror query is a limitToLast()
// query and a limit() query that share the same backend Target ID.
// Since limitToLast() queries are sent to the backend with a modified
// orderBy() clause, they can map to the same target representation as
// limit() query, even if both queries appear separate to the user.
- (void)testListenUnlistenRelistenSequenceOfMirrorQueries {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1},
    @"c" : @{@"k" : @"c", @"sort" : @1},
    @"d" : @{@"k" : @"d", @"sort" : @2},
  }];

  // Setup a `limit` query.
  FIRQuery *limit = [[collRef queryOrderedByField:@"sort" descending:NO] queryLimitedTo:2];
  FSTEventAccumulator *limitAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> limitRegistration =
      [limit addSnapshotListener:limitAccumulator.valueEventHandler];

  // Setup a mirroring `limitToLast` query.
  FIRQuery *limitToLast = [[collRef queryOrderedByField:@"sort"
                                             descending:YES] queryLimitedToLast:2];
  FSTEventAccumulator *limitToLastAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> limitToLastRegistration =
      [limitToLast addSnapshotListener:limitToLastAccumulator.valueEventHandler];

  // Verify both queries get expected result.
  FIRQuerySnapshot *snapshot = [limitAccumulator awaitEventWithName:@"Snapshot"];
  NSArray *expected = @[ @{@"k" : @"a", @"sort" : @0}, @{@"k" : @"b", @"sort" : @1} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  snapshot = [limitToLastAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"a", @"sort" : @0} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);

  // Unlisten then re-listen limit query.
  [limitRegistration remove];
  [limit addSnapshotListener:[limitAccumulator valueEventHandler]];

  // Verify limit query still works.
  snapshot = [limitAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"a", @"sort" : @0}, @{@"k" : @"b", @"sort" : @1} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);

  // Add a document that would change the result set.
  [self addDocumentRef:collRef data:@{@"k" : @"e", @"sort" : @-1}];

  // Verify both queries get expected result.
  snapshot = [limitAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"e", @"sort" : @-1}, @{@"k" : @"a", @"sort" : @0} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  snapshot = [limitToLastAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"a", @"sort" : @0}, @{@"k" : @"e", @"sort" : @-1} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);

  // Unlisten to limitToLast, update a doc, then relisten to limitToLast
  [limitToLastRegistration remove];
  [self updateDocumentRef:[collRef documentWithPath:@"a"] data:@{@"k" : @"a", @"sort" : @-2}];
  [limitToLast addSnapshotListener:[limitToLastAccumulator valueEventHandler]];

  // Verify both queries get expected result.
  snapshot = [limitAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"a", @"sort" : @-2}, @{@"k" : @"e", @"sort" : @-1} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  snapshot = [limitToLastAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"e", @"sort" : @-1}, @{@"k" : @"a", @"sort" : @-2} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
}

- (void)testLimitToLastQueriesWithCursors {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1},
    @"c" : @{@"k" : @"c", @"sort" : @1},
    @"d" : @{@"k" : @"d", @"sort" : @2},
  }];

  FIRQuerySnapshot *snapshot =
      [self readDocumentSetForRef:[[[collRef queryOrderedByField:@"sort"] queryLimitedToLast:3]
                                      queryEndingBeforeValues:@[ @2 ]]];
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetData(snapshot), (@[
        @{@"k" : @"a", @"sort" : @0}, @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"c", @"sort" : @1}
      ]));

  snapshot = [self readDocumentSetForRef:[[[collRef queryOrderedByField:@"sort"]
                                             queryLimitedToLast:3] queryEndingAtValues:@[ @1 ]]];
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetData(snapshot), (@[
        @{@"k" : @"a", @"sort" : @0}, @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"c", @"sort" : @1}
      ]));

  snapshot = [self readDocumentSetForRef:[[[collRef queryOrderedByField:@"sort"]
                                             queryLimitedToLast:3] queryStartingAtValues:@[ @2 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ @{@"k" : @"d", @"sort" : @2} ]));
  snapshot =
      [self readDocumentSetForRef:[[[collRef queryOrderedByField:@"sort"] queryLimitedToLast:3]
                                      queryStartingAfterValues:@[ @0 ]]];
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetData(snapshot), (@[
        @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"c", @"sort" : @1}, @{@"k" : @"d", @"sort" : @2}
      ]));

  snapshot =
      [self readDocumentSetForRef:[[[collRef queryOrderedByField:@"sort"] queryLimitedToLast:3]
                                      queryStartingAfterValues:@[ @-1 ]]];
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetData(snapshot), (@[
        @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"c", @"sort" : @1}, @{@"k" : @"d", @"sort" : @2}
      ]));
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

- (void)testQueriesCanRaiseInitialSnapshotFromCachedEmptyResults {
  FIRCollectionReference *collection = [self collectionRefWithDocuments:@{}];

  // Populate the cache with empty query result.
  FIRQuerySnapshot *querySnapshotA = [self readDocumentSetForRef:collection];
  XCTAssertFalse(querySnapshotA.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshotA), @[]);

  // Add a snapshot listener whose first event should be raised from cache.
  id<FIRListenerRegistration> registration = [collection
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:self.eventAccumulator.valueEventHandler];
  FIRQuerySnapshot *querySnapshotB = [self.eventAccumulator awaitEventWithName:@"initial event"];
  XCTAssertTrue(querySnapshotB.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshotB), @[]);

  [registration remove];
}

- (void)testQueriesCanRaiseInitialSnapshotFromEmptyDueToDeleteCachedResults {
  NSDictionary *testDocs = @{
    @"a" : @{@"foo" : @1},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];
  // Populate the cache with a single document.
  FIRQuerySnapshot *querySnapshotA = [self readDocumentSetForRef:collection];
  XCTAssertFalse(querySnapshotA.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshotA), @[ @{@"foo" : @1} ]);

  // Delete the document, making the cached query result empty.
  FIRDocumentReference *docRef = [collection documentWithPath:@"a"];
  [self deleteDocumentRef:docRef];

  // Add a snapshot listener whose first event should be raised from cache.
  id<FIRListenerRegistration> registration = [collection
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:self.eventAccumulator.valueEventHandler];
  FIRQuerySnapshot *querySnapshotB = [self.eventAccumulator awaitEventWithName:@"initial event"];
  XCTAssertTrue(querySnapshotB.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshotB), @[]);

  [registration remove];
}

- (void)testDocumentChangesUseNSNotFound {
  NSDictionary *testDocs = @{
    @"a" : @{@"foo" : @1},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  id<FIRListenerRegistration> registration =
      [collection addSnapshotListener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"initial event"];
  XCTAssertEqual(querySnap.documentChanges.count, 1ul);

  FIRDocumentChange *change = querySnap.documentChanges[0];
  XCTAssertEqual(change.oldIndex, NSNotFound);
  XCTAssertEqual(change.newIndex, 0ul);

  FIRDocumentReference *doc = change.document.reference;
  [self deleteDocumentRef:doc];

  querySnap = [self.eventAccumulator awaitEventWithName:@"delete"];
  XCTAssertEqual(querySnap.documentChanges.count, 1ul);

  change = querySnap.documentChanges[0];
  XCTAssertEqual(change.oldIndex, 0ul);
  XCTAssertEqual(change.newIndex, NSNotFound);

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

- (void)testQueriesCanUseNotEqualFilters {
  // These documents are ordered by value in "zip" since notEquals filter is an inequality, which
  // results in documents being sorted by value.
  NSDictionary *testDocs = @{
    @"a" : @{@"zip" : @(NAN)},
    @"b" : @{@"zip" : @91102},
    @"c" : @{@"zip" : @98101},
    @"d" : @{@"zip" : @98103},
    @"e" : @{@"zip" : @[ @98101 ]},
    @"f" : @{@"zip" : @[ @98101, @98102 ]},
    @"g" : @{@"zip" : @[ @"98101", @{@"zip" : @98101} ]},
    @"h" : @{@"zip" : @{@"code" : @500}},
    @"i" : @{@"zip" : [NSNull null]},
    @"j" : @{@"code" : @500},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  // Search for zips not matching 98101.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                                          isNotEqualTo:@98101]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          testDocs[@"a"], testDocs[@"b"], testDocs[@"d"], testDocs[@"e"],
                          testDocs[@"f"], testDocs[@"g"], testDocs[@"h"]
                        ]));

  // With objects.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                        isNotEqualTo:@{@"code" : @500}]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          testDocs[@"a"], testDocs[@"b"], testDocs[@"c"], testDocs[@"d"],
                          testDocs[@"e"], testDocs[@"f"], testDocs[@"g"]
                        ]));

  // With null.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                        isNotEqualTo:@[ [NSNull null] ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          testDocs[@"a"], testDocs[@"b"], testDocs[@"c"], testDocs[@"d"],
                          testDocs[@"e"], testDocs[@"f"], testDocs[@"g"], testDocs[@"h"]
                        ]));

  // With NAN.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip" isNotEqualTo:@(NAN)]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          testDocs[@"b"], testDocs[@"c"], testDocs[@"d"], testDocs[@"e"],
                          testDocs[@"f"], testDocs[@"g"], testDocs[@"h"]
                        ]));
}

- (void)testQueriesCanUseNotEqualFiltersWithDocIds {
  NSDictionary *testDocs = @{
    @"aa" : @{@"key" : @"aa"},
    @"ab" : @{@"key" : @"ab"},
    @"ba" : @{@"key" : @"ba"},
    @"bb" : @{@"key" : @"bb"},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  FIRQuerySnapshot *snapshot =
      [self readDocumentSetForRef:[collection queryWhereFieldPath:[FIRFieldPath documentID]
                                                     isNotEqualTo:@"aa"]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot),
                        (@[ testDocs[@"ab"], testDocs[@"ba"], testDocs[@"bb"] ]));
}

- (void)testQueriesCanUseArrayContainsFilters {
  NSDictionary *testDocs = @{
    @"a" : @{@"array" : @[ @42 ]},
    @"b" : @{@"array" : @[ @"a", @42, @"c" ]},
    @"c" : @{@"array" : @[ @41.999, @"42", @{@"a" : @[ @42 ]} ]},
    @"d" : @{@"array" : @[ @42 ], @"array2" : @[ @"bingo" ]},
    @"e" : @{@"array" : @[ [NSNull null] ]},
    @"f" : @{@"array" : @[ @(NAN) ]},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  // Search for 42
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                                         arrayContains:@42]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot),
                        (@[ testDocs[@"a"], testDocs[@"b"], testDocs[@"d"] ]));

  // With null.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                       arrayContains:[NSNull null]]];
  XCTAssertTrue(snapshot.isEmpty);

  // With NAN.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                       arrayContains:@(NAN)]];
  XCTAssertTrue(snapshot.isEmpty);
}

- (void)testQueriesCanUseInFilters {
  NSDictionary *testDocs = @{
    @"a" : @{@"zip" : @98101},
    @"b" : @{@"zip" : @91102},
    @"c" : @{@"zip" : @98103},
    @"d" : @{@"zip" : @[ @98101 ]},
    @"e" : @{@"zip" : @[ @"98101", @{@"zip" : @98101} ]},
    @"f" : @{@"zip" : @{@"code" : @500}},
    @"g" : @{@"zip" : @[ @98101, @98102 ]},
    @"h" : @{@"zip" : [NSNull null]},
    @"i" : @{@"zip" : @(NAN)}
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  // Search for zips matching 98101, 98103, and [98101, 98102].
  FIRQuerySnapshot *snapshot = [self
      readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                     in:@[ @98101, @98103, @[ @98101, @98102 ] ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot),
                        (@[ testDocs[@"a"], testDocs[@"c"], testDocs[@"g"] ]));

  // With objects
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                                  in:@[ @{@"code" : @500} ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ testDocs[@"f"] ]));

  // With null.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip" in:@[ [NSNull null] ]]];
  XCTAssertTrue(snapshot.isEmpty);

  // With null and a value.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                                  in:@[ [NSNull null], @98101 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ testDocs[@"a"] ]));

  // With NAN.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip" in:@[ @(NAN) ]]];
  XCTAssertTrue(snapshot.isEmpty);

  // With NAN and a value.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                                  in:@[ @(NAN), @98101 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ testDocs[@"a"] ]));
}

- (void)testQueriesCanUseInFiltersWithDocIds {
  NSDictionary *testDocs = @{
    @"aa" : @{@"key" : @"aa"},
    @"ab" : @{@"key" : @"ab"},
    @"ba" : @{@"key" : @"ba"},
    @"bb" : @{@"key" : @"bb"},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  FIRQuerySnapshot *snapshot =
      [self readDocumentSetForRef:[collection queryWhereFieldPath:[FIRFieldPath documentID]
                                                               in:@[ @"aa", @"ab" ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ testDocs[@"aa"], testDocs[@"ab"] ]));
}

- (void)testQueriesCanUseNotInFilters {
  // These documents are ordered by value in "zip" since the NOT_IN filter is an inequality, which
  // results in documents being sorted by value.
  NSDictionary *testDocs = @{
    @"a" : @{@"zip" : @(NAN)},
    @"b" : @{@"zip" : @91102},
    @"c" : @{@"zip" : @98101},
    @"d" : @{@"zip" : @98103},
    @"e" : @{@"zip" : @[ @98101 ]},
    @"f" : @{@"zip" : @[ @98101, @98102 ]},
    @"g" : @{@"zip" : @[ @"98101", @{@"zip" : @98101} ]},
    @"h" : @{@"zip" : @{@"code" : @500}},
    @"i" : @{@"zip" : [NSNull null]},
    @"j" : @{@"code" : @500},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  // Search for zips not matching 98101, 98103, and [98101, 98102].
  FIRQuerySnapshot *snapshot = [self
      readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                  notIn:@[ @98101, @98103, @[ @98101, @98102 ] ]]];
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetData(snapshot),
      (@[ testDocs[@"a"], testDocs[@"b"], testDocs[@"e"], testDocs[@"g"], testDocs[@"h"] ]));

  // With objects.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                               notIn:@[ @{@"code" : @500} ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          testDocs[@"a"], testDocs[@"b"], testDocs[@"c"], testDocs[@"d"],
                          testDocs[@"e"], testDocs[@"f"], testDocs[@"g"]
                        ]));

  // With null.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                               notIn:@[ [NSNull null] ]]];
  XCTAssertTrue(snapshot.isEmpty);

  // With NAN.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip" notIn:@[ @(NAN) ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          testDocs[@"b"], testDocs[@"c"], testDocs[@"d"], testDocs[@"e"],
                          testDocs[@"f"], testDocs[@"g"], testDocs[@"h"]
                        ]));

  // With NAN and a number.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"zip"
                                                               notIn:@[ @(NAN), @98101 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          testDocs[@"b"], testDocs[@"d"], testDocs[@"e"], testDocs[@"f"],
                          testDocs[@"g"], testDocs[@"h"]
                        ]));
}

- (void)testQueriesCanUseNotInFiltersWithDocIds {
  NSDictionary *testDocs = @{
    @"aa" : @{@"key" : @"aa"},
    @"ab" : @{@"key" : @"ab"},
    @"ba" : @{@"key" : @"ba"},
    @"bb" : @{@"key" : @"bb"},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  FIRQuerySnapshot *snapshot =
      [self readDocumentSetForRef:[collection queryWhereFieldPath:[FIRFieldPath documentID]
                                                            notIn:@[ @"aa", @"ab" ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ testDocs[@"ba"], testDocs[@"bb"] ]));
}

- (void)testQueriesCanUseArrayContainsAnyFilters {
  NSDictionary *testDocs = @{
    @"a" : @{@"array" : @[ @42 ]},
    @"b" : @{@"array" : @[ @"a", @42, @"c" ]},
    @"c" : @{@"array" : @[ @41.999, @"42", @{@"a" : @[ @42 ]} ]},
    @"d" : @{@"array" : @[ @42 ], @"array2" : @[ @"bingo" ]},
    @"e" : @{@"array" : @[ @43 ]},
    @"f" : @{@"array" : @[ @{@"a" : @42} ]},
    @"g" : @{@"array" : @42},
    @"h" : @{@"array" : @[ [NSNull null] ]},
    @"i" : @{@"array" : @[ @(NAN) ]},

  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  // Search for zips matching [42, 43].
  FIRQuerySnapshot *snapshot = [self
      readDocumentSetForRef:[collection queryWhereField:@"array" arrayContainsAny:@[ @42, @43 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot),
                        (@[ testDocs[@"a"], testDocs[@"b"], testDocs[@"d"], testDocs[@"e"] ]));

  // With objects.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                    arrayContainsAny:@[ @{@"a" : @42} ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          testDocs[@"f"],
                        ]));

  // With null.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                    arrayContainsAny:@[ [NSNull null] ]]];
  XCTAssertTrue(snapshot.isEmpty);

  // With null and a value.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                    arrayContainsAny:@[ [NSNull null], @43 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ testDocs[@"e"] ]));

  // With NAN.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                    arrayContainsAny:@[ @(NAN) ]]];
  XCTAssertTrue(snapshot.isEmpty);

  // With NAN and a value.
  snapshot = [self readDocumentSetForRef:[collection queryWhereField:@"array"
                                                    arrayContainsAny:@[ @(NAN), @43 ]]];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[ testDocs[@"e"] ]));
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
  [self commitWriteBatch:batch];

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
  [self commitWriteBatch:batch];

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
  [self commitWriteBatch:batch];

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

- (void)testOrQueries {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @0},
    @"doc2" : @{@"a" : @2, @"b" : @1},
    @"doc3" : @{@"a" : @3, @"b" : @2},
    @"doc4" : @{@"a" : @1, @"b" : @3},
    @"doc5" : @{@"a" : @1, @"b" : @1}
  }];

  // Two equalities: a==1 || b==1.
  FIRFilter *filter1 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter filterWhereField:@"b" isEqualTo:@1]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter1]
                     matchesResult:@[ @"doc1", @"doc2", @"doc4", @"doc5" ]];

  // (a==1 && b==0) || (a==3 && b==2)
  FIRFilter *filter2 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter filterWhereField:@"b" isEqualTo:@0]
    ]],
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"a" isEqualTo:@3], [FIRFilter filterWhereField:@"b" isEqualTo:@2]
    ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter2]
                     matchesResult:@[ @"doc1", @"doc3" ]];

  // a==1 && (b==0 || b==3).
  FIRFilter *filter3 = [FIRFilter andFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter orFilterWithFilters:@[
      [FIRFilter filterWhereField:@"b" isEqualTo:@0], [FIRFilter filterWhereField:@"b" isEqualTo:@3]
    ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter3]
                     matchesResult:@[ @"doc1", @"doc4" ]];

  // (a==2 || b==2) && (a==3 || b==3)
  FIRFilter *filter4 = [FIRFilter andFilterWithFilters:@[
    [FIRFilter orFilterWithFilters:@[
      [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b" isEqualTo:@2]
    ]],
    [FIRFilter orFilterWithFilters:@[
      [FIRFilter filterWhereField:@"a" isEqualTo:@3], [FIRFilter filterWhereField:@"b" isEqualTo:@3]
    ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter4] matchesResult:@[ @"doc3" ]];

  // Test with limits without orderBy (the __name__ ordering is the tie breaker).
  FIRFilter *filter5 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b" isEqualTo:@1]
  ]];
  [self checkOnlineAndOfflineQuery:[[collRef queryWhereFilter:filter5] queryLimitedTo:1]
                     matchesResult:@[ @"doc2" ]];
}

- (void)testOrQueriesWithIn {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @0},
    @"doc2" : @{@"b" : @1},
    @"doc3" : @{@"a" : @3, @"b" : @2},
    @"doc4" : @{@"a" : @1, @"b" : @3},
    @"doc5" : @{@"a" : @1},
    @"doc6" : @{@"a" : @2}
  }];

  // a==2 || b in [2,3]
  FIRFilter *filter = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b" in:@[ @2, @3 ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter]
                     matchesResult:@[ @"doc3", @"doc4", @"doc6" ]];
}

- (void)testOrQueriesWithArrayMembership {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @[ @0 ]},
    @"doc2" : @{@"b" : @[ @1 ]},
    @"doc3" : @{@"a" : @3, @"b" : @[ @2, @7 ]},
    @"doc4" : @{@"a" : @1, @"b" : @[ @3, @7 ]},
    @"doc5" : @{@"a" : @1},
    @"doc6" : @{@"a" : @2}
  }];

  // a==2 || b array-contains 7
  FIRFilter *filter1 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b"
                                                                  arrayContains:@7]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter1]
                     matchesResult:@[ @"doc3", @"doc4", @"doc6" ]];

  // a==2 || b array-contains-any [0, 3]
  FIRFilter *filter2 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b"
                                                               arrayContainsAny:@[ @0, @3 ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter2]
                     matchesResult:@[ @"doc1", @"doc4", @"doc6" ]];
}

- (void)testMultipleInOps {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @0},
    @"doc2" : @{@"b" : @1},
    @"doc3" : @{@"a" : @3, @"b" : @2},
    @"doc4" : @{@"a" : @1, @"b" : @3},
    @"doc5" : @{@"a" : @1},
    @"doc6" : @{@"a" : @2}
  }];

  // Two IN operations on different fields with disjunction.
  FIRFilter *filter1 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" in:@[ @2, @3 ]], [FIRFilter filterWhereField:@"b"
                                                                               in:@[ @0, @2 ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter1]
                     matchesResult:@[ @"doc1", @"doc3", @"doc6" ]];

  // Two IN operations on the same field with disjunction.
  // a IN [0,3] || a IN [0,2] should union them (similar to: a IN [0,2,3]).
  FIRFilter *filter2 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" in:@[ @0, @3 ]], [FIRFilter filterWhereField:@"a"
                                                                               in:@[ @0, @2 ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter2]
                     matchesResult:@[ @"doc3", @"doc6" ]];
}

- (void)testUsingInWithArrayContainsAny {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @[ @0 ]},
    @"doc2" : @{@"b" : @[ @1 ]},
    @"doc3" : @{@"a" : @3, @"b" : @[ @2, @7 ], @"c" : @10},
    @"doc4" : @{@"a" : @1, @"b" : @[ @3, @7 ]},
    @"doc5" : @{@"a" : @1},
    @"doc6" : @{@"a" : @2, @"c" : @20}
  }];

  FIRFilter *filter1 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" in:@[ @2, @3 ]], [FIRFilter filterWhereField:@"b"
                                                                 arrayContainsAny:@[ @0, @7 ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter1]
                     matchesResult:@[ @"doc1", @"doc3", @"doc4", @"doc6" ]];

  FIRFilter *filter2 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"a" in:@[ @2, @3 ]], [FIRFilter filterWhereField:@"c"
                                                                          isEqualTo:@10]
    ]],
    [FIRFilter filterWhereField:@"b" arrayContainsAny:@[ @0, @7 ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter2]
                     matchesResult:@[ @"doc1", @"doc3", @"doc4" ]];
}

- (void)testUseInWithArrayContains {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @[ @0 ]},
    @"doc2" : @{@"b" : @[ @1 ]},
    @"doc3" : @{@"a" : @3, @"b" : @[ @2, @7 ]},
    @"doc4" : @{@"a" : @1, @"b" : @[ @3, @7 ]},
    @"doc5" : @{@"a" : @1},
    @"doc6" : @{@"a" : @2}
  }];

  FIRFilter *filter1 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" in:@[ @2, @3 ]], [FIRFilter filterWhereField:@"b"
                                                                 arrayContainsAny:@[ @3 ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter1]
                     matchesResult:@[ @"doc3", @"doc4", @"doc6" ]];

  FIRFilter *filter2 = [FIRFilter andFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" in:@[ @2, @3 ]], [FIRFilter filterWhereField:@"b"
                                                                    arrayContains:@7]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter2] matchesResult:@[ @"doc3" ]];

  FIRFilter *filter3 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" in:@[ @2, @3 ]], [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"b" arrayContains:@3], [FIRFilter filterWhereField:@"a"
                                                                            isEqualTo:@1]
    ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter3]
                     matchesResult:@[ @"doc3", @"doc4", @"doc6" ]];

  FIRFilter *filter4 = [FIRFilter andFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" in:@[ @2, @3 ]], [FIRFilter orFilterWithFilters:@[
      [FIRFilter filterWhereField:@"b" arrayContains:@7], [FIRFilter filterWhereField:@"a"
                                                                            isEqualTo:@1]
    ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter4] matchesResult:@[ @"doc3" ]];
}

- (void)testOrderByEquality {
  // TODO(orquery): Enable this test against production when possible.
  XCTSkipIf(![FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test if running against production because order-by-equality is not "
            "supported yet.");

  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @[ @0 ]},
    @"doc2" : @{@"b" : @[ @1 ]},
    @"doc3" : @{@"a" : @3, @"b" : @[ @2, @7 ], @"c" : @10},
    @"doc4" : @{@"a" : @1, @"b" : @[ @3, @7 ]},
    @"doc5" : @{@"a" : @1},
    @"doc6" : @{@"a" : @2, @"c" : @20}
  }];

  [self checkOnlineAndOfflineQuery:[[collRef queryWhereFilter:[FIRFilter filterWhereField:@"a"
                                                                                isEqualTo:@1]]
                                       queryOrderedByField:@"a"]
                     matchesResult:@[ @"doc1", @"doc4", @"doc5" ]];

  [self checkOnlineAndOfflineQuery:[[collRef
                                       queryWhereFilter:[FIRFilter filterWhereField:@"a"
                                                                                 in:@[ @2, @3 ]]]
                                       queryOrderedByField:@"a"]
                     matchesResult:@[ @"doc6", @"doc3" ]];
}

- (void)testResumingAQueryShouldUseBloomFilterToAvoidFullRequery {
  // TODO(b/291365820): Stop skipping this test when running against the Firestore emulator once
  // the emulator is improved to include a bloom filter in the existence filter messages that it
  // sends.
  XCTSkipIf([FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test when running against the Firestore emulator because the emulator does "
            "not include a bloom filter when it sends existence filter messages, making it "
            "impossible for this test to verify the correctness of the bloom filter.");

  // Set this test to stop when the first failure occurs because some test assertion failures make
  // the rest of the test not applicable or will even crash.
  [self setContinueAfterFailure:NO];

  // Prepare the names and contents of the 100 documents to create.
  NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *testDocs =
      [[NSMutableDictionary alloc] init];
  for (int i = 0; i < 100; i++) {
    [testDocs setValue:@{@"key" : @42} forKey:[NSString stringWithFormat:@"doc%@", @(1000 + i)]];
  }

  // Each iteration of the "while" loop below runs a single iteration of the test. The test will
  // be run multiple times only if a bloom filter false positive occurs.
  int attemptNumber = 0;
  while (true) {
    attemptNumber++;

    // Create 100 documents in a new collection.
    FIRCollectionReference *collRef = [self collectionRefWithDocuments:testDocs];

    // Run a query to populate the local cache with the 100 documents and a resume token.
    FIRQuerySnapshot *querySnapshot1 = [self readDocumentSetForRef:collRef
                                                            source:FIRFirestoreSourceDefault];
    XCTAssertEqual(querySnapshot1.count, 100, @"querySnapshot1.count has an unexpected value");
    NSArray<FIRDocumentReference *> *createdDocuments =
        FIRDocumentReferenceArrayFromQuerySnapshot(querySnapshot1);

    // Delete 50 of the 100 documents. Use a different Firestore instance to avoid affecting the
    // local cache.
    NSSet<NSString *> *deletedDocumentIds;
    {
      FIRFirestore *db2 = [self firestore];
      FIRWriteBatch *batch = [db2 batch];

      NSMutableArray<NSString *> *deletedDocumentIdsAccumulator = [[NSMutableArray alloc] init];
      for (decltype(createdDocuments.count) i = 0; i < createdDocuments.count; i += 2) {
        FIRDocumentReference *documentToDelete = [db2 documentWithPath:createdDocuments[i].path];
        [batch deleteDocument:documentToDelete];
        [deletedDocumentIdsAccumulator addObject:documentToDelete.documentID];
      }

      [self commitWriteBatch:batch];

      deletedDocumentIds = [NSSet setWithArray:deletedDocumentIdsAccumulator];
    }
    XCTAssertEqual(deletedDocumentIds.count, 50u, @"deletedDocumentIds has the wrong size");

    // Wait for 10 seconds, during which Watch will stop tracking the query and will send an
    // existence filter rather than "delete" events when the query is resumed.
    [NSThread sleepForTimeInterval:10.0f];

    // Resume the query and save the resulting snapshot for verification.
    // Use some internal testing hooks to "capture" the existence filter mismatches to verify that
    // Watch sent a bloom filter, and it was used to avert a full requery.
    __block FIRQuerySnapshot *querySnapshot2;
    NSArray<FSTTestingHooksExistenceFilterMismatchInfo *> *existenceFilterMismatches =
        [FSTTestingHooks captureExistenceFilterMismatchesDuringBlock:^{
          querySnapshot2 = [self readDocumentSetForRef:collRef source:FIRFirestoreSourceDefault];
        }];

    // Verify that the snapshot from the resumed query contains the expected documents; that is,
    // that it contains the 50 documents that were _not_ deleted.
    {
      NSMutableArray<NSString *> *expectedDocumentIds = [[NSMutableArray alloc] init];
      for (FIRDocumentReference *documentRef in createdDocuments) {
        if (![deletedDocumentIds containsObject:documentRef.documentID]) {
          [expectedDocumentIds addObject:documentRef.documentID];
        }
      }
      XCTAssertEqualObjects([NSSet setWithArray:FIRQuerySnapshotGetIDs(querySnapshot2)],
                            [NSSet setWithArray:expectedDocumentIds],
                            @"querySnapshot2 has the wrong documents");
    }

    // Verify that Watch sent an existence filter with the correct counts when the query was
    // resumed.
    XCTAssertEqual(existenceFilterMismatches.count, 1u,
                   @"Watch should have sent exactly 1 existence filter");
    FSTTestingHooksExistenceFilterMismatchInfo *existenceFilterMismatchInfo =
        existenceFilterMismatches[0];
    XCTAssertEqual(existenceFilterMismatchInfo.localCacheCount, 100);
    XCTAssertEqual(existenceFilterMismatchInfo.existenceFilterCount, 50);

    // Verify that Watch sent a valid bloom filter.
    FSTTestingHooksBloomFilter *bloomFilter = existenceFilterMismatchInfo.bloomFilter;
    XCTAssertNotNil(bloomFilter,
                    "Watch should have included a bloom filter in the existence filter");
    XCTAssertGreaterThan(bloomFilter.hashCount, 0);
    XCTAssertGreaterThan(bloomFilter.bitmapLength, 0);
    XCTAssertGreaterThan(bloomFilter.padding, 0);
    XCTAssertLessThan(bloomFilter.padding, 8);

    // Verify that the bloom filter was successfully used to avert a full requery. If a false
    // positive occurred then retry the entire test. Although statistically rare, false positives
    // are expected to happen occasionally. When a false positive _does_ happen, just retry the test
    // with a different set of documents. If that retry _also_ experiences a false positive, then
    // fail the test because that is so improbable that something must have gone wrong.
    if (attemptNumber == 1 && !bloomFilter.applied) {
      continue;
    }

    XCTAssertTrue(bloomFilter.applied,
                  @"The bloom filter should have been successfully applied with attemptNumber=%@",
                  @(attemptNumber));

    // Break out of the test loop now that the test passes.
    break;
  }
}

- (void)
    testBloomFilterShouldAvertAFullRequeryWhenDocumentsWereAddedDeletedRemovedUpdatedAndUnchangedSinceTheResumeToken {
  // TODO(b/291365820): Stop skipping this test when running against the Firestore emulator once
  // the emulator is improved to include a bloom filter in the existence filter messages that it
  // sends.
  XCTSkipIf([FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test when running against the Firestore emulator because the emulator does "
            "not include a bloom filter when it sends existence filter messages, making it "
            "impossible for this test to verify the correctness of the bloom filter.");

  // Set this test to stop when the first failure occurs because some test assertion failures make
  // the rest of the test not applicable or will even crash.
  [self setContinueAfterFailure:NO];

  // Prepare the names and contents of the 20 documents to create.
  NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *testDocs =
      [[NSMutableDictionary alloc] init];
  for (int i = 0; i < 20; i++) {
    [testDocs setValue:@{@"key" : @42, @"removed" : @NO}
                forKey:[NSString stringWithFormat:@"doc%@", @(1000 + i)]];
  }

  // Each iteration of the "while" loop below runs a single iteration of the test. The test will
  // be run multiple times only if a bloom filter false positive occurs.
  int attemptNumber = 0;
  while (true) {
    attemptNumber++;

    // Create 20 documents in a new collection.
    FIRCollectionReference *collRef = [self collectionRefWithDocuments:testDocs];
    FIRQuery *query = [collRef queryWhereField:@"removed" isEqualTo:@NO];

    // Run a query to populate the local cache with the 20 documents and a resume token.
    FIRQuerySnapshot *querySnapshot1 = [self readDocumentSetForRef:query
                                                            source:FIRFirestoreSourceDefault];
    XCTAssertEqual(querySnapshot1.count, 20u, @"querySnapshot1.count has an unexpected value");
    NSArray<FIRDocumentReference *> *createdDocuments =
        FIRDocumentReferenceArrayFromQuerySnapshot(querySnapshot1);

    // Out of the 20 existing documents, leave 5 docs untouched, delete 5 docs, remove 5 docs,
    // update 5 docs, and add 15 new docs.
    NSSet<NSString *> *deletedDocumentIds;
    NSSet<NSString *> *removedDocumentIds;
    NSSet<NSString *> *updatedDocumentIds;
    NSMutableArray<NSString *> *addedDocumentIds = [[NSMutableArray alloc] init];

    {
      FIRFirestore *db2 = [self firestore];
      FIRWriteBatch *batch = [db2 batch];

      NSMutableArray<NSString *> *deletedDocumentIdsAccumulator = [[NSMutableArray alloc] init];
      for (decltype(createdDocuments.count) i = 0; i < createdDocuments.count; i += 4) {
        FIRDocumentReference *documentToDelete = [db2 documentWithPath:createdDocuments[i].path];
        [batch deleteDocument:documentToDelete];
        [deletedDocumentIdsAccumulator addObject:documentToDelete.documentID];
      }
      deletedDocumentIds = [NSSet setWithArray:deletedDocumentIdsAccumulator];
      XCTAssertEqual(deletedDocumentIds.count, 5u, @"deletedDocumentIds has the wrong size");

      // Update 5 documents to no longer match the query.
      NSMutableArray<NSString *> *removedDocumentIdsAccumulator = [[NSMutableArray alloc] init];
      for (decltype(createdDocuments.count) i = 1; i < createdDocuments.count; i += 4) {
        FIRDocumentReference *documentToRemove = [db2 documentWithPath:createdDocuments[i].path];
        [batch updateData:@{@"removed" : @YES} forDocument:documentToRemove];
        [removedDocumentIdsAccumulator addObject:documentToRemove.documentID];
      }
      removedDocumentIds = [NSSet setWithArray:removedDocumentIdsAccumulator];
      XCTAssertEqual(removedDocumentIds.count, 5u, @"removedDocumentIds has the wrong size");

      // Update 5 documents, but ensure they still match the query.
      NSMutableArray<NSString *> *updatedDocumentIdsAccumulator = [[NSMutableArray alloc] init];
      for (decltype(createdDocuments.count) i = 2; i < createdDocuments.count; i += 4) {
        FIRDocumentReference *documentToUpdate = [db2 documentWithPath:createdDocuments[i].path];
        [batch updateData:@{@"key" : @43} forDocument:documentToUpdate];
        [updatedDocumentIdsAccumulator addObject:documentToUpdate.documentID];
      }
      updatedDocumentIds = [NSSet setWithArray:updatedDocumentIdsAccumulator];
      XCTAssertEqual(updatedDocumentIds.count, 5u, @"updatedDocumentIds has the wrong size");

      for (int i = 0; i < 15; i += 1) {
        FIRDocumentReference *documentToAdd = [db2
            documentWithPath:[NSString stringWithFormat:@"%@/newDoc%@", collRef.path, @(1000 + i)]];
        [batch setData:@{@"key" : @42, @"removed" : @NO} forDocument:documentToAdd];
        [addedDocumentIds addObject:documentToAdd.documentID];
      }

      // Ensure the documentIds above are mutually exclusive.
      NSMutableSet<NSString *> *mergedSet = [NSMutableSet setWithArray:addedDocumentIds];
      [mergedSet unionSet:deletedDocumentIds];
      [mergedSet unionSet:removedDocumentIds];
      [mergedSet unionSet:updatedDocumentIds];
      XCTAssertEqual(mergedSet.count, 30u, @"There are documents experienced multiple operations.");

      [self commitWriteBatch:batch];
    }

    // Wait for 10 seconds, during which Watch will stop tracking the query and will send an
    // existence filter rather than "delete" events when the query is resumed.
    [NSThread sleepForTimeInterval:10.0f];

    // Resume the query and save the resulting snapshot for verification. Use some internal testing
    // hooks to "capture" the existence filter mismatches to verify that Watch sent a bloom
    // filter, and it was used to avert a full requery.
    __block FIRQuerySnapshot *querySnapshot2;
    NSArray<FSTTestingHooksExistenceFilterMismatchInfo *> *existenceFilterMismatches =
        [FSTTestingHooks captureExistenceFilterMismatchesDuringBlock:^{
          querySnapshot2 = [self readDocumentSetForRef:query source:FIRFirestoreSourceDefault];
        }];
    XCTAssertEqual(querySnapshot2.count, 25u, @"querySnapshot1.count has an unexpected value");

    // Verify that the snapshot from the resumed query contains the expected documents; that is, 10
    // existing documents that still match the query, and 15 documents that are newly added.
    {
      NSMutableArray<NSString *> *expectedDocumentIds = [[NSMutableArray alloc] init];
      for (FIRDocumentReference *documentRef in createdDocuments) {
        if (![deletedDocumentIds containsObject:documentRef.documentID] &&
            ![removedDocumentIds containsObject:documentRef.documentID]) {
          [expectedDocumentIds addObject:documentRef.documentID];
        }
      }
      [expectedDocumentIds addObjectsFromArray:addedDocumentIds];
      XCTAssertEqualObjects([NSSet setWithArray:FIRQuerySnapshotGetIDs(querySnapshot2)],
                            [NSSet setWithArray:expectedDocumentIds],
                            @"querySnapshot2 has the wrong documents");
    }

    // Verify that Watch sent an existence filter with the correct counts when the query was
    // resumed.
    XCTAssertEqual(existenceFilterMismatches.count, 1u,
                   @"Watch should have sent exactly 1 existence filter");
    FSTTestingHooksExistenceFilterMismatchInfo *existenceFilterMismatchInfo =
        existenceFilterMismatches[0];
    XCTAssertEqual(existenceFilterMismatchInfo.localCacheCount, 35);
    XCTAssertEqual(existenceFilterMismatchInfo.existenceFilterCount, 25);

    // Verify that Watch sent a valid bloom filter.
    FSTTestingHooksBloomFilter *bloomFilter = existenceFilterMismatchInfo.bloomFilter;
    XCTAssertNotNil(bloomFilter,
                    "Watch should have included a bloom filter in the existence filter");

    // Verify that the bloom filter was successfully used to avert a full requery. If a false
    // positive occurred then retry the entire test. Although statistically rare, false positives
    // are expected to happen occasionally. When a false positive _does_ happen, just retry the test
    // with a different set of documents. If that retry _also_ experiences a false positive, then
    // fail the test because that is so improbable that something must have gone wrong.
    if (attemptNumber == 1 && !bloomFilter.applied) {
      continue;
    }

    XCTAssertTrue(bloomFilter.applied,
                  @"The bloom filter should have been successfully applied with attemptNumber=%@",
                  @(attemptNumber));

    // Break out of the test loop now that the test passes.
    break;
  }
}

- (void)testBloomFilterShouldCorrectlyEncodeComplexUnicodeCharacters {
  // TODO(b/291365820): Stop skipping this test when running against the Firestore emulator once
  // the emulator is improved to include a bloom filter in the existence filter messages that it
  // sends.
  XCTSkipIf([FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test when running against the Firestore emulator because the emulator does "
            "not include a bloom filter when it sends existence filter messages, making it "
            "impossible for this test to verify the correctness of the bloom filter.");

  // Set this test to stop when the first failure occurs because some test assertion failures make
  // the rest of the test not applicable or will even crash.
  [self setContinueAfterFailure:NO];

  // Define a comparator that compares `NSString` objects in a way that orders canonically-
  // equivalent, but distinct, strings in a consistent manner by using `NSForcedOrderingSearch`.
  // Otherwise, the bare `[NSString compare:]` method considers canonically-equivalent, but
  // distinct, strings as "equal" and orders them indeterminately.
  NSComparator sortComparator = ^(NSString *string1, NSString *string2) {
    return [string1 compare:string2 options:NSForcedOrderingSearch];
  };

  // Firestore does not do any Unicode normalization on the document IDs. Therefore, two document
  // IDs that are canonically-equivalent (i.e. they visually appear identical) but are represented
  // by a different sequence of Unicode code points are treated as distinct document IDs.
  NSArray<NSString *> *testDocIds;
  {
    NSMutableArray<NSString *> *testDocIdsAccumulator = [[NSMutableArray alloc] init];
    [testDocIdsAccumulator addObject:@"DocumentToDelete"];
    // The next two strings both end with "e" with an accent: the first uses the dedicated Unicode
    // code point for this character, while the second uses the standard lowercase "e" followed by
    // the accent combining character.
    [testDocIdsAccumulator addObject:@"LowercaseEWithAcuteAccent_\u00E9"];
    [testDocIdsAccumulator addObject:@"LowercaseEWithAcuteAccent_\u0065\u0301"];
    // The next two strings both end with an "e" with two different accents applied via the
    // following two combining characters. The combining characters are specified in a different
    // order and Firestore treats these document IDs as unique, despite the order of the combining
    // characters being irrelevant.
    [testDocIdsAccumulator addObject:@"LowercaseEWithMultipleAccents_\u0065\u0301\u0327"];
    [testDocIdsAccumulator addObject:@"LowercaseEWithMultipleAccents_\u0065\u0327\u0301"];
    // The next string contains a character outside the BMP (the "basic multilingual plane"); that
    // is, its code point is greater than 0xFFFF. Since NSString stores text in sequences of 16-bit
    // code units, using the UTF-16 encoding (according to
    // https://www.objc.io/issues/9-strings/unicode) it is stored as a surrogate pair, two 16-bit
    // code units U+D83D and U+DE00, to represent this character. Make sure that its presence is
    // correctly tested in the bloom filter, which uses UTF-8 encoding.
    [testDocIdsAccumulator addObject:@"Smiley_\U0001F600"];

    testDocIds = [NSArray arrayWithArray:testDocIdsAccumulator];
  }

  // Verify assumptions about the equivalence of strings in `testDocIds`.
  XCTAssertEqualObjects(testDocIds[1].decomposedStringWithCanonicalMapping,
                        testDocIds[2].decomposedStringWithCanonicalMapping);
  XCTAssertEqualObjects(testDocIds[3].decomposedStringWithCanonicalMapping,
                        testDocIds[4].decomposedStringWithCanonicalMapping);
  XCTAssertEqual([testDocIds[5] characterAtIndex:7], 0xD83D);
  XCTAssertEqual([testDocIds[5] characterAtIndex:8], 0xDE00);

  // Create the mapping from document ID to document data for the document IDs specified in
  // `testDocIds`.
  NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *testDocs =
      [[NSMutableDictionary alloc] init];
  for (NSString *testDocId in testDocIds) {
    [testDocs setValue:@{@"foo" : @42} forKey:testDocId];
  }

  // Create the documents whose names contain complex Unicode characters in a new collection.
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:testDocs];

  // Run a query to populate the local cache with documents that have names with complex Unicode
  // characters.
  {
    FIRQuerySnapshot *querySnapshot1 = [self readDocumentSetForRef:collRef
                                                            source:FIRFirestoreSourceDefault];
    XCTAssertEqualObjects(
        [FIRQuerySnapshotGetIDs(querySnapshot1) sortedArrayUsingComparator:sortComparator],
        [testDocIds sortedArrayUsingComparator:sortComparator],
        @"querySnapshot1 has the wrong documents");
  }

  // Delete one of the documents so that the next call to collection.get() will experience an
  // existence filter mismatch. Use a different Firestore instance to avoid affecting the local
  // cache.
  FIRDocumentReference *documentToDelete = [collRef documentWithPath:@"DocumentToDelete"];
  {
    FIRFirestore *db2 = [self firestore];
    [self deleteDocumentRef:[db2 documentWithPath:documentToDelete.path]];
  }

  // Wait for 10 seconds, during which Watch will stop tracking the query and will send an
  // existence filter rather than "delete" events when the query is resumed.
  [NSThread sleepForTimeInterval:10.0f];

  // Resume the query and save the resulting snapshot for verification. Use some internal testing
  // hooks to "capture" the existence filter mismatches.
  __block FIRQuerySnapshot *querySnapshot2;
  NSArray<FSTTestingHooksExistenceFilterMismatchInfo *> *existenceFilterMismatches =
      [FSTTestingHooks captureExistenceFilterMismatchesDuringBlock:^{
        querySnapshot2 = [self readDocumentSetForRef:collRef source:FIRFirestoreSourceDefault];
      }];

  // Verify that the snapshot from the resumed query contains the expected documents; that is, that
  // it contains the documents whose names contain complex Unicode characters and _not_ the document
  // that was deleted.
  {
    NSMutableArray<NSString *> *querySnapshot2ExpectedDocumentIds =
        [NSMutableArray arrayWithArray:testDocIds];
    [querySnapshot2ExpectedDocumentIds removeObject:documentToDelete.documentID];
    XCTAssertEqualObjects(
        [FIRQuerySnapshotGetIDs(querySnapshot2) sortedArrayUsingComparator:sortComparator],
        [querySnapshot2ExpectedDocumentIds sortedArrayUsingComparator:sortComparator],
        @"querySnapshot2 has the wrong documents");
  }

  // Verify that Watch sent an existence filter with the correct counts.
  XCTAssertEqual(existenceFilterMismatches.count, 1u,
                 @"Watch should have sent exactly 1 existence filter");
  FSTTestingHooksExistenceFilterMismatchInfo *existenceFilterMismatchInfo =
      existenceFilterMismatches[0];
  XCTAssertEqual(existenceFilterMismatchInfo.localCacheCount, (int)testDocIds.count);
  XCTAssertEqual(existenceFilterMismatchInfo.existenceFilterCount, (int)testDocIds.count - 1);

  // Verify that Watch sent a valid bloom filter.
  FSTTestingHooksBloomFilter *bloomFilter = existenceFilterMismatchInfo.bloomFilter;
  XCTAssertNotNil(bloomFilter, "Watch should have included a bloom filter in the existence filter");

  // The bloom filter application should statistically be successful almost every time; the _only_
  // time when it would _not_ be successful is if there is a false positive when testing for
  // 'DocumentToDelete' in the bloom filter. So verify that the bloom filter application is
  // successful, unless there was a false positive.
  BOOL isFalsePositive = [bloomFilter mightContain:documentToDelete];
  XCTAssertEqual(bloomFilter.applied, !isFalsePositive);

  // Verify that the bloom filter contains the document paths with complex Unicode characters.
  for (FIRDocumentSnapshot *documentSnapshot in querySnapshot2.documents) {
    XCTAssertTrue([bloomFilter mightContain:documentSnapshot.reference],
                  @"The bloom filter should contain %@", documentSnapshot.documentID);
  }
}

@end
