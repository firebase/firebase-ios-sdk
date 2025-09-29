/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/local/query_engine_test.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

std::unique_ptr<Persistence> PersistenceFactory() {
  return MemoryPersistenceWithEagerGcForTesting();
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(
    MemoryQueryEngineTest,
    QueryEngineTest,
    testing::Values(
        QueryEngineTestParams{PersistenceFactory, /*use_pipeline=*/false},
        QueryEngineTestParams{PersistenceFactory, /*use_pipeline=*/true}));

}  // namespace local
}  // namespace firestore
}  // namespace firebase
