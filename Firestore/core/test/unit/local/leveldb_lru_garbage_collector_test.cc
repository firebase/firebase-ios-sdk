/*
 * Copyright 2019 Google LLC
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

#include <string>

#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/lru_garbage_collector.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/test/unit/local/lru_garbage_collector_test.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using model::DocumentKey;

class TestHelper : public LruGarbageCollectorTestHelper {
 public:
  std::unique_ptr<Persistence> MakePersistence(LruParams lru_params) override {
    auto persistence = LevelDbPersistenceForTesting(lru_params);
    leveldb_persistence_ = persistence.get();
    return persistence;
  }

  bool SentinelExists(const DocumentKey& key) override {
    std::string sentinel_key = LevelDbDocumentTargetKey::SentinelKey(key);
    std::string unused_value;
    auto txn = leveldb_persistence_->current_transaction();
    return !txn->Get(sentinel_key, &unused_value).IsNotFound();
  }

 private:
  LevelDbPersistence* leveldb_persistence_ = nullptr;
};

std::unique_ptr<LruGarbageCollectorTestHelper> Factory() {
  return absl::make_unique<TestHelper>();
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(LevelDbLruGarbageCollectorTest,
                         LruGarbageCollectorTest,
                         ::testing::Values(Factory));

}  // namespace local
}  // namespace firestore
}  // namespace firebase
