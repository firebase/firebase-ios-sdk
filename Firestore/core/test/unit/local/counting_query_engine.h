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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_COUNTING_QUERY_ENGINE_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_COUNTING_QUERY_ENGINE_H_

#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/local/mutation_queue.h"
#include "Firestore/core/src/local/query_engine.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {

namespace core {
class Query;
}  // namespace core

namespace local {

class LocalDocumentsView;
class WrappedMutationQueue;
class WrappedRemoteDocumentCache;

/**
 * A test-only QueryEngine that forwards all API calls and exposes the number of
 * documents and mutations read.
 */
class CountingQueryEngine : public QueryEngine {
 public:
  CountingQueryEngine();

  ~CountingQueryEngine();

  void ResetCounts();

  void SetLocalDocumentsView(LocalDocumentsView* local_document) override;

  /**
   * Returns the number of documents returned by the RemoteDocumentCache's
   * `GetMatching()` API (since the last call to `ResetCounts()`)
   */
  size_t documents_read_by_query() const {
    return documents_read_by_query_;
  }

  /**
   * Returns the number of documents returned by the RemoteDocumentCache's
   * `Get()` and `GetAll()` APIs (since the last call to `ResetCounts()`)
   */
  size_t documents_read_by_key() const {
    return documents_read_by_key_;
  }

  /**
   * Returns the number of mutations returned by the MutationQueue's
   * `getAllMutationBatchesAffectingQuery()` API (since the last call to
   * `ResetCounts()`)
   */
  size_t mutations_read_by_query() const {
    return mutations_read_by_query_;
  }

  /**
   * Returns the number of mutations returned by the MutationQueue's
   * `AllMutationBatchesAffectingDocumentKey()` and
   * `AllMutationBatchesAffectingDocumentKeys()` APIs (since the last call to
   * `ResetCounts()`)
   */
  size_t mutations_read_by_key() const {
    return mutations_read_by_key_;
  }

 private:
  friend class WrappedMutationQueue;
  friend class WrappedRemoteDocumentCache;

  std::unique_ptr<LocalDocumentsView> local_documents_;
  std::unique_ptr<WrappedMutationQueue> mutation_queue_;
  std::unique_ptr<WrappedRemoteDocumentCache> remote_documents_;

  size_t mutations_read_by_query_ = 0;
  size_t mutations_read_by_key_ = 0;
  size_t documents_read_by_query_ = 0;
  size_t documents_read_by_key_ = 0;
};

/** A MutationQueue that counts document reads. */
class WrappedMutationQueue : public MutationQueue {
 public:
  WrappedMutationQueue(MutationQueue* subject,
                       CountingQueryEngine* query_engine)
      : subject_(subject), query_engine_(query_engine) {
  }

  void Start() override;

  bool IsEmpty() override;

  void AcknowledgeBatch(const model::MutationBatch& batch,
                        const nanopb::ByteString& stream_token) override;

  model::MutationBatch AddMutationBatch(
      const Timestamp& local_write_time,
      std::vector<model::Mutation>&& base_mutations,
      std::vector<model::Mutation>&& mutations) override;

  void RemoveMutationBatch(const model::MutationBatch& batch) override;

  std::vector<model::MutationBatch> AllMutationBatches() override;

  std::vector<model::MutationBatch> AllMutationBatchesAffectingDocumentKeys(
      const model::DocumentKeySet& document_keys) override;

  std::vector<model::MutationBatch> AllMutationBatchesAffectingDocumentKey(
      const model::DocumentKey& key) override;

  std::vector<model::MutationBatch> AllMutationBatchesAffectingQuery(
      const core::Query& query) override;

  absl::optional<model::MutationBatch> LookupMutationBatch(
      model::BatchId batch_id) override;

  absl::optional<model::MutationBatch> NextMutationBatchAfterBatchId(
      model::BatchId batch_id) override;

  model::BatchId GetHighestUnacknowledgedBatchId() override;

  void PerformConsistencyCheck() override;

  nanopb::ByteString GetLastStreamToken() override;

  void SetLastStreamToken(nanopb::ByteString stream_token) override;

 private:
  MutationQueue* subject_ = nullptr;
  CountingQueryEngine* query_engine_ = nullptr;
};

/** A RemoteDocumentCache that counts document reads. */
class WrappedRemoteDocumentCache : public RemoteDocumentCache {
 public:
  WrappedRemoteDocumentCache(RemoteDocumentCache* subject,
                             CountingQueryEngine* query_engine)
      : subject_(subject), query_engine_(query_engine) {
  }

  void Add(const model::MutableDocument& document,
           const model::SnapshotVersion& read_time) override;

  void Remove(const model::DocumentKey& key) override;

  model::MutableDocument Get(const model::DocumentKey& key) override;

  model::MutableDocumentMap GetAll(const model::DocumentKeySet& keys) override;

  model::MutableDocumentMap GetMatching(
      const core::Query& query,
      const model::SnapshotVersion& since_read_time) override;

 private:
  RemoteDocumentCache* subject_ = nullptr;
  CountingQueryEngine* query_engine_ = nullptr;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_COUNTING_QUERY_ENGINE_H_
