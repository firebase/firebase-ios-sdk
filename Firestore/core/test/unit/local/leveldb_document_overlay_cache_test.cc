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

#include <type_traits>

#include "Firestore/core/src/local/leveldb_document_overlay_cache.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/test/unit/local/document_overlay_cache_test.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

// A friend class of `LevelDbDocumentOverlayCache` that can access private
// members. This class is intentionally kept separate from
// `LevelDbDocumentOverlayCacheTest` to avoid accidentally accessing private
// members of `LevelDbDocumentOverlayCache` in tests.
class LevelDbDocumentOverlayCacheTestHelper final {
 public:
  LevelDbDocumentOverlayCacheTestHelper() = delete;

  static int GetLargestBatchIdIndexEntryCount(
      const LevelDbDocumentOverlayCache& instance) {
    return instance.GetLargestBatchIdIndexEntryCount();
  }

  static int GetCollectionIndexEntryCount(
      const LevelDbDocumentOverlayCache& instance) {
    return instance.GetCollectionIndexEntryCount();
  }

  static int GetCollectionGroupIndexEntryCount(
      const LevelDbDocumentOverlayCache& instance) {
    return instance.GetCollectionGroupIndexEntryCount();
  }
};

namespace {

using model::Mutation;
using testutil::Map;
using testutil::PatchMutation;

std::unique_ptr<Persistence> PersistenceFactory() {
  return LevelDbPersistenceForTesting();
}

INSTANTIATE_TEST_SUITE_P(LevelDbDocumentOverlayCacheTest,
                         DocumentOverlayCacheTest,
                         testing::Values(PersistenceFactory));

class LevelDbDocumentOverlayCacheTest : public DocumentOverlayCacheTestBase {
 public:
  LevelDbDocumentOverlayCacheTest()
      : DocumentOverlayCacheTestBase(PersistenceFactory()) {
  }

  void ExpectDatabaseEntryAndIndexCount(int expected_count) {
    LevelDbDocumentOverlayCache& cache =
        *static_cast<LevelDbDocumentOverlayCache*>(cache_);
    {
      SCOPED_TRACE("GetOverlayCount");
      EXPECT_EQ(GetOverlayCount(), expected_count);
    }
    {
      SCOPED_TRACE("GetLargestBatchIdIndexEntryCount");
      EXPECT_EQ(LevelDbDocumentOverlayCacheTestHelper::
                    GetLargestBatchIdIndexEntryCount(cache),
                expected_count);
    }
    {
      SCOPED_TRACE("GetCollectionIndexEntryCount");
      EXPECT_EQ(
          LevelDbDocumentOverlayCacheTestHelper::GetCollectionIndexEntryCount(
              cache),
          expected_count);
    }
    {
      SCOPED_TRACE("GetCollectionGroupIndexEntryCount");
      EXPECT_EQ(LevelDbDocumentOverlayCacheTestHelper::
                    GetCollectionGroupIndexEntryCount(cache),
                expected_count);
    }
  }
};

TEST_F(LevelDbDocumentOverlayCacheTest, TypeTraits) {
  static_assert(!std::is_copy_constructible<LevelDbDocumentOverlayCache>::value,
                "is_copy_constructible");
  static_assert(!std::is_move_constructible<LevelDbDocumentOverlayCache>::value,
                "is_move_constructible");
  static_assert(!std::is_copy_assignable<LevelDbDocumentOverlayCache>::value,
                "is_copy_assignable");
  static_assert(!std::is_move_assignable<LevelDbDocumentOverlayCache>::value,
                "is_move_assignable");
}

TEST_F(LevelDbDocumentOverlayCacheTest, IndexesAreCreatedAndDestroyed) {
  persistence_->Run("Test", [&] {
    // Add some overlays and ensure that an index entry is created for each one.
    {
      SCOPED_TRACE("checkpoint 1");
      Mutation mutation1 = PatchMutation("coll/doc1", Map("foo", "1"));
      Mutation mutation2 = PatchMutation("coll/doc2", Map("foo", "2"));
      this->SaveOverlaysWithMutations(100, {mutation1, mutation2});
      ExpectDatabaseEntryAndIndexCount(2);
    }

    // Replace the overlays and ensure that the existing indexes are updated.
    {
      SCOPED_TRACE("checkpoint 2");
      Mutation mutation1 = PatchMutation("coll/doc1", Map("foo", "1_mod"));
      Mutation mutation2 = PatchMutation("coll/doc2", Map("foo", "2_mod"));
      this->SaveOverlaysWithMutations(101, {mutation1, mutation2});
      ExpectDatabaseEntryAndIndexCount(2);
    }

    // Add some overlays for different documents and ensure that index entries
    // are added for each.
    {
      SCOPED_TRACE("checkpoint 3");
      Mutation mutation1 = PatchMutation("coll/doc3", Map("foo", "1"));
      Mutation mutation2 = PatchMutation("coll/doc4", Map("foo", "2"));
      this->SaveOverlaysWithMutations(102, {mutation1, mutation2});
      ExpectDatabaseEntryAndIndexCount(4);
    }

    // Delete the overlays for the original largest_batch_id, for which the
    // documents have been moved to a new largest_batch_id, and ensure that
    // this does not affect the number of indexes.
    {
      SCOPED_TRACE("checkpoint 4");
      this->cache_->RemoveOverlaysForBatchId(100);
      ExpectDatabaseEntryAndIndexCount(4);
    }

    // Delete the overlays for the 2nd largest_batch_id, to which the original
    // documents have been moved, and ensure that the corresponding indexes are
    // deleted.
    {
      SCOPED_TRACE("checkpoint 5");
      this->cache_->RemoveOverlaysForBatchId(101);
      ExpectDatabaseEntryAndIndexCount(2);
    }

    // Delete the overlays for the sole remaining largest_batch_id and ensure
    // that the remaining indexes are deleted.
    {
      SCOPED_TRACE("checkpoint 6");
      this->cache_->RemoveOverlaysForBatchId(102);
      ExpectDatabaseEntryAndIndexCount(0);
    }

    // Add some new overlays and ensure that index entries are created.
    {
      SCOPED_TRACE("checkpoint 7");
      Mutation mutation1 = PatchMutation("coll/doc50", Map("foo", "1"));
      Mutation mutation2 = PatchMutation("coll/doc51", Map("foo", "2"));
      Mutation mutation3 = PatchMutation("coll/doc52", Map("foo", "3"));
      this->SaveOverlaysWithMutations(200, {mutation1, mutation2, mutation3});
      ExpectDatabaseEntryAndIndexCount(3);
    }
  });
}

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase
