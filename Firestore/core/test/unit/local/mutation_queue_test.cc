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

#include "Firestore/core/test/unit/local/mutation_queue_test.h"

#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

using credentials::User;
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
    : persistence_(std::move(persistence)) {
  User user("user");
  mutation_queue_ =
      persistence_->GetMutationQueue(user, persistence_->GetIndexManager(user));

  persistence_->Run("Start", [this] { mutation_queue_->Start(); });
}

MutationQueueTestBase::~MutationQueueTestBase() = default;

MutationBatch MutationQueueTestBase::AddMutationBatch(absl::string_view key) {
  SetMutation mutation = testutil::SetMutation(key, Map("a", 1));

  return mutation_queue_->AddMutationBatch(Timestamp::Now(), {}, {mutation});
}

std::vector<MutationBatch> MutationQueueTestBase::CreateBatches(int number) {
  std::vector<MutationBatch> batches;

  for (int i = 0; i < number; i++) {
    batches.push_back(AddMutationBatch());
  }

  return batches;
}

size_t MutationQueueTestBase::GetBatchCount() {
  return mutation_queue_->AllMutationBatches().size();
}

std::vector<MutationBatch> MutationQueueTestBase::RemoveFirstBatches(
    size_t n, std::vector<MutationBatch>* batches) {
  HARD_ASSERT(batches->size() >= n, "Not enough batches present");
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
  persistence_->Run("CountBatches", [&] {
    ASSERT_EQ(0, GetBatchCount());
    ASSERT_TRUE(mutation_queue_->IsEmpty());

    MutationBatch batch1 = AddMutationBatch();
    ASSERT_EQ(1, GetBatchCount());
    ASSERT_FALSE(mutation_queue_->IsEmpty());

    MutationBatch batch2 = AddMutationBatch();
    ASSERT_EQ(2, GetBatchCount());

    mutation_queue_->RemoveMutationBatch(batch1);
    ASSERT_EQ(1, GetBatchCount());

    mutation_queue_->RemoveMutationBatch(batch2);
    ASSERT_EQ(0, GetBatchCount());
    ASSERT_TRUE(mutation_queue_->IsEmpty());
  });
}

TEST_P(MutationQueueTest, AcknowledgeBatchId) {
  persistence_->Run("AcknowledgeBatchId", [&] {
    ASSERT_EQ(GetBatchCount(), 0);

    MutationBatch batch1 = AddMutationBatch();
    MutationBatch batch2 = AddMutationBatch();
    MutationBatch batch3 = AddMutationBatch();
    ASSERT_GT(batch1.batch_id(), kBatchIdUnknown);
    ASSERT_GT(batch2.batch_id(), batch1.batch_id());
    ASSERT_GT(batch3.batch_id(), batch2.batch_id());

    ASSERT_EQ(GetBatchCount(), 3);

    mutation_queue_->AcknowledgeBatch(batch1, {});
    mutation_queue_->RemoveMutationBatch(batch1);
    ASSERT_EQ(GetBatchCount(), 2);

    mutation_queue_->AcknowledgeBatch(batch2, {});
    ASSERT_EQ(GetBatchCount(), 2);

    mutation_queue_->RemoveMutationBatch(batch2);
    ASSERT_EQ(GetBatchCount(), 1);

    mutation_queue_->RemoveMutationBatch(batch3);
    ASSERT_EQ(GetBatchCount(), 0);
  });
}

TEST_P(MutationQueueTest, AcknowledgeThenRemove) {
  persistence_->Run("AcknowledgeThenRemove", [&] {
    MutationBatch batch1 = AddMutationBatch();

    mutation_queue_->AcknowledgeBatch(batch1, {});
    mutation_queue_->RemoveMutationBatch(batch1);

    EXPECT_EQ(GetBatchCount(), 0);
  });
}

TEST_P(MutationQueueTest, LookupMutationBatch) {
  persistence_->Run("LookupMutationBatch", [&] {
    // Searching on an empty queue should not find a non-existent batch.
    absl::optional<MutationBatch> not_found =
        mutation_queue_->LookupMutationBatch(42);
    ASSERT_EQ(not_found, absl::nullopt);

    std::vector<MutationBatch> batches = CreateBatches(10);
    std::vector<MutationBatch> removed = RemoveFirstBatches(3, &batches);

    // After removing, a batch should not be found
    for (const MutationBatch& batch : removed) {
      not_found = mutation_queue_->LookupMutationBatch(batch.batch_id());
      ASSERT_EQ(not_found, absl::nullopt);
    }

    // Remaining entries should still be found
    for (const MutationBatch& batch : batches) {
      absl::optional<MutationBatch> found =
          mutation_queue_->LookupMutationBatch(batch.batch_id());
      ASSERT_EQ(found->batch_id(), batch.batch_id());
    }

    // Even on a nonempty queue, searching should not find a non-existent batch
    not_found = mutation_queue_->LookupMutationBatch(42);
    ASSERT_EQ(not_found, absl::nullopt);
  });
}

TEST_P(MutationQueueTest, NextMutationBatchAfterBatchId) {
  persistence_->Run("NextMutationBatchAfterBatchId", [&] {
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
      // Searching for deleted batch IDs should return the next batch higest
      // batch ID that's still in the queue.
      const MutationBatch& current = removed[i];
      const MutationBatch& next = batches.front();
      absl::optional<MutationBatch> found =
          mutation_queue_->NextMutationBatchAfterBatchId(current.batch_id());
      ASSERT_EQ(found->batch_id(), next.batch_id());
    }

    const MutationBatch& first = batches.front();
    absl::optional<MutationBatch> found =
        mutation_queue_->NextMutationBatchAfterBatchId(first.batch_id() - 42);
    ASSERT_EQ(found->batch_id(), first.batch_id());

    const MutationBatch& last = batches.back();
    absl::optional<MutationBatch> not_found =
        mutation_queue_->NextMutationBatchAfterBatchId(last.batch_id());
    ASSERT_EQ(not_found, absl::nullopt);
  });
}

TEST_P(MutationQueueTest, AllMutationBatchesAffectingDocumentKey) {
  persistence_->Run("AllMutationBatchesAffectingDocumentKey", [&] {
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

    EXPECT_EQ(matches, expected);
  });
}

TEST_P(MutationQueueTest, AllMutationBatchesAffectingMultipleDocumentKeys) {
  persistence_->Run("AllMutationBatchesAffectingDocumentKeys", [&] {
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

    EXPECT_EQ(matches, expected);
  });
}

TEST_P(MutationQueueTest,
       AllMutationBatchesAffectingDocumentKeysHandlesOverlap) {
  persistence_->Run(
      "AllMutationBatchesAffectingDocumentKeysHandlesOverlap", [&] {
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

        EXPECT_EQ(matches, expected);
      });
}

TEST_P(MutationQueueTest, AllMutationBatchesAffectingQuery) {
  persistence_->Run("AllMutationBatchesAffectingQuery", [&] {
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

    EXPECT_EQ(matches, expected);
  });
}

TEST_P(MutationQueueTest, RemoveMutationBatches) {
  persistence_->Run("RemoveMutationBatches", [&] {
    std::vector<MutationBatch> batches = CreateBatches(10);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());

    ASSERT_EQ(GetBatchCount(), 9);

    std::vector<MutationBatch> found = mutation_queue_->AllMutationBatches();
    ASSERT_EQ(found, batches);
    ASSERT_EQ(found.size(), 9);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    mutation_queue_->RemoveMutationBatch(batches[1]);
    mutation_queue_->RemoveMutationBatch(batches[2]);
    batches.erase(batches.begin(), batches.begin() + 3);
    ASSERT_EQ(GetBatchCount(), 6);

    found = mutation_queue_->AllMutationBatches();
    ASSERT_EQ(found, batches);
    ASSERT_EQ(found.size(), 6);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    ASSERT_EQ(GetBatchCount(), 5);

    found = mutation_queue_->AllMutationBatches();
    ASSERT_EQ(found, batches);
    ASSERT_EQ(found.size(), 5);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    ASSERT_EQ(GetBatchCount(), 4);

    mutation_queue_->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    ASSERT_EQ(GetBatchCount(), 3);

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

  persistence_->Run("StreamToken", [&] {
    mutation_queue_->SetLastStreamToken(stream_token1);

    MutationBatch batch1 = AddMutationBatch();
    AddMutationBatch();

    ASSERT_EQ(mutation_queue_->GetLastStreamToken(), stream_token1);

    mutation_queue_->AcknowledgeBatch(batch1, stream_token2);
    ASSERT_EQ(mutation_queue_->GetLastStreamToken(), stream_token2);
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
