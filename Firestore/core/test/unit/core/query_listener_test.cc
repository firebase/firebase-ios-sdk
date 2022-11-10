/*
 * Copyright 2017 Google LLC
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

#include "Firestore/core/src/core/query_listener.h"

#include <future>  // NOLINT(build/c++11)
#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/core/event_listener.h"
#include "Firestore/core/src/core/listen_options.h"
#include "Firestore/core/src/core/view.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/types.h"
#include "Firestore/core/src/remote/remote_event.h"
#include "Firestore/core/src/util/delayed_constructor.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "Firestore/core/test/unit/testutil/view_testing.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using model::DocumentKeySet;
using model::DocumentSet;
using model::MutableDocument;
using model::OnlineState;
using remote::TargetChange;
using util::DelayedConstructor;
using util::Executor;
using util::Status;
using util::StatusOr;

using testing::ElementsAre;
using testing::IsEmpty;
using testutil::AckTarget;
using testutil::ApplyChanges;
using testutil::Doc;
using testutil::Expectation;
using testutil::Map;
using testutil::MarkCurrent;

namespace {

ViewSnapshot ExcludingMetadataChanges(const ViewSnapshot& snapshot) {
  return ViewSnapshot{snapshot.query(),
                      snapshot.documents(),
                      snapshot.old_documents(),
                      snapshot.document_changes(),
                      snapshot.mutated_keys(),
                      snapshot.from_cache(),
                      snapshot.sync_state_changed(),
                      /*excludes_metadata_changes=*/true,
                      snapshot.has_cached_results()};
}

ViewSnapshotListener Accumulating(std::vector<ViewSnapshot>* values) {
  return EventListener<ViewSnapshot>::Create(
      [values](const StatusOr<ViewSnapshot>& maybe_snapshot) {
        values->push_back(maybe_snapshot.ValueOrDie());
      });
}

}  // namespace

class QueryListenerTest : public testing::Test, public testutil::AsyncTest {
 protected:
  void SetUp() override {
    _executor = testutil::ExecutorForTesting("worker");
    include_metadata_changes_ = ListenOptions::FromIncludeMetadataChanges(true);
  }

  std::shared_ptr<Executor> _executor;
  ListenOptions include_metadata_changes_;
};

TEST_F(QueryListenerTest, RaisesCollectionEvents) {
  std::vector<ViewSnapshot> accum;
  std::vector<ViewSnapshot> other_accum;

  Query query = testutil::Query("rooms");
  MutableDocument doc1 = Doc("rooms/Eros", 1, Map("name", "Eros"));
  MutableDocument doc2 = Doc("rooms/Hades", 2, Map("name", "Hades"));
  MutableDocument doc2prime =
      Doc("rooms/Hades", 3, Map("name", "Hades", "owner", "Jonny"));

  auto listener = QueryListener::Create(query, include_metadata_changes_,
                                        Accumulating(&accum));
  auto other_listener =
      QueryListener::Create(query, Accumulating(&other_accum));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {doc1, doc2}, absl::nullopt).value();
  ViewSnapshot snap2 = ApplyChanges(&view, {doc2prime}, absl::nullopt).value();

  DocumentViewChange change1{doc1, DocumentViewChange::Type::Added};
  DocumentViewChange change2{doc2, DocumentViewChange::Type::Added};
  DocumentViewChange change3{doc2prime, DocumentViewChange::Type::Modified};
  DocumentViewChange change4{doc2prime, DocumentViewChange::Type::Added};

  listener->OnViewSnapshot(snap1);
  listener->OnViewSnapshot(snap2);
  other_listener->OnViewSnapshot(snap2);

  ASSERT_THAT(accum, ElementsAre(snap1, snap2));
  ASSERT_THAT(accum[0].document_changes(), ElementsAre(change1, change2));
  ASSERT_THAT(accum[1].document_changes(), ElementsAre(change3));

  ViewSnapshot expected_snap2{
      snap2.query(),
      snap2.documents(),
      /*old_documents=*/DocumentSet{snap2.query().Comparator()},
      /*document_changes=*/{change1, change4},
      snap2.mutated_keys(),
      snap2.from_cache(),
      /*sync_state_changed=*/true,
      /*excludes_metadata_changes=*/true,
      snap2.has_cached_results()};
  ASSERT_THAT(other_accum, ElementsAre(expected_snap2));
}

TEST_F(QueryListenerTest, RaisesErrorEvent) {
  std::vector<Status> accum;
  Query query = testutil::Query("rooms/Eros");

  auto listener = QueryListener::Create(
      query, EventListener<ViewSnapshot>::Create(
                 [&accum](const StatusOr<ViewSnapshot>& maybe_snapshot) {
                   accum.push_back(maybe_snapshot.status());
                 }));

  Status test_error{Error::kErrorUnauthenticated, "Some info"};
  listener->OnError(test_error);

  ASSERT_THAT(accum, ElementsAre(test_error));
}

TEST_F(QueryListenerTest, RaisesEventForEmptyCollectionAfterSync) {
  std::vector<ViewSnapshot> accum;
  Query query = testutil::Query("rooms");

  auto listener = QueryListener::Create(query, include_metadata_changes_,
                                        Accumulating(&accum));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {}, absl::nullopt).value();
  ViewSnapshot snap2 = ApplyChanges(&view, {}, MarkCurrent()).value();

  listener->OnViewSnapshot(snap1);
  ASSERT_THAT(accum, IsEmpty());

  listener->OnViewSnapshot(snap2);
  ASSERT_THAT(accum, ElementsAre(snap2));
}

TEST_F(QueryListenerTest, MutingAsyncListenerPreventsAllSubsequentEvents) {
  std::vector<ViewSnapshot> accum;

  Query query = testutil::Query("rooms/Eros");
  MutableDocument doc1 = Doc("rooms/Eros", 3, Map("name", "Eros"));
  MutableDocument doc2 = Doc("rooms/Eros", 4, Map("name", "Eros2"));

  std::shared_ptr<AsyncEventListener<ViewSnapshot>> listener =
      AsyncEventListener<ViewSnapshot>::Create(
          _executor, EventListener<ViewSnapshot>::Create(
                         [&accum, &listener](
                             const StatusOr<ViewSnapshot>& maybe_snapshot) {
                           accum.push_back(maybe_snapshot.ValueOrDie());
                           listener->Mute();
                         }));

  View view(query, DocumentKeySet{});
  ViewSnapshot view_snapshot1 =
      ApplyChanges(&view, {doc1}, absl::nullopt).value();
  ViewSnapshot view_snapshot2 =
      ApplyChanges(&view, {doc2}, absl::nullopt).value();

  listener->OnEvent(view_snapshot1);
  listener->OnEvent(view_snapshot2);

  // Drain queue
  Expectation drained;
  _executor->Execute(drained.AsCallback());
  Await(drained);

  // We should get the first snapshot but not the second.
  ASSERT_THAT(accum, ElementsAre(view_snapshot1));
}

TEST_F(QueryListenerTest, DoesNotRaiseEventsForMetadataChangesUnlessSpecified) {
  std::vector<ViewSnapshot> filtered_accum;
  std::vector<ViewSnapshot> full_accum;

  Query query = testutil::Query("rooms");
  MutableDocument doc1 = Doc("rooms/Eros", 1, Map("name", "Eros"));
  MutableDocument doc2 = Doc("rooms/Hades", 2, Map("name", "Hades"));

  auto filtered_listener =
      QueryListener::Create(query, Accumulating(&filtered_accum));
  auto full_listener = QueryListener::Create(query, include_metadata_changes_,
                                             Accumulating(&full_accum));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {doc1}, absl::nullopt).value();

  TargetChange ack_target = AckTarget({doc1});
  ViewSnapshot snap2 = ApplyChanges(&view, {}, ack_target).value();
  ViewSnapshot snap3 = ApplyChanges(&view, {doc2}, absl::nullopt).value();

  filtered_listener->OnViewSnapshot(snap1);  // local event
  filtered_listener->OnViewSnapshot(snap2);  // no event
  filtered_listener->OnViewSnapshot(snap3);  // doc2 update

  full_listener->OnViewSnapshot(snap1);  // local event
  full_listener->OnViewSnapshot(snap2);  // state change event
  full_listener->OnViewSnapshot(snap3);  // doc2 update

  ASSERT_THAT(filtered_accum, ElementsAre(ExcludingMetadataChanges(snap1),
                                          ExcludingMetadataChanges(snap3)));
  ASSERT_THAT(full_accum, ElementsAre(snap1, snap2, snap3));
}

TEST_F(QueryListenerTest, RaisesDocumentMetadataEventsOnlyWhenSpecified) {
  std::vector<ViewSnapshot> filtered_accum;
  std::vector<ViewSnapshot> full_accum;

  Query query = testutil::Query("rooms");
  MutableDocument doc1 =
      Doc("rooms/Eros", 1, Map("name", "Eros")).SetHasLocalMutations();
  MutableDocument doc2 = Doc("rooms/Hades", 2, Map("name", "Hades"));
  MutableDocument doc1_prime = Doc("rooms/Eros", 1, Map("name", "Eros"));
  MutableDocument doc3 = Doc("rooms/Other", 3, Map("name", "Other"));

  ListenOptions options(
      /*include_query_metadata_changes=*/false,
      /*include_document_metadata_changes=*/true,
      /*wait_for_sync_when_online=*/false);

  auto filtered_listener =
      QueryListener::Create(query, Accumulating(&filtered_accum));
  auto full_listener =
      QueryListener::Create(query, options, Accumulating(&full_accum));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {doc1, doc2}, absl::nullopt).value();
  ViewSnapshot snap2 = ApplyChanges(&view, {doc1_prime}, absl::nullopt).value();
  ViewSnapshot snap3 = ApplyChanges(&view, {doc3}, absl::nullopt).value();

  DocumentViewChange change1{doc1, DocumentViewChange::Type::Added};
  DocumentViewChange change2{doc2, DocumentViewChange::Type::Added};
  DocumentViewChange change3{doc1_prime, DocumentViewChange::Type::Metadata};
  DocumentViewChange change4{doc3, DocumentViewChange::Type::Added};

  filtered_listener->OnViewSnapshot(snap1);
  filtered_listener->OnViewSnapshot(snap2);
  filtered_listener->OnViewSnapshot(snap3);
  full_listener->OnViewSnapshot(snap1);
  full_listener->OnViewSnapshot(snap2);
  full_listener->OnViewSnapshot(snap3);

  ASSERT_THAT(filtered_accum, ElementsAre(ExcludingMetadataChanges(snap1),
                                          ExcludingMetadataChanges(snap3)));
  ASSERT_THAT(filtered_accum[0].document_changes(),
              ElementsAre(change1, change2));
  ASSERT_THAT(filtered_accum[1].document_changes(), ElementsAre(change4));

  ASSERT_THAT(full_accum, ElementsAre(snap1, snap2, snap3));
  ASSERT_THAT(full_accum[0].document_changes(), ElementsAre(change1, change2));
  ASSERT_THAT(full_accum[1].document_changes(), ElementsAre(change3));
  ASSERT_THAT(full_accum[2].document_changes(), ElementsAre(change4));
}

TEST_F(QueryListenerTest,
       RaisesQueryMetadataEventsOnlyWhenHasPendingWritesOnTheQueryChanges) {
  std::vector<ViewSnapshot> full_accum;

  Query query = testutil::Query("rooms");
  MutableDocument doc1 =
      Doc("rooms/Eros", 1, Map("name", "Eros")).SetHasLocalMutations();
  MutableDocument doc2 =
      Doc("rooms/Hades", 2, Map("name", "Hades")).SetHasLocalMutations();
  MutableDocument doc1_prime = Doc("rooms/Eros", 1, Map("name", "Eros"));
  MutableDocument doc2_prime = Doc("rooms/Hades", 2, Map("name", "Hades"));
  MutableDocument doc3 = Doc("rooms/Other", 3, Map("name", "Other"));

  ListenOptions options(
      /*include_query_metadata_changes=*/true,
      /*include_document_metadata_changes=*/false,
      /*wait_for_sync_when_online=*/false);
  auto full_listener =
      QueryListener::Create(query, options, Accumulating(&full_accum));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {doc1, doc2}, absl::nullopt).value();
  ViewSnapshot snap2 = ApplyChanges(&view, {doc1_prime}, absl::nullopt).value();
  ViewSnapshot snap3 = ApplyChanges(&view, {doc3}, absl::nullopt).value();
  ViewSnapshot snap4 = ApplyChanges(&view, {doc2_prime}, absl::nullopt).value();

  full_listener->OnViewSnapshot(snap1);
  full_listener->OnViewSnapshot(snap2);  // Emits no events.
  full_listener->OnViewSnapshot(snap3);
  full_listener->OnViewSnapshot(snap4);  // Metadata change event.

  ViewSnapshot expected_snap4{snap4.query(),
                              snap4.documents(),
                              snap3.documents(),
                              /*document_changes=*/{},
                              snap4.mutated_keys(),
                              snap4.from_cache(),
                              snap4.sync_state_changed(),
                              /*excludes_metadata_changes=*/true,
                              snap4.has_cached_results()};

  ASSERT_THAT(full_accum,
              ElementsAre(ExcludingMetadataChanges(snap1),
                          ExcludingMetadataChanges(snap3), expected_snap4));
}

TEST_F(QueryListenerTest,
       TestMetadataOnlyDocChangesAreRemovedWhenIncludeMetadataChangesIsFalse) {
  std::vector<ViewSnapshot> filtered_accum;

  Query query = testutil::Query("rooms");
  MutableDocument doc1 =
      Doc("rooms/Eros", 1, Map("name", "Eros")).SetHasLocalMutations();
  MutableDocument doc2 = Doc("rooms/Hades", 2, Map("name", "Hades"));
  MutableDocument doc1_prime = Doc("rooms/Eros", 1, Map("name", "Eros"));
  MutableDocument doc3 = Doc("rooms/Other", 3, Map("name", "Other"));

  auto filtered_listener =
      QueryListener::Create(query, Accumulating(&filtered_accum));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {doc1, doc2}, absl::nullopt).value();
  ViewSnapshot snap2 =
      ApplyChanges(&view, {doc1_prime, doc3}, absl::nullopt).value();

  DocumentViewChange change3{doc3, DocumentViewChange::Type::Added};

  filtered_listener->OnViewSnapshot(snap1);
  filtered_listener->OnViewSnapshot(snap2);

  ViewSnapshot expected_snap2{snap2.query(),
                              snap2.documents(),
                              snap1.documents(),
                              /*document_changes=*/{change3},
                              snap2.mutated_keys(),
                              snap2.from_cache(),
                              snap2.sync_state_changed(),
                              /*excludes_metadata_changes=*/true,
                              snap2.has_cached_results()};
  ASSERT_THAT(filtered_accum,
              ElementsAre(ExcludingMetadataChanges(snap1), expected_snap2));
}

TEST_F(QueryListenerTest, WillWaitForSyncIfOnline) {
  std::vector<ViewSnapshot> events;

  Query query = testutil::Query("rooms");
  MutableDocument doc1 = Doc("rooms/Eros", 1, Map("name", "Eros"));
  MutableDocument doc2 = Doc("rooms/Hades", 2, Map("name", "Hades"));

  ListenOptions options(
      /*include_query_metadata_changes=*/false,
      /*include_document_metadata_changes=*/false,
      /*wait_for_sync_when_online=*/true);
  auto listener = QueryListener::Create(query, options, Accumulating(&events));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {doc1}, absl::nullopt).value();
  ViewSnapshot snap2 = ApplyChanges(&view, {doc2}, absl::nullopt).value();
  ViewSnapshot snap3 = ApplyChanges(&view, {}, AckTarget({doc1, doc2})).value();

  listener->OnOnlineStateChanged(OnlineState::Online);  // no event
  listener->OnViewSnapshot(snap1);
  listener->OnOnlineStateChanged(OnlineState::Unknown);
  listener->OnOnlineStateChanged(OnlineState::Online);
  listener->OnViewSnapshot(snap2);
  listener->OnViewSnapshot(snap3);

  DocumentViewChange change1{doc1, DocumentViewChange::Type::Added};
  DocumentViewChange change2{doc2, DocumentViewChange::Type::Added};
  ViewSnapshot expected_snap{
      snap3.query(),
      snap3.documents(),
      /*old_documents=*/DocumentSet{snap3.query().Comparator()},
      /*document_changes=*/{change1, change2},
      snap3.mutated_keys(),
      /*from_cache=*/false,
      /*sync_state_changed=*/true,
      /*excludes_metadata_changes=*/true,
      snap3.has_cached_results()};
  ASSERT_THAT(events, ElementsAre(expected_snap));
}

TEST_F(QueryListenerTest, WillRaiseInitialEventWhenGoingOffline) {
  std::vector<ViewSnapshot> events;

  Query query = testutil::Query("rooms");
  MutableDocument doc1 = Doc("rooms/Eros", 1, Map("name", "Eros"));
  MutableDocument doc2 = Doc("rooms/Hades", 2, Map("name", "Hades"));

  ListenOptions options(
      /*include_query_metadata_changes=*/false,
      /*include_document_metadata_changes=*/false,
      /*wait_for_sync_when_online=*/true);

  auto listener = QueryListener::Create(query, options, Accumulating(&events));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {doc1}, absl::nullopt).value();
  ViewSnapshot snap2 = ApplyChanges(&view, {doc2}, absl::nullopt).value();

  listener->OnOnlineStateChanged(OnlineState::Online);   // no event
  listener->OnViewSnapshot(snap1);                       // no event
  listener->OnOnlineStateChanged(OnlineState::Offline);  // event
  listener->OnOnlineStateChanged(OnlineState::Unknown);  // no event
  listener->OnOnlineStateChanged(OnlineState::Offline);  // no event
  listener->OnViewSnapshot(snap2);                       // another event

  DocumentViewChange change1{doc1, DocumentViewChange::Type::Added};
  DocumentViewChange change2{doc2, DocumentViewChange::Type::Added};
  ViewSnapshot expected_snap1{
      query,
      /*documents=*/snap1.documents(),
      /*old_documents=*/DocumentSet{snap1.query().Comparator()},
      /*document_changes=*/{change1},
      snap1.mutated_keys(),
      /*from_cache=*/true,
      /*sync_state_changed=*/true,
      /*excludes_metadata_changes=*/true,
      snap1.has_cached_results()};

  ViewSnapshot expected_snap2{query,
                              /*documents=*/snap2.documents(),
                              /*old_documents=*/snap1.documents(),
                              /*document_changes=*/{change2},
                              snap2.mutated_keys(),
                              /*from_cache=*/true,
                              /*sync_state_changed=*/false,
                              /*excludes_metadata_changes=*/true,
                              snap2.has_cached_results()};
  ASSERT_THAT(events, ElementsAre(expected_snap1, expected_snap2));
}

TEST_F(QueryListenerTest,
       WillRaiseInitialEventWhenGoingOfflineAndThereAreNoDocs) {
  std::vector<ViewSnapshot> events;

  Query query = testutil::Query("rooms");
  auto listener = QueryListener::Create(query, Accumulating(&events));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {}, absl::nullopt).value();

  listener->OnOnlineStateChanged(OnlineState::Online);   // no event
  listener->OnViewSnapshot(snap1);                       // no event
  listener->OnOnlineStateChanged(OnlineState::Offline);  // event

  ViewSnapshot expected_snap{
      query,
      /*documents=*/snap1.documents(),
      /*old_documents=*/DocumentSet{snap1.query().Comparator()},
      /*document_changes=*/{},
      snap1.mutated_keys(),
      /*from_cache=*/true,
      /*sync_state_changed=*/true,
      /*excludes_metadata_changes=*/true,
      snap1.has_cached_results()};
  ASSERT_THAT(events, ElementsAre(expected_snap));
}

TEST_F(QueryListenerTest,
       WillRaiseInitialEventWhenStartingOfflineAndThereAreNoDocs) {
  std::vector<ViewSnapshot> events;

  Query query = testutil::Query("rooms");
  auto listener = QueryListener::Create(query, Accumulating(&events));

  View view(query, DocumentKeySet{});
  ViewSnapshot snap1 = ApplyChanges(&view, {}, absl::nullopt).value();

  listener->OnOnlineStateChanged(OnlineState::Offline);  // no event
  listener->OnViewSnapshot(snap1);                       // event

  ViewSnapshot expected_snap{
      query,
      /*documents=*/snap1.documents(),
      /*old_documents=*/DocumentSet{snap1.query().Comparator()},
      /*document_changes=*/{},
      snap1.mutated_keys(),
      /*from_cache=*/true,
      /*sync_state_changed=*/true,
      /*excludes_metadata_changes=*/true,
      snap1.has_cached_results()};
  ASSERT_THAT(events, ElementsAre(expected_snap));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
