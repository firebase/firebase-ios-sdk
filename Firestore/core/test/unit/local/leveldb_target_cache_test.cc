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

#include "Firestore/core/src/local/leveldb_target_cache.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/local/target_cache_test.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
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

INSTANTIATE_TEST_SUITE_P(LevelDbTargetCacheTest,
                         TargetCacheTest,
                         testing::Values(PersistenceFactory));

class LevelDbTargetCacheTest : public TargetCacheTestBase {
 public:
  LevelDbTargetCacheTest() : TargetCacheTestBase(PersistenceFactory()) {
  }

  LevelDbTargetCache* leveldb_cache() {
    return static_cast<LevelDbTargetCache*>(persistence_->target_cache());
  }

  LevelDbPersistence* leveldb_persistence() {
    return static_cast<LevelDbPersistence*>(persistence_.get());
  }
};

TEST_F(LevelDbTargetCacheTest, MetadataPersistedAcrossRestarts) {
  persistence_->Shutdown();
  persistence_.reset();

  Path dir = LevelDbDir();

  auto db1 = LevelDbPersistenceForTesting(dir);
  LevelDbTargetCache* target_cache = db1->target_cache();

  ASSERT_EQ(0, target_cache->highest_listen_sequence_number());
  ASSERT_EQ(0, target_cache->highest_target_id());
  SnapshotVersion version_zero;
  ASSERT_EQ(version_zero, target_cache->GetLastRemoteSnapshotVersion());

  ListenSequenceNumber minimum_sequence_number = 1234;
  TargetId last_target_id = 5;
  SnapshotVersion last_version(Timestamp(1, 2));

  db1->Run("add target data", [&] {
    Query query = testutil::Query("some/path");
    TargetData target_data(query.ToTarget(), last_target_id,
                           minimum_sequence_number, QueryPurpose::Listen);
    target_cache->AddTarget(target_data);
    target_cache->SetLastRemoteSnapshotVersion(last_version);
  });

  db1->Shutdown();
  db1.reset();

  auto db2 = LevelDbPersistenceForTesting(dir);
  db2->Run("verify sequence number", [&] {
    // We should remember the previous sequence number, and the next transaction
    // should have a higher one.
    ASSERT_GT(db2->current_sequence_number(), minimum_sequence_number);
  });

  LevelDbTargetCache* target_cache2 = db2->target_cache();
  ASSERT_EQ(last_target_id, target_cache2->highest_target_id());
  ASSERT_EQ(last_version, target_cache2->GetLastRemoteSnapshotVersion());

  db2->Shutdown();
  db2.reset();
}

TEST_F(LevelDbTargetCacheTest, RemoveMatchingKeysForTargetID) {
  persistence_->Run("test_remove_matching_keys_for_target_id", [&]() {
    DocumentKey key1 = testutil::Key("foo/bar");
    DocumentKey key2 = testutil::Key("foo/baz");
    DocumentKey key3 = testutil::Key("foo/blah");

    LevelDbTargetCache* cache = leveldb_cache();
    AddMatchingKey(key1, 1);
    AddMatchingKey(key2, 1);
    AddMatchingKey(key3, 2);
    ASSERT_TRUE(cache->Contains(key1));
    ASSERT_TRUE(cache->Contains(key2));
    ASSERT_TRUE(cache->Contains(key3));

    cache->RemoveMatchingKeysForTarget(1);
    ASSERT_FALSE(cache_->Contains(key1));
    ASSERT_FALSE(cache_->Contains(key2));
    ASSERT_TRUE(cache_->Contains(key3));

    cache->RemoveMatchingKeysForTarget(2);
    ASSERT_FALSE(cache_->Contains(key1));
    ASSERT_FALSE(cache_->Contains(key2));
    ASSERT_FALSE(cache_->Contains(key3));
  });
}

// We see user issues where target data is missing for some reason, and the root
// cause is unknown. This test makes sure the SDK proceeds even when this
// happens. See: https://github.com/firebase/firebase-ios-sdk/issues/6644
TEST_F(LevelDbTargetCacheTest, SurvivesMissingTargetData) {
  persistence_->Run("test_remove_matching_keys_for_target_id", [&]() {
    TargetData target_data = MakeTargetData(query_rooms_);
    cache_->AddTarget(target_data);
    TargetId target_id = target_data.target_id();
    std::string key = LevelDbTargetKey::Key(target_id);
    leveldb_persistence()->current_transaction()->Delete(key);

    auto result = cache_->GetTarget(query_rooms_.ToTarget());
    ASSERT_EQ(result, absl::nullopt);
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
