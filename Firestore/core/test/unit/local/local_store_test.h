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
#include <string>
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

class LocalStoreTestBase : public testing::Test {
 protected:
  explicit LocalStoreTestBase(
      std::unique_ptr<LocalStoreTestHelper>&& test_helper);

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
  void BackfillIndexes();
  void AcknowledgeMutationWithVersion(
      int64_t document_version,
      absl::optional<nanopb::Message<google_firestore_v1_Value>>
          transform_result = absl::nullopt);
  void RejectMutation();
  std::vector<model::FieldIndex> GetFieldIndexes();
  void ConfigureFieldIndexes(
      std::vector<model::FieldIndex>&& new_field_indexes);
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

class LocalStoreTest : public LocalStoreTestBase,
                       public testing::WithParamInterface<FactoryFunc> {
 public:
  // `GetParam()` must return a factory function.
  LocalStoreTest();
};

/** Asserts that the last target ID is the given number. */
#define FSTAssertTargetID(target_id)       \
  do {                                     \
    ASSERT_EQ(last_target_id_, target_id); \
  } while (0)

/** Asserts that a the last_changes contain the docs in the given array. */
#define FSTAssertChanged(...)                               \
  do {                                                      \
    std::vector<Document> expected = {__VA_ARGS__};         \
    ASSERT_EQ(last_changes_.size(), expected.size());       \
    auto last_changes_list = DocMapToVector(last_changes_); \
    ASSERT_EQ(last_changes_list, expected);                 \
    last_changes_ = DocumentMap{};                          \
  } while (0)

/**
 * Asserts that the last ExecuteQuery results contain the docs in the given
 * array.
 */
#define FSTAssertQueryReturned(...)                                         \
  do {                                                                      \
    std::vector<std::string> expected_keys = {__VA_ARGS__};                 \
    ASSERT_EQ(last_query_result_.documents().size(), expected_keys.size()); \
    auto expected_keys_iterator = expected_keys.begin();                    \
    for (const auto& kv : last_query_result_.documents()) {                 \
      const DocumentKey& actual_key = kv.first;                             \
      DocumentKey expected_key = Key(*expected_keys_iterator);              \
      ASSERT_EQ(actual_key, expected_key);                                  \
      ++expected_keys_iterator;                                             \
    }                                                                       \
    last_query_result_ = QueryResult{};                                     \
  } while (0)

/** Asserts that the given keys were removed. */
#define FSTAssertRemoved(...)                             \
  do {                                                    \
    std::vector<std::string> key_paths = {__VA_ARGS__};   \
    ASSERT_EQ(last_changes_.size(), key_paths.size());    \
    auto key_path_iterator = key_paths.begin();           \
    for (const auto& kv : last_changes_) {                \
      const DocumentKey& actual_key = kv.first;           \
      const Document& value = kv.second;                  \
      DocumentKey expected_key = Key(*key_path_iterator); \
      ASSERT_EQ(actual_key, expected_key);                \
      ASSERT_FALSE(value->is_found_document());           \
      ++key_path_iterator;                                \
    }                                                     \
    last_changes_ = DocumentMap{};                        \
  } while (0)

/** Asserts that the given local store contains the given document. */
#define FSTAssertContains(document)                              \
  do {                                                           \
    MutableDocument expected = (document);                       \
    Document actual = local_store_.ReadDocument(expected.key()); \
    ASSERT_EQ(actual, expected);                                 \
  } while (0)

/** Asserts that the given local store does not contain the given document. */
#define FSTAssertNotContains(key_path_string)         \
  do {                                                \
    DocumentKey key = Key(key_path_string);           \
    Document actual = local_store_.ReadDocument(key); \
    ASSERT_FALSE(actual->is_valid_document());        \
  } while (0)

/**
 * Asserts the expected numbers of documents read by the RemoteDocumentCache
 * since the last call to `ResetPersistenceStats()`.
 */
#define FSTAssertRemoteDocumentsRead(by_key, by_query)             \
  do {                                                             \
    ASSERT_EQ(query_engine_.documents_read_by_key(), (by_key))     \
        << "Remote documents read (by key)";                       \
    ASSERT_EQ(query_engine_.documents_read_by_query(), (by_query)) \
        << "Remote documents read (by query)";                     \
  } while (0)

/**
 * Asserts the expected numbers of documents read by the MutationQueue since the
 * last call to `ResetPersistenceStats()`.
 */
#define FSTAssertOverlaysRead(by_key, by_query)                        \
  do {                                                                 \
    ASSERT_EQ(query_engine_.overlays_read_by_key(), (by_key))          \
        << "Mutations read (by key)";                                  \
    ASSERT_EQ(query_engine_.overlays_read_by_collection(), (by_query)) \
        << "Mutations read (by query)";                                \
  } while (0)

/**
 * Asserts the expected document keys mapped to a given target id.
 */
#define FSTAssertQueryDocumentMapping(target_id, keys)               \
  do {                                                               \
    ASSERT_EQ(local_store_.GetRemoteDocumentKeys(target_id), (keys)) \
        << "Query Document Mapping";                                 \
  } while (0)

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_LOCAL_STORE_TEST_H_
