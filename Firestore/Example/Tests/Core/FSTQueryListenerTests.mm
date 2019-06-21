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
#include <utility>
#include <vector>

#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Model/FSTDocument.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/core/event_listener.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/util/delayed_constructor.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/test/firebase/firestore/testutil/xcgmock.h"

using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::core::AsyncEventListener;
using firebase::firestore::core::EventListener;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::EventListener;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::OnlineState;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::util::DelayedConstructor;
using firebase::firestore::util::ExecutorLibdispatch;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;
using testing::ElementsAre;
using testing::IsEmpty;

NS_ASSUME_NONNULL_BEGIN

namespace {

ViewSnapshot ExcludingMetadataChanges(const ViewSnapshot &snapshot) {
  return ViewSnapshot{
      snapshot.query(),
      snapshot.documents(),
      snapshot.old_documents(),
      snapshot.document_changes(),
      snapshot.mutated_keys(),
      snapshot.from_cache(),
      snapshot.sync_state_changed(),
      /*excludes_metadata_changes=*/true,
  };
}

ViewSnapshot::Listener Accumulating(std::vector<ViewSnapshot> *values) {
  return EventListener<ViewSnapshot>::Create(
      [values](const StatusOr<ViewSnapshot> &maybe_snapshot) {
        values->push_back(maybe_snapshot.ValueOrDie());
      });
}

}  // namespace

@interface FSTQueryListenerTests : XCTestCase
@end

@implementation FSTQueryListenerTests {
  std::shared_ptr<ExecutorLibdispatch> _executor;
  ListenOptions _includeMetadataChanges;
}

- (void)setUp {
  _executor = std::make_shared<ExecutorLibdispatch>(
      dispatch_queue_create("FSTQueryListenerTests Queue", DISPATCH_QUEUE_SERIAL));
  _includeMetadataChanges = ListenOptions::FromIncludeMetadataChanges(true);
}

- (void)testRaisesCollectionEvents {
  std::vector<ViewSnapshot> accum;
  std::vector<ViewSnapshot> otherAccum;

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, DocumentState::kSynced);
  FSTDocument *doc2prime = FSTTestDoc("rooms/Hades", 3, @{@"name" : @"Hades", @"owner" : @"Jonny"},
                                      DocumentState::kSynced);

  auto listener = QueryListener::Create(query, _includeMetadataChanges, Accumulating(&accum));
  auto otherListener = QueryListener::Create(query, Accumulating(&otherAccum));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt).value();
  ViewSnapshot snap2 = FSTTestApplyChanges(view, @[ doc2prime ], absl::nullopt).value();

  DocumentViewChange change1{doc1, DocumentViewChange::Type::kAdded};
  DocumentViewChange change2{doc2, DocumentViewChange::Type::kAdded};
  DocumentViewChange change3{doc2prime, DocumentViewChange::Type::kModified};
  DocumentViewChange change4{doc2prime, DocumentViewChange::Type::kAdded};

  listener->OnViewSnapshot(snap1);
  listener->OnViewSnapshot(snap2);
  otherListener->OnViewSnapshot(snap2);

  XC_ASSERT_THAT(accum, ElementsAre(snap1, snap2));
  XC_ASSERT_THAT(accum[0].document_changes(), ElementsAre(change1, change2));
  XC_ASSERT_THAT(accum[1].document_changes(), ElementsAre(change3));

  ViewSnapshot expectedSnap2{snap2.query(),
                             snap2.documents(),
                             /*old_documents=*/DocumentSet{snap2.query().comparator},
                             /*document_changes=*/{change1, change4},
                             snap2.mutated_keys(),
                             snap2.from_cache(),
                             /*sync_state_changed=*/true,
                             /*excludes_metadata_changes=*/true};
  XC_ASSERT_THAT(otherAccum, ElementsAre(expectedSnap2));
}

- (void)testRaisesErrorEvent {
  __block std::vector<Status> accum;
  FSTQuery *query = FSTTestQuery("rooms/Eros");

  auto listener = QueryListener::Create(query, ^(const StatusOr<ViewSnapshot> &maybe_snapshot) {
    accum.push_back(maybe_snapshot.status());
  });

  Status testError{FirestoreErrorCode::Unauthenticated, "Some info"};
  listener->OnError(testError);

  XC_ASSERT_THAT(accum, ElementsAre(testError));
}

- (void)testRaisesEventForEmptyCollectionAfterSync {
  std::vector<ViewSnapshot> accum;
  FSTQuery *query = FSTTestQuery("rooms");

  auto listener = QueryListener::Create(query, _includeMetadataChanges, Accumulating(&accum));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[], absl::nullopt).value();
  ViewSnapshot snap2 = FSTTestApplyChanges(view, @[], FSTTestTargetChangeMarkCurrent()).value();

  listener->OnViewSnapshot(snap1);
  XC_ASSERT_THAT(accum, IsEmpty());

  listener->OnViewSnapshot(snap2);
  XC_ASSERT_THAT(accum, ElementsAre(snap2));
}

- (void)testMutingAsyncListenerPreventsAllSubsequentEvents {
  std::vector<ViewSnapshot> accum;

  FSTQuery *query = FSTTestQuery("rooms/Eros");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 3, @{@"name" : @"Eros"}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Eros", 4, @{@"name" : @"Eros2"}, DocumentState::kSynced);

  std::shared_ptr<AsyncEventListener<ViewSnapshot>> listener =
      AsyncEventListener<ViewSnapshot>::Create(
          _executor, EventListener<ViewSnapshot>::Create(
                         [&accum, &listener](const StatusOr<ViewSnapshot> &maybe_snapshot) {
                           accum.push_back(maybe_snapshot.ValueOrDie());
                           listener->Mute();
                         }));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot viewSnapshot1 = FSTTestApplyChanges(view, @[ doc1 ], absl::nullopt).value();
  ViewSnapshot viewSnapshot2 = FSTTestApplyChanges(view, @[ doc2 ], absl::nullopt).value();

  listener->OnEvent(viewSnapshot1);
  listener->OnEvent(viewSnapshot2);

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
  XC_ASSERT_THAT(accum, ElementsAre(viewSnapshot1));
}

- (void)testDoesNotRaiseEventsForMetadataChangesUnlessSpecified {
  std::vector<ViewSnapshot> filteredAccum;
  std::vector<ViewSnapshot> fullAccum;

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, DocumentState::kSynced);

  auto filteredListener = QueryListener::Create(query, Accumulating(&filteredAccum));
  auto fullListener =
      QueryListener::Create(query, _includeMetadataChanges, Accumulating(&fullAccum));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[ doc1 ], absl::nullopt).value();

  TargetChange ackTarget = FSTTestTargetChangeAckDocuments({doc1.key});
  ViewSnapshot snap2 = FSTTestApplyChanges(view, @[], ackTarget).value();
  ViewSnapshot snap3 = FSTTestApplyChanges(view, @[ doc2 ], absl::nullopt).value();

  filteredListener->OnViewSnapshot(snap1);  // local event
  filteredListener->OnViewSnapshot(snap2);  // no event
  filteredListener->OnViewSnapshot(snap3);  // doc2 update

  fullListener->OnViewSnapshot(snap1);  // local event
  fullListener->OnViewSnapshot(snap2);  // state change event
  fullListener->OnViewSnapshot(snap3);  // doc2 update

  XC_ASSERT_THAT(filteredAccum,
                 ElementsAre(ExcludingMetadataChanges(snap1), ExcludingMetadataChanges(snap3)));
  XC_ASSERT_THAT(fullAccum, ElementsAre(snap1, snap2, snap3));
}

- (void)testRaisesDocumentMetadataEventsOnlyWhenSpecified {
  std::vector<ViewSnapshot> filteredAccum;
  std::vector<ViewSnapshot> fullAccum;

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kLocalMutations);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, DocumentState::kSynced);
  FSTDocument *doc1Prime =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kSynced);
  FSTDocument *doc3 = FSTTestDoc("rooms/Other", 3, @{@"name" : @"Other"}, DocumentState::kSynced);

  ListenOptions options(
      /*include_query_metadata_changes=*/false,
      /*include_document_metadata_changes=*/true,
      /*wait_for_sync_when_online=*/false);

  auto filteredListener = QueryListener::Create(query, Accumulating(&filteredAccum));
  auto fullListener = QueryListener::Create(query, options, Accumulating(&fullAccum));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt).value();
  ViewSnapshot snap2 = FSTTestApplyChanges(view, @[ doc1Prime ], absl::nullopt).value();
  ViewSnapshot snap3 = FSTTestApplyChanges(view, @[ doc3 ], absl::nullopt).value();

  DocumentViewChange change1{doc1, DocumentViewChange::Type::kAdded};
  DocumentViewChange change2{doc2, DocumentViewChange::Type::kAdded};
  DocumentViewChange change3{doc1Prime, DocumentViewChange::Type::kMetadata};
  DocumentViewChange change4{doc3, DocumentViewChange::Type::kAdded};

  filteredListener->OnViewSnapshot(snap1);
  filteredListener->OnViewSnapshot(snap2);
  filteredListener->OnViewSnapshot(snap3);
  fullListener->OnViewSnapshot(snap1);
  fullListener->OnViewSnapshot(snap2);
  fullListener->OnViewSnapshot(snap3);

  XC_ASSERT_THAT(filteredAccum,
                 ElementsAre(ExcludingMetadataChanges(snap1), ExcludingMetadataChanges(snap3)));
  XC_ASSERT_THAT(filteredAccum[0].document_changes(), ElementsAre(change1, change2));
  XC_ASSERT_THAT(filteredAccum[1].document_changes(), ElementsAre(change4));

  XC_ASSERT_THAT(fullAccum, ElementsAre(snap1, snap2, snap3));
  XC_ASSERT_THAT(fullAccum[0].document_changes(), ElementsAre(change1, change2));
  XC_ASSERT_THAT(fullAccum[1].document_changes(), ElementsAre(change3));
  XC_ASSERT_THAT(fullAccum[2].document_changes(), ElementsAre(change4));
}

- (void)testRaisesQueryMetadataEventsOnlyWhenHasPendingWritesOnTheQueryChanges {
  std::vector<ViewSnapshot> fullAccum;

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kLocalMutations);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, DocumentState::kLocalMutations);
  FSTDocument *doc1Prime =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kSynced);
  FSTDocument *doc2Prime =
      FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, DocumentState::kSynced);
  FSTDocument *doc3 = FSTTestDoc("rooms/Other", 3, @{@"name" : @"Other"}, DocumentState::kSynced);

  ListenOptions options(
      /*include_query_metadata_changes=*/true,
      /*include_document_metadata_changes=*/false,
      /*wait_for_sync_when_online=*/false);
  auto fullListener = QueryListener::Create(query, options, Accumulating(&fullAccum));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt).value();
  ViewSnapshot snap2 = FSTTestApplyChanges(view, @[ doc1Prime ], absl::nullopt).value();
  ViewSnapshot snap3 = FSTTestApplyChanges(view, @[ doc3 ], absl::nullopt).value();
  ViewSnapshot snap4 = FSTTestApplyChanges(view, @[ doc2Prime ], absl::nullopt).value();

  fullListener->OnViewSnapshot(snap1);
  fullListener->OnViewSnapshot(snap2);  // Emits no events.
  fullListener->OnViewSnapshot(snap3);
  fullListener->OnViewSnapshot(snap4);  // Metadata change event.

  ViewSnapshot expectedSnap4{
      snap4.query(),
      snap4.documents(),
      snap3.documents(),
      /*document_changes=*/{},
      snap4.mutated_keys(),
      snap4.from_cache(),
      snap4.sync_state_changed(),
      /*excludes_metadata_changes=*/true  // This test excludes document metadata changes
  };

  XC_ASSERT_THAT(fullAccum, ElementsAre(ExcludingMetadataChanges(snap1),
                                        ExcludingMetadataChanges(snap3), expectedSnap4));
}

- (void)testMetadataOnlyDocumentChangesAreFilteredOutWhenIncludeDocumentMetadataChangesIsFalse {
  std::vector<ViewSnapshot> filteredAccum;

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kLocalMutations);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, DocumentState::kSynced);
  FSTDocument *doc1Prime =
      FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kSynced);
  FSTDocument *doc3 = FSTTestDoc("rooms/Other", 3, @{@"name" : @"Other"}, DocumentState::kSynced);

  auto filteredListener = QueryListener::Create(query, Accumulating(&filteredAccum));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt).value();
  ViewSnapshot snap2 = FSTTestApplyChanges(view, @[ doc1Prime, doc3 ], absl::nullopt).value();

  DocumentViewChange change3{doc3, DocumentViewChange::Type::kAdded};

  filteredListener->OnViewSnapshot(snap1);
  filteredListener->OnViewSnapshot(snap2);

  ViewSnapshot expectedSnap2{snap2.query(),
                             snap2.documents(),
                             snap1.documents(),
                             /*document_changes=*/{change3},
                             snap2.mutated_keys(),
                             snap2.from_cache(),
                             snap2.sync_state_changed(),
                             /*excludes_metadata_changes=*/true};
  XC_ASSERT_THAT(filteredAccum, ElementsAre(ExcludingMetadataChanges(snap1), expectedSnap2));
}

- (void)testWillWaitForSyncIfOnline {
  std::vector<ViewSnapshot> events;

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, DocumentState::kSynced);

  ListenOptions options(
      /*include_query_metadata_changes=*/false,
      /*include_document_metadata_changes=*/false,
      /*wait_for_sync_when_online=*/true);
  auto listener = QueryListener::Create(query, options, Accumulating(&events));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[ doc1 ], absl::nullopt).value();
  ViewSnapshot snap2 = FSTTestApplyChanges(view, @[ doc2 ], absl::nullopt).value();
  ViewSnapshot snap3 =
      FSTTestApplyChanges(view, @[], FSTTestTargetChangeAckDocuments({doc1.key, doc2.key})).value();

  listener->OnOnlineStateChanged(OnlineState::Online);  // no event
  listener->OnViewSnapshot(snap1);
  listener->OnOnlineStateChanged(OnlineState::Unknown);
  listener->OnOnlineStateChanged(OnlineState::Online);
  listener->OnViewSnapshot(snap2);
  listener->OnViewSnapshot(snap3);

  DocumentViewChange change1{doc1, DocumentViewChange::Type::kAdded};
  DocumentViewChange change2{doc2, DocumentViewChange::Type::kAdded};
  ViewSnapshot expectedSnap{snap3.query(),
                            snap3.documents(),
                            /*old_documents=*/DocumentSet{snap3.query().comparator},
                            /*document_changes=*/{change1, change2},
                            snap3.mutated_keys(),
                            /*from_cache=*/false,
                            /*sync_state_changed=*/true,
                            /*excludes_metadata_changes=*/true};
  XC_ASSERT_THAT(events, ElementsAre(expectedSnap));
}

- (void)testWillRaiseInitialEventWhenGoingOffline {
  std::vector<ViewSnapshot> events;

  FSTQuery *query = FSTTestQuery("rooms");
  FSTDocument *doc1 = FSTTestDoc("rooms/Eros", 1, @{@"name" : @"Eros"}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/Hades", 2, @{@"name" : @"Hades"}, DocumentState::kSynced);

  ListenOptions options(
      /*include_query_metadata_changes=*/false,
      /*include_document_metadata_changes=*/false,
      /*wait_for_sync_when_online=*/true);

  auto listener = QueryListener::Create(query, options, Accumulating(&events));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[ doc1 ], absl::nullopt).value();
  ViewSnapshot snap2 = FSTTestApplyChanges(view, @[ doc2 ], absl::nullopt).value();

  listener->OnOnlineStateChanged(OnlineState::Online);   // no event
  listener->OnViewSnapshot(snap1);                       // no event
  listener->OnOnlineStateChanged(OnlineState::Offline);  // event
  listener->OnOnlineStateChanged(OnlineState::Unknown);  // no event
  listener->OnOnlineStateChanged(OnlineState::Offline);  // no event
  listener->OnViewSnapshot(snap2);                       // another event

  DocumentViewChange change1{doc1, DocumentViewChange::Type::kAdded};
  DocumentViewChange change2{doc2, DocumentViewChange::Type::kAdded};
  ViewSnapshot expectedSnap1{query,
                             /*documents=*/snap1.documents(),
                             /*old_documents=*/DocumentSet{snap1.query().comparator},
                             /*document_changes=*/{change1},
                             snap1.mutated_keys(),
                             /*from_cache=*/true,
                             /*sync_state_changed=*/true,
                             /*excludes_metadata_changes=*/true};

  ViewSnapshot expectedSnap2{query,
                             /*documents=*/snap2.documents(),
                             /*old_documents=*/snap1.documents(),
                             /*document_changes=*/{change2},
                             snap2.mutated_keys(),
                             /*from_cache=*/true,
                             /*sync_state_changed=*/false,
                             /*excludes_metadata_changes=*/true};
  XC_ASSERT_THAT(events, ElementsAre(expectedSnap1, expectedSnap2));
}

- (void)testWillRaiseInitialEventWhenGoingOfflineAndThereAreNoDocs {
  std::vector<ViewSnapshot> events;

  FSTQuery *query = FSTTestQuery("rooms");
  auto listener = QueryListener::Create(query, Accumulating(&events));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[], absl::nullopt).value();

  listener->OnOnlineStateChanged(OnlineState::Online);   // no event
  listener->OnViewSnapshot(snap1);                       // no event
  listener->OnOnlineStateChanged(OnlineState::Offline);  // event

  ViewSnapshot expectedSnap{query,
                            /*documents=*/snap1.documents(),
                            /*old_documents=*/DocumentSet{snap1.query().comparator},
                            /*document_changes=*/{},
                            snap1.mutated_keys(),
                            /*from_cache=*/true,
                            /*sync_state_changed=*/true,
                            /*excludes_metadata_changes=*/true};
  XC_ASSERT_THAT(events, ElementsAre(expectedSnap));
}

- (void)testWillRaiseInitialEventWhenStartingOfflineAndThereAreNoDocs {
  std::vector<ViewSnapshot> events;

  FSTQuery *query = FSTTestQuery("rooms");
  auto listener = QueryListener::Create(query, Accumulating(&events));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  ViewSnapshot snap1 = FSTTestApplyChanges(view, @[], absl::nullopt).value();

  listener->OnOnlineStateChanged(OnlineState::Offline);  // no event
  listener->OnViewSnapshot(snap1);                       // event

  ViewSnapshot expectedSnap{query,
                            /*documents=*/snap1.documents(),
                            /*old_documents=*/DocumentSet{snap1.query().comparator},
                            /*document_changes=*/{},
                            snap1.mutated_keys(),
                            /*from_cache=*/true,
                            /*sync_state_changed=*/true,
                            /*excludes_metadata_changes=*/true};
  XC_ASSERT_THAT(events, ElementsAre(expectedSnap));
}

@end

NS_ASSUME_NONNULL_END
