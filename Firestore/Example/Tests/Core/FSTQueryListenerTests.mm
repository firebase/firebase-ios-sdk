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

#import "Firestore/Source/Core/FSTEventManager.h"

#import <XCTest/XCTest.h>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Util/FSTAsyncQueryListener.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTQueryListenerTests : XCTestCase
@property(nonatomic, strong, readonly) FSTDispatchQueue *asyncQueue;
@end

@implementation FSTQueryListenerTests

- (void)setUp {
  _asyncQueue = [FSTDispatchQueue
      queueWith:dispatch_queue_create("FSTQueryListenerTests Queue", DISPATCH_QUEUE_SERIAL)];
}

- (void)testRaisesCollectionEvents {
  NSMutableArray<FSTViewSnapshot *> *accum = [NSMutableArray array];
  NSMutableArray<FSTViewSnapshot *> *otherAccum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/Hades", 2, @{@"name" : @"Hades"}, NO);
  FSTDocument *doc2prime =
      FSTTestDoc(@"rooms/Hades", 3, @{@"name" : @"Hades", @"owner" : @"Jonny"}, NO);

  FSTQueryListener *listener = [self listenToQuery:query accumulatingSnapshots:accum];
  FSTQueryListener *otherListener = [self listenToQuery:query accumulatingSnapshots:otherAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], nil);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc2prime ], nil);

  FSTDocumentViewChange *change1 =
      [FSTDocumentViewChange changeWithDocument:doc1 type:FSTDocumentViewChangeTypeAdded];
  FSTDocumentViewChange *change2 =
      [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeAdded];
  FSTDocumentViewChange *change3 =
      [FSTDocumentViewChange changeWithDocument:doc2prime type:FSTDocumentViewChangeTypeModified];
  FSTDocumentViewChange *change4 =
      [FSTDocumentViewChange changeWithDocument:doc2prime type:FSTDocumentViewChangeTypeAdded];

  [listener queryDidChangeViewSnapshot:snap1];
  [listener queryDidChangeViewSnapshot:snap2];
  [otherListener queryDidChangeViewSnapshot:snap2];

  XCTAssertEqualObjects(accum, (@[ snap1, snap2 ]));
  XCTAssertEqualObjects(accum[0].documentChanges, (@[ change1, change2 ]));
  XCTAssertEqualObjects(accum[1].documentChanges, (@[ change3 ]));

  FSTViewSnapshot *expectedSnap2 = [[FSTViewSnapshot alloc]
         initWithQuery:snap2.query
             documents:snap2.documents
          oldDocuments:[FSTDocumentSet documentSetWithComparator:snap2.query.comparator]
       documentChanges:@[ change1, change4 ]
             fromCache:snap2.fromCache
      hasPendingWrites:snap2.hasPendingWrites
      syncStateChanged:YES];
  XCTAssertEqualObjects(otherAccum, (@[ expectedSnap2 ]));
}

- (void)testRaisesErrorEvent {
  NSMutableArray<NSError *> *accum = [NSMutableArray array];
  FSTQuery *query = FSTTestQuery("rooms/Eros");

  FSTQueryListener *listener = [self listenToQuery:query
                                           handler:^(FSTViewSnapshot *snapshot, NSError *error) {
                                             [accum addObject:error];
                                           }];

  NSError *testError =
      [NSError errorWithDomain:@"com.google.firestore.test" code:42 userInfo:@{@"some" : @"info"}];
  [listener queryDidError:testError];

  XCTAssertEqualObjects(accum, @[ testError ]);
}

- (void)testRaisesEventForEmptyCollectionAfterSync {
  NSMutableArray<FSTViewSnapshot *> *accum = [NSMutableArray array];
  FSTQuery *query = FSTTestQuery("rooms");

  FSTQueryListener *listener = [self listenToQuery:query accumulatingSnapshots:accum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[], nil);

  FSTTargetChange *ackTarget =
      [FSTTargetChange changeWithDocuments:@[]
                       currentStatusUpdate:FSTCurrentStatusUpdateMarkCurrent];
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[], ackTarget);

  [listener queryDidChangeViewSnapshot:snap1];
  XCTAssertEqualObjects(accum, @[]);

  [listener queryDidChangeViewSnapshot:snap2];
  XCTAssertEqualObjects(accum, @[ snap2 ]);
}

- (void)testMutingAsyncListenerPreventsAllSubsequentEvents {
  NSMutableArray<FSTViewSnapshot *> *accum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms/Eros");
  FSTDocument *doc1 = FSTTestDoc(@"rooms/Eros", 3, @{@"name" : @"Eros"}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/Eros", 4, @{@"name" : @"Eros2"}, NO);

  __block FSTAsyncQueryListener *listener = [[FSTAsyncQueryListener alloc]
      initWithDispatchQueue:self.asyncQueue
            snapshotHandler:^(FSTViewSnapshot *snapshot, NSError *error) {
              [accum addObject:snapshot];
              [listener mute];
            }];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *viewSnapshot1 = FSTTestApplyChanges(view, @[ doc1 ], nil);
  FSTViewSnapshot *viewSnapshot2 = FSTTestApplyChanges(view, @[ doc2 ], nil);

  FSTViewSnapshotHandler handler = listener.asyncSnapshotHandler;
  handler(viewSnapshot1, nil);
  handler(viewSnapshot2, nil);

  // Drain queue
  XCTestExpectation *expectation = [self expectationWithDescription:@"Queue drained"];
  [self.asyncQueue dispatchAsync:^{
    [expectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:4.0
                               handler:^(NSError *_Nullable expectationError) {
                                 if (expectationError) {
                                   XCTFail(@"Error waiting for timeout: %@", expectationError);
                                 }
                               }];

  // We should get the first snapshot but not the second.
  XCTAssertEqualObjects(accum, @[ viewSnapshot1 ]);
}

- (void)testDoesNotRaiseEventsForMetadataChangesUnlessSpecified {
  NSMutableArray<FSTViewSnapshot *> *filteredAccum = [NSMutableArray array];
  NSMutableArray<FSTViewSnapshot *> *fullAccum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/Hades", 2, @{@"name" : @"Hades"}, NO);

  FSTListenOptions *options = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
                                                             includeDocumentMetadataChanges:NO
                                                                      waitForSyncWhenOnline:NO];

  FSTQueryListener *filteredListener =
      [self listenToQuery:query accumulatingSnapshots:filteredAccum];
  FSTQueryListener *fullListener =
      [self listenToQuery:query options:options accumulatingSnapshots:fullAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1 ], nil);

  FSTTargetChange *ackTarget =
      [FSTTargetChange changeWithDocuments:@[ doc1 ]
                       currentStatusUpdate:FSTCurrentStatusUpdateMarkCurrent];
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[], ackTarget);
  FSTViewSnapshot *snap3 = FSTTestApplyChanges(view, @[ doc2 ], nil);

  [filteredListener queryDidChangeViewSnapshot:snap1];  // local event
  [filteredListener queryDidChangeViewSnapshot:snap2];  // no event
  [filteredListener queryDidChangeViewSnapshot:snap3];  // doc2 update

  [fullListener queryDidChangeViewSnapshot:snap1];  // local event
  [fullListener queryDidChangeViewSnapshot:snap2];  // state change event
  [fullListener queryDidChangeViewSnapshot:snap3];  // doc2 update

  XCTAssertEqualObjects(filteredAccum, (@[ snap1, snap3 ]));
  XCTAssertEqualObjects(fullAccum, (@[ snap1, snap2, snap3 ]));
}

- (void)testRaisesDocumentMetadataEventsOnlyWhenSpecified {
  NSMutableArray<FSTViewSnapshot *> *filteredAccum = [NSMutableArray array];
  NSMutableArray<FSTViewSnapshot *> *fullAccum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, YES);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/Hades", 2, @{@"name" : @"Hades"}, NO);
  FSTDocument *doc1Prime = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, NO);
  FSTDocument *doc3 = FSTTestDoc(@"rooms/Other", 3, @{@"name" : @"Other"}, NO);

  FSTListenOptions *options = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:NO
                                                             includeDocumentMetadataChanges:YES
                                                                      waitForSyncWhenOnline:NO];

  FSTQueryListener *filteredListener =
      [self listenToQuery:query accumulatingSnapshots:filteredAccum];
  FSTQueryListener *fullListener =
      [self listenToQuery:query options:options accumulatingSnapshots:fullAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], nil);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc1Prime ], nil);
  FSTViewSnapshot *snap3 = FSTTestApplyChanges(view, @[ doc3 ], nil);

  FSTDocumentViewChange *change1 =
      [FSTDocumentViewChange changeWithDocument:doc1 type:FSTDocumentViewChangeTypeAdded];
  FSTDocumentViewChange *change2 =
      [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeAdded];
  FSTDocumentViewChange *change3 =
      [FSTDocumentViewChange changeWithDocument:doc1Prime type:FSTDocumentViewChangeTypeMetadata];
  FSTDocumentViewChange *change4 =
      [FSTDocumentViewChange changeWithDocument:doc3 type:FSTDocumentViewChangeTypeAdded];

  [filteredListener queryDidChangeViewSnapshot:snap1];
  [filteredListener queryDidChangeViewSnapshot:snap2];
  [filteredListener queryDidChangeViewSnapshot:snap3];
  [fullListener queryDidChangeViewSnapshot:snap1];
  [fullListener queryDidChangeViewSnapshot:snap2];
  [fullListener queryDidChangeViewSnapshot:snap3];

  XCTAssertEqualObjects(filteredAccum, (@[ snap1, snap3 ]));
  XCTAssertEqualObjects(filteredAccum[0].documentChanges, (@[ change1, change2 ]));
  XCTAssertEqualObjects(filteredAccum[1].documentChanges, (@[ change4 ]));

  XCTAssertEqualObjects(fullAccum, (@[ snap1, snap2, snap3 ]));
  XCTAssertEqualObjects(fullAccum[0].documentChanges, (@[ change1, change2 ]));
  XCTAssertEqualObjects(fullAccum[1].documentChanges, (@[ change3 ]));
  XCTAssertEqualObjects(fullAccum[2].documentChanges, (@[ change4 ]));
}

- (void)testRaisesQueryMetadataEventsOnlyWhenHasPendingWritesOnTheQueryChanges {
  NSMutableArray<FSTViewSnapshot *> *fullAccum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, YES);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/Hades", 2, @{@"name" : @"Hades"}, YES);
  FSTDocument *doc1Prime = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, NO);
  FSTDocument *doc2Prime = FSTTestDoc(@"rooms/Hades", 2, @{@"name" : @"Hades"}, NO);
  FSTDocument *doc3 = FSTTestDoc(@"rooms/Other", 3, @{@"name" : @"Other"}, NO);

  FSTListenOptions *options = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
                                                             includeDocumentMetadataChanges:NO
                                                                      waitForSyncWhenOnline:NO];
  FSTQueryListener *fullListener =
      [self listenToQuery:query options:options accumulatingSnapshots:fullAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], nil);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc1Prime ], nil);
  FSTViewSnapshot *snap3 = FSTTestApplyChanges(view, @[ doc3 ], nil);
  FSTViewSnapshot *snap4 = FSTTestApplyChanges(view, @[ doc2Prime ], nil);

  [fullListener queryDidChangeViewSnapshot:snap1];
  [fullListener queryDidChangeViewSnapshot:snap2];  // Emits no events.
  [fullListener queryDidChangeViewSnapshot:snap3];
  [fullListener queryDidChangeViewSnapshot:snap4];  // Metadata change event.

  FSTViewSnapshot *expectedSnap4 = [[FSTViewSnapshot alloc] initWithQuery:snap4.query
                                                                documents:snap4.documents
                                                             oldDocuments:snap3.documents
                                                          documentChanges:@[]
                                                                fromCache:snap4.fromCache
                                                         hasPendingWrites:NO
                                                         syncStateChanged:snap4.syncStateChanged];
  XCTAssertEqualObjects(fullAccum, (@[ snap1, snap3, expectedSnap4 ]));
}

- (void)testMetadataOnlyDocumentChangesAreFilteredOutWhenIncludeDocumentMetadataChangesIsFalse {
  NSMutableArray<FSTViewSnapshot *> *filteredAccum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, YES);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/Hades", 2, @{@"name" : @"Hades"}, NO);
  FSTDocument *doc1Prime = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, NO);
  FSTDocument *doc3 = FSTTestDoc(@"rooms/Other", 3, @{@"name" : @"Other"}, NO);

  FSTQueryListener *filteredListener =
      [self listenToQuery:query accumulatingSnapshots:filteredAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], nil);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc1Prime, doc3 ], nil);

  FSTDocumentViewChange *change3 =
      [FSTDocumentViewChange changeWithDocument:doc3 type:FSTDocumentViewChangeTypeAdded];

  [filteredListener queryDidChangeViewSnapshot:snap1];
  [filteredListener queryDidChangeViewSnapshot:snap2];

  FSTViewSnapshot *expectedSnap2 = [[FSTViewSnapshot alloc] initWithQuery:snap2.query
                                                                documents:snap2.documents
                                                             oldDocuments:snap1.documents
                                                          documentChanges:@[ change3 ]
                                                                fromCache:snap2.isFromCache
                                                         hasPendingWrites:snap2.hasPendingWrites
                                                         syncStateChanged:snap2.syncStateChanged];
  XCTAssertEqualObjects(filteredAccum, (@[ snap1, expectedSnap2 ]));
}

- (void)testWillWaitForSyncIfOnline {
  NSMutableArray<FSTViewSnapshot *> *events = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/Hades", 2, @{@"name" : @"Hades"}, NO);
  FSTQueryListener *listener =
      [self listenToQuery:query
                        options:[[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:NO
                                                               includeDocumentMetadataChanges:NO
                                                                        waitForSyncWhenOnline:YES]
          accumulatingSnapshots:events];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1 ], nil);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc2 ], nil);
  FSTViewSnapshot *snap3 =
      FSTTestApplyChanges(view, @[],
                          [FSTTargetChange changeWithDocuments:@[ doc1, doc2 ]
                                           currentStatusUpdate:FSTCurrentStatusUpdateMarkCurrent]);

  [listener applyChangedOnlineState:FSTOnlineStateOnline];  // no event
  [listener queryDidChangeViewSnapshot:snap1];
  [listener applyChangedOnlineState:FSTOnlineStateUnknown];
  [listener applyChangedOnlineState:FSTOnlineStateOnline];
  [listener queryDidChangeViewSnapshot:snap2];
  [listener queryDidChangeViewSnapshot:snap3];

  FSTDocumentViewChange *change1 =
      [FSTDocumentViewChange changeWithDocument:doc1 type:FSTDocumentViewChangeTypeAdded];
  FSTDocumentViewChange *change2 =
      [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeAdded];
  FSTViewSnapshot *expectedSnap = [[FSTViewSnapshot alloc]
         initWithQuery:snap3.query
             documents:snap3.documents
          oldDocuments:[FSTDocumentSet documentSetWithComparator:snap3.query.comparator]
       documentChanges:@[ change1, change2 ]
             fromCache:NO
      hasPendingWrites:NO
      syncStateChanged:YES];
  XCTAssertEqualObjects(events, (@[ expectedSnap ]));
}

- (void)testWillRaiseInitialEventWhenGoingOffline {
  NSMutableArray<FSTViewSnapshot *> *events = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc(@"rooms/Eros", 1, @{@"name" : @"Eros"}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/Hades", 2, @{@"name" : @"Hades"}, NO);
  FSTQueryListener *listener =
      [self listenToQuery:query
                        options:[[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:NO
                                                               includeDocumentMetadataChanges:NO
                                                                        waitForSyncWhenOnline:YES]
          accumulatingSnapshots:events];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1 ], nil);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc2 ], nil);

  [listener applyChangedOnlineState:FSTOnlineStateOnline];   // no event
  [listener queryDidChangeViewSnapshot:snap1];               // no event
  [listener applyChangedOnlineState:FSTOnlineStateOffline];  // event
  [listener applyChangedOnlineState:FSTOnlineStateUnknown];  // no event
  [listener applyChangedOnlineState:FSTOnlineStateOffline];  // no event
  [listener queryDidChangeViewSnapshot:snap2];               // another event

  FSTDocumentViewChange *change1 =
      [FSTDocumentViewChange changeWithDocument:doc1 type:FSTDocumentViewChangeTypeAdded];
  FSTDocumentViewChange *change2 =
      [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeAdded];
  FSTViewSnapshot *expectedSnap1 = [[FSTViewSnapshot alloc]
         initWithQuery:query
             documents:snap1.documents
          oldDocuments:[FSTDocumentSet documentSetWithComparator:snap1.query.comparator]
       documentChanges:@[ change1 ]
             fromCache:YES
      hasPendingWrites:NO
      syncStateChanged:YES];
  FSTViewSnapshot *expectedSnap2 = [[FSTViewSnapshot alloc] initWithQuery:query
                                                                documents:snap2.documents
                                                             oldDocuments:snap1.documents
                                                          documentChanges:@[ change2 ]
                                                                fromCache:YES
                                                         hasPendingWrites:NO
                                                         syncStateChanged:NO];
  XCTAssertEqualObjects(events, (@[ expectedSnap1, expectedSnap2 ]));
}

- (void)testWillRaiseInitialEventWhenGoingOfflineAndThereAreNoDocs {
  NSMutableArray<FSTViewSnapshot *> *events = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTQueryListener *listener = [self listenToQuery:query
                                           options:[FSTListenOptions defaultOptions]
                             accumulatingSnapshots:events];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[], nil);

  [listener applyChangedOnlineState:FSTOnlineStateOnline];   // no event
  [listener queryDidChangeViewSnapshot:snap1];               // no event
  [listener applyChangedOnlineState:FSTOnlineStateOffline];  // event

  FSTViewSnapshot *expectedSnap = [[FSTViewSnapshot alloc]
         initWithQuery:query
             documents:snap1.documents
          oldDocuments:[FSTDocumentSet documentSetWithComparator:snap1.query.comparator]
       documentChanges:@[]
             fromCache:YES
      hasPendingWrites:NO
      syncStateChanged:YES];
  XCTAssertEqualObjects(events, (@[ expectedSnap ]));
}

- (void)testWillRaiseInitialEventWhenStartingOfflineAndThereAreNoDocs {
  NSMutableArray<FSTViewSnapshot *> *events = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTQueryListener *listener = [self listenToQuery:query
                                           options:[FSTListenOptions defaultOptions]
                             accumulatingSnapshots:events];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:[FSTDocumentKeySet keySet]];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[], nil);

  [listener applyChangedOnlineState:FSTOnlineStateOffline];  // no event
  [listener queryDidChangeViewSnapshot:snap1];               // event

  FSTViewSnapshot *expectedSnap = [[FSTViewSnapshot alloc]
         initWithQuery:query
             documents:snap1.documents
          oldDocuments:[FSTDocumentSet documentSetWithComparator:snap1.query.comparator]
       documentChanges:@[]
             fromCache:YES
      hasPendingWrites:NO
      syncStateChanged:YES];
  XCTAssertEqualObjects(events, (@[ expectedSnap ]));
}

- (FSTQueryListener *)listenToQuery:(FSTQuery *)query handler:(FSTViewSnapshotHandler)handler {
  return [[FSTQueryListener alloc] initWithQuery:query
                                         options:[FSTListenOptions defaultOptions]
                             viewSnapshotHandler:handler];
}

- (FSTQueryListener *)listenToQuery:(FSTQuery *)query
                            options:(FSTListenOptions *)options
              accumulatingSnapshots:(NSMutableArray<FSTViewSnapshot *> *)values {
  return [[FSTQueryListener alloc] initWithQuery:query
                                         options:options
                             viewSnapshotHandler:^(FSTViewSnapshot *snapshot, NSError *error) {
                               [values addObject:snapshot];
                             }];
}

- (FSTQueryListener *)listenToQuery:(FSTQuery *)query
              accumulatingSnapshots:(NSMutableArray<FSTViewSnapshot *> *)values {
  return [self listenToQuery:query
                     options:[FSTListenOptions defaultOptions]
       accumulatingSnapshots:values];
}

@end

NS_ASSUME_NONNULL_END
