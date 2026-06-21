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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_LRU_GARBAGE_COLLECTOR_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_LRU_GARBAGE_COLLECTOR_TEST_H_

#include <memory>
#include <unordered_map>

#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/reference_set.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/model/types.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

class DocumentKey;
class SetMutation;

}  // namespace model

namespace local {

class IndexManager;
class LruDelegate;
class LruGarbageCollector;
class MutationQueue;
class Persistence;
class RemoteDocumentCache;
class TargetCache;
class TargetData;
struct LruParams;

/**
 * A set of helper methods needed by LruGarbageCollectorTest that customize it
 * to the specific implementation it is testing.
 */
class LruGarbageCollectorTestHelper {
 public:
  virtual ~LruGarbageCollectorTestHelper() = default;

  /** Creates a new instance of Persistence. */
  virtual std::unique_ptr<Persistence> MakePersistence(
      LruParams lru_params) = 0;

  /** Checks whether or not a sentinel row exists for the given key. */
  virtual bool SentinelExists(const model::DocumentKey& key) = 0;
};

using FactoryFunc = std::unique_ptr<LruGarbageCollectorTestHelper> (*)();

class LruGarbageCollectorTest : public ::testing::TestWithParam<FactoryFunc> {
 protected:
  LruGarbageCollectorTest();
  ~LruGarbageCollectorTest();

  /**
   * Prepares all test members based on the given LruParams, or the defaults if
   * none are supplied.
   */
  void NewTestResources();
  void NewTestResources(LruParams lru_params);

  /** Invokes `MakePersistence` on the test helper. */
  std::unique_ptr<Persistence> MakePersistence(LruParams lru_params);

  /** Invokes `SentinelExists` on the test helper. */
  bool SentinelExists(const model::DocumentKey& key);

  /** Asserts that a sentinel does not exist. */
  void ExpectSentinelRemoved(const model::DocumentKey& key);

  /** Invokes `gc_->SequenceNumberForQueryCount` in a transaction. */
  model::ListenSequenceNumber SequenceNumberForQueryCount(int query_count);

  /** Invokes `gc_->QueryCountForPercentile` in a transaction. */
  int QueryCountForPercentile(int percentile);

  /** Invokes `gc_->RemoveTargets` in a transaction. */
  int RemoveTargets(
      model::ListenSequenceNumber sequence_number,
      const std::unordered_map<model::TargetId, TargetData>& live_queries);

  /**
   * Removes documents that are not part of a target or a mutation and have a
   * sequence number less than or equal to the given sequence number.
   */
  int RemoveOrphanedDocuments(model::ListenSequenceNumber sequence_number);

  /**
   * Creates the next test query, bumping target and sequence numbers but does
   * not actually persist the query.
   */
  TargetData NextTestQuery();

  /**
   * Calls `NextTestQuery` and adds the result to the target cache, in a new
   * transaction.
   */
  TargetData AddNextQuery();

  /**
   * Calls `NextTestQuery` and adds the result to the target cache, within an
   * existing transaction.
   */
  TargetData AddNextQueryInTransaction();

  /**
   * Updates the given query in the target cache, within an existing
   * transaction.
   */
  void UpdateTargetInTransaction(const TargetData& target_data);

  /**
   * Creates and marks a document as eligible for GC, in a new transaction.
   *
   * Simulates a document being mutated and then having that mutation ack'd.
   * Since the document is not in a mutation queue anymore, there is potentially
   * nothing keeping it alive. We mark it with the current sequence number so it
   * can be collected later.
   */
  model::DocumentKey CreateDocumentEligibleForGc();

  /**
   * Creates and marks a document as eligible for GC, in an existing
   * transaction.
   *
   * See CreateDocumentEligibleForGc for discussion.
   */
  model::DocumentKey CreateDocumentEligibleForGcInTransaction();

  /**
   * Marks a document as eligible for GC, in a new transaction.
   *
   * See CreateDocumentEligibleForGc for discussion.
   */
  void MarkDocumentEligibleForGc(const model::DocumentKey& doc_key);

  /**
   * Marks a document as eligible for GC, within an existing transaction.
   *
   * See CreateDocumentEligibleForGc for discussion.
   */
  void MarkDocumentEligibleForGcInTransaction(
      const model::DocumentKey& doc_key);

  /**
   * Adds the given document to the given target, as if the server said it
   * matched the query that the target represents.
   */
  void AddDocument(const model::DocumentKey& doc_key,
                   model::TargetId target_id);

  /**
   * Removes the given document from the given target, as if the server said it
   * no longer matched the query that the target represents.
   */
  void RemoveDocument(const model::DocumentKey& doc_key,
                      model::TargetId target_id);

  /**
   * Used to insert a document into the remote document cache. Use of this
   * method should be paired with some explanation for why it is in the cache,
   * for instance:
   *
   *   - added to a target
   *   - now has or previously had a pending mutation
   */
  model::MutableDocument CacheADocumentInTransaction();

  /**
   * Returns a new arbitrary, unsaved mutation for the document named by
   * doc_key.
   */
  model::SetMutation MutationForDocument(const model::DocumentKey& doc_key);

  /** Returns a new document key. */
  model::DocumentKey NextTestDocKey();

  /** Returns a new, unsaved document with arbitrary contents. */
  model::MutableDocument NextTestDocument();

  /** Returns a new, unsaved document with the given contents. */
  model::MutableDocument NextTestDocumentWithValue(model::ObjectValue value);

  std::unique_ptr<LruGarbageCollectorTestHelper> test_helper_;

  model::TargetId previous_target_id_ = 500;
  int previous_doc_num_ = 10;
  model::ObjectValue test_value_;
  model::ObjectValue big_object_value_;
  std::unique_ptr<Persistence> persistence_;
  TargetCache* target_cache_ = nullptr;
  RemoteDocumentCache* document_cache_ = nullptr;
  IndexManager* index_manager_ = nullptr;
  MutationQueue* mutation_queue_ = nullptr;
  LruDelegate* lru_delegate_ = nullptr;
  LruGarbageCollector* gc_ = nullptr;
  model::ListenSequenceNumber initial_sequence_number_ = 0;
  credentials::User user_;
  ReferenceSet additional_references_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_LRU_GARBAGE_COLLECTOR_TEST_H_
