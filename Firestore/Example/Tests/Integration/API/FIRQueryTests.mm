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

namespace {

NSArray<NSString *> *SortedStringsNotIn(NSSet<NSString *> *set, NSSet<NSString *> *remove) {
  NSMutableSet<NSString *> *mutableSet = [NSMutableSet setWithSet:set];
  [mutableSet minusSet:remove];
  return [mutableSet.allObjects sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

}  // namespace

@interface FIRQueryTests : FSTIntegrationTestCase
@end

@implementation FIRQueryTests

/**
 * Checks that running the query while online (against the backend/emulator) results in the same
 * documents as running the query while offline. It also checks that both online and offline
 * query result is equal to the expected documents.
 *
 * @param query The query to check.
 * @param expectedDocs Array of document keys that are expected to match the query.
 */
- (void)checkOnlineAndOfflineQuery:(FIRQuery *)query matchesResult:(NSArray *)expectedDocs {
  FIRQuerySnapshot *docsFromServer = [self readDocumentSetForRef:query
                                                          source:FIRFirestoreSourceServer];
  FIRQuerySnapshot *docsFromCache = [self readDocumentSetForRef:query
                                                         source:FIRFirestoreSourceCache];

  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(docsFromServer),
                        FIRQuerySnapshotGetIDs(docsFromCache));
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(docsFromCache), expectedDocs);
}

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

- (void)testOrQueriesWithCompositeIndexes {
  // TODO(orquery): Enable this test against production when possible.
  XCTSkipIf(![FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test if running against production because order-by-equality is not "
            "supported yet.");

  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @0},
    @"doc2" : @{@"a" : @2, @"b" : @1},
    @"doc3" : @{@"a" : @3, @"b" : @2},
    @"doc4" : @{@"a" : @1, @"b" : @3},
    @"doc5" : @{@"a" : @1, @"b" : @1}
  }];

  // with one inequality: a>2 || b==1.
  FIRFilter *filter1 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isGreaterThan:@2], [FIRFilter filterWhereField:@"b"
                                                                          isEqualTo:@1]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter1]
                     matchesResult:@[ @"doc5", @"doc2", @"doc3" ]];

  // Test with limits (implicit order by ASC): (a==1) || (b > 0) LIMIT 2
  FIRFilter *filter2 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter filterWhereField:@"b"
                                                                  isGreaterThan:@0]
  ]];
  [self checkOnlineAndOfflineQuery:[[collRef queryWhereFilter:filter2] queryLimitedTo:2]
                     matchesResult:@[ @"doc1", @"doc2" ]];

  // Test with limits (explicit order by): (a==1) || (b > 0) LIMIT_TO_LAST 2
  // Note: The public query API does not allow implicit ordering when limitToLast is used.
  FIRFilter *filter3 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter filterWhereField:@"b"
                                                                  isGreaterThan:@0]
  ]];
  [self checkOnlineAndOfflineQuery:[[[collRef queryWhereFilter:filter3] queryLimitedToLast:2]
                                       queryOrderedByField:@"b"]
                     matchesResult:@[ @"doc3", @"doc4" ]];

  // Test with limits (explicit order by ASC): (a==2) || (b == 1) ORDER BY a LIMIT 1
  FIRFilter *filter4 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b" isEqualTo:@1]
  ]];
  [self checkOnlineAndOfflineQuery:[[[collRef queryWhereFilter:filter4] queryLimitedTo:1]
                                       queryOrderedByField:@"a"]
                     matchesResult:@[ @"doc5" ]];

  // Test with limits (explicit order by DESC): (a==2) || (b == 1) ORDER BY a LIMIT_TO_LAST 1
  FIRFilter *filter5 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b" isEqualTo:@1]
  ]];
  [self checkOnlineAndOfflineQuery:[[[collRef queryWhereFilter:filter5] queryLimitedToLast:1]
                                       queryOrderedByField:@"a"]
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

- (void)testOrQueriesWithNotIn {
  // TODO(orquery): Enable this test against production when possible.
  XCTSkipIf(![FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test if running against production because it results in a 'missing index' "
            "error. The Firestore Emulator, however, does serve these queries");

  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"doc1" : @{@"a" : @1, @"b" : @0},
    @"doc2" : @{@"b" : @1},
    @"doc3" : @{@"a" : @3, @"b" : @2},
    @"doc4" : @{@"a" : @1, @"b" : @3},
    @"doc5" : @{@"a" : @1},
    @"doc6" : @{@"a" : @2}
  }];

  // a==2 || b not-in [2,3]
  // Has implicit orderBy b.
  FIRFilter *filter = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b"
                                                                          notIn:@[ @2, @3 ]]
  ]];
  [self checkOnlineAndOfflineQuery:[collRef queryWhereFilter:filter]
                     matchesResult:@[ @"doc1", @"doc2" ]];
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
  // TODO(orquery): Enable this test against production when possible.
  XCTSkipIf(![FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test if running against production because it's not yet supported.");

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
  // TODO(orquery): Enable this test against production when possible.
  XCTSkipIf(![FSTIntegrationTestCase isRunningAgainstEmulator],
            "Skip this test if running against production because it's not yet supported.");

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

- (void)testResumingAQueryShouldUseExistenceFilterToDetectDeletes {
  // Prepare the names and contents of the 100 documents to create.
  NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *testData =
      [[NSMutableDictionary alloc] init];
  for (int i = 0; i < 100; i++) {
    [testData setValue:@{@"key" : @42} forKey:[NSString stringWithFormat:@"doc%@", @(i)]];
  }

  // Create 100 documents in a new collection.
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:testData];

  // Run a query to populate the local cache with the 100 documents and a resume token.
  NSArray<FIRDocumentReference *> *createdDocuments;
  {
    FIRQuerySnapshot *querySnapshot1 = [self readDocumentSetForRef:collRef
                                                            source:FIRFirestoreSourceDefault];
    NSMutableArray<FIRDocumentReference *> *createdDocumentsAccumulator =
        [[NSMutableArray alloc] init];
    for (FIRDocumentSnapshot *documentSnapshot in querySnapshot1.documents) {
      [createdDocumentsAccumulator addObject:documentSnapshot.reference];
    }
    createdDocuments = [createdDocumentsAccumulator copy];
  }
  XCTAssertEqual(createdDocuments.count, 100u, @"createdDocuments has the wrong size");

  // Delete 50 of the 100 documents. Do this in a transaction, rather than
  // [FIRDocumentReference deleteDocument], to avoid affecting the local cache.
  NSSet<NSString *> *deletedDocumentIds;
  {
    NSMutableArray<NSString *> *deletedDocumentIdsAccumulator = [[NSMutableArray alloc] init];
    deletedDocumentIds = [deletedDocumentIdsAccumulator copy];
    XCTestExpectation *expectation = [self expectationWithDescription:@"DeleteTransaction"];
    [collRef.firestore
        runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
          for (NSUInteger i = 0; i < createdDocuments.count; i += 2) {
            FIRDocumentReference *documentToDelete = createdDocuments[i];
            [transaction deleteDocument:documentToDelete];
            [deletedDocumentIdsAccumulator addObject:documentToDelete.documentID];
          }
          return @"document deletion successful";
        }
        completion:^(id, NSError *) {
          [expectation fulfill];
        }];
    [self awaitExpectation:expectation];
    deletedDocumentIds = [NSSet setWithArray:deletedDocumentIdsAccumulator];
  }
  XCTAssertEqual(deletedDocumentIds.count, 50u, @"deletedDocumentIds has the wrong size");

  // Wait for 10 seconds, during which Watch will stop tracking the query and will send an existence
  // filter rather than "delete" events when the query is resumed.
  [NSThread sleepForTimeInterval:10.0f];

  // Resume the query and save the resulting snapshot for verification.
  FIRQuerySnapshot *querySnapshot2 = [self readDocumentSetForRef:collRef
                                                          source:FIRFirestoreSourceDefault];

  // Verify that the snapshot from the resumed query contains the expected documents; that is,
  // that it contains the 50 documents that were _not_ deleted.
  // TODO(b/270731363): Remove the "if" condition below once the Firestore Emulator is fixed to
  // send an existence filter. At the time of writing, the Firestore emulator fails to send an
  // existence filter, resulting in the client including the deleted documents in the snapshot
  // of the resumed query.
  if (!([FSTIntegrationTestCase isRunningAgainstEmulator] && querySnapshot2.count == 100)) {
    NSSet<NSString *> *actualDocumentIds;
    {
      NSMutableArray<NSString *> *actualDocumentIdsAccumulator = [[NSMutableArray alloc] init];
      for (FIRDocumentSnapshot *documentSnapshot in querySnapshot2.documents) {
        [actualDocumentIdsAccumulator addObject:documentSnapshot.documentID];
      }
      actualDocumentIds = [NSSet setWithArray:actualDocumentIdsAccumulator];
    }
    NSSet<NSString *> *expectedDocumentIds;
    {
      NSMutableArray<NSString *> *expectedDocumentIdsAccumulator = [[NSMutableArray alloc] init];
      for (FIRDocumentReference *documentRef in createdDocuments) {
        if (![deletedDocumentIds containsObject:documentRef.documentID]) {
          [expectedDocumentIdsAccumulator addObject:documentRef.documentID];
        }
      }
      expectedDocumentIds = [NSSet setWithArray:expectedDocumentIdsAccumulator];
    }
    if (![actualDocumentIds isEqualToSet:expectedDocumentIds]) {
      NSArray<NSString *> *unexpectedDocumentIds =
          SortedStringsNotIn(actualDocumentIds, expectedDocumentIds);
      NSArray<NSString *> *missingDocumentIds =
          SortedStringsNotIn(expectedDocumentIds, actualDocumentIds);
      XCTFail(@"The snapshot contained %lu documents (expected %lu): "
              @"%lu unexpected and %lu missing; "
              @"unexpected documents: %@; missing documents: %@",
              (unsigned long)actualDocumentIds.count, (unsigned long)expectedDocumentIds.count,
              (unsigned long)unexpectedDocumentIds.count, (unsigned long)missingDocumentIds.count,
              [unexpectedDocumentIds componentsJoinedByString:@", "],
              [missingDocumentIds componentsJoinedByString:@", "]);
    }
  }
}

@end
