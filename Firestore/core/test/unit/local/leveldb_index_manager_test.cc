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

#include "Firestore/core/test/unit/local/index_manager_test.h"

#include "Firestore/core/src/local/leveldb_index_manager.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

namespace {

using credentials::User;
using model::FieldIndex;
using model::IndexOffset;
using model::IndexState;
using model::ResourcePath;
using model::Segment;
using testutil::Key;
using testutil::MakeFieldIndex;
using testutil::Version;

std::unique_ptr<Persistence> PersistenceFactory() {
  return LevelDbPersistenceForTesting();
}

void VerifySequenceNumber(IndexManager* index_manager,
                          const std::string& group,
                          int32_t expected_seq_num) {
  std::vector<FieldIndex> indexes = index_manager->GetFieldIndexes(group);
  EXPECT_EQ(indexes.size(), 1);
  EXPECT_EQ(indexes[0].index_state().sequence_number(), expected_seq_num);
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(LevelDbIndexManagerTest,
                         IndexManagerTest,
                         ::testing::Values(PersistenceFactory));

class LevelDbIndexManagerTest : public ::testing::Test {
 public:
  // `GetParam()` must return a factory function.
  LevelDbIndexManagerTest() : persistence{PersistenceFactory()} {
  }

  std::unique_ptr<Persistence> persistence;
};

TEST_F(LevelDbIndexManagerTest, CreateReadFieldsIndexes) {
  persistence->Run("CreateReadDeleteFieldsIndexes", [&]() {
    IndexManager* index_manager =
        persistence->GetIndexManager(User::Unauthenticated());
    index_manager->Start();

    index_manager->AddFieldIndex(
        MakeFieldIndex("coll1", 1, model::FieldIndex::InitialState(), "value",
                       model::Segment::kAscending));
    index_manager->AddFieldIndex(
        MakeFieldIndex("coll2", 2, model::FieldIndex::InitialState(), "value",
                       model::Segment::kContains));

    {
      auto indexes = index_manager->GetFieldIndexes("coll1");
      EXPECT_EQ(indexes.size(), 1);
      // Note index_id() is 0 because index manager rewrites it using its
      // internal id.
      EXPECT_EQ(indexes[0].index_id(), 0);
      EXPECT_EQ(indexes[0].collection_group(), "coll1");
    }

    index_manager->AddFieldIndex(
        MakeFieldIndex("coll1", 3, model::FieldIndex::InitialState(),
                       "newValue", model::Segment::kContains));
    {
      auto indexes = index_manager->GetFieldIndexes("coll1");
      EXPECT_EQ(indexes.size(), 2);
      EXPECT_EQ(indexes[0].collection_group(), "coll1");
      EXPECT_EQ(indexes[1].collection_group(), "coll1");
    }

    {
      auto indexes = index_manager->GetFieldIndexes("coll2");
      EXPECT_EQ(indexes.size(), 1);
      EXPECT_EQ(indexes[0].collection_group(), "coll2");
    }
  });
}

TEST_F(LevelDbIndexManagerTest,
       NextCollectionGroupAdvancesWhenCollectionIsUpdated) {
  persistence->Run("CreateReadDeleteFieldsIndexes", [&]() {
    IndexManager* index_manager =
        persistence->GetIndexManager(User::Unauthenticated());
    index_manager->Start();

    index_manager->AddFieldIndex(MakeFieldIndex("coll1"));
    index_manager->AddFieldIndex(MakeFieldIndex("coll2"));

    {
      const auto& collection_group =
          index_manager->GetNextCollectionGroupToUpdate();
      EXPECT_TRUE(collection_group.has_value());
      EXPECT_EQ(collection_group.value(), "coll1");
    }

    index_manager->UpdateCollectionGroup("coll1", IndexOffset::None());
    {
      const auto& collection_group =
          index_manager->GetNextCollectionGroupToUpdate();
      EXPECT_TRUE(collection_group.has_value());
      EXPECT_EQ(collection_group.value(), "coll2");
    }

    index_manager->UpdateCollectionGroup("coll2", IndexOffset::None());
    {
      const auto& collection_group =
          index_manager->GetNextCollectionGroupToUpdate();
      EXPECT_TRUE(collection_group.has_value());
      EXPECT_EQ(collection_group.value(), "coll1");
    }
  });
}

TEST_F(LevelDbIndexManagerTest, PersistsIndexOffset) {
  persistence->Run("CreateReadDeleteFieldsIndexes", [&]() {
    IndexManager* index_manager =
        persistence->GetIndexManager(User::Unauthenticated());
    index_manager->Start();

    index_manager->AddFieldIndex(
        MakeFieldIndex("coll1", "value", model::Segment::kAscending));
    IndexOffset offset{Version(20), Key("coll/doc"), 42};
    index_manager->UpdateCollectionGroup("coll1", offset);

    index_manager =
        persistence->GetIndexManager(credentials::User::Unauthenticated());
    index_manager->Start();

    std::vector<FieldIndex> indexes = index_manager->GetFieldIndexes("coll1");
    EXPECT_EQ(indexes.size(), 1);
    FieldIndex index = indexes[0];
    EXPECT_EQ(index.index_state().index_offset(), offset);
  });
}

TEST_F(LevelDbIndexManagerTest, DeleteFieldsIndexeRemovesAllMetadata) {
  persistence->Run("CreateReadDeleteFieldsIndexes", [&]() {
    IndexManager* index_manager =
        persistence->GetIndexManager(User::Unauthenticated());
    index_manager->Start();

    auto index = MakeFieldIndex("coll1", 0, model::FieldIndex::InitialState(),
                                "value", model::Segment::kAscending);
    index_manager->AddFieldIndex(index);
    {
      auto indexes = index_manager->GetFieldIndexes("coll1");
      EXPECT_EQ(indexes.size(), 1);
    }

    index_manager->DeleteFieldIndex(index);
    {
      auto indexes = index_manager->GetFieldIndexes("coll1");
      EXPECT_EQ(indexes.size(), 0);
    }
  });
}

TEST_F(LevelDbIndexManagerTest,
       DeleteFieldIndexRemovesEntryFromCollectionGroup) {
  persistence->Run("CreateReadDeleteFieldsIndexes", [&]() {
    IndexManager* index_manager =
        persistence->GetIndexManager(User::Unauthenticated());
    index_manager->Start();

    index_manager->AddFieldIndex(
        MakeFieldIndex("coll1", 1, IndexState{1, IndexOffset::None()}, "value",
                       model::Segment::kAscending));
    index_manager->AddFieldIndex(
        MakeFieldIndex("coll2", 2, IndexState{2, IndexOffset::None()}, "value",
                       model::Segment::kContains));
    auto collection_group = index_manager->GetNextCollectionGroupToUpdate();
    EXPECT_TRUE(collection_group);
    EXPECT_EQ(collection_group.value(), "coll1");

    std::vector<FieldIndex> indexes = index_manager->GetFieldIndexes("coll1");
    EXPECT_EQ(indexes.size(), 1);
    index_manager->DeleteFieldIndex(indexes[0]);
    collection_group = index_manager->GetNextCollectionGroupToUpdate();
    EXPECT_EQ(collection_group, "coll2");
  });
}

TEST_F(LevelDbIndexManagerTest, CanChangeUser) {
  persistence->Run("CreateReadDeleteFieldsIndexes", [&]() {
    IndexManager* index_manager =
        persistence->GetIndexManager(User::Unauthenticated());
    index_manager->Start();

    // Add two indexes and mark one as updated.
    index_manager->AddFieldIndex(
        MakeFieldIndex("coll1", 1, FieldIndex::InitialState()));
    index_manager->AddFieldIndex(
        MakeFieldIndex("coll2", 2, FieldIndex::InitialState()));
    index_manager->UpdateCollectionGroup("coll2", IndexOffset::None());

    VerifySequenceNumber(index_manager, "coll1", 0);
    VerifySequenceNumber(index_manager, "coll2", 1);

    // New user signs it. The user should see all existing field indices.
    // Sequence numbers are set to 0.
    index_manager = persistence->GetIndexManager(User("authenticated"));
    index_manager->Start();

    // Add a new index and mark it as updated.
    index_manager->AddFieldIndex(
        MakeFieldIndex("coll3", 2, FieldIndex::InitialState()));
    index_manager->UpdateCollectionGroup("coll3", IndexOffset::None());

    VerifySequenceNumber(index_manager, "coll1", 0);
    VerifySequenceNumber(index_manager, "coll2", 0);
    VerifySequenceNumber(index_manager, "coll3", 1);

    // Original user signs it. The user should also see the new index with a
    // zero sequence number.
    index_manager = persistence->GetIndexManager(User::Unauthenticated());
    index_manager->Start();

    VerifySequenceNumber(index_manager, "coll1", 0);
    VerifySequenceNumber(index_manager, "coll2", 1);
    VerifySequenceNumber(index_manager, "coll3", 0);
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
