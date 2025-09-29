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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_QUERY_ENGINE_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_QUERY_ENGINE_TEST_H_

#include <memory>
#include <vector>

#include "Firestore/core/src/local/local_documents_view.h"
#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/query_engine.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/patch_mutation.h"
// For QueryOrPipeline, absl::optional
#include "Firestore/core/src/api/realtime_pipeline.h"  // Full definition for api::RealtimePipeline
#include "Firestore/core/src/core/pipeline_util.h"  // Defines QueryOrPipeline
#include "Firestore/core/src/remote/serializer.h"  // For remote::Serializer if needed by ConvertQueryToPipeline
#include "absl/types/optional.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

namespace core {
class Query;
// Forward declare RealtimePipeline if its full definition isn't needed here
// yet. However, QueryOrPipeline will bring it in. class RealtimePipeline; //
// from api/realtime_pipeline.h
}  // namespace core

namespace model {
class DocumentSet;
class Mutation;
class SnapshotVersion;
}  // namespace model

namespace local {

class TargetCache;
class Persistence;
class MemoryRemoteDocumentCache;
// api::RealtimePipeline is now fully included above.
// No need to forward-declare if full header included.
namespace remote {
class Serializer;  // Forward declaration
}  // namespace remote
class DocumentOverlayCache;
class MemoryIndexManager;
class MutationQueue;

class TestLocalDocumentsView : public LocalDocumentsView {
 public:
  using LocalDocumentsView::LocalDocumentsView;

  model::DocumentMap GetDocumentsMatchingQuery(
      const core::QueryOrPipeline& query,
      const model::IndexOffset& offset) override;

  void ExpectFullCollectionScan(bool full_collection_scan);

 private:
  absl::optional<bool> expect_full_collection_scan_;
};

using FactoryFunc = std::unique_ptr<Persistence> (*)();

// Parameters for QueryEngine tests, combining persistence factory and pipeline
// flag.
struct QueryEngineTestParams {
  FactoryFunc persistence_factory;
  bool use_pipeline;
};

/**
 * A test fixture for implementing tests of the QueryEngine interface.
 *
 * This is separate from QueryEngineTest below in order to make
 * additional implementation-specific tests.
 */
class QueryEngineTestBase : public testing::Test {
 protected:
  explicit QueryEngineTestBase(std::unique_ptr<Persistence>&& persistence);

  /** Adds the provided documents to the query target mapping. */
  void PersistQueryMapping(const std::vector<model::DocumentKey>& keys);

  /** Adds the provided documents to the remote document cache. */
  void AddDocuments(const std::vector<model::MutableDocument>& docs);

  /**
   * Adds the provided documents to the remote document cache in a event of the
   * given snapshot version.
   */
  void AddDocumentWithEventVersion(
      const model::SnapshotVersion& event_version,
      const std::vector<model::MutableDocument>& docs);

  /** Adds a mutation to the mutation queue. */
  void AddMutation(model::Mutation mutation);

  model::DocumentSet ExpectOptimizedCollectionScan(
      const std::function<model::DocumentSet(void)>& f);

  template <typename T>
  T ExpectFullCollectionScan(const std::function<T(void)>& f);

  // RunQuery will now use the should_use_pipeline_ member.
  model::DocumentSet RunQuery(
      const core::Query& query,
      const model::SnapshotVersion& last_limbo_free_snapshot_version);

  api::RealtimePipeline ConvertQueryToPipeline(const core::Query& query);

  std::unique_ptr<local::Persistence> persistence_;
  bool should_use_pipeline_ =
      false;  // Flag to indicate if pipeline conversion should be attempted.
  RemoteDocumentCache* remote_document_cache_ = nullptr;
  DocumentOverlayCache* document_overlay_cache_;
  IndexManager* index_manager_;
  MutationQueue* mutation_queue_ = nullptr;
  TestLocalDocumentsView local_documents_view_;
  QueryEngine query_engine_;
  local::TargetCache* target_cache_ = nullptr;
};

/**
 * These are tests for any implementation of the QueryEngine interface.
 *
 * To test a specific implementation of QueryEngine:
 *
 * + Write a persistence factory function
 * + Call INSTANTIATE_TEST_SUITE_P(MyNewQueryEngineTest,
 *                                 QueryEngineTest,
 *                                 testing::Values(
 *                                   QueryEngineTestParams{&CreateMemoryPersistence,
 * false}, QueryEngineTestParams{&CreateMemoryPersistence, true}
 *                                 ));
 */

class QueryEngineTest
    : public QueryEngineTestBase,
      public testing::WithParamInterface<QueryEngineTestParams> {
 public:
  QueryEngineTest();
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_QUERY_ENGINE_TEST_H_
