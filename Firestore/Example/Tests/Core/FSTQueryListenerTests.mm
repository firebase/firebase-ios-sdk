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

#import <XCTest/XCTest.h>
#include <memory>

#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Util/FSTAsyncQueryListener.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "absl/memory/memory.h"

using firebase::firestore::core::DocumentViewChangeType;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::OnlineState;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::util::ExecutorLibdispatch;

NS_ASSUME_NONNULL_BEGIN

@interface FSTQueryListenerTests : XCTestCase
@end

@implementation FSTQueryListenerTests {
  std::unique_ptr<ExecutorLibdispatch> _executor;
  FSTListenOptions *_includeMetadataChanges;
}

- (void)setUp {
  // TODO(varconst): moving this test to C++, it should be possible to store Executor as a value,
  // not a pointer, and initialize it in the constructor.
  _executor = absl::make_unique<ExecutorLibdispatch>(
      dispatch_queue_create("FSTQueryListenerTests Queue", DISPATCH_QUEUE_SERIAL));
  _includeMetadataChanges = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
                                                           includeDocumentMetadataChanges:YES
                                                                    waitForSyncWhenOnline:NO];
}

- (FSTViewSnapshot *)setExcludesMetadataChanges:(BOOL)excludesMetadataChanges
                                       snapshot:(FSTViewSnapshot *)snapshot {
  return [[FSTViewSnapshot alloc] initWithQuery:snapshot.query
                                      documents:snapshot.documents
                                   oldDocuments:snapshot.oldDocuments
                                documentChanges:snapshot.documentChanges
                                      fromCache:snapshot.fromCache
                                    mutatedKeys:snapshot.mutatedKeys
                               syncStateChanged:snapshot.syncStateChanged
                        excludesMetadataChanges:excludesMetadataChanges];
}

- (void)testRaisesCollectionEvents {
  NSMutableArray<FSTViewSnapshot *> *accum = [NSMutableArray array];
  NSMutableArray<FSTViewSnapshot *> *otherAccum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, FSTDocumentStateSynced);
  FSTDocument *doc2prime = FSTTestDoc("rooms/Hades", 3, @{@"name" : @"Hades", @"owner" : @"Jonny"},
                                      FSTDocumentStateSynced);

  FSTQueryListener *listener = [self listenToQuery:query
                                           options:_includeMetadataChanges
                             accumulatingSnapshots:accum];
  FSTQueryListener *otherListener = [self listenToQuery:query accumulatingSnapshots:otherAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc2prime ], absl::nullopt);

  FSTDocumentViewChange *change1 =
      [FSTDocumentViewChange changeWithDocument:doc1 type:DocumentViewChangeType::kAdded];
  FSTDocumentViewChange *change2 =
      [FSTDocumentViewChange changeWithDocument:doc2 type:DocumentViewChangeType::kAdded];
  FSTDocumentViewChange *change3 =
      [FSTDocumentViewChange changeWithDocument:doc2prime type:DocumentViewChangeType::kModified];
  FSTDocumentViewChange *change4 =
      [FSTDocumentViewChange changeWithDocument:doc2prime type:DocumentViewChangeType::kAdded];

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
                  mutatedKeys:snap2.mutatedKeys
             syncStateChanged:YES
      excludesMetadataChanges:YES];
  XCTAssertEqualObjects(otherAccum, (@[ expectedSnap2 ]));
}

- (void)testRaisesErrorEvent {
  NSMutableArray<NSError *> *accum = [NSMutableArray array];
  FSTQuery *query = FSTTestQuery("rooms/Eros");

  FSTQueryListener *listener = [self listenToQuery:query
                                           handler:^(FSTViewSnapshot *snapshot, NSError *error) {
                                             [accum addObject:error];
                                           }];

  NSError *testError = [NSError errorWithDomain:@"com.google.firestore.test"
                                           code:42
                                       userInfo:@{@"some" : @"info"}];
  [listener queryDidError:testError];

  XCTAssertEqualObjects(accum, @[ testError ]);
}

- (void)testRaisesEventForEmptyCollectionAfterSync {
  NSMutableArray<FSTViewSnapshot *> *accum = [NSMutableArray array];
  FSTQuery *query = FSTTestQuery("rooms");

  FSTQueryListener *listener = [self listenToQuery:query
                                           options:_includeMetadataChanges
                             accumulatingSnapshots:accum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[], absl::nullopt);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[], FSTTestTargetChangeMarkCurrent());

  [listener queryDidChangeViewSnapshot:snap1];
  XCTAssertEqualObjects(accum, @[]);

  [listener queryDidChangeViewSnapshot:snap2];
  XCTAssertEqualObjects(accum, @[ snap2 ]);
}

- (void)testMutingAsyncListenerPreventsAllSubsequentEvents {
  NSMutableArray<FSTViewSnapshot *> *accum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms/Eros");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 3, @{@"name" : @"Eros"}, FSTDocumentStateSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Eros", 4, @{@"name" : @"Eros2"}, FSTDocumentStateSynced);

  __block FSTAsyncQueryListener *listener =
      [[FSTAsyncQueryListener alloc] initWithExecutor:_executor.get()
                                      snapshotHandler:^(FSTViewSnapshot *snapshot, NSError *error) {
                                        [accum addObject:snapshot];
                                        [listener mute];
                                      }];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *viewSnapshot1 = FSTTestApplyChanges(view, @[ doc1 ], absl::nullopt);
  FSTViewSnapshot *viewSnapshot2 = FSTTestApplyChanges(view, @[ doc2 ], absl::nullopt);

  FSTViewSnapshotHandler handler = listener.asyncSnapshotHandler;
  handler(viewSnapshot1, nil);
  handler(viewSnapshot2, nil);

  // Drain queue
  XCTestExpectation *expectation = [self expectationWithDescription:@"Queue drained"];
  _executor->Execute([=] { [expectation fulfill]; });

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
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, FSTDocumentStateSynced);

  FSTQueryListener *filteredListener = [self listenToQuery:query
                                     accumulatingSnapshots:filteredAccum];
  FSTQueryListener *fullListener = [self listenToQuery:query
                                               options:_includeMetadataChanges
                                 accumulatingSnapshots:fullAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1 ], absl::nullopt);

  TargetChange ackTarget = FSTTestTargetChangeAckDocuments({doc1.key});
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[], ackTarget);
  FSTViewSnapshot *snap3 = FSTTestApplyChanges(view, @[ doc2 ], absl::nullopt);

  [filteredListener queryDidChangeViewSnapshot:snap1];  // local event
  [filteredListener queryDidChangeViewSnapshot:snap2];  // no event
  [filteredListener queryDidChangeViewSnapshot:snap3];  // doc2 update

  [fullListener queryDidChangeViewSnapshot:snap1];  // local event
  [fullListener queryDidChangeViewSnapshot:snap2];  // state change event
  [fullListener queryDidChangeViewSnapshot:snap3];  // doc2 update

  XCTAssertEqualObjects(filteredAccum, (@[
                          [self setExcludesMetadataChanges:YES snapshot:snap1],
                          [self setExcludesMetadataChanges:YES snapshot:snap3]
                        ]));
  XCTAssertEqualObjects(fullAccum, (@[ snap1, snap2, snap3 ]));
}

- (void)testRaisesDocumentMetadataEventsOnlyWhenSpecified {
  NSMutableArray<FSTViewSnapshot *> *filteredAccum = [NSMutableArray array];
  NSMutableArray<FSTViewSnapshot *> *fullAccum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateLocalMutations);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, FSTDocumentStateSynced);
  FSTDocument *doc1Prime =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateSynced);
  FSTDocument *doc3 = FSTTestDoc("rooms/Other", 3, @{@"name" : @"Other"}, FSTDocumentStateSynced);

  FSTListenOptions *options = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:NO
                                                             includeDocumentMetadataChanges:YES
                                                                      waitForSyncWhenOnline:NO];

  FSTQueryListener *filteredListener = [self listenToQuery:query
                                     accumulatingSnapshots:filteredAccum];
  FSTQueryListener *fullListener = [self listenToQuery:query
                                               options:options
                                 accumulatingSnapshots:fullAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc1Prime ], absl::nullopt);
  FSTViewSnapshot *snap3 = FSTTestApplyChanges(view, @[ doc3 ], absl::nullopt);

  FSTDocumentViewChange *change1 =
      [FSTDocumentViewChange changeWithDocument:doc1 type:DocumentViewChangeType::kAdded];
  FSTDocumentViewChange *change2 =
      [FSTDocumentViewChange changeWithDocument:doc2 type:DocumentViewChangeType::kAdded];
  FSTDocumentViewChange *change3 =
      [FSTDocumentViewChange changeWithDocument:doc1Prime type:DocumentViewChangeType::kMetadata];
  FSTDocumentViewChange *change4 =
      [FSTDocumentViewChange changeWithDocument:doc3 type:DocumentViewChangeType::kAdded];

  [filteredListener queryDidChangeViewSnapshot:snap1];
  [filteredListener queryDidChangeViewSnapshot:snap2];
  [filteredListener queryDidChangeViewSnapshot:snap3];
  [fullListener queryDidChangeViewSnapshot:snap1];
  [fullListener queryDidChangeViewSnapshot:snap2];
  [fullListener queryDidChangeViewSnapshot:snap3];

  XCTAssertEqualObjects(filteredAccum, (@[
                          [self setExcludesMetadataChanges:YES snapshot:snap1],
                          [self setExcludesMetadataChanges:YES snapshot:snap3]
                        ]));
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
  FSTDocument *doc1 =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateLocalMutations);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, FSTDocumentStateLocalMutations);
  FSTDocument *doc1Prime =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateSynced);
  FSTDocument *doc2Prime =
      FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, FSTDocumentStateSynced);
  FSTDocument *doc3 = FSTTestDoc("rooms/Other", 3, @{@"name" : @"Other"}, FSTDocumentStateSynced);

  FSTListenOptions *options = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
                                                             includeDocumentMetadataChanges:NO
                                                                      waitForSyncWhenOnline:NO];
  FSTQueryListener *fullListener = [self listenToQuery:query
                                               options:options
                                 accumulatingSnapshots:fullAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc1Prime ], absl::nullopt);
  FSTViewSnapshot *snap3 = FSTTestApplyChanges(view, @[ doc3 ], absl::nullopt);
  FSTViewSnapshot *snap4 = FSTTestApplyChanges(view, @[ doc2Prime ], absl::nullopt);

  [fullListener queryDidChangeViewSnapshot:snap1];
  [fullListener queryDidChangeViewSnapshot:snap2];  // Emits no events.
  [fullListener queryDidChangeViewSnapshot:snap3];
  [fullListener queryDidChangeViewSnapshot:snap4];  // Metadata change event.

  FSTViewSnapshot *expectedSnap4 =
      [[FSTViewSnapshot alloc] initWithQuery:snap4.query
                                   documents:snap4.documents
                                oldDocuments:snap3.documents
                             documentChanges:@[]
                                   fromCache:snap4.fromCache
                                 mutatedKeys:snap4.mutatedKeys
                            syncStateChanged:snap4.syncStateChanged
                     excludesMetadataChanges:YES];  // This test excludes document metadata changes
  XCTAssertEqualObjects(fullAccum, (@[
                          [self setExcludesMetadataChanges:YES snapshot:snap1],
                          [self setExcludesMetadataChanges:YES snapshot:snap3], expectedSnap4
                        ]));
}

- (void)testMetadataOnlyDocumentChangesAreFilteredOutWhenIncludeDocumentMetadataChangesIsFalse {
  NSMutableArray<FSTViewSnapshot *> *filteredAccum = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateLocalMutations);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, FSTDocumentStateSynced);
  FSTDocument *doc1Prime =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateSynced);
  FSTDocument *doc3 = FSTTestDoc("rooms/Other", 3, @{@"name" : @"Other"}, FSTDocumentStateSynced);

  FSTQueryListener *filteredListener = [self listenToQuery:query
                                     accumulatingSnapshots:filteredAccum];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc1Prime, doc3 ], absl::nullopt);

  FSTDocumentViewChange *change3 =
      [FSTDocumentViewChange changeWithDocument:doc3 type:DocumentViewChangeType::kAdded];

  [filteredListener queryDidChangeViewSnapshot:snap1];
  [filteredListener queryDidChangeViewSnapshot:snap2];

  FSTViewSnapshot *expectedSnap2 = [[FSTViewSnapshot alloc] initWithQuery:snap2.query
                                                                documents:snap2.documents
                                                             oldDocuments:snap1.documents
                                                          documentChanges:@[ change3 ]
                                                                fromCache:snap2.isFromCache
                                                              mutatedKeys:snap2.mutatedKeys
                                                         syncStateChanged:snap2.syncStateChanged
                                                  excludesMetadataChanges:YES];
  XCTAssertEqualObjects(filteredAccum,
                        (@[ [self setExcludesMetadataChanges:YES snapshot:snap1], expectedSnap2 ]));
}

- (void)testWillWaitForSyncIfOnline {
  NSMutableArray<FSTViewSnapshot *> *events = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, FSTDocumentStateSynced);
  FSTQueryListener *listener =
      [self listenToQuery:query
                        options:[[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:NO
                                                               includeDocumentMetadataChanges:NO
                                                                        waitForSyncWhenOnline:YES]
          accumulatingSnapshots:events];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1 ], absl::nullopt);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc2 ], absl::nullopt);
  FSTViewSnapshot *snap3 =
      FSTTestApplyChanges(view, @[], FSTTestTargetChangeAckDocuments({doc1.key, doc2.key}));

  [listener applyChangedOnlineState:OnlineState::Online];  // no event
  [listener queryDidChangeViewSnapshot:snap1];
  [listener applyChangedOnlineState:OnlineState::Unknown];
  [listener applyChangedOnlineState:OnlineState::Online];
  [listener queryDidChangeViewSnapshot:snap2];
  [listener queryDidChangeViewSnapshot:snap3];

  FSTDocumentViewChange *change1 =
      [FSTDocumentViewChange changeWithDocument:doc1 type:DocumentViewChangeType::kAdded];
  FSTDocumentViewChange *change2 =
      [FSTDocumentViewChange changeWithDocument:doc2 type:DocumentViewChangeType::kAdded];
  FSTViewSnapshot *expectedSnap = [[FSTViewSnapshot alloc]
                initWithQuery:snap3.query
                    documents:snap3.documents
                 oldDocuments:[FSTDocumentSet documentSetWithComparator:snap3.query.comparator]
              documentChanges:@[ change1, change2 ]
                    fromCache:NO
                  mutatedKeys:snap3.mutatedKeys
             syncStateChanged:YES
      excludesMetadataChanges:YES];
  XCTAssertEqualObjects(events, (@[ expectedSnap ]));
}

- (void)testWillRaiseInitialEventWhenGoingOffline {
  NSMutableArray<FSTViewSnapshot *> *events = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, FSTDocumentStateSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, FSTDocumentStateSynced);
  FSTQueryListener *listener =
      [self listenToQuery:query
                        options:[[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:NO
                                                               includeDocumentMetadataChanges:NO
                                                                        waitForSyncWhenOnline:YES]
          accumulatingSnapshots:events];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[ doc1 ], absl::nullopt);
  FSTViewSnapshot *snap2 = FSTTestApplyChanges(view, @[ doc2 ], absl::nullopt);

  [listener applyChangedOnlineState:OnlineState::Online];   // no event
  [listener queryDidChangeViewSnapshot:snap1];              // no event
  [listener applyChangedOnlineState:OnlineState::Offline];  // event
  [listener applyChangedOnlineState:OnlineState::Unknown];  // no event
  [listener applyChangedOnlineState:OnlineState::Offline];  // no event
  [listener queryDidChangeViewSnapshot:snap2];              // another event

  FSTDocumentViewChange *change1 =
      [FSTDocumentViewChange changeWithDocument:doc1 type:DocumentViewChangeType::kAdded];
  FSTDocumentViewChange *change2 =
      [FSTDocumentViewChange changeWithDocument:doc2 type:DocumentViewChangeType::kAdded];
  FSTViewSnapshot *expectedSnap1 = [[FSTViewSnapshot alloc]
                initWithQuery:query
                    documents:snap1.documents
                 oldDocuments:[FSTDocumentSet documentSetWithComparator:snap1.query.comparator]
              documentChanges:@[ change1 ]
                    fromCache:YES
                  mutatedKeys:snap1.mutatedKeys
             syncStateChanged:YES
      excludesMetadataChanges:YES];
  FSTViewSnapshot *expectedSnap2 = [[FSTViewSnapshot alloc] initWithQuery:query
                                                                documents:snap2.documents
                                                             oldDocuments:snap1.documents
                                                          documentChanges:@[ change2 ]
                                                                fromCache:YES
                                                              mutatedKeys:snap2.mutatedKeys
                                                         syncStateChanged:NO
                                                  excludesMetadataChanges:YES];
  XCTAssertEqualObjects(events, (@[ expectedSnap1, expectedSnap2 ]));
}

- (void)testWillRaiseInitialEventWhenGoingOfflineAndThereAreNoDocs {
  NSMutableArray<FSTViewSnapshot *> *events = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTQueryListener *listener = [self listenToQuery:query
                                           options:[FSTListenOptions defaultOptions]
                             accumulatingSnapshots:events];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[], absl::nullopt);

  [listener applyChangedOnlineState:OnlineState::Online];   // no event
  [listener queryDidChangeViewSnapshot:snap1];              // no event
  [listener applyChangedOnlineState:OnlineState::Offline];  // event

  FSTViewSnapshot *expectedSnap = [[FSTViewSnapshot alloc]
                initWithQuery:query
                    documents:snap1.documents
                 oldDocuments:[FSTDocumentSet documentSetWithComparator:snap1.query.comparator]
              documentChanges:@[]
                    fromCache:YES
                  mutatedKeys:snap1.mutatedKeys
             syncStateChanged:YES
      excludesMetadataChanges:YES];
  XCTAssertEqualObjects(events, (@[ expectedSnap ]));
}

- (void)testWillRaiseInitialEventWhenStartingOfflineAndThereAreNoDocs {
  NSMutableArray<FSTViewSnapshot *> *events = [NSMutableArray array];

  FSTQuery *query = FSTTestQuery("rooms");
  FSTQueryListener *listener = [self listenToQuery:query
                                           options:[FSTListenOptions defaultOptions]
                             accumulatingSnapshots:events];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewSnapshot *snap1 = FSTTestApplyChanges(view, @[], absl::nullopt);

  [listener applyChangedOnlineState:OnlineState::Offline];  // no event
  [listener queryDidChangeViewSnapshot:snap1];              // event

  FSTViewSnapshot *expectedSnap = [[FSTViewSnapshot alloc]
                initWithQuery:query
                    documents:snap1.documents
                 oldDocuments:[FSTDocumentSet documentSetWithComparator:snap1.query.comparator]
              documentChanges:@[]
                    fromCache:YES
                  mutatedKeys:snap1.mutatedKeys
             syncStateChanged:YES
      excludesMetadataChanges:YES];
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
