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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_LOCAL_COUNTING_QUERY_ENGINE_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_LOCAL_COUNTING_QUERY_ENGINE_H_

#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/query_engine.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

namespace firebase {
namespace firestore {
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
  CountingQueryEngine(QueryEngine* query_engine, bool index_free)
      : query_engine_(query_engine), index_free_(index_free) {
  }

  void ResetCounts();

  void SetLocalDocumentsView(LocalDocumentsView* local_document) override;

  model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::SnapshotVersion& last_limbo_free_snapshot_version,
      const model::DocumentKeySet& remote_keys) override;

  /**
   * Returns whether the backing query engine is optimized to perform key-based
   * lookups.
   */
  // TODO(mrschmidt): Come up with a name that describes the behavior change
  bool is_index_free() {
    return index_free_;
  }

  /**
   * Returns the number of documents returned by the RemoteDocumentCache's
   * `GetMatching()` API (since the last call to `ResetCounts()`)
   */
  int documents_read_by_query() {
    return documents_read_by_query_;
  }

  /**
   * Returns the number of documents returned by the RemoteDocumentCache's
   * `Get()` and `GetAll()` APIs (since the last call to `ResetCounts()`)
   */
  int documents_read_by_key() {
    return documents_read_by_key_;
  }

  /**
   * Returns the number of mutations returned by the MutationQueue's
   * `getAllMutationBatchesAffectingQuery()` API (since the last call to
   * `ResetCounts()`)
   */
  int mutations_read_by_query() {
    return mutations_read_by_query_;
  }

  /**
   * Returns the number of mutations returned by the MutationQueue's
   * `AllMutationBatchesAffectingDocumentKey()` and
   * `AllMutationBatchesAffectingDocumentKeys()` APIs (since the last call to
   * `ResetCounts()`)
   */
  int mutations_read_by_key() {
    return mutations_read_by_key_;
  }

 private:
  friend class WrappedMutationQueue;
  friend class WrappedRemoteDocumentCache;

  QueryEngine* query_engine_;
  bool index_free_;

  std::unique_ptr<LocalDocumentsView> local_documents_;
  std::unique_ptr<WrappedMutationQueue> mutation_queue_;
  std::unique_ptr<WrappedRemoteDocumentCache> remote_documents_;

  int mutations_read_by_query_ = 0;
  int mutations_read_by_key_ = 0;
  int documents_read_by_query_ = 0;
  int documents_read_by_key_ = 0;
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
  MutationQueue* subject_;
  CountingQueryEngine* query_engine_;
};

/** A RemoteDocumentCache that counts document reads. */
class WrappedRemoteDocumentCache : public RemoteDocumentCache {
 public:
  WrappedRemoteDocumentCache(RemoteDocumentCache* subject,
                             CountingQueryEngine* query_engine)
      : subject_(subject), query_engine_(query_engine) {
  }

  void Add(const model::MaybeDocument& document,
           const model::SnapshotVersion& read_time) override;

  void Remove(const model::DocumentKey& key) override;

  absl::optional<model::MaybeDocument> Get(
      const model::DocumentKey& key) override;

  model::OptionalMaybeDocumentMap GetAll(
      const model::DocumentKeySet& keys) override;

  model::DocumentMap GetMatching(
      const core::Query& query,
      const model::SnapshotVersion& since_read_time) override;

 private:
  RemoteDocumentCache* subject_;
  CountingQueryEngine* query_engine_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_LOCAL_COUNTING_QUERY_ENGINE_H_
