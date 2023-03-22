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

#include "Firestore/core/src/remote/remote_event.h"

#include <memory>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/types.h"
#include "Firestore/core/src/remote/existence_filter.h"
#include "Firestore/core/src/remote/watch_change.h"
#include "Firestore/core/test/unit/remote/fake_target_metadata_provider.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using local::QueryPurpose;
using local::TargetData;
using model::DocumentKey;
using model::DocumentKeySet;
using model::MutableDocument;
using model::SnapshotVersion;
using model::TargetId;
using nanopb::ByteString;
using util::Status;

using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Key;
using testutil::Map;
using testutil::Query;
using testutil::VectorOfUniquePtrs;

namespace {

template <typename... Elems>
std::vector<std::unique_ptr<WatchChange>> Changes(Elems... elems) {
  return VectorOfUniquePtrs<WatchChange>(std::move(elems)...);
}

// These helpers work around the fact that `make_unique` cannot deduce the
// desired type (`vector<TargetId>` in this case) from an initialization list
// (e.g., `{1,2}`).
std::unique_ptr<DocumentWatchChange> MakeDocChange(
    std::vector<TargetId> updated,
    std::vector<TargetId> removed,
    DocumentKey key,
    const MutableDocument& doc) {
  return absl::make_unique<DocumentWatchChange>(
      std::move(updated), std::move(removed), std::move(key), doc);
}

std::unique_ptr<WatchTargetChange> MakeTargetChange(
    WatchTargetChangeState state, std::vector<TargetId> target_ids) {
  return absl::make_unique<WatchTargetChange>(state, std::move(target_ids));
}

std::unique_ptr<WatchTargetChange> MakeTargetChange(
    WatchTargetChangeState state,
    std::vector<TargetId> target_ids,
    ByteString token) {
  return absl::make_unique<WatchTargetChange>(state, std::move(target_ids),
                                              std::move(token));
}

}  // namespace

class RemoteEventTest : public testing::Test {
 protected:
  void SetUp() override {
    resume_token1_ = testutil::ResumeToken(7);
  }

  WatchChangeAggregator CreateAggregator(
      const std::unordered_map<TargetId, TargetData>& target_map,
      const std::unordered_map<TargetId, int>& outstanding_responses,
      DocumentKeySet existing_keys,
      const std::vector<std::unique_ptr<WatchChange>>& watch_changes);

  RemoteEvent CreateRemoteEvent(
      int64_t snapshot_version,
      std::unordered_map<TargetId, TargetData> target_map,
      const std::unordered_map<TargetId, int>& outstanding_responses,
      DocumentKeySet existing_keys,
      const std::vector<std::unique_ptr<WatchChange>>& watch_changes);

  void OverrideDefaultDatabaseId(model::DatabaseId database_id) {
    target_metadata_provider_.SetDatabaseId(std::move(database_id));
  }

  ByteString resume_token1_;
  FakeTargetMetadataProvider target_metadata_provider_;
  std::unordered_map<TargetId, int> no_outstanding_responses_;
};

/**
 * Returns a map of fake target data for the provided target IDs. All targets
 * are considered active and query a collection named "coll".
 */
std::unordered_map<TargetId, TargetData> ActiveQueries(
    std::initializer_list<TargetId> target_ids) {
  std::unordered_map<TargetId, TargetData> targets;
  for (TargetId target_id : target_ids) {
    core::Query query = Query("coll");
    targets[target_id] =
        TargetData(query.ToTarget(), target_id, 0, QueryPurpose::Listen);
  }
  return targets;
}

/**
 * Returns a map of fake target data for the provided target IDs. All targets
 * are marked as limbo queries for the document at "coll/limbo".
 */
std::unordered_map<TargetId, TargetData> ActiveLimboQueries(
    std::initializer_list<TargetId> target_ids) {
  std::unordered_map<TargetId, TargetData> targets;
  for (TargetId target_id : target_ids) {
    core::Query query = Query("coll/limbo");
    targets[target_id] = TargetData(query.ToTarget(), target_id, 0,
                                    QueryPurpose::LimboResolution);
  }
  return targets;
}

/**
 * Creates an aggregator initialized with the set of provided `WatchChange`s.
 * Tests can add further changes via `HandleDocumentChange`,
 * `HandleTargetChange` and `HandleExistenceFilterChange`.
 *
 * @param target_map A map of target data for all active targets. The map must
 *     include an entry for every target referenced by any of the watch
 *     changes.
 * @param outstanding_responses The number of outstanding ACKs a target has to
 *     receive before it is considered active, or `no_outstanding_responses_`
 *     if all targets are already active.
 * @param existing_keys The set of documents that are considered synced with the
 *     test targets as part of a previous listen. To modify this set during
 *     test execution, invoke `target_metadata_provider_.SetSyncedKeys()`.
 * @param watch_changes The watch changes to apply before returning the
 *     aggregator. Supported changes are `DocumentWatchChange` and
 *     `WatchTargetChange`.
 */
WatchChangeAggregator RemoteEventTest::CreateAggregator(
    const std::unordered_map<TargetId, TargetData>& target_map,
    const std::unordered_map<TargetId, int>& outstanding_responses,
    DocumentKeySet existing_keys,
    const std::vector<std::unique_ptr<WatchChange>>& watch_changes) {
  WatchChangeAggregator aggregator{&target_metadata_provider_};

  std::vector<TargetId> target_ids;
  for (const auto& kv : target_map) {
    TargetId target_id = kv.first;
    const TargetData& target_data = kv.second;

    target_ids.push_back(target_id);
    target_metadata_provider_.SetSyncedKeys(existing_keys, target_data);
  }

  for (const auto& kv : outstanding_responses) {
    TargetId target_id = kv.first;
    int count = kv.second;
    for (int i = 0; i < count; ++i) {
      aggregator.RecordPendingTargetRequest(target_id);
    }
  }

  for (const std::unique_ptr<WatchChange>& change : watch_changes) {
    switch (change->type()) {
      case WatchChange::Type::Document: {
        aggregator.HandleDocumentChange(
            *static_cast<const DocumentWatchChange*>(change.get()));
        break;
      }
      case WatchChange::Type::TargetChange: {
        aggregator.HandleTargetChange(
            *static_cast<const WatchTargetChange*>(change.get()));
        break;
      }
      default:
        HARD_ASSERT("Encountered unexpected type of WatchChange");
    }
  }

  aggregator.HandleTargetChange(WatchTargetChange{
      WatchTargetChangeState::NoChange, target_ids, resume_token1_});

  return aggregator;
}

/**
 * Creates a single remote event that includes target changes for all provided
 * `WatchChange`s.
 *
 * @param snapshot_version The version at which to create the remote event.
 *     This corresponds to the snapshot version provided by the NO_CHANGE
 *     event.
 * @param target_map A map of target data for all active targets. The map must
 *     include an entry for every target referenced by any of the watch
 *     changes.
 * @param outstanding_responses The number of outstanding ACKs a target has to
 *     receive before it is considered active, or `no_outstanding_responses_`
 *     if all targets are already active.
 * @param existing_keys The set of documents that are considered synced with
 *     the test targets as part of a previous listen.
 * @param watch_changes The watch changes to apply before creating the remote
 *     event. Supported changes are `DocumentWatchChange` and
 *     `WatchTargetChange`.
 */
RemoteEvent RemoteEventTest::CreateRemoteEvent(
    int64_t snapshot_version,
    std::unordered_map<TargetId, TargetData> target_map,
    const std::unordered_map<TargetId, int>& outstanding_responses,
    DocumentKeySet existing_keys,
    const std::vector<std::unique_ptr<WatchChange>>& watch_changes) {
  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, outstanding_responses, existing_keys, watch_changes);
  return aggregator.CreateRemoteEvent(testutil::Version(snapshot_version));
}

TEST_F(RemoteEventTest, WillAccumulateDocumentAddedAndRemovedEvents) {
  // The target map that contains an entry for every target in this test. If a
  // target ID is omitted, the target is considered inactive and
  // `TestTargetMetadataProvider` will fail on access.
  std::unordered_map<TargetId, TargetData> target_map =
      ActiveQueries({1, 2, 3, 4, 5, 6});

  MutableDocument existing_doc = Doc("docs/1", 1, Map("value", 1));
  auto change1 =
      MakeDocChange({1, 2, 3}, {4, 5, 6}, existing_doc.key(), existing_doc);

  MutableDocument new_doc = Doc("docs/2", 2, Map("value", 2));
  auto change2 = MakeDocChange({1, 4}, {2, 6}, new_doc.key(), new_doc);

  // Create a remote event that includes both `change1` and `change2` as well as
  // a NO_CHANGE event with the default resume token (`resume_token1_`). As
  // `existing_doc` is provided as an existing key, any updates to this document
  // will be treated as modifications rather than adds.
  RemoteEvent event =
      CreateRemoteEvent(3, target_map, no_outstanding_responses_,
                        DocumentKeySet{existing_doc.key()},
                        Changes(std::move(change1), std::move(change2)));
  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 2);
  ASSERT_EQ(event.document_updates().at(existing_doc.key()), existing_doc);
  ASSERT_EQ(event.document_updates().at(new_doc.key()), new_doc);

  // 'change1' and 'change2' affect six different targets
  ASSERT_EQ(event.target_changes().size(), 6);

  TargetChange target_change1{
      resume_token1_, false, DocumentKeySet{new_doc.key()},
      DocumentKeySet{existing_doc.key()}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);

  TargetChange target_change2{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{existing_doc.key()},
                              DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(2) == target_change2);

  TargetChange target_change3{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{existing_doc.key()},
                              DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(3) == target_change3);

  TargetChange target_change4{resume_token1_, false,
                              DocumentKeySet{new_doc.key()}, DocumentKeySet{},
                              DocumentKeySet{existing_doc.key()}};
  ASSERT_TRUE(event.target_changes().at(4) == target_change4);

  TargetChange target_change5{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{},
                              DocumentKeySet{existing_doc.key()}};
  ASSERT_TRUE(event.target_changes().at(5) == target_change5);

  TargetChange target_change6{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{},
                              DocumentKeySet{existing_doc.key()}};
  ASSERT_TRUE(event.target_changes().at(6) == target_change6);
}

TEST_F(RemoteEventTest, WillIgnoreEventsForPendingTargets) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1}, {}, doc1.key(), doc1);
  auto change2 = MakeTargetChange(WatchTargetChangeState::Removed, {1});
  auto change3 = MakeTargetChange(WatchTargetChangeState::Added, {1});
  MutableDocument doc2 = Doc("docs/2", 2, Map("value", 2));
  auto change4 = MakeDocChange({1}, {}, doc2.key(), doc2);

  // We're waiting for the unwatch and watch ack
  std::unordered_map<TargetId, int> outstanding_responses{{1, 2}};

  RemoteEvent event =
      CreateRemoteEvent(3, target_map, outstanding_responses, DocumentKeySet{},
                        Changes(std::move(change1), std::move(change2),
                                std::move(change3), std::move(change4)));
  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  // doc1 is ignored because it was part of an inactive target, but doc2 is in
  // the changes because it become active.
  ASSERT_EQ(event.document_updates().size(), 1);
  ASSERT_EQ(event.document_updates().at(doc2.key()), doc2);

  ASSERT_EQ(event.target_changes().size(), 1);
}

TEST_F(RemoteEventTest, WillIgnoreEventsForRemovedTargets) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({});

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1}, {}, doc1.key(), doc1);
  auto change2 = MakeTargetChange(WatchTargetChangeState::Removed, {1});

  // We're waiting for the unwatch ack
  std::unordered_map<TargetId, int> outstanding_responses{{1, 1}};

  RemoteEvent event =
      CreateRemoteEvent(3, target_map, outstanding_responses, DocumentKeySet{},
                        Changes(std::move(change1), std::move(change2)));
  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  // doc1 is ignored because it was part of an inactive target
  ASSERT_EQ(event.document_updates().size(), 0);

  // Target 1 is ignored because it was removed
  ASSERT_EQ(event.target_changes().size(), 0);
}

TEST_F(RemoteEventTest, WillKeepResetMappingEvenWithUpdates) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1}, {}, doc1.key(), doc1);

  // Reset stream, ignoring doc1
  auto change2 = MakeTargetChange(WatchTargetChangeState::Reset, {1});

  // Add doc2, doc3
  MutableDocument doc2 = Doc("docs/2", 2, Map("value", 2));
  auto change3 = MakeDocChange({1}, {}, doc2.key(), doc2);

  MutableDocument doc3 = Doc("docs/3", 3, Map("value", 3));
  auto change4 = MakeDocChange({1}, {}, doc3.key(), doc3);

  // Remove doc2 again, should not show up in reset mapping
  auto change5 = MakeDocChange({}, {1}, doc2.key(), doc2);

  RemoteEvent event = CreateRemoteEvent(
      3, target_map, no_outstanding_responses_, DocumentKeySet{doc1.key()},
      Changes(std::move(change1), std::move(change2), std::move(change3),
              std::move(change4), std::move(change5)));
  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 3);
  ASSERT_EQ(event.document_updates().at(doc1.key()), doc1);
  ASSERT_EQ(event.document_updates().at(doc2.key()), doc2);
  ASSERT_EQ(event.document_updates().at(doc3.key()), doc3);

  ASSERT_EQ(event.target_changes().size(), 1);

  // Only doc3 is part of the new mapping
  TargetChange expected_change{resume_token1_, false,
                               DocumentKeySet{doc3.key()}, DocumentKeySet{},
                               DocumentKeySet{doc1.key()}};
  ASSERT_TRUE(event.target_changes().at(1) == expected_change);
}

TEST_F(RemoteEventTest, WillHandleSingleReset) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});

  // Reset target
  WatchTargetChange change{WatchTargetChangeState::Reset, {1}};

  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, no_outstanding_responses_, DocumentKeySet{}, {});
  aggregator.HandleTargetChange(change);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 0);
  ASSERT_EQ(event.target_changes().size(), 1);

  // Reset mapping is empty
  TargetChange expected_change{ByteString(), false, DocumentKeySet{},
                               DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == expected_change);
}

TEST_F(RemoteEventTest, WillHandleTargetAddAndRemovalInSameBatch) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1, 2});

  MutableDocument doc1a = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1}, {2}, doc1a.key(), doc1a);

  MutableDocument doc1b = Doc("docs/1", 1, Map("value", 2));
  auto change2 = MakeDocChange({2}, {1}, doc1b.key(), doc1b);

  RemoteEvent event = CreateRemoteEvent(
      3, target_map, no_outstanding_responses_, DocumentKeySet{doc1a.key()},
      Changes(std::move(change1), std::move(change2)));
  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 1);
  ASSERT_EQ(event.document_updates().at(doc1b.key()), doc1b);

  ASSERT_EQ(event.target_changes().size(), 2);

  TargetChange target_change1{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{doc1b.key()}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);

  TargetChange target_change2{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{doc1b.key()}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(2) == target_change2);
}

TEST_F(RemoteEventTest, TargetCurrentChangeWillMarkTheTargetCurrent) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});

  auto change =
      MakeTargetChange(WatchTargetChangeState::Current, {1}, resume_token1_);

  RemoteEvent event =
      CreateRemoteEvent(3, target_map, no_outstanding_responses_,
                        DocumentKeySet{}, Changes(std::move(change)));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 0);
  ASSERT_EQ(event.target_changes().size(), 1);

  TargetChange target_change1{resume_token1_, true, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);
}

TEST_F(RemoteEventTest, TargetAddedChangeWillResetPreviousState) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1, 3});

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1, 3}, {2}, doc1.key(), doc1);
  auto change2 = MakeTargetChange(WatchTargetChangeState::Current, {1, 2, 3},
                                  resume_token1_);
  auto change3 = MakeTargetChange(WatchTargetChangeState::Removed, {1});
  auto change4 = MakeTargetChange(WatchTargetChangeState::Removed, {2});
  auto change5 = MakeTargetChange(WatchTargetChangeState::Added, {1});
  MutableDocument doc2 = Doc("docs/2", 2, Map("value", 2));
  auto change6 = MakeDocChange({1}, {3}, doc2.key(), doc2);

  std::unordered_map<TargetId, int> outstanding_responses{{1, 2}, {2, 1}};

  RemoteEvent event = CreateRemoteEvent(
      3, target_map, outstanding_responses, DocumentKeySet{doc2.key()},
      Changes(std::move(change1), std::move(change2), std::move(change3),
              std::move(change4), std::move(change5), std::move(change6)));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 2);
  ASSERT_EQ(event.document_updates().at(doc1.key()), doc1);
  ASSERT_EQ(event.document_updates().at(doc2.key()), doc2);

  // target 1 and 3 are affected (1 because of re-add), target 2 is not because
  // of remove
  ASSERT_EQ(event.target_changes().size(), 2);

  // doc1 was before the remove, so it does not show up in the mapping.
  // Current was before the remove.
  TargetChange target_change1{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{doc2.key()}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);

  // Doc1 was before the remove
  // Current was before the remove
  TargetChange target_change3{resume_token1_, true, DocumentKeySet{doc1.key()},
                              DocumentKeySet{}, DocumentKeySet{doc2.key()}};
  ASSERT_TRUE(event.target_changes().at(3) == target_change3);
}

TEST_F(RemoteEventTest, NoChangeWillStillMarkTheAffectedTargets) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});

  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, no_outstanding_responses_, DocumentKeySet{}, {});

  WatchTargetChange change{
      WatchTargetChangeState::NoChange, {1}, resume_token1_};
  aggregator.HandleTargetChange(change);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 0);
  ASSERT_EQ(event.target_changes().size(), 1);

  TargetChange target_change{resume_token1_, false, DocumentKeySet{},
                             DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change);
}

TEST_F(RemoteEventTest, ExistenceFilterMismatchClearsTarget) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1, 2});

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1}, {}, doc1.key(), doc1);
  MutableDocument doc2 = Doc("docs/2", 2, Map("value", 2));
  auto change2 = MakeDocChange({1}, {}, doc2.key(), doc2);
  auto change3 =
      MakeTargetChange(WatchTargetChangeState::Current, {1}, resume_token1_);

  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, no_outstanding_responses_,
      DocumentKeySet{doc1.key(), doc2.key()},
      Changes(std::move(change1), std::move(change2), std::move(change3)));

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 2);
  ASSERT_EQ(event.document_updates().at(doc1.key()), doc1);
  ASSERT_EQ(event.document_updates().at(doc2.key()), doc2);

  ASSERT_EQ(event.target_changes().size(), 2);

  TargetChange target_change1{resume_token1_, true, DocumentKeySet{},
                              DocumentKeySet{doc1.key(), doc2.key()},
                              DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);

  TargetChange target_change2{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(2) == target_change2);

  // The existence filter mismatch will remove the document from target 1,
  // but not synthesize a document delete.
  ExistenceFilterWatchChange change4{
      ExistenceFilter{1, /*bloom_filter=*/absl::nullopt}, 1};
  aggregator.HandleExistenceFilter(change4);

  event = aggregator.CreateRemoteEvent(testutil::Version(4));

  TargetChange target_change3{ByteString(), false, DocumentKeySet{},
                              DocumentKeySet{},
                              DocumentKeySet{doc1.key(), doc2.key()}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change3);

  ASSERT_EQ(event.target_changes().size(), 1);
  ASSERT_EQ(event.target_mismatches().size(), 1);
  ASSERT_EQ(event.document_updates().size(), 0);
}

TEST_F(RemoteEventTest, ExistenceFilterMismatchWithBloomFilterSuccess) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1, 2});

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1}, {}, doc1.key(), doc1);
  MutableDocument doc2 = Doc("docs/2", 2, Map("value", 2));
  auto change2 = MakeDocChange({1}, {}, doc2.key(), doc2);
  auto change3 =
      MakeTargetChange(WatchTargetChangeState::Current, {1}, resume_token1_);

  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, no_outstanding_responses_,
      DocumentKeySet{doc1.key(), doc2.key()},
      Changes(std::move(change1), std::move(change2), std::move(change3)));

  // The BloomFilterParameters value below is created based on the document
  // paths that are constructed using the following pattern:
  // "projects/test-project/databases/test-database/documents/"+document_key.
  // Override the database ID to ensure that the document path matches the
  // pattern above.
  OverrideDefaultDatabaseId(model::DatabaseId("test-project", "test-database"));

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 2);
  ASSERT_EQ(event.document_updates().at(doc1.key()), doc1);
  ASSERT_EQ(event.document_updates().at(doc2.key()), doc2);

  ASSERT_EQ(event.target_changes().size(), 2);

  TargetChange target_change1{resume_token1_, true, DocumentKeySet{},
                              DocumentKeySet{doc1.key(), doc2.key()},
                              DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);

  TargetChange target_change2{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(2) == target_change2);

  // The given BloomFilter will return false on MightContain(doc1) and true on
  // MightContain(doc2).
  ExistenceFilterWatchChange change4{
      ExistenceFilter{1, BloomFilterParameters{{0x0E, 0x0F}, 1, 7}}, 1};
  // The existence filter identifies that doc1 is deleted, and skips the full
  // re-query.
  aggregator.HandleExistenceFilter(change4);

  event = aggregator.CreateRemoteEvent(testutil::Version(4));

  ASSERT_EQ(event.target_changes().size(), 1);
  ASSERT_EQ(event.target_mismatches().size(), 0);
  ASSERT_EQ(event.document_updates().size(), 0);
}

TEST_F(RemoteEventTest,
       ExistenceFilterMismatchWithBloomFilterFalsePositiveResult) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1, 2});

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1}, {}, doc1.key(), doc1);
  MutableDocument doc2 = Doc("docs/2", 2, Map("value", 2));
  auto change2 = MakeDocChange({1}, {}, doc2.key(), doc2);
  auto change3 =
      MakeTargetChange(WatchTargetChangeState::Current, {1}, resume_token1_);

  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, no_outstanding_responses_,
      DocumentKeySet{doc1.key(), doc2.key()},
      Changes(std::move(change1), std::move(change2), std::move(change3)));

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 2);
  ASSERT_EQ(event.document_updates().at(doc1.key()), doc1);
  ASSERT_EQ(event.document_updates().at(doc2.key()), doc2);

  ASSERT_EQ(event.target_changes().size(), 2);

  TargetChange target_change1{resume_token1_, true, DocumentKeySet{},
                              DocumentKeySet{doc1.key(), doc2.key()},
                              DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);

  TargetChange target_change2{resume_token1_, false, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(2) == target_change2);

  // The given BloomFilter will return true on both MightContain(doc1) and
  // MightContain(doc2).
  ExistenceFilterWatchChange change4{
      ExistenceFilter{1, BloomFilterParameters{{0x42, 0xFE}, 2, 7}}, 1};
  // The existence filter cannot identify which doc is deleted. It will remove
  // the document from target 1, but not synthesize a document delete.
  aggregator.HandleExistenceFilter(change4);

  event = aggregator.CreateRemoteEvent(testutil::Version(4));

  TargetChange target_change3{ByteString(), false, DocumentKeySet{},
                              DocumentKeySet{},
                              DocumentKeySet{doc1.key(), doc2.key()}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change3);

  ASSERT_EQ(event.target_changes().size(), 1);
  ASSERT_EQ(event.target_mismatches().size(), 1);
  ASSERT_EQ(event.document_updates().size(), 0);
}

TEST_F(RemoteEventTest, ExistenceFilterMismatchRemovesCurrentChanges) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});

  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, no_outstanding_responses_, DocumentKeySet{}, {});

  WatchTargetChange mark_current{
      WatchTargetChangeState::Current, {1}, resume_token1_};
  aggregator.HandleTargetChange(mark_current);

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  DocumentWatchChange add_doc{{1}, {}, doc1.key(), doc1};
  aggregator.HandleDocumentChange(add_doc);

  // The existence filter mismatch will remove the document from target 1, but
  // not synthesize a document delete.
  ExistenceFilterWatchChange existence_filter{
      ExistenceFilter{0, /*bloom_filter=*/absl::nullopt}, 1};
  aggregator.HandleExistenceFilter(existence_filter);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 1);
  ASSERT_EQ(event.target_mismatches().size(), 1);
  ASSERT_EQ(event.document_updates().at(doc1.key()), doc1);

  ASSERT_EQ(event.target_changes().size(), 1);

  TargetChange target_change1{ByteString(), false, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);
}

TEST_F(RemoteEventTest, DocumentUpdate) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});

  MutableDocument doc1 = Doc("docs/1", 1, Map("value", 1));
  auto change1 = MakeDocChange({1}, {}, doc1.key(), doc1);
  MutableDocument doc2 = Doc("docs/2", 2, Map("value", 2));
  auto change2 = MakeDocChange({1}, {}, doc2.key(), doc2);

  WatchChangeAggregator aggregator =
      CreateAggregator(target_map, no_outstanding_responses_, DocumentKeySet{},
                       Changes(std::move(change1), std::move(change2)));

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 2);
  ASSERT_EQ(event.document_updates().at(doc1.key()), doc1);
  ASSERT_EQ(event.document_updates().at(doc2.key()), doc2);

  target_metadata_provider_.SetSyncedKeys(
      DocumentKeySet{doc1.key(), doc2.key()}, target_map[1]);

  MutableDocument deleted_doc1 = DeletedDoc(doc1.key(), 3);
  DocumentWatchChange change3{{}, {1}, deleted_doc1.key(), deleted_doc1};
  aggregator.HandleDocumentChange(change3);

  MutableDocument updated_doc2 = Doc("docs/2", 3, Map("value", 2));
  DocumentWatchChange change4{{1}, {}, updated_doc2.key(), updated_doc2};
  aggregator.HandleDocumentChange(change4);

  MutableDocument doc3 = Doc("docs/3", 3, Map("value", 3));
  DocumentWatchChange change5{{1}, {}, doc3.key(), doc3};
  aggregator.HandleDocumentChange(change5);

  event = aggregator.CreateRemoteEvent(testutil::Version(3));

  ASSERT_EQ(event.snapshot_version(), testutil::Version(3));
  ASSERT_EQ(event.document_updates().size(), 3);
  // doc1 is replaced
  ASSERT_EQ(event.document_updates().at(doc1.key()), deleted_doc1);
  // doc2 is updated
  ASSERT_EQ(event.document_updates().at(doc2.key()), updated_doc2);
  // doc3 is new
  ASSERT_EQ(event.document_updates().at(doc3.key()), doc3);

  // Target is unchanged
  ASSERT_EQ(event.target_changes().size(), 1);

  TargetChange target_change1{resume_token1_, false, DocumentKeySet{doc3.key()},
                              DocumentKeySet{updated_doc2.key()},
                              DocumentKeySet{deleted_doc1.key()}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);
}

TEST_F(RemoteEventTest, ResumeTokensHandledPerTarget) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1, 2});

  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, no_outstanding_responses_, DocumentKeySet{}, {});

  WatchTargetChange change1{
      WatchTargetChangeState::Current, {1}, resume_token1_};
  aggregator.HandleTargetChange(change1);

  ByteString resume_token2 = testutil::ResumeToken(7);
  WatchTargetChange change2{
      WatchTargetChangeState::Current, {2}, resume_token2};
  aggregator.HandleTargetChange(change2);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));
  ASSERT_EQ(event.target_changes().size(), 2);

  TargetChange target_change1{resume_token1_, true, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);

  TargetChange target_change2{resume_token2, true, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(2) == target_change2);
}

TEST_F(RemoteEventTest, LastResumeTokenWins) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1, 2});

  WatchChangeAggregator aggregator = CreateAggregator(
      target_map, no_outstanding_responses_, DocumentKeySet{}, {});

  WatchTargetChange change1{
      WatchTargetChangeState::Current, {1}, resume_token1_};
  aggregator.HandleTargetChange(change1);

  ByteString resume_token2 = testutil::ResumeToken(2);
  WatchTargetChange change2{
      WatchTargetChangeState::NoChange, {1}, resume_token2};
  aggregator.HandleTargetChange(change2);

  ByteString resume_token3 = testutil::ResumeToken(3);
  WatchTargetChange change3{
      WatchTargetChangeState::NoChange, {2}, resume_token3};
  aggregator.HandleTargetChange(change3);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));
  ASSERT_EQ(event.target_changes().size(), 2);

  TargetChange target_change1{resume_token2, true, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(1) == target_change1);

  TargetChange target_change2{resume_token3, false, DocumentKeySet{},
                              DocumentKeySet{}, DocumentKeySet{}};
  ASSERT_TRUE(event.target_changes().at(2) == target_change2);
}

TEST_F(RemoteEventTest, SynthesizeDeletes) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveLimboQueries({1});
  DocumentKey limbo_key = testutil::Key("coll/limbo");

  auto resolve_limbo_target =
      MakeTargetChange(WatchTargetChangeState::Current, {1});
  RemoteEvent event = CreateRemoteEvent(
      3, target_map, no_outstanding_responses_, DocumentKeySet{},
      Changes(std::move(resolve_limbo_target)));

  MutableDocument expected =
      MutableDocument::NoDocument(limbo_key, event.snapshot_version());
  ASSERT_EQ(event.document_updates().at(limbo_key), expected);
  ASSERT_TRUE(event.limbo_document_changes().contains(limbo_key));
}

TEST_F(RemoteEventTest, DoesntSynthesizeDeletesForWrongState) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});

  auto wrong_state = MakeTargetChange(WatchTargetChangeState::NoChange, {1});

  RemoteEvent event =
      CreateRemoteEvent(3, target_map, no_outstanding_responses_,
                        DocumentKeySet{}, Changes(std::move(wrong_state)));

  ASSERT_EQ(event.document_updates().size(), 0);
  ASSERT_EQ(event.limbo_document_changes().size(), 0);
}

TEST_F(RemoteEventTest, DoesntSynthesizeDeletesForExistingDoc) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({3});

  auto has_document = MakeTargetChange(WatchTargetChangeState::Current, {3});

  RemoteEvent event = CreateRemoteEvent(
      3, target_map, no_outstanding_responses_,
      DocumentKeySet{Key("coll/limbo")}, Changes(std::move(has_document)));

  ASSERT_EQ(event.document_updates().size(), 0);
  ASSERT_EQ(event.limbo_document_changes().size(), 0);
}

TEST_F(RemoteEventTest, SeparatesDocumentUpdates) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveLimboQueries({1});

  MutableDocument new_doc = Doc("docs/new", 1, Map("key", "value"));
  auto new_doc_change = MakeDocChange({1}, {}, new_doc.key(), new_doc);

  MutableDocument existing_doc = Doc("docs/existing", 1, Map("some", "data"));
  auto existing_doc_change =
      MakeDocChange({1}, {}, existing_doc.key(), existing_doc);

  MutableDocument deleted_doc = DeletedDoc("docs/deleted", 1);
  auto deleted_doc_change =
      MakeDocChange({}, {1}, deleted_doc.key(), deleted_doc);

  MutableDocument missing_doc = DeletedDoc("docs/missing", 1);
  auto missing_doc_change =
      MakeDocChange({}, {1}, missing_doc.key(), missing_doc);

  RemoteEvent event = CreateRemoteEvent(
      3, target_map, no_outstanding_responses_,
      DocumentKeySet{existing_doc.key(), deleted_doc.key()},
      Changes(std::move(new_doc_change), std::move(existing_doc_change),
              std::move(deleted_doc_change), std::move(missing_doc_change)));

  TargetChange target_change2{
      resume_token1_, false, DocumentKeySet{new_doc.key()},
      DocumentKeySet{existing_doc.key()}, DocumentKeySet{deleted_doc.key()}};

  ASSERT_TRUE(event.target_changes().at(1) == target_change2);
}

TEST_F(RemoteEventTest, TracksLimboDocuments) {
  std::unordered_map<TargetId, TargetData> target_map = ActiveQueries({1});
  auto additional_targets = ActiveLimboQueries({2});
  target_map.insert(additional_targets.begin(), additional_targets.end());

  // Add 3 docs: 1 is limbo and non-limbo, 2 is limbo-only, 3 is non-limbo
  MutableDocument doc1 = Doc("docs/1", 1, Map("key", "value"));
  MutableDocument doc2 = Doc("docs/2", 1, Map("key", "value"));
  MutableDocument doc3 = Doc("docs/3", 1, Map("key", "value"));

  // Target 2 is a limbo target
  auto doc_change1 = MakeDocChange({1, 2}, {}, doc1.key(), doc1);
  auto doc_change2 = MakeDocChange({2}, {}, doc2.key(), doc2);
  auto doc_change3 = MakeDocChange({1}, {}, doc3.key(), doc3);
  auto targets_change =
      MakeTargetChange(WatchTargetChangeState::Current, {1, 2});

  RemoteEvent event = CreateRemoteEvent(
      3, target_map, no_outstanding_responses_, DocumentKeySet{},
      Changes(std::move(doc_change1), std::move(doc_change2),
              std::move(doc_change3), std::move(targets_change)));

  DocumentKeySet limbo_doc_changes = event.limbo_document_changes();
  // Doc1 is in both limbo and non-limbo targets, therefore not tracked as limbo
  ASSERT_FALSE(limbo_doc_changes.contains(doc1.key()));
  // Doc2 is only in the limbo target, so is tracked as a limbo document
  ASSERT_TRUE(limbo_doc_changes.contains(doc2.key()));
  // Doc3 is only in the non-limbo target, therefore not tracked as limbo
  ASSERT_FALSE(limbo_doc_changes.contains(doc3.key()));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
