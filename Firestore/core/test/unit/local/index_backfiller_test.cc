// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Firestore/core/src/local/index_backfiller.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_store.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/test/unit/local/counting_query_engine.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using model::DocumentKey;
using model::FieldIndex;
using model::IndexOffset;
using model::Segment;
using model::SnapshotVersion;
using testutil::DeleteMutation;
using testutil::Doc;
using testutil::Field;
using testutil::Filter;
using testutil::MakeFieldIndex;
using testutil::Map;
using testutil::OrderBy;
using testutil::PatchMutation;
using testutil::Query;
using testutil::Version;

}  // namespace

class IndexBackfillerTest : public ::testing::Test {
 public:
  IndexBackfillerTest()
      : persistence_(LevelDbPersistenceForTesting()),
        remote_document_cache_(persistence_->remote_document_cache()),
        document_overlay_cache_(persistence_->GetDocumentOverlayCache(
            credentials::User::Unauthenticated())),
        local_store_(persistence_.get(),
                     &query_engine_,
                     credentials::User::Unauthenticated()),
        index_manager_(local_store_.index_manager()),
        index_backfiller_(local_store_.index_backfiller()) {
    persistence_->Run("Start Index Manager in BackfillerTests",
                      [&] { index_manager_->Start(); });
  }

  void AddFieldIndex(const std::string& collection_group,
                     const std::string& field) const {
    const auto field_index =
        MakeFieldIndex(collection_group, field, Segment::Kind::kAscending);
    persistence_->Run("AddFieldIndex in BackfillerTests",
                      [&] { index_manager_->AddFieldIndex(field_index); });
  }

  void AddFieldIndex(const std::string& collection_group,
                     const std::string& field,
                     SnapshotVersion version) const {
    const auto field_index =
        FieldIndex(-1, collection_group,
                   {model::Segment{Field(field), Segment::Kind::kAscending}},
                   model::IndexState(0, version, {},
                                     IndexOffset::InitialLargestBatchId()));
    persistence_->Run("AddFieldIndex in BackfillerTests",
                      [&] { index_manager_->AddFieldIndex(field_index); });
  }

  void AddFieldIndex(const std::string& collection_group,
                     const std::string& field,
                     int64_t sequence_number) const {
    const auto field_index =
        FieldIndex(-1, collection_group,
                   {model::Segment{Field(field), Segment::Kind::kAscending}},
                   model::IndexState(sequence_number, IndexOffset::None()));
    persistence_->Run("AddFieldIndex in BackfillerTests",
                      [&] { index_manager_->AddFieldIndex(field_index); });
  }

  /** Creates a document and adds it to the RemoteDocumentCache. */
  void AddDoc(const std::string& path,
              SnapshotVersion readTime,
              const std::string& field,
              int value) const {
    persistence_->Run("AddDoc in BackfillerTests", [&] {
      remote_document_cache_->Add(Doc(path, 10, Map(field, value)), readTime);
    });
  }

  void SetMaxDocumentsToProcess(int new_max) const {
    index_backfiller_->SetMaxDocumentsToProcess(new_max);
  }

  void VerifyQueryResults(
      const core::Query& query,
      const std::unordered_set<std::string>& expected_keys) const {
    persistence_->Run("VerifyQueryResults", [&] {
      const core::Target& target = query.ToTarget();
      auto actual_keys = index_manager_->GetDocumentsMatchingTarget(target);
      if (!actual_keys) {
        ASSERT_EQ(0u, expected_keys.size());
      } else {
        ASSERT_EQ(actual_keys.value().size(), expected_keys.size());
        for (const auto& key : actual_keys.value()) {
          EXPECT_TRUE(expected_keys.find(key.ToString()) !=
                      expected_keys.end());
        }
      }
    });
  }

  void VerifyQueryResults(
      const std::string& collection_group,
      const std::unordered_set<std::string>& expected_keys) const {
    VerifyQueryResults(Query(collection_group).AddingOrderBy(OrderBy("foo")),
                       expected_keys);
  }

  /**
   * Adds a set mutation to a batch with the specified id for every specified
   * document path.
   */
  void AddSetMutationsToOverlay(int batch_id,
                                const std::vector<std::string>& paths) const {
    persistence_->Run("AddSetMutationsToOverlay", [&] {
      model::MutationByDocumentKeyMap map;
      for (const auto& path : paths) {
        map[DocumentKey::FromPathString(path)] =
            testutil::SetMutation(path, testutil::Map("foo", "bar"));
      }
      document_overlay_cache_->SaveOverlays(batch_id, map);
    });
  }

  void AddMutationToOverlay(const std::string path,
                            const model::Mutation& mutation) const {
    persistence_->Run("AddMutationToOverlay", [&] {
      document_overlay_cache_->SaveOverlays(
          5, model::MutationByDocumentKeyMap{
                 {DocumentKey::FromPathString(path), mutation}});
    });
  }

  std::unique_ptr<LevelDbPersistence> persistence_;
  RemoteDocumentCache* remote_document_cache_;
  DocumentOverlayCache* document_overlay_cache_;
  CountingQueryEngine query_engine_;
  LocalStore local_store_;
  IndexManager* index_manager_;
  IndexBackfiller* index_backfiller_;
};

TEST_F(IndexBackfillerTest, WritesLatestReadTimeToFieldIndexOnCompletion) {
  AddFieldIndex("coll1", "foo");
  AddFieldIndex("coll2", "bar");
  AddDoc("coll1/docA", Version(10), "foo", 1);
  AddDoc("coll2/docA", Version(20), "bar", 1);
  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);

  auto field_index1 = index_manager_->GetFieldIndexes("coll1").at(0);
  auto field_index2 = index_manager_->GetFieldIndexes("coll2").at(0);
  EXPECT_EQ(Version(10), field_index1.index_state().index_offset().read_time());
  EXPECT_EQ(Version(20), field_index2.index_state().index_offset().read_time());

  AddDoc("coll1/docB", Version(50, 10), "foo", 1);
  AddDoc("coll1/docC", Version(50), "foo", 1);
  AddDoc("coll2/docB", Version(60), "bar", 1);
  AddDoc("coll2/docC", Version(60, 10), "bar", 1);

  documents_processed = local_store_.Backfill();
  ASSERT_EQ(4, documents_processed);

  field_index1 = index_manager_->GetFieldIndexes("coll1").at(0);
  field_index2 = index_manager_->GetFieldIndexes("coll2").at(0);
  EXPECT_EQ(Version(50, 10),
            field_index1.index_state().index_offset().read_time());
  EXPECT_EQ(Version(60, 10),
            field_index2.index_state().index_offset().read_time());
}

TEST_F(IndexBackfillerTest, FetchesDocumentsAfterEarliestReadTime) {
  AddFieldIndex("coll1", "foo", Version(10));

  // Documents before read time should not be fetched.
  AddDoc("coll1/docA", Version(9), "foo", 1);
  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(0, documents_processed);

  // Read time should be the highest read time from the cache.
  auto field_index = index_manager_->GetFieldIndexes("coll1").at(0);
  EXPECT_EQ(IndexOffset(Version(10), DocumentKey::Empty(),
                        IndexOffset::InitialLargestBatchId()),
            field_index.index_state().index_offset());

  // Documents that are after the earliest read time
  // but before field index read time are fetched.
  AddDoc("coll1/docB", Version(19), "boo", 1);
  documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  // Field indexes should now hold the latest read time
  field_index = index_manager_->GetFieldIndexes("coll1").at(0);
  EXPECT_EQ(Version(19), field_index.index_state().index_offset().read_time());
}

TEST_F(IndexBackfillerTest, WritesIndexEntries) {
  AddFieldIndex("coll1", "foo");
  AddFieldIndex("coll2", "bar");
  AddDoc("coll1/docA", Version(10), "foo", 1);
  AddDoc("coll1/docB", Version(10), "boo", 1);
  AddDoc("coll2/docA", Version(10), "bar", 1);
  AddDoc("coll2/docB", Version(10), "car", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(4, documents_processed);
}

TEST_F(IndexBackfillerTest, WritesOldestDocumentFirst) {
  SetMaxDocumentsToProcess(2);

  AddFieldIndex("coll1", "foo");
  AddDoc("coll1/docA", Version(5), "foo", 1);
  AddDoc("coll1/docB", Version(3), "foo", 1);
  AddDoc("coll1/docC", Version(10), "foo", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);

  VerifyQueryResults("coll1", {"coll1/docA", "coll1/docB"});

  documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  VerifyQueryResults("coll1", {"coll1/docA", "coll1/docB", "coll1/docC"});
}

TEST_F(IndexBackfillerTest, UsesDocumentKeyOffsetForLargeSnapshots) {
  SetMaxDocumentsToProcess(2);

  AddFieldIndex("coll1", "foo");
  AddDoc("coll1/docA", Version(1), "foo", 1);
  AddDoc("coll1/docB", Version(1), "foo", 1);
  AddDoc("coll1/docC", Version(1), "foo", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);

  VerifyQueryResults("coll1", {"coll1/docA", "coll1/docB"});

  documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  VerifyQueryResults("coll1", {"coll1/docA", "coll1/docB", "coll1/docC"});
}

TEST_F(IndexBackfillerTest, UpdatesCollectionGroups) {
  SetMaxDocumentsToProcess(2);

  AddFieldIndex("coll1", "foo");
  AddFieldIndex("coll2", "foo");

  AddDoc("coll1/docA", Version(10), "foo", 1);
  AddDoc("coll1/docB", Version(20), "foo", 1);
  AddDoc("coll2/docA", Version(30), "foo", 1);

  absl::optional<std::string> collection_group =
      index_manager_->GetNextCollectionGroupToUpdate();
  ASSERT_TRUE(collection_group.has_value());
  ASSERT_EQ("coll1", collection_group.value());

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);

  // Check that coll1 was backfilled and that coll2 is next
  collection_group = index_manager_->GetNextCollectionGroupToUpdate();
  ASSERT_TRUE(collection_group.has_value());
  ASSERT_EQ("coll2", collection_group.value());
}

TEST_F(IndexBackfillerTest, PrioritizesNewCollectionGroups) {
  SetMaxDocumentsToProcess(1);

  // In this test case, `coll3` is a new collection group that hasn't been
  // indexed, so it should be processed ahead of the other collection groups.
  AddFieldIndex("coll1", "foo", /* sequenceNumber= */ 1);
  AddFieldIndex("coll2", "foo", /* sequenceNumber= */ 2);
  AddFieldIndex("coll3", "foo", /* sequenceNumber= */ 0);

  AddDoc("coll1/doc", Version(10), "foo", 1);
  AddDoc("coll2/doc", Version(20), "foo", 1);
  AddDoc("coll3/doc", Version(30), "foo", 1);

  // Check that coll3 is the next collection ID the backfiller should update
  absl::optional<std::string> collection_group =
      index_manager_->GetNextCollectionGroupToUpdate();
  ASSERT_TRUE(collection_group.has_value());
  ASSERT_EQ("coll3", collection_group.value());

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  VerifyQueryResults("coll3", {"coll3/doc"});
}

TEST_F(IndexBackfillerTest, WritesUntilCap) {
  SetMaxDocumentsToProcess(3);

  AddFieldIndex("coll1", "foo");
  AddFieldIndex("coll2", "foo");
  AddDoc("coll1/docA", Version(10), "foo", 1);
  AddDoc("coll1/docB", Version(20), "foo", 1);
  AddDoc("coll2/docA", Version(30), "foo", 1);
  AddDoc("coll2/docA", Version(40), "foo", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(3, documents_processed);

  VerifyQueryResults("coll1", {"coll1/docA", "coll1/docB"});
  VerifyQueryResults("coll2", {"coll2/docA"});
}

TEST_F(IndexBackfillerTest, UsesLatestReadTimeForEmptyCollections) {
  AddFieldIndex("coll", "foo", Version(1));
  AddDoc("readtime/doc", Version(1), "foo", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(0, documents_processed);

  AddDoc("coll/ignored", Version(2), "foo", 1);
  AddDoc("coll/added", Version(3), "foo", 1);

  documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);
}

TEST_F(IndexBackfillerTest, HandlesLocalMutationsAfterRemoteDocs) {
  SetMaxDocumentsToProcess(2);
  AddFieldIndex("coll1", "foo");

  AddDoc("coll1/docA", Version(10), "foo", 1);
  AddDoc("coll1/docB", Version(20), "foo", 1);
  AddDoc("coll1/docC", Version(30), "foo", 1);
  AddSetMutationsToOverlay(1, {"coll1/docD"});

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);
  VerifyQueryResults("coll1", {"coll1/docA", "coll1/docB"});

  documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);
  VerifyQueryResults("coll1",
                     {"coll1/docA", "coll1/docB", "coll1/docC", "coll1/docD"});
}

TEST_F(IndexBackfillerTest,
       MutationsUpToDocumentLimitAndUpdatesBatchIdOnIndex) {
  SetMaxDocumentsToProcess(2);
  AddFieldIndex("coll1", "foo");
  AddDoc("coll1/docA", Version(10), "foo", 1);
  AddSetMutationsToOverlay(2, {"coll1/docB"});
  AddSetMutationsToOverlay(3, {"coll1/docC"});
  AddSetMutationsToOverlay(4, {"coll1/docD"});

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);
  VerifyQueryResults("coll1", {"coll1/docA", "coll1/docB"});
  auto field_index = index_manager_->GetFieldIndexes("coll1").at(0);
  ASSERT_EQ(2, field_index.index_state().index_offset().largest_batch_id());

  documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);
  VerifyQueryResults("coll1",
                     {"coll1/docA", "coll1/docB", "coll1/docC", "coll1/docD"});
  field_index = index_manager_->GetFieldIndexes("coll1").at(0);
  ASSERT_EQ(4, field_index.index_state().index_offset().largest_batch_id());
}

TEST_F(IndexBackfillerTest, MutationFinishesMutationBatchEvenIfItExceedsLimit) {
  SetMaxDocumentsToProcess(2);
  AddFieldIndex("coll1", "foo");
  AddDoc("coll1/docA", Version(10), "foo", 1);
  AddSetMutationsToOverlay(2, {"coll1/docB", "coll1/docC", "coll1/docD"});
  AddSetMutationsToOverlay(3, {"coll1/docE"});

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(4, documents_processed);
  VerifyQueryResults("coll1",
                     {"coll1/docA", "coll1/docB", "coll1/docC", "coll1/docD"});
}

TEST_F(IndexBackfillerTest, MutationsFromHighWaterMark) {
  SetMaxDocumentsToProcess(2);
  AddFieldIndex("coll1", "foo");
  AddDoc("coll1/docA", Version(10), "foo", 1);
  AddSetMutationsToOverlay(3, {"coll1/docB"});

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);
  VerifyQueryResults("coll1", {"coll1/docA", "coll1/docB"});

  AddSetMutationsToOverlay(1, {"coll1/docC"});
  AddSetMutationsToOverlay(2, {"coll1/docD"});
  documents_processed = local_store_.Backfill();
  ASSERT_EQ(0, documents_processed);
}

TEST_F(IndexBackfillerTest, UpdatesExistingDocToNewValue) {
  const auto& query = Query("coll").AddingFilter(Filter("foo", "==", 2));
  AddFieldIndex("coll", "foo");

  AddDoc("coll/doc", Version(10), "foo", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);
  VerifyQueryResults(query, {});

  // Update doc to new remote version with new value.
  AddDoc("coll/doc", Version(40), "foo", 2);
  local_store_.Backfill();

  VerifyQueryResults(query, {"coll/doc"});
}

TEST_F(IndexBackfillerTest, UpdatesDocsThatNoLongerMatch) {
  const auto& query = Query("coll").AddingFilter(Filter("foo", ">", 0));
  AddFieldIndex("coll", "foo");
  AddDoc("coll/doc", Version(10), "foo", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);
  VerifyQueryResults(query, {"coll/doc"});

  // Update doc to new remote version with new value that doesn't match field
  // index.
  AddDoc("coll/doc", Version(40), "foo", -1);

  documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);
  VerifyQueryResults(query, {});
}

TEST_F(IndexBackfillerTest, DoesNotProcessSameDocumentTwice) {
  AddFieldIndex("coll", "foo");
  AddDoc("coll/doc", Version(5), "foo", 1);
  AddSetMutationsToOverlay(1, {"coll/doc"});

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  const auto field_index = index_manager_->GetFieldIndexes("coll").at(0);
  ASSERT_EQ(Version(5), field_index.index_state().index_offset().read_time());
  ASSERT_EQ(1, field_index.index_state().index_offset().largest_batch_id());
}

TEST_F(IndexBackfillerTest, AppliesSetToRemoteDoc) {
  AddFieldIndex("coll", "foo");
  AddDoc("coll/doc", Version(5), "boo", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  model::Mutation patch = PatchMutation("coll/doc", Map("foo", "bar"));
  AddMutationToOverlay("coll/doc", patch);

  documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  VerifyQueryResults("coll", {"coll/doc"});
}

TEST_F(IndexBackfillerTest, AppliesPatchToRemoteDoc) {
  const auto& query_a = Query("coll").AddingOrderBy(OrderBy("a"));
  const auto& query_b = Query("coll").AddingOrderBy(OrderBy("b"));

  AddFieldIndex("coll", "a");
  AddFieldIndex("coll", "b");
  AddDoc("coll/doc", Version(5), "a", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  VerifyQueryResults(query_a, {"coll/doc"});
  VerifyQueryResults(query_b, {});

  model::Mutation patch = PatchMutation("coll/doc", Map("b", 1));
  AddMutationToOverlay("coll/doc", patch);
  documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  VerifyQueryResults(query_a, {"coll/doc"});
  VerifyQueryResults(query_b, {"coll/doc"});
}

TEST_F(IndexBackfillerTest, AppliesDeleteToRemoteDoc) {
  AddFieldIndex("coll", "foo");
  AddDoc("coll/doc", Version(5), "foo", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  const model::DeleteMutation delete_mutation = DeleteMutation("coll/doc");
  AddMutationToOverlay("coll/doc", delete_mutation);
  documents_processed = local_store_.Backfill();
  ASSERT_EQ(1, documents_processed);

  persistence_->Run("BackfillAppliesDeleteToRemoteDoc", [&] {
    auto query = Query("coll").AddingFilter(Filter("foo", "==", 2));
    const core::Target& target = query.ToTarget();
    const auto matching = index_manager_->GetDocumentsMatchingTarget(target);
    ASSERT_TRUE(matching.has_value() && matching.value().empty());
  });
}

TEST_F(IndexBackfillerTest, ReindexesDocumentsWhenNewIndexIsAdded) {
  const auto& query_a = Query("coll").AddingOrderBy(OrderBy("a"));
  const auto& query_b = Query("coll").AddingOrderBy(OrderBy("b"));

  AddFieldIndex("coll", "a");
  AddDoc("coll/doc1", Version(1), "a", 1);
  AddDoc("coll/doc2", Version(1), "b", 1);

  int documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);
  VerifyQueryResults(query_a, {"coll/doc1"});
  VerifyQueryResults(query_b, {});

  AddFieldIndex("coll", "b");
  documents_processed = local_store_.Backfill();
  ASSERT_EQ(2, documents_processed);

  VerifyQueryResults(query_a, {"coll/doc1"});
  VerifyQueryResults(query_b, {"coll/doc2"});
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
