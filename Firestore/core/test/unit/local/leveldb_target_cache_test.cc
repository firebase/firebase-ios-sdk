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
