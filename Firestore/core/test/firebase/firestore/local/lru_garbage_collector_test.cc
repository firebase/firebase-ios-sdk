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

#include "Firestore/core/test/firebase/firestore/local/lru_garbage_collector_test.h"

#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/lru_garbage_collector.h"
#include "Firestore/core/src/firebase/firestore/local/mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/local/query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/strings/str_cat.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

using auth::User;
using model::Document;
using model::DocumentKey;
using model::DocumentKeyHash;
using model::DocumentKeySet;
using model::DocumentState;
using model::ListenSequenceNumber;
using model::Mutation;
using model::ObjectValue;
using model::Precondition;
using model::SetMutation;
using model::TargetId;

using testutil::Key;
using testutil::Query;
using testutil::Version;
using testutil::WrapObject;

LruGarbageCollectorTest::LruGarbageCollectorTest()
    : test_helper_(GetParam()()),
      test_value_(WrapObject("baz", true, "ok", "fine")),
      user_("user") {
  std::string big_string(4096, 'a');
  big_object_value_ = WrapObject("BigProperty", std::move(big_string));
}

LruGarbageCollectorTest::~LruGarbageCollectorTest() = default;

void LruGarbageCollectorTest::NewTestResources() {
  return NewTestResources(LruParams::Default());
}

void LruGarbageCollectorTest::NewTestResources(LruParams lru_params) {
  HARD_ASSERT(persistence_ == nullptr, "Persistence already created");

  persistence_ = MakePersistence(lru_params);
  persistence_->reference_delegate()->AddInMemoryPins(&additional_references_);

  query_cache_ = persistence_->query_cache();
  document_cache_ = persistence_->remote_document_cache();
  mutation_queue_ = persistence_->GetMutationQueueForUser(user_);

  lru_delegate_ = static_cast<LruDelegate*>(persistence_->reference_delegate());
  initial_sequence_number_ = persistence_->Run("start querycache", [&] {
    mutation_queue_->Start();
    gc_ = lru_delegate_->garbage_collector();
    return persistence_->current_sequence_number();
  });
}

std::unique_ptr<Persistence> LruGarbageCollectorTest::MakePersistence(
    LruParams lru_params) {
  return test_helper_->MakePersistence(lru_params);
}

bool LruGarbageCollectorTest::SentinelExists(const DocumentKey& key) {
  return test_helper_->SentinelExists(key);
}

void LruGarbageCollectorTest::ExpectSentinelRemoved(const DocumentKey& key) {
  ASSERT_FALSE(SentinelExists(key));
}

// MARK: - helpers

ListenSequenceNumber LruGarbageCollectorTest::SequenceNumberForQueryCount(
    int query_count) {
  return persistence_->Run(
      "gc", [&] { return gc_->SequenceNumberForQueryCount(query_count); });
}

int LruGarbageCollectorTest::QueryCountForPercentile(int percentile) {
  return persistence_->Run(
      "query count", [&] { return gc_->QueryCountForPercentile(percentile); });
}

int LruGarbageCollectorTest::RemoveTargets(
    ListenSequenceNumber sequence_number,
    const std::unordered_map<TargetId, QueryData>& live_queries) {
  return persistence_->Run(
      "gc", [&] { return gc_->RemoveTargets(sequence_number, live_queries); });
}

int LruGarbageCollectorTest::RemoveOrphanedDocuments(
    ListenSequenceNumber sequence_number) {
  return persistence_->Run(
      "gc", [&] { return gc_->RemoveOrphanedDocuments(sequence_number); });
}

QueryData LruGarbageCollectorTest::NextTestQuery() {
  TargetId target_id = ++previous_target_id_;
  ListenSequenceNumber listen_sequence_number =
      persistence_->current_sequence_number();
  core::Query query = Query(absl::StrCat("path", target_id));
  return QueryData(query.ToTarget(), target_id, listen_sequence_number,
                   QueryPurpose::Listen);
}

QueryData LruGarbageCollectorTest::AddNextQuery() {
  return persistence_->Run("adding query",
                           [&] { return AddNextQueryInTransaction(); });
}

QueryData LruGarbageCollectorTest::AddNextQueryInTransaction() {
  QueryData query_data = NextTestQuery();
  query_cache_->AddTarget(query_data);
  return query_data;
}

void LruGarbageCollectorTest::UpdateTargetInTransaction(
    const QueryData& query_data) {
  QueryData updated =
      query_data.WithSequenceNumber(persistence_->current_sequence_number());
  query_cache_->UpdateTarget(updated);
}

DocumentKey LruGarbageCollectorTest::CreateDocumentEligibleForGc() {
  DocumentKey key = NextTestDocKey();
  MarkDocumentEligibleForGc(key);
  return key;
}

DocumentKey
LruGarbageCollectorTest::CreateDocumentEligibleForGcInTransaction() {
  DocumentKey key = NextTestDocKey();
  MarkDocumentEligibleForGcInTransaction(key);
  return key;
}

void LruGarbageCollectorTest::MarkDocumentEligibleForGc(
    const DocumentKey& doc_key) {
  persistence_->Run("Removing mutation reference",
                    [&] { MarkDocumentEligibleForGcInTransaction(doc_key); });
}

void LruGarbageCollectorTest::MarkDocumentEligibleForGcInTransaction(
    const DocumentKey& doc_key) {
  persistence_->reference_delegate()->RemoveMutationReference(doc_key);
}

void LruGarbageCollectorTest::AddDocument(const DocumentKey& doc_key,
                                          TargetId target_id) {
  query_cache_->AddMatchingKeys(DocumentKeySet{doc_key}, target_id);
}

void LruGarbageCollectorTest::RemoveDocument(const DocumentKey& doc_key,
                                             TargetId target_id) {
  query_cache_->RemoveMatchingKeys(DocumentKeySet{doc_key}, target_id);
}

Document LruGarbageCollectorTest::CacheADocumentInTransaction() {
  Document doc = NextTestDocument();
  document_cache_->Add(doc);
  return doc;
}

SetMutation LruGarbageCollectorTest::MutationForDocument(
    const DocumentKey& doc_key) {
  return SetMutation(doc_key, test_value_, Precondition::None());
}

DocumentKey LruGarbageCollectorTest::NextTestDocKey() {
  return Key("docs/doc_" + std::to_string(++previous_doc_num_));
}

Document LruGarbageCollectorTest::NextTestDocumentWithValue(ObjectValue value) {
  DocumentKey key = NextTestDocKey();
  return Document(std::move(value), std::move(key), Version(2),
                  DocumentState::kSynced);
}

Document LruGarbageCollectorTest::NextTestDocument() {
  return NextTestDocumentWithValue(test_value_);
}

// MARK: - tests

TEST_P(LruGarbageCollectorTest, PickSequenceNumberPercentile) {
  const int num_test_cases = 5;
  struct Case {
    // number of queries to cache
    int queries;
    // number expected to be calculated as 10%
    int expected;
  };
  Case test_cases[num_test_cases] = {{0, 0}, {10, 1}, {9, 0}, {50, 5}, {49, 4}};

  for (int i = 0; i < num_test_cases; i++) {
    // Fill the query cache.
    int num_queries = test_cases[i].queries;
    int expected_tenth_percentile = test_cases[i].expected;
    NewTestResources();
    for (int j = 0; j < num_queries; j++) {
      AddNextQuery();
    }

    int tenth = QueryCountForPercentile(10);
    ASSERT_EQ(expected_tenth_percentile, tenth)
        << "Total query count: " << num_queries;
    persistence_->Shutdown();
    persistence_.reset();
  }
}

TEST_P(LruGarbageCollectorTest, SequenceNumberNoQueries) {
  // No queries... should get invalid sequence number (-1)
  NewTestResources();
  ASSERT_EQ(local::kListenSequenceNumberInvalid,
            SequenceNumberForQueryCount(0));
}

TEST_P(LruGarbageCollectorTest, SequenceNumberForFiftyQueries) {
  // Add 50 queries sequentially, aim to collect 10 of them.
  // The sequence number to collect should be 10 past the initial sequence
  // number.
  NewTestResources();
  for (int i = 0; i < 50; i++) {
    AddNextQuery();
  }

  ASSERT_EQ(initial_sequence_number_ + 10, SequenceNumberForQueryCount(10));
}

TEST_P(LruGarbageCollectorTest,
       SequenceNumberForMultipleQueriesInATransaction) {
  // 50 queries, 9 with one transaction, incrementing from there. Should get
  // second sequence number.
  NewTestResources();
  persistence_->Run("9 queries in a batch", [&] {
    for (int i = 0; i < 9; i++) {
      AddNextQueryInTransaction();
    }
  });

  for (int i = 9; i < 50; i++) {
    AddNextQuery();
  }

  ASSERT_EQ(2 + initial_sequence_number_, SequenceNumberForQueryCount(10));
}

// Ensure that even if all of the queries are added in a single transaction, we
// still pick a sequence number and GC. In this case, the initial transaction
// contains all of the targets that will get GC'd, since they account for more
// than the first 10 targets.
TEST_P(LruGarbageCollectorTest, AllCollectedQueriesInSingleTransaction) {
  // 50 queries, 11 with one transaction, incrementing from there. Should get
  // first sequence number.
  NewTestResources();
  persistence_->Run("11 queries in a transaction", [&] {
    for (int i = 0; i < 11; i++) {
      AddNextQueryInTransaction();
    }
  });

  for (int i = 11; i < 50; i++) {
    AddNextQuery();
  }

  // We expect to GC the targets from the first transaction, since they account
  // for at least the first 10 of the targets.
  ASSERT_EQ(1 + initial_sequence_number_, SequenceNumberForQueryCount(10));
}

TEST_P(LruGarbageCollectorTest,
       SequenceNumbersWithMutationAndSequentialQueries) {
  // Remove a mutated doc reference, marking it as eligible for GC.
  // Then add 50 queries. Should get 10 past initial (9 queries).
  NewTestResources();
  CreateDocumentEligibleForGc();
  for (int i = 0; i < 50; i++) {
    AddNextQuery();
  }

  ASSERT_EQ(10 + initial_sequence_number_, SequenceNumberForQueryCount(10));
}

TEST_P(LruGarbageCollectorTest, SequenceNumbersWithMutationsInQueries) {
  // Add mutated docs, then add one of them to a query target so it doesn't get
  // GC'd. Expect 3 past the initial value: the mutations not part of a query,
  // and two queries.
  NewTestResources();
  Document doc_in_query = NextTestDocument();
  persistence_->Run("mark mutations", [&] {
    // Adding 9 doc keys in a transaction. If we remove one of them, we'll have
    // room for two actual queries.
    MarkDocumentEligibleForGcInTransaction(doc_in_query.key());
    for (int i = 0; i < 8; i++) {
      CreateDocumentEligibleForGcInTransaction();
    }
  });

  for (int i = 0; i < 49; i++) {
    AddNextQuery();
  }

  persistence_->Run("query with mutation", [&] {
    QueryData query_data = AddNextQueryInTransaction();
    // This should keep the document from getting GC'd, since it is no longer
    // orphaned.
    AddDocument(doc_in_query.key(), query_data.target_id());
  });

  // This should catch the remaining 8 documents, plus the first two queries we
  // added.
  ASSERT_EQ(3 + initial_sequence_number_, SequenceNumberForQueryCount(10));
}

TEST_P(LruGarbageCollectorTest, RemoveQueriesUpThroughSequenceNumber) {
  NewTestResources();
  std::unordered_map<TargetId, QueryData> live_queries;
  for (int i = 0; i < 100; i++) {
    QueryData query_data = AddNextQuery();
    // Mark odd queries as live so we can test filtering out live queries.
    if (query_data.target_id() % 2 == 1) {
      live_queries[query_data.target_id()] = query_data;
    }
  }

  // GC up through 20th query, which is 20%.
  // Expect to have GC'd 10 targets, since every other target is live
  int removed = RemoveTargets(20 + initial_sequence_number_, live_queries);
  ASSERT_EQ(10, removed);

  // Make sure we removed the even targets with target_id <= 20.
  persistence_->Run("verify remaining targets are > 20 or odd", [&] {
    query_cache_->EnumerateTargets([&](const QueryData& query_data) {
      ASSERT_TRUE(query_data.target_id() > 20 ||
                  query_data.target_id() % 2 == 1);
    });
  });
}

TEST_P(LruGarbageCollectorTest, RemoveOrphanedDocuments) {
  NewTestResources();
  // Track documents we expect to be retained so we can verify post-GC. This
  // will contain documents associated with targets that survive GC, as well as
  // any documents with pending mutations.
  std::unordered_set<DocumentKey, DocumentKeyHash> expected_retained;

  // Add two mutations later, for now track them in a vector.
  std::vector<Mutation> mutations;

  // Add a target and add two documents to it. The documents are expected to be
  // retained, since their membership in the target keeps them alive.
  persistence_->Run("add a target and add two documents to it", [&] {
    // Add two documents to first target, queue a mutation on the second
    // document.
    QueryData query_data = AddNextQueryInTransaction();
    Document doc1 = CacheADocumentInTransaction();
    AddDocument(doc1.key(), query_data.target_id());
    expected_retained.insert(doc1.key());

    Document doc2 = CacheADocumentInTransaction();
    AddDocument(doc2.key(), query_data.target_id());
    expected_retained.insert(doc2.key());
    mutations.push_back(MutationForDocument(doc2.key()));
  });

  // Add a second query and register a third document on it.
  persistence_->Run("second query", [&] {
    QueryData query_data = AddNextQueryInTransaction();
    Document doc3 = CacheADocumentInTransaction();
    expected_retained.insert(doc3.key());
    AddDocument(doc3.key(), query_data.target_id());
  });

  // Cache another document and prepare a mutation on it.
  persistence_->Run("queue a mutation", [&] {
    Document doc4 = CacheADocumentInTransaction();
    mutations.push_back(MutationForDocument(doc4.key()));
    expected_retained.insert(doc4.key());
  });

  // Insert the mutations. These operations don't have a sequence number, they
  // just serve to keep the mutated documents from being GC'd while the
  // mutations are outstanding.
  persistence_->Run("actually register the mutations", [&] {
    Timestamp write_time = Timestamp::Now();
    mutation_queue_->AddMutationBatch(write_time, {}, std::move(mutations));
  });

  // Mark 5 documents eligible for GC. This simulates documents that were
  // mutated then ack'd. Since they were ack'd, they are no longer in a mutation
  // queue, and there is nothing keeping them alive.
  std::unordered_set<DocumentKey, DocumentKeyHash> to_be_removed;
  persistence_->Run("add orphaned docs (previously mutated, then ack'd)", [&] {
    for (int i = 0; i < 5; i++) {
      Document doc = CacheADocumentInTransaction();
      to_be_removed.insert(doc.key());
      MarkDocumentEligibleForGcInTransaction(doc.key());
    }
  });

  // We expect only the orphaned documents, those not in a mutation or a target,
  // to be removed. Use a large sequence number to remove as much as possible.
  int removed = RemoveOrphanedDocuments(1000);
  ASSERT_EQ(to_be_removed.size(), removed);
  persistence_->Run("verify", [&] {
    for (const DocumentKey& key : to_be_removed) {
      ASSERT_EQ(document_cache_->Get(key), absl::nullopt);
      ASSERT_FALSE(query_cache_->Contains(key));
    }
    for (const DocumentKey& key : expected_retained) {
      ASSERT_NE(document_cache_->Get(key), absl::nullopt)
          << "Missing document " << key.ToString().c_str();
    }
  });
}

// TODO(gsoltis): write a test that includes limbo documents

TEST_P(LruGarbageCollectorTest, RemoveTargetsThenGC) {
  // Setup:
  //   - Create 3 targets, add docs to all of them.
  //   - Leave oldest target alone, it is still alive.
  //   - Remove newest target.
  //   - Blind write 2 documents.
  //   - Add one of the blind write docs to the oldest target (preserves it).
  //   - Remove some documents from middle target (bumps sequence number).
  //   - Add some documents from newest target to the oldest target (preserves
  //   - them).
  //   - Update a doc from middle target.
  //   - Remove middle target.
  //   - Do a blind write.
  //   - GC up to but not including the removal of the middle target.
  //
  // Expect:
  //   - All docs in oldest target are still around.
  //   - One blind write is gone, the first one not added to the oldest target.
  //   - Documents removed from middle target are gone, except ones added to
  //     oldest target.
  //   - Documents from newest target are gone, except ones added to the oldest
  //     target.

  NewTestResources();

  // Through the various steps, track which documents we expect to be removed vs
  // documents we expect to be retained.
  std::unordered_set<DocumentKey, DocumentKeyHash> expected_retained;
  std::unordered_set<DocumentKey, DocumentKeyHash> expected_removed;

  // Add oldest target, 5 documents, and add those documents to the target.
  // This target will not be removed, so all documents that are part of it will
  // be retained.
  QueryData oldest_target =
      persistence_->Run("Add oldest target and docs", [&] {
        QueryData query_data = AddNextQueryInTransaction();
        for (int i = 0; i < 5; i++) {
          Document doc = CacheADocumentInTransaction();
          expected_retained.insert(doc.key());
          AddDocument(doc.key(), query_data.target_id());
        }
        return query_data;
      });

  // Add middle target and docs. Some docs will be removed from this target
  // later, which we track here.
  DocumentKeySet middle_docs_to_remove;

  // This will be the document in this target that gets an update later
  DocumentKey middle_doc_to_update;
  QueryData middle_target =
      persistence_->Run("Add middle target and docs", [&] {
        QueryData middle_target = AddNextQueryInTransaction();

        // These docs will be removed from this target later, triggering a bump
        // to their sequence numbers. Since they will not be a part of the
        // target, we expect them to be removed.
        for (int i = 0; i < 2; i++) {
          Document doc = CacheADocumentInTransaction();
          expected_removed.insert(doc.key());
          AddDocument(doc.key(), middle_target.target_id());
          middle_docs_to_remove = middle_docs_to_remove.insert(doc.key());
        }

        // These docs stay in this target and only this target. There presence
        // in this target prevents them from being GC'd, so they are also
        // expected to be retained.
        for (int i = 2; i < 4; i++) {
          Document doc = CacheADocumentInTransaction();
          expected_retained.insert(doc.key());
          AddDocument(doc.key(), middle_target.target_id());
        }

        // This doc stays in this target, but gets updated.
        {
          Document doc = CacheADocumentInTransaction();
          expected_retained.insert(doc.key());
          AddDocument(doc.key(), middle_target.target_id());
          middle_doc_to_update = doc.key();
        }
        return middle_target;
      });

  // Add the newest target and add 5 documents to it. Some of those documents
  // will additionally be added to the oldest target, which will cause those
  // documents to be retained. The remaining documents are expected to be
  // removed, since this target will be removed.
  DocumentKeySet newest_docs_to_add_to_oldest;
  persistence_->Run("Add newest target and docs", [&] {
    QueryData newest_target = AddNextQueryInTransaction();

    // These documents are only in this target. They are expected to be removed
    // because this target will also be removed.
    for (int i = 0; i < 3; i++) {
      Document doc = CacheADocumentInTransaction();
      expected_removed.insert(doc.key());
      AddDocument(doc.key(), newest_target.target_id());
    }

    // Docs to add to the oldest target in addition to this target. They will be
    // retained.
    for (int i = 3; i < 5; i++) {
      Document doc = CacheADocumentInTransaction();
      expected_retained.insert(doc.key());
      AddDocument(doc.key(), newest_target.target_id());
      newest_docs_to_add_to_oldest =
          newest_docs_to_add_to_oldest.insert(doc.key());
    }
  });

  // Two doc writes, add one of them to the oldest target.
  persistence_->Run("2 doc writes, add one of them to the oldest target", [&] {
    // Write two docs and have them ack'd by the server. Can skip mutation queue
    // and set them in document cache. Add potentially orphaned first, also add
    // one doc to a target.
    Document doc1 = CacheADocumentInTransaction();
    MarkDocumentEligibleForGcInTransaction(doc1.key());
    UpdateTargetInTransaction(oldest_target);
    AddDocument(doc1.key(), oldest_target.target_id());
    // doc1 should be retained by being added to oldest_target.
    expected_retained.insert(doc1.key());

    Document doc2 = CacheADocumentInTransaction();
    MarkDocumentEligibleForGcInTransaction(doc2.key());
    // Nothing is keeping doc2 around, it should be removed.
    expected_removed.insert(doc2.key());
  });

  // Remove some documents from the middle target.
  persistence_->Run("Remove some documents from the middle target", [&] {
    UpdateTargetInTransaction(middle_target);
    for (const DocumentKey& doc_key : middle_docs_to_remove) {
      RemoveDocument(doc_key, middle_target.target_id());
    }
  });

  // Add a couple docs from the newest target to the oldest (preserves them past
  // the point where newest was removed). upper_bound is the sequence number
  // right before middle_target is updated, then removed.
  ListenSequenceNumber upper_bound = persistence_->Run(
      "Add a couple docs from the newest target to the oldest", [&] {
        UpdateTargetInTransaction(oldest_target);
        for (const DocumentKey& doc_key : newest_docs_to_add_to_oldest) {
          AddDocument(doc_key, oldest_target.target_id());
        }
        return persistence_->current_sequence_number();
      });

  // Update a doc in the middle target
  persistence_->Run("Update a doc in the middle target", [&] {
    int64_t version = 3;
    Document doc(ObjectValue(test_value_), middle_doc_to_update,
                 Version(version), DocumentState::kSynced);
    document_cache_->Add(doc);
    UpdateTargetInTransaction(middle_target);
  });

  // middle_target removed here, no update needed.

  // Write a doc and get an ack, not part of a target.
  persistence_->Run("Write a doc and get an ack, not part of a target", [&] {
    Document doc = CacheADocumentInTransaction();
    // Mark it as eligible for GC, but this is after our upper bound for what we
    // will collect.
    MarkDocumentEligibleForGcInTransaction(doc.key());
    // This should be retained, it's too new to get removed.
    expected_retained.insert(doc.key());
  });

  // Finally, do the garbage collection, up to but not including the removal of
  // middle_target.
  std::unordered_map<TargetId, QueryData> live_queries{
      {oldest_target.target_id(), oldest_target}};

  int queries_removed = RemoveTargets(upper_bound, live_queries);
  ASSERT_EQ(1, queries_removed) << "Expected to remove newest target";
  int docs_removed = RemoveOrphanedDocuments(upper_bound);
  ASSERT_EQ(expected_removed.size(), docs_removed);
  persistence_->Run("verify results", [&] {
    for (const DocumentKey& key : expected_removed) {
      ASSERT_EQ(document_cache_->Get(key), absl::nullopt)
          << "Did not expect to find " << key.ToString().c_str()
          << "in document cache";
      ASSERT_FALSE(query_cache_->Contains(key))
          << "Did not expect to find " << key.ToString().c_str()
          << " in query_cache";
      ExpectSentinelRemoved(key);
    }
    for (const DocumentKey& key : expected_retained) {
      ASSERT_NE(document_cache_->Get(key), absl::nullopt)
          << "Expected to find " << key.ToString().c_str()
          << " in document cache";
    }
  });
}

TEST_P(LruGarbageCollectorTest, GetsSize) {
  NewTestResources();

  size_t initial_size = gc_->CalculateByteSize();

  persistence_->Run("fill cache", [&] {
    // Simulate a bunch of ack'd mutations.
    for (int i = 0; i < 50; i++) {
      Document doc = CacheADocumentInTransaction();
      MarkDocumentEligibleForGcInTransaction(doc.key());
    }
  });

  size_t final_size = gc_->CalculateByteSize();
  ASSERT_GT(final_size, initial_size);
}

TEST_P(LruGarbageCollectorTest, Disabled) {
  LruParams params = LruParams::Disabled();
  NewTestResources(params);

  persistence_->Run("fill cache", [&] {
    // Simulate a bunch of ack'd mutations.
    for (int i = 0; i < 500; i++) {
      Document doc = CacheADocumentInTransaction();
      MarkDocumentEligibleForGcInTransaction(doc.key());
    }
  });

  LruResults results =
      persistence_->Run("GC", [&] { return gc_->Collect({}); });
  ASSERT_FALSE(results.did_run);
}

TEST_P(LruGarbageCollectorTest, CacheTooSmall) {
  LruParams params = LruParams::Default();
  NewTestResources(params);

  persistence_->Run("fill cache", [&] {
    // Simulate a bunch of ack'd mutations.
    for (int i = 0; i < 50; i++) {
      Document doc = CacheADocumentInTransaction();
      MarkDocumentEligibleForGcInTransaction(doc.key());
    }
  });

  int64_t cache_size = gc_->CalculateByteSize();
  // Verify that we don't have enough in our cache to warrant collection.
  ASSERT_LT(cache_size, params.min_bytes_threshold);

  // Try collection and verify that it didn't run.
  LruResults results =
      persistence_->Run("GC", [&] { return gc_->Collect({}); });
  ASSERT_FALSE(results.did_run);
}

TEST_P(LruGarbageCollectorTest, GCRan) {
  LruParams params = LruParams::Default();
  // Set a low threshold so we will definitely run.
  params.min_bytes_threshold = 100;
  NewTestResources(params);

  // Add 100 targets and 10 documents to each.
  for (int i = 0; i < 100; i++) {
    // Use separate transactions so that each target and associated documents
    // get their own sequence number.
    persistence_->Run("Add a target and some documents", [&] {
      QueryData query_data = AddNextQueryInTransaction();
      for (int j = 0; j < 10; j++) {
        Document doc = CacheADocumentInTransaction();
        AddDocument(doc.key(), query_data.target_id());
      }
    });
  }

  // Mark nothing as live, so everything is eligible.
  LruResults results =
      persistence_->Run("GC", [&] { return gc_->Collect({}); });

  // By default, we collect 10% of the sequence numbers. Since we added 100
  // targets, that should be 10 targets with 10 documents each, for a total of
  // 100 documents.
  ASSERT_TRUE(results.did_run);
  ASSERT_EQ(10, results.targets_removed);
  ASSERT_EQ(100, results.documents_removed);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
