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

#include "Firestore/core/src/local/index_free_query_engine.h"
#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/query_engine.h"
#include "Firestore/core/src/local/reference_delegate.h"
#include "Firestore/core/src/local/simple_query_engine.h"
#include "Firestore/core/test/unit/local/local_store_test.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

class TestHelper : public LocalStoreTestHelper {
 public:
  explicit TestHelper(std::unique_ptr<QueryEngine> query_engine)
      : query_engine_(std::move(query_engine)) {
  }

  std::unique_ptr<Persistence> MakePersistence() override {
    return MemoryPersistenceWithEagerGcForTesting();
  }

  QueryEngine* query_engine() override {
    return query_engine_.get();
  }

  /** Returns true if the garbage collector is eager, false if LRU. */
  bool IsGcEager() const override {
    return true;
  }

 private:
  std::unique_ptr<QueryEngine> query_engine_;
};

std::unique_ptr<LocalStoreTestHelper> SimpleQueryEngineFactory() {
  return absl::make_unique<TestHelper>(absl::make_unique<SimpleQueryEngine>());
}

std::unique_ptr<LocalStoreTestHelper> IndexFreeQueryEngineFactory() {
  return absl::make_unique<TestHelper>(
      absl::make_unique<IndexFreeQueryEngine>());
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(MemoryLocalStoreTest,
                         LocalStoreTest,
                         ::testing::Values(SimpleQueryEngineFactory,
                                           IndexFreeQueryEngineFactory));

}  // namespace local
}  // namespace firestore
}  // namespace firebase
