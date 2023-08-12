/*
 * Copyright 2019 Google
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

#include "Firestore/core/test/unit/local/local_store_test.h"

#include <thread>  // NOLINT(build/c++11)
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/bundle/bundle_metadata.h"
#include "Firestore/core/src/bundle/named_query.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/index_backfiller.h"
#include "Firestore/core/src/local/local_view_changes.h"
#include "Firestore/core/src/local/local_write_result.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/query_result.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/model/field_mask.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/field_transform.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/mutation_batch_result.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/transform_operation.h"
#include "Firestore/core/src/remote/existence_filter.h"
#include "Firestore/core/src/remote/remote_event.h"
#include "Firestore/core/src/remote/watch_change.h"
#include "Firestore/core/test/unit/remote/fake_target_metadata_provider.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using bundle::BundleMetadata;
using bundle::NamedQuery;
using credentials::User;
using local::QueryResult;
using model::Document;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::ListenSequenceNumber;
using model::MutableDocument;
using model::MutableDocumentMap;
using model::Mutation;
using model::MutationBatch;
using model::MutationBatchResult;
using model::MutationResult;
using model::NumericIncrementTransform;
using model::ResourcePath;
using model::SnapshotVersion;
using model::TargetId;
using nanopb::ByteString;
using nanopb::Message;
using remote::DocumentWatchChange;
using remote::ExistenceFilter;
using remote::ExistenceFilterWatchChange;
using remote::FakeTargetMetadataProvider;
using remote::RemoteEvent;
using remote::WatchChangeAggregator;
using remote::WatchTargetChange;
using remote::WatchTargetChangeState;
using util::Status;

using testutil::AddedRemoteEvent;
using testutil::Array;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Key;
using testutil::Map;
using testutil::OverlayTypeMap;
using testutil::Query;
using testutil::ServerTimestamp;
using testutil::UnknownDoc;
using testutil::UpdateRemoteEvent;
using testutil::UpdateRemoteEventWithLimboTargets;
using testutil::Value;
using testutil::Vector;

std::vector<Document> DocMapToVector(const DocumentMap& docs) {
  std::vector<Document> result;
  for (const auto& kv : docs) {
    result.push_back(kv.second);
  }
  return result;
}

MutableDocumentMap DocVectorToMap(const std::vector<MutableDocument>& docs) {
  MutableDocumentMap result;
  for (const auto& d : docs) {
    result = result.insert(d.key(), d);
  }
  return result;
}

RemoteEvent NoChangeEvent(int target_id,
                          int version,
                          nanopb::ByteString resume_token) {
  remote::FakeTargetMetadataProvider metadata_provider;

  // Register target data for the target. The query itself is not inspected, so
  // we can listen to any path.
  TargetData target_data(Query("foo").ToTarget(), target_id, 0,
                         QueryPurpose::Listen);
  metadata_provider.SetSyncedKeys(DocumentKeySet{}, target_data);

  WatchChangeAggregator aggregator{&metadata_provider};
  WatchTargetChange watch_change(remote::WatchTargetChangeState::NoChange,
                                 {target_id}, resume_token);
  aggregator.HandleTargetChange(watch_change);
  return aggregator.CreateRemoteEvent(testutil::Version(version));
}

RemoteEvent NoChangeEvent(int target_id, int version) {
  return NoChangeEvent(target_id, version, testutil::ResumeToken(version));
}

/** Creates a remote event that inserts a list of documents. */
RemoteEvent ExistenceFilterEvent(TargetId target_id,
                                 const DocumentKeySet& synced_keys,
                                 int remote_count,
                                 int version) {
  TargetData target_data(Query("foo").ToTarget(), target_id, 0,
                         QueryPurpose::Listen);
  remote::FakeTargetMetadataProvider metadata_provider;
  metadata_provider.SetSyncedKeys(synced_keys, target_data);

  ExistenceFilter existence_filter{remote_count,
                                   /*bloom_filter=*/absl::nullopt};
  WatchChangeAggregator aggregator{&metadata_provider};
  ExistenceFilterWatchChange existence_filter_watch_change{existence_filter,
                                                           target_id};
  aggregator.HandleExistenceFilter(existence_filter_watch_change);
  return aggregator.CreateRemoteEvent(testutil::Version(version));
}

LocalViewChanges TestViewChanges(TargetId target_id,
                                 bool from_cache,
                                 std::vector<std::string> added_keys,
                                 std::vector<std::string> removed_keys) {
  DocumentKeySet added;
  for (const std::string& key_path : added_keys) {
    added = added.insert(Key(key_path));
  }
  DocumentKeySet removed;
  for (const std::string& key_path : removed_keys) {
    removed = removed.insert(Key(key_path));
  }
  return LocalViewChanges(target_id, from_cache, std::move(added),
                          std::move(removed));
}

}  // namespace

LocalStoreTestBase::LocalStoreTestBase(
    std::unique_ptr<LocalStoreTestHelper>&& test_helper)
    : test_helper_(std::move(test_helper)),
      persistence_(test_helper_->MakePersistence()),
      local_store_(
          persistence_.get(), &query_engine_, User::Unauthenticated()) {
  local_store_.Start();
}

void LocalStoreTestBase::WriteMutation(Mutation mutation) {
  WriteMutations({std::move(mutation)});
}

void LocalStoreTestBase::WriteMutations(std::vector<Mutation>&& mutations) {
  auto mutations_copy = mutations;
  LocalWriteResult result =
      local_store_.WriteLocally(std::move(mutations_copy));
  batches_.emplace_back(result.batch_id(), Timestamp::Now(),
                        std::vector<Mutation>{}, std::move(mutations));
  last_changes_ = result.changes();
}

void LocalStoreTestBase::ApplyRemoteEvent(const RemoteEvent& event) {
  last_changes_ = local_store_.ApplyRemoteEvent(event);
}

void LocalStoreTestBase::NotifyLocalViewChanges(LocalViewChanges changes) {
  local_store_.NotifyLocalViewChanges(
      std::vector<LocalViewChanges>{std::move(changes)});
}

void LocalStoreTestBase::BackfillIndexes() {
  local_store_.Backfill();
}

void LocalStoreTestBase::SetBackfillerMaxDocumentsToProcess(size_t new_max) {
  local_store_.index_backfiller()->SetMaxDocumentsToProcess(new_max);
}

void LocalStoreTestBase::UpdateViews(int target_id, bool from_cache) {
  NotifyLocalViewChanges(TestViewChanges(target_id, from_cache, {}, {}));
}

void LocalStoreTestBase::AcknowledgeMutationWithVersion(
    int64_t document_version,
    absl::optional<Message<google_firestore_v1_Value>> transform_result) {
  ASSERT_GT(batches_.size(), 0) << "Missing batch to acknowledge.";
  MutationBatch batch = batches_.front();
  batches_.erase(batches_.begin());

  ASSERT_EQ(batch.mutations().size(), 1)
      << "Acknowledging more than one mutation not supported.";
  SnapshotVersion version = testutil::Version(document_version);

  Message<google_firestore_v1_ArrayValue> mutation_transform_result{};
  if (transform_result) {
    mutation_transform_result = Array(std::move(*transform_result));
  }

  MutationResult mutation_result(version, std::move(mutation_transform_result));
  std::vector<MutationResult> mutation_results;
  mutation_results.emplace_back(std::move(mutation_result));
  MutationBatchResult result(batch, version, std::move(mutation_results), {});
  last_changes_ = local_store_.AcknowledgeBatch(result);
}

void LocalStoreTestBase::RejectMutation() {
  MutationBatch batch = batches_.front();
  batches_.erase(batches_.begin());
  last_changes_ = local_store_.RejectBatch(batch.batch_id());
}

std::vector<model::FieldIndex> LocalStoreTestBase::GetFieldIndexes() {
  return local_store_.GetFieldIndexes();
}

void LocalStoreTestBase::ConfigureFieldIndexes(
    std::vector<model::FieldIndex>&& new_field_indexes) {
  local_store_.ConfigureFieldIndexes(std::move(new_field_indexes));
}

TargetId LocalStoreTestBase::AllocateQuery(core::Query query) {
  TargetData target_data = local_store_.AllocateTarget(query.ToTarget());
  last_target_id_ = target_data.target_id();
  return target_data.target_id();
}

TargetData LocalStoreTestBase::GetTargetData(const core::Query& query) {
  return persistence_->Run("GetTargetData", [&] {
    return *local_store_.GetTargetData(query.ToTarget());
  });
}

QueryResult LocalStoreTestBase::ExecuteQuery(const core::Query& query) {
  ResetPersistenceStats();
  last_query_result_ =
      local_store_.ExecuteQuery(query, /* use_previous_results= */ true);
  return last_query_result_;
}

void LocalStoreTestBase::SetIndexAutoCreationEnabled(bool is_enabled) {
  query_engine_.SetIndexAutoCreationEnabled(is_enabled);
}

void LocalStoreTestBase::DeleteAllIndexes() const {
  local_store_.DeleteAllFieldIndexes();
}

void LocalStoreTestBase::SetMinCollectionSizeToAutoCreateIndex(size_t new_min) {
  query_engine_.SetIndexAutoCreationMinCollectionSize(new_min);
}

void LocalStoreTestBase::SetRelativeIndexReadCostPerDocument(double new_cost) {
  query_engine_.SetRelativeIndexReadCostPerDocument(new_cost);
}

void LocalStoreTestBase::ApplyBundledDocuments(
    const std::vector<MutableDocument>& documents) {
  last_changes_ =
      local_store_.ApplyBundledDocuments(DocVectorToMap(documents), "");
}

void LocalStoreTestBase::ResetPersistenceStats() {
  query_engine_.ResetCounts();
}

LocalStoreTest::LocalStoreTest() : LocalStoreTestBase(GetParam()()) {
}

TEST_P(LocalStoreTest, MutationBatchKeys) {
  Mutation base = testutil::SetMutation("foo/ignore", Map("foo", "bar"));
  Mutation set1 = testutil::SetMutation("foo/bar", Map("foo", "bar"));
  Mutation set2 = testutil::SetMutation("bar/baz", Map("bar", "baz"));
  MutationBatch batch =
      MutationBatch(1, Timestamp::Now(), {base}, {set1, set2});
  DocumentKeySet keys = batch.keys();
  ASSERT_EQ(keys.size(), 2u);
}

TEST_P(LocalStoreTest, HandlesSetMutation) {
  WriteMutation(testutil::SetMutation("foo/bar", Map("foo", "bar")));
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(1);
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("foo", "bar")).SetHasCommittedMutations());
  if (IsGcEager()) {
    // Nothing is pinning this anymore, as it has been acknowledged and there
    // are no targets active.
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(
        Doc("foo/bar", 1, Map("foo", "bar")).SetHasCommittedMutations());
  }
}

TEST_P(LocalStoreTest, HandlesSetMutationThenDocument) {
  WriteMutation(testutil::SetMutation("foo/bar", Map("foo", "bar")));
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());

  TargetId target_id = AllocateQuery(Query("foo"));

  ApplyRemoteEvent(UpdateRemoteEvent(Doc("foo/bar", 2, Map("it", "changed")),
                                     {target_id}, {}));
  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, HandlesAckThenRejectThenRemoteEvent) {
  // Start a query that requires acks to be held.
  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  WriteMutation(testutil::SetMutation("foo/bar", Map("foo", "bar")));
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());

  // The last seen version is zero, so this ack must be held.
  AcknowledgeMutationWithVersion(1);
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("foo", "bar")).SetHasCommittedMutations());

  // Under eager GC, there is no longer a reference for the document, and it
  // should be deleted.
  if (IsGcEager()) {
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(
        Doc("foo/bar", 1, Map("foo", "bar")).SetHasCommittedMutations());
  }

  WriteMutation(testutil::SetMutation("bar/baz", Map("bar", "baz")));
  FSTAssertChanged(Doc("bar/baz", 0, Map("bar", "baz")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("bar/baz", 0, Map("bar", "baz")).SetHasLocalMutations());

  RejectMutation();
  FSTAssertRemoved("bar/baz");
  FSTAssertNotContains("bar/baz");

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/bar", 2, Map("it", "changed")), {target_id}));
  FSTAssertChanged(Doc("foo/bar", 2, Map("it", "changed")));
  FSTAssertContains(Doc("foo/bar", 2, Map("it", "changed")));
  FSTAssertNotContains("bar/baz");
}

TEST_P(LocalStoreTest, HandlesDeletedDocumentThenSetMutationThenAck) {
  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      UpdateRemoteEvent(DeletedDoc("foo/bar", 2), {target_id}, {}));
  FSTAssertRemoved("foo/bar");
  // Under eager GC, there is no longer a reference for the document, and it
  // should be deleted.
  if (!IsGcEager()) {
    FSTAssertContains(DeletedDoc("foo/bar", 2));
  } else {
    FSTAssertNotContains("foo/bar");
  }

  WriteMutation(testutil::SetMutation("foo/bar", Map("foo", "bar")));
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  // Can now remove the target, since we have a mutation pinning the document
  local_store_.ReleaseTarget(target_id);
  // Verify we didn't lose anything
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(3);
  FSTAssertChanged(
      Doc("foo/bar", 3, Map("foo", "bar")).SetHasCommittedMutations());
  // It has been acknowledged, and should no longer be retained as there is no
  // target and mutation
  if (IsGcEager()) {
    FSTAssertNotContains("foo/bar");
  }
}

TEST_P(LocalStoreTest, HandlesSetMutationThenDeletedDocument) {
  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  WriteMutation(testutil::SetMutation("foo/bar", Map("foo", "bar")));
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());

  ApplyRemoteEvent(
      UpdateRemoteEvent(DeletedDoc("foo/bar", 2), {target_id}, {}));
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, HandlesDocumentThenSetMutationThenAckThenDocument) {
  // Start a query that requires acks to be held.
  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/bar", 2, Map("it", "base")), {target_id}));
  FSTAssertChanged(Doc("foo/bar", 2, Map("it", "base")));
  FSTAssertContains(Doc("foo/bar", 2, Map("it", "base")));

  WriteMutation(testutil::SetMutation("foo/bar", Map("foo", "bar")));
  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(3);
  // we haven't seen the remote event yet, so the write is still held.
  FSTAssertChanged(
      Doc("foo/bar", 3, Map("foo", "bar")).SetHasCommittedMutations());
  FSTAssertContains(
      Doc("foo/bar", 3, Map("foo", "bar")).SetHasCommittedMutations());

  ApplyRemoteEvent(UpdateRemoteEvent(Doc("foo/bar", 3, Map("it", "changed")),
                                     {target_id}, {}));
  FSTAssertChanged(Doc("foo/bar", 3, Map("it", "changed")));
  FSTAssertContains(Doc("foo/bar", 3, Map("it", "changed")));
}

TEST_P(LocalStoreTest, HandlesPatchWithoutPriorDocument) {
  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  FSTAssertRemoved("foo/bar");
  FSTAssertNotContains("foo/bar");

  AcknowledgeMutationWithVersion(1);
  FSTAssertChanged(UnknownDoc("foo/bar", 1));
  if (IsGcEager()) {
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(UnknownDoc("foo/bar", 1));
  }
}

TEST_P(LocalStoreTest, HandlesPatchMutationThenDocumentThenAck) {
  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  FSTAssertRemoved("foo/bar");
  FSTAssertNotContains("foo/bar");

  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {target_id}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("foo", "bar", "it", "base"))
                       .SetHasLocalMutations());
  FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar", "it", "base"))
                        .SetHasLocalMutations());

  AcknowledgeMutationWithVersion(2);
  // We still haven't seen the remote events for the patch, so the local changes
  // remain, and there are no changes
  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar", "it", "base"))
                       .SetHasCommittedMutations());
  FSTAssertContains(Doc("foo/bar", 2, Map("foo", "bar", "it", "base"))
                        .SetHasCommittedMutations());

  ApplyRemoteEvent(UpdateRemoteEvent(
      Doc("foo/bar", 2, Map("foo", "bar", "it", "base")), {target_id}, {}));

  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar", "it", "base")));
  FSTAssertContains(Doc("foo/bar", 2, Map("foo", "bar", "it", "base")));
}

TEST_P(LocalStoreTest, HandlesPatchMutationThenAckThenDocument) {
  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  FSTAssertRemoved("foo/bar");
  FSTAssertNotContains("foo/bar");

  AcknowledgeMutationWithVersion(1);
  FSTAssertChanged(UnknownDoc("foo/bar", 1));

  // There's no target pinning the doc, and we've ack'd the mutation.
  if (IsGcEager()) {
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(UnknownDoc("foo/bar", 1));
  }

  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {target_id}, {}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("it", "base")));
  FSTAssertContains(Doc("foo/bar", 1, Map("it", "base")));
}

TEST_P(LocalStoreTest, HandlesDeleteMutationThenAck) {
  WriteMutation(testutil::DeleteMutation("foo/bar"));
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar").SetHasLocalMutations());

  AcknowledgeMutationWithVersion(1);
  FSTAssertRemoved("foo/bar");
  // There's no target pinning the doc, and we've ack'd the mutation.
  if (IsGcEager()) {
    FSTAssertNotContains("foo/bar");
  }
}

TEST_P(LocalStoreTest, HandlesDocumentThenDeleteMutationThenAck) {
  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {target_id}, {}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("it", "base")));
  FSTAssertContains(Doc("foo/bar", 1, Map("it", "base")));

  WriteMutation(testutil::DeleteMutation("foo/bar"));
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar").SetHasLocalMutations());

  // Remove the target so only the mutation is pinning the document
  local_store_.ReleaseTarget(target_id);

  AcknowledgeMutationWithVersion(2);
  FSTAssertRemoved("foo/bar");
  if (IsGcEager()) {
    // Neither the target nor the mutation pin the document, it should be gone.
    FSTAssertNotContains("foo/bar");
  }
}

TEST_P(LocalStoreTest, HandlesDeleteMutationThenDocumentThenAck) {
  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  WriteMutation(testutil::DeleteMutation("foo/bar"));
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar").SetHasLocalMutations());

  // Add the document to a target so it will remain in persistence even when
  // ack'd
  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {target_id}, {}));
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar").SetHasLocalMutations());

  // Don't need to keep it pinned anymore
  local_store_.ReleaseTarget(target_id);

  AcknowledgeMutationWithVersion(2);
  FSTAssertRemoved("foo/bar");
  if (IsGcEager()) {
    // The doc is not pinned in a target and we've acknowledged the mutation. It
    // shouldn't exist anymore.
    FSTAssertNotContains("foo/bar");
  }
}

TEST_P(LocalStoreTest, HandlesDocumentThenDeletedDocumentThenDocument) {
  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {target_id}, {}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("it", "base")));
  FSTAssertContains(Doc("foo/bar", 1, Map("it", "base")));

  ApplyRemoteEvent(
      UpdateRemoteEvent(DeletedDoc("foo/bar", 2), {target_id}, {}));
  FSTAssertRemoved("foo/bar");
  if (!IsGcEager()) {
    FSTAssertContains(DeletedDoc("foo/bar", 2));
  }

  ApplyRemoteEvent(UpdateRemoteEvent(Doc("foo/bar", 3, Map("it", "changed")),
                                     {target_id}, {}));
  FSTAssertChanged(Doc("foo/bar", 3, Map("it", "changed")));
  FSTAssertContains(Doc("foo/bar", 3, Map("it", "changed")));
}

TEST_P(LocalStoreTest,
       HandlesSetMutationThenPatchMutationThenDocumentThenAckThenAck) {
  WriteMutation(testutil::SetMutation("foo/bar", Map("foo", "old")));
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "old")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "old")).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());

  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {target_id}, {}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 1, Map("foo", "bar")).SetHasLocalMutations());

  local_store_.ReleaseTarget(target_id);
  AcknowledgeMutationWithVersion(2);  // delete mutation
  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(3);  // patch mutation
  FSTAssertChanged(
      Doc("foo/bar", 3, Map("foo", "bar")).SetHasCommittedMutations());
  if (IsGcEager()) {
    // we've ack'd all of the mutations, nothing is keeping this pinned anymore
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(
        Doc("foo/bar", 3, Map("foo", "bar")).SetHasCommittedMutations());
  }
}

TEST_P(LocalStoreTest, HandlesSetMutationAndPatchMutationTogether) {
  WriteMutations({testutil::SetMutation("foo/bar", Map("foo", "old")),
                  testutil::PatchMutation("foo/bar", Map("foo", "bar"))});

  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, HandlesSetMutationThenPatchMutationThenReject) {
  if (!IsGcEager()) return;

  WriteMutation(testutil::SetMutation("foo/bar", Map("foo", "old")));
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "old")).SetHasLocalMutations());
  AcknowledgeMutationWithVersion(1);
  FSTAssertNotContains("foo/bar");

  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  // A blind patch is not visible in the cache
  FSTAssertNotContains("foo/bar");

  RejectMutation();
  FSTAssertNotContains("foo/bar");
}

TEST_P(LocalStoreTest, HandlesSetMutationsAndPatchMutationOfJustOneTogether) {
  WriteMutations({testutil::SetMutation("foo/bar", Map("foo", "old")),
                  testutil::SetMutation("bar/baz", Map("bar", "baz")),
                  testutil::PatchMutation("foo/bar", Map("foo", "bar"))});

  FSTAssertChanged(Doc("bar/baz", 0, Map("bar", "baz")).SetHasLocalMutations(),
                   Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("bar/baz", 0, Map("bar", "baz")).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, HandlesDeleteMutationThenPatchMutationThenAckThenAck) {
  WriteMutation(testutil::DeleteMutation("foo/bar"));
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar").SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar").SetHasLocalMutations());

  AcknowledgeMutationWithVersion(2);  // delete mutation
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar", 0).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(3);  // patch mutation
  FSTAssertChanged(UnknownDoc("foo/bar", 3));
  if (IsGcEager()) {
    // There are no more pending mutations, the doc has been dropped
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(UnknownDoc("foo/bar", 3));
  }
}

TEST_P(LocalStoreTest, CollectsGarbageAfterChangeBatchWithNoTargetIDs) {
  if (!IsGcEager()) return;

  ApplyRemoteEvent(
      UpdateRemoteEventWithLimboTargets(DeletedDoc("foo/bar", 2), {}, {}, {1}));
  FSTAssertNotContains("foo/bar");

  ApplyRemoteEvent(UpdateRemoteEventWithLimboTargets(
      Doc("foo/bar", 2, Map("foo", "bar")), {}, {}, {1}));
  FSTAssertNotContains("foo/bar");
}

TEST_P(LocalStoreTest, CollectsGarbageAfterChangeBatch) {
  if (!IsGcEager()) return;

  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/bar", 2, Map("foo", "bar")), {target_id}));
  FSTAssertContains(Doc("foo/bar", 2, Map("foo", "bar")));

  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 2, Map("foo", "baz")), {}, {target_id}));

  FSTAssertNotContains("foo/bar");
}

TEST_P(LocalStoreTest, CollectsGarbageAfterAcknowledgedMutation) {
  if (!IsGcEager()) return;

  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 1, Map("foo", "old")), {target_id}, {}));
  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  // Release the target so that our target count goes back to 0 and we are
  // considered up-to-date.
  local_store_.ReleaseTarget(target_id);

  WriteMutation(testutil::SetMutation("foo/bah", Map("foo", "bah")));
  WriteMutation(testutil::DeleteMutation("foo/baz"));
  FSTAssertContains(
      Doc("foo/bar", 1, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bah", 0, Map("foo", "bah")).SetHasLocalMutations());
  FSTAssertContains(DeletedDoc("foo/baz").SetHasLocalMutations());

  AcknowledgeMutationWithVersion(3);
  FSTAssertNotContains("foo/bar");
  FSTAssertContains(
      Doc("foo/bah", 0, Map("foo", "bah")).SetHasLocalMutations());
  FSTAssertContains(DeletedDoc("foo/baz").SetHasLocalMutations());

  AcknowledgeMutationWithVersion(4);
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/bah");
  FSTAssertContains(DeletedDoc("foo/baz").SetHasLocalMutations());

  AcknowledgeMutationWithVersion(5);
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/bah");
  FSTAssertNotContains("foo/baz");
}

TEST_P(LocalStoreTest, CollectsGarbageAfterRejectedMutation) {
  if (!IsGcEager()) return;

  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 1, Map("foo", "old")), {target_id}, {}));
  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  // Release the target so that our target count goes back to 0 and we are
  // considered up-to-date.
  local_store_.ReleaseTarget(target_id);

  WriteMutation(testutil::SetMutation("foo/bah", Map("foo", "bah")));
  WriteMutation(testutil::DeleteMutation("foo/baz"));
  FSTAssertContains(
      Doc("foo/bar", 1, Map("foo", "bar")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bah", 0, Map("foo", "bah")).SetHasLocalMutations());
  FSTAssertContains(DeletedDoc("foo/baz").SetHasLocalMutations());

  RejectMutation();  // patch mutation
  FSTAssertNotContains("foo/bar");
  FSTAssertContains(
      Doc("foo/bah", 0, Map("foo", "bah")).SetHasLocalMutations());
  FSTAssertContains(DeletedDoc("foo/baz").SetHasLocalMutations());

  RejectMutation();  // set mutation
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/bah");
  FSTAssertContains(DeletedDoc("foo/baz").SetHasLocalMutations());

  RejectMutation();  // delete mutation
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/bah");
  FSTAssertNotContains("foo/baz");
}

TEST_P(LocalStoreTest, PinsDocumentsInTheLocalView) {
  if (!IsGcEager()) return;

  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/bar", 1, Map("foo", "bar")), {target_id}));
  WriteMutation(testutil::SetMutation("foo/baz", Map("foo", "baz")));
  FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar")));
  FSTAssertContains(
      Doc("foo/baz", 0, Map("foo", "baz")).SetHasLocalMutations());

  NotifyLocalViewChanges(TestViewChanges(target_id, /* from_cache= */ false,
                                         {"foo/bar", "foo/baz"}, {}));
  FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar")));
  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 1, Map("foo", "bar")), {}, {target_id}));
  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/baz", 2, Map("foo", "baz")), {target_id}, {}));
  FSTAssertContains(
      Doc("foo/baz", 2, Map("foo", "baz")).SetHasLocalMutations());
  AcknowledgeMutationWithVersion(2);
  FSTAssertContains(Doc("foo/baz", 2, Map("foo", "baz")));
  FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar")));
  FSTAssertContains(Doc("foo/baz", 2, Map("foo", "baz")));

  NotifyLocalViewChanges(TestViewChanges(target_id, /* from_cache= */ false, {},
                                         {"foo/bar", "foo/baz"}));
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/baz");

  local_store_.ReleaseTarget(target_id);
}

TEST_P(LocalStoreTest, ThrowsAwayDocumentsWithUnknownTargetIDsImmediately) {
  if (!IsGcEager()) return;

  TargetId target_id = 321;
  ApplyRemoteEvent(UpdateRemoteEventWithLimboTargets(Doc("foo/bar", 1, Map()),
                                                     {}, {}, {target_id}));

  FSTAssertNotContains("foo/bar");
}

TEST_P(LocalStoreTest, CanExecuteDocumentQueries) {
  local_store_.WriteLocally(
      {testutil::SetMutation("foo/bar", Map("foo", "bar")),
       testutil::SetMutation("foo/baz", Map("foo", "baz")),
       testutil::SetMutation("foo/bar/Foo/Bar", Map("Foo", "Bar"))});
  core::Query query = Query("foo/bar");
  QueryResult query_result = ExecuteQuery(query);
  ASSERT_EQ(DocMapToVector(query_result.documents()),
            Vector(Document{
                Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations()}));
}

TEST_P(LocalStoreTest, CanExecuteCollectionQueries) {
  local_store_.WriteLocally(
      {testutil::SetMutation("fo/bar", Map("fo", "bar")),
       testutil::SetMutation("foo/bar", Map("foo", "bar")),
       testutil::SetMutation("foo/baz", Map("foo", "baz")),
       testutil::SetMutation("foo/bar/Foo/Bar", Map("Foo", "Bar")),
       testutil::SetMutation("fooo/blah", Map("fooo", "blah"))});
  core::Query query = Query("foo");
  QueryResult query_result = ExecuteQuery(query);
  ASSERT_EQ(
      DocMapToVector(query_result.documents()),
      Vector(
          Document{Doc("foo/bar", 0, Map("foo", "bar")).SetHasLocalMutations()},
          Document{
              Doc("foo/baz", 0, Map("foo", "baz")).SetHasLocalMutations()}));
}

TEST_P(LocalStoreTest, CanExecuteMixedCollectionQueries) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/baz", 10, Map("a", "b")), {2}, {}));
  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 20, Map("a", "b")), {2}, {}));

  local_store_.WriteLocally({testutil::SetMutation("foo/bonk", Map("a", "b"))});

  QueryResult query_result = ExecuteQuery(query);
  ASSERT_EQ(
      DocMapToVector(query_result.documents()),
      Vector(
          Document{Doc("foo/bar", 20, Map("a", "b"))},
          Document{Doc("foo/baz", 10, Map("a", "b"))},
          Document{Doc("foo/bonk", 0, Map("a", "b")).SetHasLocalMutations()}));
}

TEST_P(LocalStoreTest, ReadsAllDocumentsForInitialCollectionQueries) {
  core::Query query = Query("foo");
  local_store_.AllocateTarget(query.ToTarget());

  ApplyRemoteEvent(UpdateRemoteEvent(Doc("foo/baz", 10, Map()), {2}, {}));
  ApplyRemoteEvent(UpdateRemoteEvent(Doc("foo/bar", 20, Map()), {2}, {}));
  WriteMutation(testutil::SetMutation("foo/bonk", Map()));

  ResetPersistenceStats();

  ExecuteQuery(query);

  FSTAssertRemoteDocumentsRead(/* by_key= */ 0, /* by_query= */ 2);
  FSTAssertOverlaysRead(/* by_key= */ 0, /* by_query= */ 1);
  FSTAssertOverlayTypes(
      OverlayTypeMap({{Key("foo/bonk"), model::Mutation::Type::Set}}));
}

TEST_P(LocalStoreTest, PersistsResumeTokens) {
  // This test only works in the absence of the FSTEagerGarbageCollector.
  if (IsGcEager()) return;

  core::Query query = Query("foo/bar");
  TargetData target_data = local_store_.AllocateTarget(query.ToTarget());
  ListenSequenceNumber initial_sequence_number = target_data.sequence_number();
  TargetId target_id = target_data.target_id();
  ByteString resume_token = testutil::ResumeToken(1000);

  WatchTargetChange watch_change{
      WatchTargetChangeState::Current, {target_id}, resume_token};
  auto metadata_provider =
      FakeTargetMetadataProvider::CreateSingleResultProvider(
          testutil::Key("foo/bar"), std::vector<TargetId>{target_id});
  WatchChangeAggregator aggregator{&metadata_provider};
  aggregator.HandleTargetChange(watch_change);
  RemoteEvent remote_event =
      aggregator.CreateRemoteEvent(testutil::Version(1000));
  ApplyRemoteEvent(remote_event);

  // Stop listening so that the query should become inactive (but persistent)
  local_store_.ReleaseTarget(target_id);

  // Should come back with the same resume token
  TargetData target_data2 = local_store_.AllocateTarget(query.ToTarget());
  ASSERT_EQ(target_data2.resume_token(), resume_token);

  // The sequence number should have been bumped when we saved the new resume
  // token.
  ListenSequenceNumber new_sequence_number = target_data2.sequence_number();
  ASSERT_GT(new_sequence_number, initial_sequence_number);
}

TEST_P(LocalStoreTest, RemoteDocumentKeysForTarget) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  ApplyRemoteEvent(AddedRemoteEvent(Doc("foo/baz", 10, Map("a", "b")), {2}));
  ApplyRemoteEvent(AddedRemoteEvent(Doc("foo/bar", 20, Map("a", "b")), {2}));

  local_store_.WriteLocally({testutil::SetMutation("foo/bonk", Map("a", "b"))});

  DocumentKeySet keys = local_store_.GetRemoteDocumentKeys(2);
  DocumentKeySet expected{testutil::Key("foo/bar"), testutil::Key("foo/baz")};
  ASSERT_EQ(keys, expected);

  keys = local_store_.GetRemoteDocumentKeys(2);
  ASSERT_EQ(keys, (DocumentKeySet{testutil::Key("foo/bar"),
                                  testutil::Key("foo/baz")}));
}

// TODO(mrschmidt): The FieldValue.increment() field transform tests below would
// probably be better implemented as spec tests but currently they don't support
// transforms.

TEST_P(LocalStoreTest, HandlesSetMutationThenTransformThenTransform) {
  WriteMutation(testutil::SetMutation("foo/bar", Map("sum", 0)));
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 0)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 0)).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(1))}));
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 1)).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(2))}));
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 3)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 3)).SetHasLocalMutations());
}

TEST_P(LocalStoreTest,
       HandlesSetMutationThenAckThenTransformThenAckThenTransform) {  // NOLINT
  // Since this test doesn't start a listen, Eager GC removes the documents from
  // the cache as soon as the mutation is applied. This creates a lot of special
  // casing in this unit test but does not expand its test coverage.
  if (IsGcEager()) return;

  WriteMutation(testutil::SetMutation("foo/bar", Map("sum", 0)));
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 0)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 0)).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(1);
  FSTAssertContains(
      Doc("foo/bar", 1, Map("sum", 0)).SetHasCommittedMutations());
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 0)).SetHasCommittedMutations());

  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(1))}));
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(2, Value(1));
  FSTAssertContains(
      Doc("foo/bar", 2, Map("sum", 1)).SetHasCommittedMutations());
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 1)).SetHasCommittedMutations());

  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(2))}));
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 3)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 3)).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, UsesTargetMappingToExecuteQueries) {
  if (IsGcEager()) return;

  // This test verifies that once a target mapping has been written, only
  // documents that match the query are read from the RemoteDocumentCache.

  core::Query query =
      Query("foo").AddingFilter(testutil::Filter("matches", "==", true));
  TargetId target_id = AllocateQuery(query);

  WriteMutation(testutil::SetMutation("foo/a", Map("matches", true)));
  WriteMutation(testutil::SetMutation("foo/b", Map("matches", true)));
  WriteMutation(testutil::SetMutation("foo/ignored", Map("matches", false)));
  AcknowledgeMutationWithVersion(10);
  AcknowledgeMutationWithVersion(10);
  AcknowledgeMutationWithVersion(10);

  // Execute the query, but note that we read matching documents from the
  // RemoteDocumentCache since we do not yet have target mapping.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* by_key */ 0, /* by_query= */ 2);

  // Issue a RemoteEvent to persist the target mapping.
  ApplyRemoteEvent(AddedRemoteEvent({Doc("foo/a", 10, Map("matches", true)),
                                     Doc("foo/b", 10, Map("matches", true))},
                                    {target_id}));
  ApplyRemoteEvent(NoChangeEvent(target_id, 10));
  UpdateViews(target_id, /* from_cache= */ false);

  // Execute the query again, this time verifying that we only read the two
  // documents that match the query.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* by_key */ 2, /* by_query= */ 0);
  FSTAssertQueryReturned("foo/a", "foo/b");
}

TEST_P(LocalStoreTest, IgnoresTargetMappingAfterExistenceFilterMismatch) {
  if (IsGcEager()) return;

  core::Query query =
      Query("foo").AddingFilter(testutil::Filter("matches", "==", true));
  TargetId target_id = AllocateQuery(query);

  ExecuteQuery(query);

  // Persist a mapping with a single document
  ApplyRemoteEvent(
      AddedRemoteEvent({Doc("foo/a", 10, Map("matches", true))}, {target_id}));
  ApplyRemoteEvent(NoChangeEvent(target_id, 10));
  UpdateViews(target_id, /* from_cache= */ false);

  // At this point, we have not yet confirmed that the query is limbo free.
  TargetData cached_target_data = GetTargetData(query);
  ASSERT_EQ(testutil::Version(10),
            cached_target_data.last_limbo_free_snapshot_version());

  // Create an existence filter mismatch and verify that the last limbo free
  // snapshot version is deleted
  ApplyRemoteEvent(ExistenceFilterEvent(
      target_id, DocumentKeySet{testutil::Key("foo/a")}, 2, 20));
  cached_target_data = GetTargetData(query);
  ASSERT_EQ(SnapshotVersion::None(),
            cached_target_data.last_limbo_free_snapshot_version());
  ASSERT_EQ(ByteString{}, cached_target_data.resume_token());

  // Re-run the query as a collection scan
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* by_key */ 0, /* by_query= */ 1);
  FSTAssertQueryReturned("foo/a");
}

TEST_P(LocalStoreTest, LastLimboFreeSnapshotIsAdvancedDuringViewProcessing) {
  // This test verifies that the `last_limbo_free_snapshot` version for
  // TargetData is advanced when we compute a limbo-free free view and that the
  // mapping is persisted when we release a query.

  core::Query query = Query("foo");
  TargetId target_id = AllocateQuery(query);

  // Advance the target snapshot.
  ApplyRemoteEvent(NoChangeEvent(target_id, 10));

  // At this point, we have not yet confirmed that the query is limbo free.
  TargetData cached_target_data = GetTargetData(query);
  ASSERT_EQ(SnapshotVersion::None(),
            cached_target_data.last_limbo_free_snapshot_version());

  // Mark the view synced, which updates the last limbo free snapshot version.
  UpdateViews(target_id, /* from_cache= */ false);
  cached_target_data = GetTargetData(query);
  ASSERT_EQ(testutil::Version(10),
            cached_target_data.last_limbo_free_snapshot_version());

  // The last limbo free snapshot version is persisted even if we release the
  // query.
  local_store_.ReleaseTarget(target_id);

  if (!IsGcEager()) {
    cached_target_data = GetTargetData(query);
    ASSERT_EQ(testutil::Version(10),
              cached_target_data.last_limbo_free_snapshot_version());
  }
}

TEST_P(LocalStoreTest, QueriesIncludeLocallyModifiedDocuments) {
  if (IsGcEager()) return;

  // This test verifies that queries that have a persisted TargetMapping include
  // documents that were modified by local edits after the target mapping was
  // written.
  core::Query query =
      Query("foo").AddingFilter(testutil::Filter("matches", "==", true));
  TargetId target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent({Doc("foo/a", 10, Map("matches", true))}, {target_id}));
  ApplyRemoteEvent(NoChangeEvent(target_id, 10));
  UpdateViews(target_id, /* from_cache= */ false);

  // Execute the query based on the RemoteEvent.
  ExecuteQuery(query);
  FSTAssertQueryReturned("foo/a");

  // Write a document.
  WriteMutation(testutil::SetMutation("foo/b", Map("matches", true)));

  // Execute the query and make sure that the pending mutation is included in
  // the result.
  ExecuteQuery(query);
  FSTAssertQueryReturned("foo/a", "foo/b");

  AcknowledgeMutationWithVersion(11);

  // Execute the query and make sure that the acknowledged mutation is included
  // in the result.
  ExecuteQuery(query);
  FSTAssertQueryReturned("foo/a", "foo/b");
}

TEST_P(LocalStoreTest, QueriesIncludeDocumentsFromOtherQueries) {
  if (IsGcEager()) return;

  // This test verifies that queries that have a persisted TargetMapping include
  // documents that were modified by other queries after the target mapping was
  // written.

  core::Query filtered_query =
      Query("foo").AddingFilter(testutil::Filter("matches", "==", true));
  TargetId target_id = AllocateQuery(filtered_query);

  ApplyRemoteEvent(
      AddedRemoteEvent({Doc("foo/a", 10, Map("matches", true))}, {target_id}));
  ApplyRemoteEvent(NoChangeEvent(target_id, 10));
  UpdateViews(target_id, /* from_cache=*/false);
  local_store_.ReleaseTarget(target_id);

  // Start another query and add more matching documents to the collection.
  core::Query full_query = Query("foo");
  target_id = AllocateQuery(full_query);
  ApplyRemoteEvent(AddedRemoteEvent({Doc("foo/a", 10, Map("matches", true)),
                                     Doc("foo/b", 20, Map("matches", true))},
                                    {target_id}));
  local_store_.ReleaseTarget(target_id);

  // Run the original query again and ensure that both the original matches as
  // well as all new matches are included in the result set.
  AllocateQuery(filtered_query);
  ExecuteQuery(filtered_query);
  FSTAssertQueryReturned("foo/a", "foo/b");
}

TEST_P(LocalStoreTest, QueriesFilterDocumentsThatNoLongerMatch) {
  if (IsGcEager()) return;

  // This test verifies that documents that once matched a query are
  // post-filtered if they no longer match the query filter.

  // Add two document results for a simple filter query
  core::Query filtered_query =
      Query("foo").AddingFilter(testutil::Filter("matches", "==", true));
  TargetId target_id = AllocateQuery(filtered_query);

  ApplyRemoteEvent(AddedRemoteEvent({Doc("foo/a", 10, Map("matches", true)),
                                     Doc("foo/b", 10, Map("matches", true))},
                                    {target_id}));
  ApplyRemoteEvent(NoChangeEvent(target_id, 10));
  UpdateViews(target_id, /* from_cache= */ false);
  local_store_.ReleaseTarget(target_id);

  // Modify one of the documents to no longer match while the filtered query is
  // inactive.
  core::Query full_query = Query("foo");
  target_id = AllocateQuery(full_query);
  ApplyRemoteEvent(AddedRemoteEvent({Doc("foo/a", 10, Map("matches", true)),
                                     Doc("foo/b", 20, Map("matches", false))},
                                    {target_id}));
  local_store_.ReleaseTarget(target_id);

  // Re-run the filtered query and verify that the modified document is no
  // longer returned.
  AllocateQuery(filtered_query);
  ExecuteQuery(filtered_query);
  FSTAssertQueryReturned("foo/a");
}

TEST_P(LocalStoreTest,
       HandlesSetMutationThenTransformThenRemoteEventThenTransform) {  // NOLINT
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  WriteMutation(testutil::SetMutation("foo/bar", Map("sum", 0)));
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 0)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 0)).SetHasLocalMutations());

  ApplyRemoteEvent(AddedRemoteEvent(Doc("foo/bar", 1, Map("sum", 0)), {2}));

  AcknowledgeMutationWithVersion(1);
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 0)));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 0)));

  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(1))}));
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());

  // The value in this remote event gets ignored since we still have a pending
  // transform mutation.
  ApplyRemoteEvent(
      UpdateRemoteEvent(Doc("foo/bar", 2, Map("sum", 0)), {2}, {}));
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 1)).SetHasLocalMutations());

  // Add another increment. Note that we still compute the increment based on
  // the local value.
  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(2))}));
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 3)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 3)).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(3, Value(1));
  FSTAssertContains(Doc("foo/bar", 3, Map("sum", 3)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 3, Map("sum", 3)).SetHasLocalMutations());

  AcknowledgeMutationWithVersion(4, Value(1339));
  FSTAssertContains(
      Doc("foo/bar", 4, Map("sum", 1339)).SetHasCommittedMutations());
  FSTAssertChanged(
      Doc("foo/bar", 4, Map("sum", 1339)).SetHasCommittedMutations());
}

TEST_P(LocalStoreTest, HoldsBackTransforms) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  WriteMutation(
      testutil::SetMutation("foo/bar", Map("sum", 0, "array_union", Array())));
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 0, "array_union", Array()))
                       .SetHasLocalMutations());

  AcknowledgeMutationWithVersion(1);
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 0, "array_union", Array()))
                       .SetHasCommittedMutations());

  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("foo/bar", 1, Map("sum", 0, "array_union", Array())), {2}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 0, "array_union", Array())));

  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(1))}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1, "array_union", Array()))
                       .SetHasLocalMutations());

  std::vector<Message<google_firestore_v1_Value>> array_union;
  array_union.push_back(Value("foo"));
  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::ArrayUnion("array_union", array_union)}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1, "array_union", Array("foo")))
                       .SetHasLocalMutations());

  // The sum transform and array union transform make the SDK ignore the
  // backend's updated value.
  ApplyRemoteEvent(UpdateRemoteEvent(
      Doc("foo/bar", 2, Map("sum", 1337, "array_union", Array("bar"))), {2},
      {}));
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 1, "array_union", Array("foo")))
                       .SetHasLocalMutations());

  // With a field transform acknowledgement, the overlay is recalculated with
  // remaining local mutations.
  AcknowledgeMutationWithVersion(3, Value(1338));
  FSTAssertChanged(
      Doc("foo/bar", 3, Map("sum", 1338, "array_union", Array("bar", "foo")))
          .SetHasLocalMutations());

  AcknowledgeMutationWithVersion(4, Value("bar"));
  FSTAssertChanged(
      Doc("foo/bar", 4, Map("sum", 1338, "array_union", Array("bar", "foo")))
          .SetHasCommittedMutations());
}

TEST_P(LocalStoreTest, HandlesMergeMutationWithTransformThenRemoteEvent) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  WriteMutation(
      testutil::MergeMutation("foo/bar", Map(), std::vector<model::FieldPath>(),
                              {testutil::Increment("sum", Value(1))}));

  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 1)).SetHasLocalMutations());

  ApplyRemoteEvent(AddedRemoteEvent(Doc("foo/bar", 1, Map("sum", 1337)), {2}));

  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, HandlesPatchMutationWithTransformThenRemoteEvent) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(1))}));

  FSTAssertNotContains("foo/bar");
  FSTAssertChanged(DeletedDoc("foo/bar"));

  // Note: This test reflects the current behavior, but it may be preferable to
  // replay the mutation once we receive the first value from the remote event.
  ApplyRemoteEvent(AddedRemoteEvent(Doc("foo/bar", 1, Map("sum", 1337)), {2}));

  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, HandlesSavingBundledDocuments) {
  ApplyBundledDocuments(
      {Doc("foo/bar", 1, Map("sum", 1337)), DeletedDoc("foo/bar1", 1)});
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1337)),
                   DeletedDoc("foo/bar1", 1));
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1337)));
  FSTAssertContains(DeletedDoc("foo/bar1", 1));

  DocumentKeySet expected_keys({Key("foo/bar")});
  FSTAssertQueryDocumentMapping(2, expected_keys);
}

TEST_P(LocalStoreTest, HandlesSavingBundledDocumentsWithNewerExistingVersion) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  ApplyRemoteEvent(AddedRemoteEvent(Doc("foo/bar", 2, Map("sum", 1337)), {2}));
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 1337)));

  ApplyBundledDocuments(
      {Doc("foo/bar", 1, Map("sum", 1337)), DeletedDoc("foo/bar1", 1)});
  FSTAssertChanged(DeletedDoc("foo/bar1", 1));
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 1337)));
  FSTAssertContains(DeletedDoc("foo/bar1", 1));

  DocumentKeySet expected_keys({Key("foo/bar")});
  FSTAssertQueryDocumentMapping(4, expected_keys);
}

TEST_P(LocalStoreTest, HandlesSavingBundledDocumentsWithOlderExistingVersion) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/bar", 1, Map("val", "to-delete")), {2}));
  FSTAssertContains(Doc("foo/bar", 1, Map("val", "to-delete")));

  ApplyBundledDocuments(
      {Doc("foo/new", 1, Map("sum", 1336)), DeletedDoc("foo/bar", 2)});
  FSTAssertChanged(DeletedDoc("foo/bar", 2),
                   Doc("foo/new", 1, Map("sum", 1336)));
  FSTAssertContains(Doc("foo/new", 1, Map("sum", 1336)));
  FSTAssertContains(DeletedDoc("foo/bar", 2));

  DocumentKeySet expected_keys({Key("foo/new")});
  FSTAssertQueryDocumentMapping(4, expected_keys);
}

TEST_P(LocalStoreTest,
       HandlesSavingBundledDocumentsWithSameExistingVersionShouldNotOverwrite) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  ApplyRemoteEvent(AddedRemoteEvent(Doc("foo/bar", 1, Map("val", "old")), {2}));
  FSTAssertContains(Doc("foo/bar", 1, Map("val", "old")));

  ApplyBundledDocuments({Doc("foo/bar", 1, Map("val", "new"))});
  FSTAssertChanged();
  FSTAssertContains(Doc("foo/bar", 1, Map("val", "old")));

  DocumentKeySet expected_keys({Key("foo/bar")});
  FSTAssertQueryDocumentMapping(4, expected_keys);
}

TEST_P(LocalStoreTest,
       HandlesMergeMutationWithTransformationThenBundledDocuments) {
  core::Query query = Query("foo");
  AllocateQuery(query);

  WriteMutation(
      testutil::MergeMutation("foo/bar", Map(), std::vector<model::FieldPath>(),
                              {testutil::Increment("sum", Value(1))}));

  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 1)).SetHasLocalMutations());

  ApplyBundledDocuments({Doc("foo/bar", 1, Map("sum", 1337))});
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());

  DocumentKeySet expected_keys({Key("foo/bar")});
  FSTAssertQueryDocumentMapping(4, expected_keys);
}

TEST_P(LocalStoreTest,
       HandlesPatchMutationWithTransformationThenBundledDocuments) {
  // Note: see comments in HandlesPatchMutationWithTransformThenRemoteEvent.
  // The behavior for this and remote event is the same.
  core::Query query = Query("foo");
  AllocateQuery(query);

  WriteMutation(testutil::PatchMutation(
      "foo/bar", Map(), {testutil::Increment("sum", Value(1))}));

  FSTAssertNotContains("foo/bar");
  FSTAssertChanged(DeletedDoc("foo/bar"));

  ApplyBundledDocuments({Doc("foo/bar", 1, Map("sum", 1337))});
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1)).SetHasLocalMutations());

  DocumentKeySet expected_keys({Key("foo/bar")});
  FSTAssertQueryDocumentMapping(4, expected_keys);
}

TEST_P(LocalStoreTest, HandlesSavingAndCheckingBundleMetadata) {
  BundleMetadata metadata("bundle", 1, SnapshotVersion(Timestamp(3, 0)));
  EXPECT_FALSE(local_store_.HasNewerBundle(metadata));

  local_store_.SaveBundle(metadata);

  EXPECT_TRUE(local_store_.HasNewerBundle(metadata));
}

TEST_P(LocalStoreTest, HandlesSavingAndLoadingNamedQueries) {
  core::Target target = Query("foo").ToTarget();

  NamedQuery named_query(
      "testQuery",
      bundle::BundledQuery(std::move(target), core::LimitType::First),
      SnapshotVersion(Timestamp::Now()));
  local_store_.SaveNamedQuery(named_query, DocumentKeySet());

  EXPECT_EQ(local_store_.GetNamedQuery("testQuery"), named_query);
}

TEST_P(LocalStoreTest,
       SavingNamedQueriesAllocatesTargetsAndUpdatesTargetDocumentMapping) {
  ApplyBundledDocuments({Doc("foo1/bar", 1, Map("sum", 1337)),
                         Doc("foo2/bar", 1, Map("sum", 42))});
  FSTAssertChanged(Doc("foo1/bar", 1, Map("sum", 1337)),
                   Doc("foo2/bar", 1, Map("sum", 42)));
  FSTAssertContains(Doc("foo1/bar", 1, Map("sum", 1337)));
  FSTAssertContains(Doc("foo2/bar", 1, Map("sum", 42)));

  core::Target target1 = Query("foo1").ToTarget();

  NamedQuery named_query1(
      "query-1",
      bundle::BundledQuery(std::move(target1), core::LimitType::First),
      SnapshotVersion(Timestamp::Now()));
  DocumentKeySet mapped_keys1({Key("foo1/bar")});
  local_store_.SaveNamedQuery(named_query1, mapped_keys1);

  EXPECT_EQ(local_store_.GetNamedQuery("query-1"), named_query1);
  FSTAssertQueryDocumentMapping(4, mapped_keys1);

  core::Target target2 = Query("foo2").ToTarget();

  NamedQuery named_query2(
      "query-2",
      bundle::BundledQuery(std::move(target2), core::LimitType::First),
      SnapshotVersion(Timestamp::Now()));
  DocumentKeySet mapped_keys2({Key("foo2/bar")});
  local_store_.SaveNamedQuery(named_query2, mapped_keys2);

  EXPECT_EQ(local_store_.GetNamedQuery("query-2"), named_query2);
  FSTAssertQueryDocumentMapping(6, mapped_keys2);
}

TEST_P(LocalStoreTest, HandlesSavingAndLoadingLimitToLastQueries) {
  core::Target target =
      Query("foo")
          .AddingOrderBy(testutil::OrderBy(testutil::Field("length"),
                                           core::Direction::Descending))
          // Use LimitToFirst here so `ToTarget()` does not flip the order,
          // simulating how LimitToLast queries are stored in bundles.
          .WithLimitToFirst(5)
          .ToTarget();

  NamedQuery named_query(
      "testQuery",
      bundle::BundledQuery(std::move(target), core::LimitType::First),
      SnapshotVersion(Timestamp::Now()));
  local_store_.SaveNamedQuery(named_query, DocumentKeySet());

  EXPECT_EQ(local_store_.GetNamedQuery("testQuery"), named_query);
}

TEST_P(LocalStoreTest, GetHighestUnacknowledgeBatchId) {
  ASSERT_EQ(-1, local_store_.GetHighestUnacknowledgedBatchId());

  WriteMutation(testutil::SetMutation("foo/bar", Map("abc", 123)));
  ASSERT_EQ(1, local_store_.GetHighestUnacknowledgedBatchId());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("abc", 321)));
  ASSERT_EQ(2, local_store_.GetHighestUnacknowledgedBatchId());

  AcknowledgeMutationWithVersion(1);
  ASSERT_EQ(2, local_store_.GetHighestUnacknowledgedBatchId());

  RejectMutation();
  ASSERT_EQ(-1, local_store_.GetHighestUnacknowledgedBatchId());
}

TEST_P(LocalStoreTest, OnlyPersistsUpdatesForDocumentsWhenVersionChanges) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  ApplyRemoteEvent(AddedRemoteEvent(Doc("foo/bar", 1, Map("val", "old")), {2}));
  FSTAssertContains(Doc("foo/bar", 1, Map("val", "old")));
  FSTAssertChanged(Doc("foo/bar", 1, Map("val", "old")));

  ApplyRemoteEvent(AddedRemoteEvent({Doc("foo/bar", 1, Map("val", "new")),
                                     Doc("foo/baz", 2, Map("val", "new"))},
                                    {2}));
  // The update to foo/bar is ignored.
  FSTAssertContains(Doc("foo/bar", 1, Map("val", "old")));
  FSTAssertContains(Doc("foo/baz", 2, Map("val", "new")));
  FSTAssertChanged(Doc("foo/baz", 2, Map("val", "new")));
}

TEST_P(LocalStoreTest, CanHandleBatchAckWhenPendingBatchesHaveOtherDocs) {
  // Prepare two batches, the first one will get rejected by the backend.
  // When the first batch is rejected, overlay is recalculated with only the
  // second batch, even though it has more documents than what is being
  // rejected. See: https://github.com/firebase/firebase-android-sdk/issues/3490
  WriteMutation(testutil::PatchMutation("foo/bar", Map("foo", "bar")));
  WriteMutations({testutil::SetMutation("foo/bar", Map("foo", "bar-set")),
                  testutil::SetMutation("foo/another", Map("foo", "another"))});

  RejectMutation();
  FSTAssertContains(
      Doc("foo/bar", 0, Map("foo", "bar-set")).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/another", 0, Map("foo", "another")).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, MultipleFieldPatchesOnRemoteDocs) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/bar", 1, Map("likes", 0, "stars", 0)), {2}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("likes", 0, "stars", 0)));
  FSTAssertContains(Doc("foo/bar", 1, Map("likes", 0, "stars", 0)));

  WriteMutation(testutil::PatchMutation("foo/bar", Map("likes", 1)));
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 0)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 0)).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("stars", 1)));
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 1)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 1)).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("stars", 2)));
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 2)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 2)).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, MultipleFieldPatchesInOneBatchOnRemoteDocs) {
  core::Query query = Query("foo");
  AllocateQuery(query);
  FSTAssertTargetID(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/bar", 1, Map("likes", 0, "stars", 0)), {2}));
  FSTAssertChanged(Doc("foo/bar", 1, Map("likes", 0, "stars", 0)));
  FSTAssertContains(Doc("foo/bar", 1, Map("likes", 0, "stars", 0)));

  WriteMutations({testutil::PatchMutation("foo/bar", Map("likes", 1)),
                  testutil::PatchMutation("foo/bar", Map("stars", 1))});
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 1)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 1)).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("stars", 2)));
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 2)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 1, Map("likes", 1, "stars", 2)).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, MultipleFieldPatchesOnLocalDocs) {
  WriteMutation(testutil::SetMutation("foo/bar", Map("likes", 0, "stars", 0)));
  FSTAssertChanged(
      Doc("foo/bar", 0, Map("likes", 0, "stars", 0)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("likes", 0, "stars", 0)).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("likes", 1)));
  FSTAssertChanged(
      Doc("foo/bar", 0, Map("likes", 1, "stars", 0)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("likes", 1, "stars", 0)).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("stars", 1)));
  FSTAssertChanged(
      Doc("foo/bar", 0, Map("likes", 1, "stars", 1)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("likes", 1, "stars", 1)).SetHasLocalMutations());

  WriteMutation(testutil::PatchMutation("foo/bar", Map("stars", 2)));
  FSTAssertChanged(
      Doc("foo/bar", 0, Map("likes", 1, "stars", 2)).SetHasLocalMutations());
  FSTAssertContains(
      Doc("foo/bar", 0, Map("likes", 1, "stars", 2)).SetHasLocalMutations());
}

TEST_P(LocalStoreTest, PatchMutationLeadsToPatchOverlay) {
  AllocateQuery(Query("foo"));
  ApplyRemoteEvent(UpdateRemoteEvent(Doc("foo/baz", 10, Map("a", 1)), {2}, {}));
  ApplyRemoteEvent(UpdateRemoteEvent(Doc("foo/bar", 20, Map()), {2}, {}));
  WriteMutation(testutil::PatchMutation("foo/baz", Map("b", 2)));

  ResetPersistenceStats();

  ExecuteQuery(Query("foo"));
  FSTAssertRemoteDocumentsRead(0, 2);
  FSTAssertOverlaysRead(0, 1);
  FSTAssertOverlayTypes(
      OverlayTypeMap({{Key("foo/baz"), model::Mutation::Type::Patch}}));
}

TEST_P(LocalStoreTest, DeeplyNestedTimestampDoesNotCauseStackOverflow) {
  Timestamp timestamp = Timestamp::Now();
  Message<_google_firestore_v1_Value> initialServerTimestamp =
      model::EncodeServerTimestamp(timestamp, absl::nullopt);
  model::FieldPath path = model::FieldPath::FromDotSeparatedString("timestamp");
  auto makeDeeplyNestedTimestamp = [&]() {
    for (int i = 0; i < 1000; ++i) {
      WriteMutation(testutil::MergeMutation(
          "foo/bar",
          Map("timestamp",
              model::EncodeServerTimestamp(timestamp, *initialServerTimestamp)),
          {path}, {ServerTimestamp("timestamp")}));
    }
  };
  std::thread t(makeDeeplyNestedTimestamp);
  EXPECT_NO_FATAL_FAILURE(t.join());
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
