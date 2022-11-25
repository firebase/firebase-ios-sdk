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

#import "Firestore/Source/API/FIRFilter+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

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

@end
