/*
 * Copyright 2024 Google
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

#import "Firestore/Source/API/FIRAggregateQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

@interface FIRSnapshotListenerSourceTests : FSTIntegrationTestCase
@end

@implementation FIRSnapshotListenerSourceTests

- (FIRSnapshotListenOptions *)optionsWithSourceFromCache {
  FIRSnapshotListenOptions *options = [[FIRSnapshotListenOptions alloc] init];
  return [options optionsWithSource:FIRListenSourceCache];
}
- (FIRSnapshotListenOptions *)optionsWithSourceFromCacheAndIncludeMetadataChanges {
  FIRSnapshotListenOptions *options = [[FIRSnapshotListenOptions alloc] init];
  return [[options optionsWithSource:FIRListenSourceCache] optionsWithIncludeMetadataChanges:YES];
}

- (void)testCanRaiseSnapshotFromCacheForQuery {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{@"a" : @{@"k" : @"a"}}];

  [self readDocumentSetForRef:collRef];  // populate the cache.

  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> registration =
      [collRef addSnapshotListenerWithOptions:options
                                     listener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"a"} ]));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  [self.eventAccumulator assertNoAdditionalEvents];
  [registration remove];
}

- (void)testCanRaiseSnapshotFromCacheForDocumentReference {
  FIRDocumentReference *docRef = [self documentRef];
  [docRef setData:@{@"k" : @"a"}];

  [self readDocumentForRef:docRef];  // populate the cache.

  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> registration =
      [docRef addSnapshotListenerWithOptions:options
                                    listener:self.eventAccumulator.valueEventHandler];

  FIRDocumentSnapshot *docSnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(docSnap.data, (@{@"k" : @"a"}));
  XCTAssertEqual(docSnap.metadata.isFromCache, YES);

  [self.eventAccumulator assertNoAdditionalEvents];
  [registration remove];
}

- (void)testListenToCacheShouldNotBeAffectedByOnlineStatusChange {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{@"a" : @{@"k" : @"a"}}];

  [self readDocumentSetForRef:collRef];  // populate the cache.

  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCacheAndIncludeMetadataChanges];
  id<FIRListenerRegistration> registration =
      [collRef addSnapshotListenerWithOptions:options
                                     listener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"a"} ]));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  [self disableNetwork];
  [self enableNetwork];

  [self.eventAccumulator assertNoAdditionalEvents];
  [registration remove];
}

- (void)testMultipleListenersSourcedFromCacheCanWorkIndependently {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  [self readDocumentSetForRef:collRef];  // populate the cache.

  FIRQuery *query = [[collRef queryWhereField:@"sort"
                                isGreaterThan:@0] queryOrderedByField:@"sort"];

  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> registration1 =
      [query addSnapshotListenerWithOptions:options
                                   listener:self.eventAccumulator.valueEventHandler];
  id<FIRListenerRegistration> registration2 =
      [query addSnapshotListenerWithOptions:options
                                   listener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  NSArray *expected = @[ @{@"k" : @"b", @"sort" : @1L} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);
  querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  // Do a local mutation
  [self addDocumentRef:collRef data:@{@"k" : @"c", @"sort" : @2}];

  querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"b", @"sort" : @1L}, @{@"k" : @"c", @"sort" : @2L} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  // Detach one listener, and do a local mutation. The other listener
  // should not be affected.
  [registration1 remove];
  [self addDocumentRef:collRef data:@{@"k" : @"d", @"sort" : @3}];

  querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[
    @{@"k" : @"b", @"sort" : @1L}, @{@"k" : @"c", @"sort" : @2L}, @{@"k" : @"d", @"sort" : @3L}
  ];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  [self.eventAccumulator assertNoAdditionalEvents];
  [registration2 remove];
}

// Two queries that mapped to the same target ID are referred to as
// "mirror queries". An example for a mirror query is a limitToLast()
// query and a limit() query that share the same backend Target ID.
// Since limitToLast() queries are sent to the backend with a modified
// orderBy() clause, they can map to the same target representation as
// limit() query, even if both queries appear separate to the user.
- (void)testListenUnlistenRelistenToMirrorQueriesFromCache {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1},
    @"c" : @{@"k" : @"c", @"sort" : @1},
  }];

  [self readDocumentSetForRef:collRef];  // populate the cache.

  // Setup a `limit` query.
  FIRQuery *limit = [[collRef queryOrderedByField:@"sort" descending:NO] queryLimitedTo:2];
  FSTEventAccumulator *limitAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> limitRegistration =
      [limit addSnapshotListenerWithOptions:options listener:limitAccumulator.valueEventHandler];

  // Setup a mirroring `limitToLast` query.
  FIRQuery *limitToLast = [[collRef queryOrderedByField:@"sort"
                                             descending:YES] queryLimitedToLast:2];
  FSTEventAccumulator *limitToLastAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> limitToLastRegistration =
      [limitToLast addSnapshotListenerWithOptions:options
                                         listener:limitToLastAccumulator.valueEventHandler];

  // Verify both queries get expected result.
  FIRQuerySnapshot *snapshot = [limitAccumulator awaitEventWithName:@"Snapshot"];
  NSArray *expected = @[ @{@"k" : @"a", @"sort" : @0}, @{@"k" : @"b", @"sort" : @1} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  snapshot = [limitToLastAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"a", @"sort" : @0} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);

  // Un-listen then re-listen to the limit query.
  [limitRegistration remove];
  limitRegistration = [limit addSnapshotListenerWithOptions:options
                                                   listener:limitAccumulator.valueEventHandler];
  snapshot = [limitAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"a", @"sort" : @0}, @{@"k" : @"b", @"sort" : @1} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  XCTAssertEqual(snapshot.metadata.isFromCache, YES);

  // Add a document that would change the result set.
  [self addDocumentRef:collRef data:@{@"k" : @"d", @"sort" : @-1}];

  // Verify both queries get expected result.
  snapshot = [limitAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"d", @"sort" : @-1}, @{@"k" : @"a", @"sort" : @0} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  XCTAssertEqual(snapshot.metadata.hasPendingWrites, YES);
  snapshot = [limitToLastAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"a", @"sort" : @0}, @{@"k" : @"d", @"sort" : @-1} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  XCTAssertEqual(snapshot.metadata.hasPendingWrites, YES);

  // Un-listen to limitToLast, update a doc, then re-listen to limitToLast
  [limitToLastRegistration remove];
  [self updateDocumentRef:[collRef documentWithPath:@"a"] data:@{@"k" : @"a", @"sort" : @-2}];
  limitToLastRegistration =
      [limitToLast addSnapshotListenerWithOptions:options
                                         listener:limitToLastAccumulator.valueEventHandler];

  // Verify both queries get expected result.
  snapshot = [limitAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"a", @"sort" : @-2}, @{@"k" : @"d", @"sort" : @-1} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  XCTAssertEqual(snapshot.metadata.hasPendingWrites, YES);

  snapshot = [limitToLastAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"d", @"sort" : @-1}, @{@"k" : @"a", @"sort" : @-2} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(snapshot), expected);
  // We listened to LimitToLast query after the doc update.
  XCTAssertEqual(snapshot.metadata.hasPendingWrites, NO);
}

- (void)testCanListenToDefaultSourceFirstAndThenCache {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  FIRQuery *query = [[collRef queryWhereField:@"sort"
                       isGreaterThanOrEqualTo:@1] queryOrderedByField:@"sort"];

  // Listen to the query with default options, which will also populates the cache
  FSTEventAccumulator *defaultAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> defaultRegistration =
      [query addSnapshotListener:defaultAccumulator.valueEventHandler];
  FIRQuerySnapshot *querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"b", @"sort" : @1L} ]));
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  // Listen to the same query from cache
  FSTEventAccumulator *cacheAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> cacheRegistration =
      [query addSnapshotListenerWithOptions:options listener:cacheAccumulator.valueEventHandler];
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"b", @"sort" : @1L} ]));
  // The metadata is sync with server due to the default listener
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  [defaultAccumulator assertNoAdditionalEvents];
  [cacheAccumulator assertNoAdditionalEvents];
  [defaultRegistration remove];
  [cacheRegistration remove];
}

- (void)testCanListenToCacheSourceFirstAndThenDefault {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  FIRQuery *query = [[collRef queryWhereField:@"sort" isNotEqualTo:@0] queryOrderedByField:@"sort"];

  // Listen to the cache
  FSTEventAccumulator *cacheAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> cacheRegistration =
      [query addSnapshotListenerWithOptions:options listener:cacheAccumulator.valueEventHandler];
  FIRQuerySnapshot *querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  // Cache is empty
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[]));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  // Listen to the same query from server
  FSTEventAccumulator *defaultAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> defaultRegistration =
      [query addSnapshotListener:defaultAccumulator.valueEventHandler];
  querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"b", @"sort" : @1L} ]));
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  // Default listener updates the cache, whish triggers cache listener to raise snapshot.
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"b", @"sort" : @1L} ]));
  // The metadata is sync with server due to the default listener
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  [defaultAccumulator assertNoAdditionalEvents];
  [cacheAccumulator assertNoAdditionalEvents];
  [defaultRegistration remove];
  [cacheRegistration remove];
}

- (void)testWillNotGetMetadataOnlyUpdatesIfListeningToCacheOnly {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];

  [self readDocumentSetForRef:collRef];  // populate the cache.

  FIRQuery *query = [[collRef queryWhereField:@"sort" isNotEqualTo:@0] queryOrderedByField:@"sort"];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCacheAndIncludeMetadataChanges];
  id<FIRListenerRegistration> registration =
      [query addSnapshotListenerWithOptions:options
                                   listener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"b", @"sort" : @1L} ]));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  // Do a local mutation
  [self addDocumentRef:collRef data:@{@"k" : @"c", @"sort" : @2}];

  querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap),
                        (@[ @{@"k" : @"b", @"sort" : @1L}, @{@"k" : @"c", @"sort" : @2L} ]));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);
  XCTAssertEqual(querySnap.metadata.hasPendingWrites, YES);

  // As we are not listening to server, the listener will not get notified
  // when local mutation is acknowledged by server.
  [self.eventAccumulator assertNoAdditionalEvents];
  [registration remove];
}

- (void)testWillHaveSynceMetadataUpdatesWhenListeningToBothCacheAndDefaultSource {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  [self readDocumentSetForRef:collRef];  // populate the cache.

  FIRQuery *query = [[collRef queryWhereField:@"sort" isNotEqualTo:@0] queryOrderedByField:@"sort"];

  // Listen to the cache
  FSTEventAccumulator *cacheAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCacheAndIncludeMetadataChanges];
  id<FIRListenerRegistration> cacheRegistration =
      [query addSnapshotListenerWithOptions:options listener:cacheAccumulator.valueEventHandler];
  FIRQuerySnapshot *querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  NSArray *expected = @[ @{@"k" : @"b", @"sort" : @1L} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);

  // Listen to the same query from server
  FSTEventAccumulator *defaultAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> defaultRegistration =
      [query addSnapshotListenerWithIncludeMetadataChanges:YES
                                                  listener:defaultAccumulator.valueEventHandler];
  querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));
  // First snapshot will be raised from cache.
  XCTAssertEqual(querySnap.metadata.isFromCache, YES);
  querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  // Second snapshot will be raised from server result
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  // As listening to metadata changes, the cache listener also gets triggered and synced
  // with default listener.
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  // The metadata is sync with server due to the default listener
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  // Do a local mutation
  [self addDocumentRef:collRef data:@{@"k" : @"c", @"sort" : @2}];

  // snapshot gets triggered by local mutation
  expected = @[ @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"c", @"sort" : @2} ];
  querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), expected);
  XCTAssertEqual(querySnap.metadata.hasPendingWrites, YES);
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), expected);
  XCTAssertEqual(querySnap.metadata.hasPendingWrites, YES);
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  // Local mutation gets acknowledged by the server
  querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqual(querySnap.metadata.hasPendingWrites, NO);
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqual(querySnap.metadata.hasPendingWrites, NO);
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  [defaultAccumulator assertNoAdditionalEvents];
  [cacheAccumulator assertNoAdditionalEvents];
  [defaultRegistration remove];
  [cacheRegistration remove];
}

- (void)testCanUnlistenToDefaultSourceWhileStillListeningToCache {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  FIRQuery *query = [[collRef queryWhereField:@"sort" isNotEqualTo:@0] queryOrderedByField:@"sort"];

  // Listen to the query with both source options
  FSTEventAccumulator *defaultAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> defaultRegistration =
      [query addSnapshotListener:defaultAccumulator.valueEventHandler];
  [defaultAccumulator awaitEventWithName:@"Snapshot"];
  FSTEventAccumulator *cacheAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> cacheRegistration =
      [query addSnapshotListenerWithOptions:options listener:cacheAccumulator.valueEventHandler];
  [cacheAccumulator awaitEventWithName:@"Snapshot"];

  // Un-listen to the default listener.
  [defaultRegistration remove];

  // Add a document and verify listener to cache works as expected
  [self addDocumentRef:collRef data:@{@"k" : @"c", @"sort" : @-1}];
  [defaultAccumulator assertNoAdditionalEvents];

  FIRQuerySnapshot *querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap),
                        (@[ @{@"k" : @"c", @"sort" : @-1L}, @{@"k" : @"b", @"sort" : @1L} ]));

  [cacheAccumulator assertNoAdditionalEvents];
  [cacheRegistration remove];
}

- (void)testCanUnlistenToCacheSourceWhileStillListeningToServer {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  FIRQuery *query = [[collRef queryWhereField:@"sort" isNotEqualTo:@0] queryOrderedByField:@"sort"];

  // Listen to the query with both source options
  FSTEventAccumulator *defaultAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> defaultRegistration =
      [query addSnapshotListener:defaultAccumulator.valueEventHandler];
  [defaultAccumulator awaitEventWithName:@"Snapshot"];
  FSTEventAccumulator *cacheAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> cacheRegistration =
      [query addSnapshotListenerWithOptions:options listener:cacheAccumulator.valueEventHandler];
  [cacheAccumulator awaitEventWithName:@"Snapshot"];

  // Un-listen to cache.
  [cacheRegistration remove];

  // Add a document and verify listener to server works as expected.
  [self addDocumentRef:collRef data:@{@"k" : @"c", @"sort" : @-1}];
  [cacheAccumulator assertNoAdditionalEvents];

  FIRQuerySnapshot *querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap),
                        (@[ @{@"k" : @"c", @"sort" : @-1L}, @{@"k" : @"b", @"sort" : @1L} ]));

  [defaultAccumulator assertNoAdditionalEvents];
  [defaultRegistration remove];
}

- (void)testCanListenUnlistenRelistenToSameQueryWithDifferentSourceOptions {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  FIRQuery *query = [[collRef queryWhereField:@"sort"
                                isGreaterThan:@0] queryOrderedByField:@"sort"];

  // Listen to the query with default options, which will also populates the cache
  FSTEventAccumulator *defaultAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> defaultRegistration =
      [query addSnapshotListener:defaultAccumulator.valueEventHandler];
  FIRQuerySnapshot *querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  NSArray *expected = @[ @{@"k" : @"b", @"sort" : @1L} ];

  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));

  // Listen to the same query from cache
  FSTEventAccumulator *cacheAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> cacheRegistration =
      [query addSnapshotListenerWithOptions:options listener:cacheAccumulator.valueEventHandler];
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (expected));

  // Un-listen to the default listener, add a doc and re-listen.
  [defaultRegistration remove];
  [self addDocumentRef:collRef data:@{@"k" : @"c", @"sort" : @2}];

  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"c", @"sort" : @2} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), expected);

  defaultRegistration = [query addSnapshotListener:defaultAccumulator.valueEventHandler];
  querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), expected);

  // Un-listen to cache, update a doc, then re-listen to cache.
  [cacheRegistration remove];
  [self updateDocumentRef:[collRef documentWithPath:@"b"] data:@{@"k" : @"b", @"sort" : @3}];

  querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  expected = @[ @{@"k" : @"c", @"sort" : @2}, @{@"k" : @"b", @"sort" : @3} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), expected);

  cacheRegistration = [query addSnapshotListenerWithOptions:options
                                                   listener:cacheAccumulator.valueEventHandler];
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), expected);

  [defaultAccumulator assertNoAdditionalEvents];
  [cacheAccumulator assertNoAdditionalEvents];
  [defaultRegistration remove];
  [cacheRegistration remove];
}

- (void)testCanListenToCompositeIndexQueriesFromCache {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  [self readDocumentSetForRef:collRef];  // populate the cache.

  FIRQuery *query = [[collRef queryWhereField:@"k" isLessThanOrEqualTo:@"a"] queryWhereField:@"sort"
                                                                      isGreaterThanOrEqualTo:@0];

  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> registration =
      [query addSnapshotListenerWithOptions:options
                                   listener:self.eventAccumulator.valueEventHandler];
  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"a", @"sort" : @0L} ]));

  [self.eventAccumulator assertNoAdditionalEvents];
  [registration remove];
}

- (void)testCanRaiseInitialSnapshotFromCachedEmptyResults {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{}];

  // Populate the cache with empty query result.
  FIRQuerySnapshot *querySnapshot = [self readDocumentSetForRef:collRef];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshot), @[]);

  // Add a snapshot listener whose first event should be raised from cache.
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> registration =
      [collRef addSnapshotListenerWithOptions:options
                                     listener:self.eventAccumulator.valueEventHandler];

  querySnapshot = [self.eventAccumulator awaitEventWithName:@"initial event"];
  XCTAssertTrue(querySnapshot.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnapshot), @[]);

  [registration remove];
}

- (void)testWillNotBeTriggeredByTransactionsWhileListeningToCache {
  FIRCollectionReference *collRef =
      [self collectionRefWithDocuments:@{@"a" : @{@"k" : @"a", @"sort" : @0}}];

  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> registration =
      [collRef addSnapshotListenerWithOptions:options
                                     listener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[]));

  FIRDocumentReference *docRef = [self documentRef];
  // Use a transaction to perform a write without triggering any local events.
  [docRef.firestore
      runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **) {
        [transaction setData:@{@"k" : @"a"} forDocument:docRef];
        return nil;
      }
                   completion:^(id, NSError *){
                   }];

  // There should be no events raised
  [self.eventAccumulator assertNoAdditionalEvents];
  [registration remove];
}

- (void)testSharesServerSideUpdatesWhenListeningToBothCacheAndDefault {
  FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"sort" : @0},
    @"b" : @{@"k" : @"b", @"sort" : @1}
  }];
  FIRQuery *query = [[collRef queryWhereField:@"sort"
                                isGreaterThan:@0] queryOrderedByField:@"sort"];

  // Listen to the query with default options, which will also populates the cache
  FSTEventAccumulator *defaultAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> defaultRegistration =
      [query addSnapshotListener:defaultAccumulator.valueEventHandler];
  FIRQuerySnapshot *querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"b", @"sort" : @1L} ]));

  // Listen to the same query from cache
  FSTEventAccumulator *cacheAccumulator = [FSTEventAccumulator accumulatorForTest:self];
  FIRSnapshotListenOptions *options = [self optionsWithSourceFromCache];
  id<FIRListenerRegistration> cacheRegistration =
      [query addSnapshotListenerWithOptions:options listener:cacheAccumulator.valueEventHandler];
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"b", @"sort" : @1L} ]));

  // Use a transaction to mock server side updates
  FIRDocumentReference *docRef = [collRef documentWithAutoID];
  // Use a transaction to perform a write without triggering any local events.
  [docRef.firestore
      runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **) {
        [transaction setData:@{@"k" : @"c", @"sort" : @2} forDocument:docRef];
        return nil;
      }
                   completion:^(id, NSError *){
                   }];

  // Default listener receives the server update
  querySnap = [defaultAccumulator awaitEventWithName:@"Snapshot"];
  NSArray *expected = @[ @{@"k" : @"b", @"sort" : @1}, @{@"k" : @"c", @"sort" : @2} ];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), expected);
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  // Cache listener raises snapshot as well
  querySnap = [cacheAccumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), expected);
  XCTAssertEqual(querySnap.metadata.isFromCache, NO);

  [defaultAccumulator assertNoAdditionalEvents];
  [cacheAccumulator assertNoAdditionalEvents];
  [defaultRegistration remove];
  [cacheRegistration remove];
}

@end
