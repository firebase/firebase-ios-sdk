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

#include "Firestore/core/src/firebase/firestore/local/leveldb_query_cache.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"
#include "Firestore/core/test/firebase/firestore/local/query_cache_test.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using core::Query;
using model::DocumentKey;
using model::ListenSequenceNumber;
using model::SnapshotVersion;
using model::TargetId;
using util::Path;

std::unique_ptr<Persistence> PersistenceFactory() {
  return LevelDbPersistenceForTesting();
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(LevelDbQueryCacheTest,
                         QueryCacheTest,
                         testing::Values(PersistenceFactory));

class LevelDbQueryCacheTest : public QueryCacheTestBase {
 public:
  LevelDbQueryCacheTest() : QueryCacheTestBase(PersistenceFactory()) {
  }

  LevelDbQueryCache* leveldb_cache() {
    return static_cast<LevelDbQueryCache*>(persistence_->query_cache());
  }
};

TEST_F(LevelDbQueryCacheTest, MetadataPersistedAcrossRestarts) {
  persistence_->Shutdown();
  persistence_.reset();

  Path dir = LevelDbDir();

  auto db1 = LevelDbPersistenceForTesting(dir);
  LevelDbQueryCache* query_cache = db1->query_cache();

  ASSERT_EQ(0, query_cache->highest_listen_sequence_number());
  ASSERT_EQ(0, query_cache->highest_target_id());
  SnapshotVersion version_zero;
  ASSERT_EQ(version_zero, query_cache->GetLastRemoteSnapshotVersion());

  ListenSequenceNumber minimum_sequence_number = 1234;
  TargetId last_target_id = 5;
  SnapshotVersion last_version(Timestamp(1, 2));

  db1->Run("add query data", [&] {
    Query query = testutil::Query("some/path");
    QueryData query_data(std::move(query), last_target_id,
                         minimum_sequence_number, QueryPurpose::Listen);
    query_cache->AddTarget(query_data);
    query_cache->SetLastRemoteSnapshotVersion(last_version);
  });

  db1->Shutdown();
  db1.reset();

  auto db2 = LevelDbPersistenceForTesting(dir);
  db2->Run("verify sequence number", [&] {
    // We should remember the previous sequence number, and the next transaction
    // should have a higher one.
    ASSERT_GT(db2->current_sequence_number(), minimum_sequence_number);
  });

  LevelDbQueryCache* query_cache2 = db2->query_cache();
  ASSERT_EQ(last_target_id, query_cache2->highest_target_id());
  ASSERT_EQ(last_version, query_cache2->GetLastRemoteSnapshotVersion());

  db2->Shutdown();
  db2.reset();
}

TEST_F(LevelDbQueryCacheTest, RemoveMatchingKeysForTargetID) {
  persistence_->Run("test_remove_matching_keys_for_target_id", [&]() {
    DocumentKey key1 = testutil::Key("foo/bar");
    DocumentKey key2 = testutil::Key("foo/baz");
    DocumentKey key3 = testutil::Key("foo/blah");

    LevelDbQueryCache* cache = leveldb_cache();
    AddMatchingKey(key1, 1);
    AddMatchingKey(key2, 1);
    AddMatchingKey(key3, 2);
    ASSERT_TRUE(cache->Contains(key1));
    ASSERT_TRUE(cache->Contains(key2));
    ASSERT_TRUE(cache->Contains(key3));

    cache->RemoveAllKeysForTarget(1);
    ASSERT_FALSE(cache_->Contains(key1));
    ASSERT_FALSE(cache_->Contains(key2));
    ASSERT_TRUE(cache_->Contains(key3));

    cache->RemoveAllKeysForTarget(2);
    ASSERT_FALSE(cache_->Contains(key1));
    ASSERT_FALSE(cache_->Contains(key2));
    ASSERT_FALSE(cache_->Contains(key3));
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
