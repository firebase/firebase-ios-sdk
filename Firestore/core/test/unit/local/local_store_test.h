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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_LOCAL_STORE_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_LOCAL_STORE_TEST_H_

#include <memory>
#include <vector>

#include "Firestore/core/src/core/core_fwd.h"
#include "Firestore/core/src/local/local_store.h"
#include "Firestore/core/src/local/query_engine.h"
#include "Firestore/core/src/local/query_result.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/test/unit/local/counting_query_engine.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

namespace remote {
class RemoteEvent;
}  // namespace remote

namespace local {

class Persistence;
class LocalStore;
class LocalViewChanges;

/**
 * A set of helper methods needed by LocalStoreTest that customize it to the
 * specific implementation it is testing.
 */
class LocalStoreTestHelper {
 public:
  virtual ~LocalStoreTestHelper() = default;

  /** Creates a new instance of Persistence. */
  virtual std::unique_ptr<Persistence> MakePersistence() = 0;

  /** Returns true if the garbage collector is eager, false if LRU. */
  virtual bool IsGcEager() const = 0;
};

using FactoryFunc = std::unique_ptr<LocalStoreTestHelper> (*)();

/**
 * These are tests for any configuration of the LocalStore.
 *
 * To test a specific configuration of LocalStore:
 *
 * + Write an implementation of LocalStoreTestHelper
 * + Call INSTANTIATE_TEST_SUITE_P(MyNewLocalStoreTest,
 *                                 LocalStoreTest,
 *                                 testing::Values(MyNewLocalStoreTestHelper));
 */
class LocalStoreTest : public ::testing::TestWithParam<FactoryFunc> {
 protected:
  LocalStoreTest();

  bool IsGcEager() const {
    return test_helper_->IsGcEager();
  }

  /**
   * Resets the count of entities read by MutationQueue and the
   * RemoteDocumentCache.
   */
  void ResetPersistenceStats();
  void WriteMutation(model::Mutation mutation);
  void WriteMutations(std::vector<model::Mutation>&& mutations);

  void ApplyRemoteEvent(const remote::RemoteEvent& event);
  void NotifyLocalViewChanges(LocalViewChanges changes);
  void AcknowledgeMutationWithVersion(
      int64_t document_version,
      absl::optional<nanopb::Message<google_firestore_v1_Value>>
          transform_result = absl::nullopt);
  void RejectMutation();
  model::TargetId AllocateQuery(core::Query query);
  local::TargetData GetTargetData(const core::Query& query);
  local::QueryResult ExecuteQuery(const core::Query& query);
  void ApplyBundledDocuments(
      const std::vector<model::MutableDocument>& documents);

  /**
   * Applies the `from_cache` state to the given target via a synthesized
   * RemoteEvent.
   */
  void UpdateViews(int target_id, bool from_cache);

  std::unique_ptr<LocalStoreTestHelper> test_helper_;

  std::unique_ptr<Persistence> persistence_;
  CountingQueryEngine query_engine_;
  LocalStore local_store_;
  std::vector<model::MutationBatch> batches_;
  model::DocumentMap last_changes_;

  model::TargetId last_target_id_ = 0;
  local::QueryResult last_query_result_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_LOCAL_STORE_TEST_H_
