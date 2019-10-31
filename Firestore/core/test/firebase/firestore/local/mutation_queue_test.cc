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

#include "Firestore/core/test/firebase/firestore/local/mutation_queue_test.h"

#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

using auth::User;
using model::DocumentKey;
using model::DocumentKeySet;
using model::kBatchIdUnknown;
using model::Mutation;
using model::MutationBatch;
using model::SetMutation;
using nanopb::ByteString;
using testutil::Key;
using testutil::Map;
using testutil::Query;

MutationQueueTestBase::MutationQueueTestBase(
    std::unique_ptr<Persistence> persistence)
    : persistence_(std::move(persistence)),
      mutation_queue_(persistence_->GetMutationQueueForUser(User("user"))) {
}

MutationQueueTestBase::~MutationQueueTestBase() = default;

/**
 * Creates a new MutationBatch with the given key, the next batch ID and a set
 * of dummy mutations.
 */
MutationBatch MutationQueueTestBase::AddMutationBatch(const std::string& key) {
  SetMutation mutation = testutil::SetMutation(key, Map("a", 1));

  MutationBatch batch =
      mutation_queue_->AddMutationBatch(Timestamp::Now(), {}, {mutation});
  return batch;
}

/**
 * Creates an array of batches containing @a number dummy MutationBatches. Each
 * has a different batch_id.
 */
std::vector<MutationBatch> MutationQueueTestBase::CreateBatches(int number) {
  std::vector<MutationBatch> batches;

  for (int i = 0; i < number; i++) {
    MutationBatch batch = AddMutationBatch();
    batches.push_back(batch);
  }

  return batches;
}

/** Returns the number of mutation batches in the mutation queue. */
size_t MutationQueueTestBase::BatchCount() {
  return mutation_queue_->AllMutationBatches().size();
}

/**
 * Removes the first n entries from the the given batches and returns them.
 *
 * @param n The number of batches to remove.
 * @param batches The array to mutate, removing entries from it.
 * @return A new array containing all the entries that were removed from @a
 * batches.
 */
std::vector<MutationBatch> MutationQueueTestBase::RemoveFirstBatches(
    size_t n, std::vector<MutationBatch>* batches) {
  std::vector<MutationBatch> removed(batches->begin(), batches->begin() + n);
  batches->erase(batches->begin(), batches->begin() + n);

  for (const MutationBatch& batch : removed) {
    mutation_queue_->RemoveMutationBatch(batch);
  }
  return removed;
}

MutationQueueTest::MutationQueueTest() : MutationQueueTestBase(GetParam()()) {
}

TEST_P(MutationQueueTest, CountBatches) {
  persistence_->Run("test_count_batches", [&] {
    ASSERT_EQ(0, BatchCount());
    ASSERT_TRUE(mutation_queue_->IsEmpty());

    MutationBatch batch1 = AddMutationBatch();
    ASSERT_EQ(1, BatchCount());
    ASSERT_FALSE(mutation_queue_->IsEmpty());

    MutationBatch batch2 = AddMutationBatch();
    ASSERT_EQ(2, BatchCount());

    mutation_queue_->RemoveMutationBatch(batch1);
    ASSERT_EQ(1, BatchCount());

    mutation_queue_->RemoveMutationBatch(batch2);
    ASSERT_EQ(0, BatchCount());
    ASSERT_TRUE(mutation_queue_->IsEmpty());
  });
}

TEST_P(MutationQueueTest, AcknowledgeBatchID) {
  persistence_->Run("test_acknowledge_batch_id", [&] {
    ASSERT_EQ(BatchCount(), 0);

    MutationBatch batch1 = AddMutationBatch();
    MutationBatch batch2 = AddMutationBatch();
    MutationBatch batch3 = AddMutationBatch();
    ASSERT_GT(batch1.batch_id(), kBatchIdUnknown);
    ASSERT_GT(batch2.batch_id(), batch1.batch_id());
    ASSERT_GT(batch3.batch_id(), batch2.batch_id());

    ASSERT_EQ(BatchCount(), 3);

    mutation_queue_->AcknowledgeBatch(batch1, {});
    mutation_queue_->RemoveMutationBatch(batch1);
    ASSERT_EQ(BatchCount(), 2);

    mutation_queue_->AcknowledgeBatch(batch2, {});
    ASSERT_EQ(BatchCount(), 2);

    mutation_queue_->RemoveMutationBatch(batch2);
    ASSERT_EQ(BatchCount(), 1);

    mutation_queue_->RemoveMutationBatch(batch3);
    ASSERT_EQ(BatchCount(), 0);
  });
}

TEST_P(MutationQueueTest, AcknowledgeThenRemove) {
  persistence_->Run("test_acknowledge_then_remove", [&] {
    MutationBatch batch1 = AddMutationBatch();

    mutation_queue_->AcknowledgeBatch(batch1, {});
    mutation_queue_->RemoveMutationBatch(batch1);

    ASSERT_EQ(BatchCount(), 0);
  });
}

TEST_P(MutationQueueTest, LookupMutationBatch) {
  // Searching on an empty queue should not find a non-existent batch
  persistence_->Run("test_lookup_mutation_batch", [&] {
    absl::optional<MutationBatch> not_found =
        mutation_queue_->LookupMutationBatch(42);
    ASSERT_EQ(not_found, absl::nullopt);

    std::vector<MutationBatch> batches = CreateBatches(10);
    std::vector<MutationBatch> removed = RemoveFirstBatches(3, &batches);

    // After removing, a batch should not be found
    for (size_t i = 0; i < removed.size(); i++) {
      not_found = mutation_queue_->LookupMutationBatch(removed[i].batch_id());
      ASSERT_EQ(not_found, absl::nullopt);
    }

    // Remaining entries should still be found
    for (const MutationBatch& batch : batches) {
      absl::optional<MutationBatch> found =
          mutation_queue_->LookupMutationBatch(batch.batch_id());
      ASSERT_EQ(found->batch_id(), batch.batch_id());
    }

    // Even on a nonempty queue searching should not find a non-existent batch
    not_found = mutation_queue_->LookupMutationBatch(42);
    ASSERT_EQ(not_found, absl::nullopt);
  });
}

TEST_P(MutationQueueTest, NextMutationBatchAfterBatchID) {
  persistence_->Run("test_next_mutation_batch_after_batch_id", [&] {
    std::vector<MutationBatch> batches = CreateBatches(10);
    std::vector<MutationBatch> removed = RemoveFirstBatches(3, &batches);

    for (size_t i = 0; i < batches.size() - 1; i++) {
      const MutationBatch& current = batches[i];
      const MutationBatch& next = batches[i + 1];
      absl::optional<MutationBatch> found =
          mutation_queue_->NextMutationBatchAfterBatchId(current.batch_id());
      ASSERT_EQ(found->batch_id(), next.batch_id());
    }

    for (size_t i = 0; i < removed.size(); i++) {
      const MutationBatch& current = removed[i];
      const MutationBatch& next = batches[0];
      absl::optional<MutationBatch> found =
          mutation_queue_->NextMutationBatchAfterBatchId(current.batch_id());
      ASSERT_EQ(found->batch_id(), next.batch_id());
    }

    const MutationBatch& first = batches[0];
    absl::optional<MutationBatch> found =
        mutation_queue_->NextMutationBatchAfterBatchId(first.batch_id() - 42);
    ASSERT_EQ(found->batch_id(), first.batch_id());

    const MutationBatch& last = batches[batches.size() - 1];
    absl::optional<MutationBatch> not_found =
        mutation_queue_->NextMutationBatchAfterBatchId(last.batch_id());
    ASSERT_EQ(not_found, absl::nullopt);
  });
}

TEST_P(MutationQueueTest, AllMutationBatchesAffectingDocumentKey) {
  persistence_->Run("test_all_mutation_batches_affecting_document_key", [&] {
    std::vector<Mutation> mutations = {
        testutil::SetMutation("foi/bar", Map("a", 1)),
        testutil::SetMutation("foo/bar", Map("a", 1)),
        testutil::PatchMutation("foo/bar", Map("b", 1), {}),
        testutil::SetMutation("foo/bar/suffix/key", Map("a", 1)),
        testutil::SetMutation("foo/baz", Map("a", 1)),
        testutil::SetMutation("food/bar", Map("a", 1)),
    };

    // Store all the mutations.
    std::vector<MutationBatch> batches;
    for (const Mutation& mutation : mutations) {
      MutationBatch batch =
          mutation_queue_->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      batches.push_back(batch);
    }

    std::vector<MutationBatch> expected{batches[1], batches[2]};
    std::vector<MutationBatch> matches =
        mutation_queue_->AllMutationBatchesAffectingDocumentKey(
            testutil::Key("foo/bar"));

    ASSERT_EQ(matches, expected);
  });
}

TEST_P(MutationQueueTest, AllMutationBatchesAffectingDocumentKeys) {
  persistence_->Run("test_all_mutation_batches_affecting_document_key", [&] {
    std::vector<Mutation> mutations = {
        testutil::SetMutation("fob/bar", Map("a", 1)),
        testutil::SetMutation("foo/bar", Map("a", 1)),
        testutil::PatchMutation("foo/bar", Map("b", 1), {}),
        testutil::SetMutation("foo/bar/suffix/key", Map("a", 1)),
        testutil::SetMutation("foo/baz", Map("a", 1)),
        testutil::SetMutation("food/bar", Map("a", 1)),
    };

    // Store all the mutations.
    std::vector<MutationBatch> batches;
    for (const Mutation& mutation : mutations) {
      MutationBatch batch =
          mutation_queue_->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      batches.push_back(batch);
    }

    DocumentKeySet keys{
        Key("foo/bar"),
        Key("foo/baz"),
    };

    std::vector<MutationBatch> expected{batches[1], batches[2], batches[4]};
    std::vector<MutationBatch> matches =
        mutation_queue_->AllMutationBatchesAffectingDocumentKeys(keys);

    ASSERT_EQ(matches, expected);
  });
}

TEST_P(MutationQueueTest,
       AllMutationBatchesAffectingDocumentKeys_handlesOverlap) {
  persistence_->Run(
      "test_all_mutation_batches_affecting_document_keys_handlesOverlap", [&] {
        std::vector<Mutation> group1 = {
            testutil::SetMutation("foo/bar", Map("a", 1)),
            testutil::SetMutation("foo/baz", Map("a", 1)),
        };
        MutationBatch batch1 = mutation_queue_->AddMutationBatch(
            Timestamp::Now(), {}, std::move(group1));

        std::vector<Mutation> group2 = {
            testutil::SetMutation("food/bar", Map("a", 1))};
        mutation_queue_->AddMutationBatch(Timestamp::Now(), {},
                                          std::move(group2));

        std::vector<Mutation> group3 = {
            testutil::SetMutation("foo/bar", Map("b", 1)),
        };
        MutationBatch batch3 = mutation_queue_->AddMutationBatch(
            Timestamp::Now(), {}, std::move(group3));

        DocumentKeySet keys{
            Key("foo/bar"),
            Key("foo/baz"),
        };

        std::vector<MutationBatch> expected{batch1, batch3};
        std::vector<MutationBatch> matches =
            mutation_queue_->AllMutationBatchesAffectingDocumentKeys(keys);

        ASSERT_EQ(matches, expected);
      });
}

TEST_P(MutationQueueTest, AllMutationBatchesAffectingQuery) {
  persistence_->Run("test_all_mutation_batches_affecting_query", [&] {
    std::vector<Mutation> mutations = {
        testutil::SetMutation("fob/bar", Map("a", 1)),
        testutil::SetMutation("foo/bar", Map("a", 1)),
        testutil::PatchMutation("foo/bar", Map("b", 1), {}),
        testutil::SetMutation("foo/bar/suffix/key", Map("a", 1)),
        testutil::SetMutation("foo/baz", Map("a", 1)),
        testutil::SetMutation("food/bar", Map("a", 1)),
    };

    // Store all the mutations.
    std::vector<MutationBatch> batches;
    for (const Mutation& mutation : mutations) {
      MutationBatch batch =
          mutation_queue_->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      batches.push_back(batch);
    }

    std::vector<MutationBatch> expected = {batches[1], batches[2], batches[4]};
    core::Query query = Query("foo");
    std::vector<MutationBatch> matches =
        mutation_queue_->AllMutationBatchesAffectingQuery(query);

    ASSERT_EQ(matches, expected);
  });
}

TEST_P(MutationQueueTest, RemoveMutationBatches) {
  persistence_->Run("test_remove_mutation_batches", [&] {
    std::vector<MutationBatch> batches = CreateBatches(10);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());

    ASSERT_EQ(BatchCount(), 9);

    std::vector<MutationBatch> found;

    found = mutation_queue_->AllMutationBatches();
    ASSERT_EQ(found, batches);
    ASSERT_EQ(found.size(), 9);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    mutation_queue_->RemoveMutationBatch(batches[1]);
    mutation_queue_->RemoveMutationBatch(batches[2]);
    batches.erase(batches.begin(), batches.begin() + 3);
    ASSERT_EQ(BatchCount(), 6);

    found = mutation_queue_->AllMutationBatches();
    ASSERT_EQ(found, batches);
    ASSERT_EQ(found.size(), 6);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    ASSERT_EQ(BatchCount(), 5);

    found = mutation_queue_->AllMutationBatches();
    ASSERT_EQ(found, batches);
    ASSERT_EQ(found.size(), 5);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    ASSERT_EQ(BatchCount(), 4);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    ASSERT_EQ(BatchCount(), 3);

    found = mutation_queue_->AllMutationBatches();
    ASSERT_EQ(found, batches);
    ASSERT_EQ(found.size(), 3);
    ASSERT_FALSE(mutation_queue_->IsEmpty());

    for (const MutationBatch& batch : batches) {
      mutation_queue_->RemoveMutationBatch(batch);
    }
    found = mutation_queue_->AllMutationBatches();
    ASSERT_EQ(found.size(), 0);
    ASSERT_TRUE(mutation_queue_->IsEmpty());
  });
}

TEST_P(MutationQueueTest, StreamToken) {
  ByteString stream_token1("token1");
  ByteString stream_token2("token2");

  persistence_->Run("test_stream_token", [&] {
    mutation_queue_->SetLastStreamToken(stream_token1);

    MutationBatch batch1 = AddMutationBatch();
    AddMutationBatch();

    ASSERT_EQ(mutation_queue_->GetLastStreamToken(), stream_token1);

    mutation_queue_->AcknowledgeBatch(batch1, stream_token2);
    ASSERT_EQ(mutation_queue_->GetLastStreamToken(), stream_token2);
  });
}

#pragma mark - Helpers

}  // namespace local
}  // namespace firestore
}  // namespace firebase
