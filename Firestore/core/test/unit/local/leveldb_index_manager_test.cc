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
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

namespace {

using model::FieldIndex;
using model::ResourcePath;
using model::Segment;
using testutil::MakeFieldIndex;

std::unique_ptr<Persistence> PersistenceFactory() {
  return LevelDbPersistenceForTesting();
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
    IndexManager* index_manager = persistence->index_manager();
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

TEST_F(LevelDbIndexManagerTest, DeleteFieldsIndexeRemovesAllMetadata) {
  persistence->Run("CreateReadDeleteFieldsIndexes", [&]() {
    IndexManager* index_manager = persistence->index_manager();
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

}  // namespace local
}  // namespace firestore
}  // namespace firebase
