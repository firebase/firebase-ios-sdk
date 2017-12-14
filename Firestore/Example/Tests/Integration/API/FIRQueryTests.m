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

@import FirebaseFirestore;

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"

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
      [self readDocumentSetForRef:[[collRef queryOrderedByField:@"sort" descending:YES]
                                      queryLimitedTo:2]];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), (@[
                          @{ @"k" : @"d",
                             @"sort" : @2 },
                          @{ @"k" : @"c",
                             @"sort" : @1 }
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
      [self readDocumentSetForRef:[[collRef queryWhereField:@"foo" isGreaterThan:@21]
                                      queryOrderedByField:@"foo"
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
      [self readDocumentSetForRef:[[collRef queryWhereField:@"null" isEqualTo:[NSNull null]]
                                      queryWhereField:@"nan"
                                            isEqualTo:@(NAN)]];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(results), (@[
                          @{ @"null" : [NSNull null],
                             @"nan" : @(NAN) }
                        ]));
}

- (void)testQueryWithFieldPaths {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"a" : @1},
    @"b" : @{@"a" : @2},
    @"c" : @{@"a" : @3}
  }];

  FIRQuery *query =
      [collRef queryWhereFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"a" ]] isLessThan:@3];
  query = [query queryOrderedByFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"a" ]]
                              descending:YES];

  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:query];

  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(snapshot), (@[ @"b", @"a" ]));
}

- (void)testQueryWithPredicate {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"a" : @1},
    @"b" : @{@"a" : @2},
    @"c" : @{@"a" : @3}
  }];

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

  FIRQuerySnapshot *results =
      [self readDocumentSetForRef:[collRef queryWhereField:@"inf" isEqualTo:@(INFINITY)]];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(results), (@[ @{ @"inf" : @(INFINITY) } ]));
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

- (void)testQueriesFireFromCacheWhenOffline {
  NSDictionary *testDocs = @{
    @"a" : @{@"foo" : @1},
  };
  FIRCollectionReference *collection = [self collectionRefWithDocuments:testDocs];

  FIRQueryListenOptions *options = [[[FIRQueryListenOptions options]
      includeDocumentMetadataChanges:YES] includeQueryMetadataChanges:YES];
  id<FIRListenerRegistration> registration =
      [collection addSnapshotListenerWithOptions:options
                                        listener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"initial event"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), @[ @{ @"foo" : @1 } ]);
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);
  XCTestExpectation *networkDisabled = [self expectationWithDescription:@"disable network"];
  [collection.firestore.client disableNetworkWithCompletion:^(NSError *error) {
    [networkDisabled fulfill];
  }];
  [self awaitExpectations];

  querySnap = [self.eventAccumulator awaitEventWithName:@"offline event with isFromCache=YES"];
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  // TODO(b/70631617): There's currently a backend bug that prevents us from using a resume token
  // right away (against hexa at least). So we sleep. :-( :-( Anything over ~10ms seems to be
  // sufficient.
  [NSThread sleepForTimeInterval:0.2f];

  XCTestExpectation *networkEnabled = [self expectationWithDescription:@"enable network"];
  [collection.firestore.client enableNetworkWithCompletion:^(NSError *error) {
    [networkEnabled fulfill];
  }];
  [self awaitExpectations];

  querySnap = [self.eventAccumulator awaitEventWithName:@"back online event with isFromCache=NO"];
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);
}

@end
