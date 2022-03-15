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

#include "Firestore/core/test/unit/local/document_overlay_cache_test.h"

#include <memory>
#include <string>
#include <type_traits>
#include <unordered_set>
#include <vector>

#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/document_overlay_cache.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

using credentials::User;
using model::DocumentKey;
using model::Mutation;
using model::Overlay;
using model::ResourcePath;
using ::testing::UnorderedElementsAreArray;
using testutil::DeleteMutation;
using testutil::Map;
using testutil::PatchMutation;
using testutil::SetMutation;

// A friend class of `DocumentOverlayCache` that can access private members.
// This class is intentionally kept separate from `DocumentOverlayCacheTestBase`
// and `DocumentOverlayCacheTest` to avoid accidentally accessing private
// members of `DocumentOverlayCache` in tests.
class DocumentOverlayCacheTestHelper final {
 public:
  DocumentOverlayCacheTestHelper() = delete;

  static int GetOverlayCount(const DocumentOverlayCache& instance) {
    return instance.GetOverlayCount();
  }
};

DocumentOverlayCacheTestBase::DocumentOverlayCacheTestBase(
    std::unique_ptr<Persistence> persistence)
    : persistence_(std::move(persistence)),
      cache_(persistence_->GetDocumentOverlayCache(User("user"))) {
}

void DocumentOverlayCacheTestBase::SaveOverlaysWithMutations(
    int largest_batch_id, const std::vector<Mutation>& mutations) {
  DocumentOverlayCache::MutationByDocumentKeyMap data;
  for (const auto& mutation : mutations) {
    ASSERT_TRUE(data.find(mutation.key()) == data.end());
    data.insert({mutation.key(), mutation});
  }
  this->cache_->SaveOverlays(largest_batch_id, data);
}

void DocumentOverlayCacheTestBase::SaveOverlaysWithSetMutations(
    int largest_batch_id, const std::vector<std::string>& keys) {
  DocumentOverlayCache::MutationByDocumentKeyMap data;
  for (const auto& key : keys) {
    DocumentKey document_key = DocumentKey::FromPathString(key);
    ASSERT_TRUE(data.find(document_key) == data.end());
    data.insert({document_key, SetMutation(key, Map())});
  }
  this->cache_->SaveOverlays(largest_batch_id, data);
}

void DocumentOverlayCacheTestBase::ExpectCacheContainsOverlaysFor(
    const std::vector<std::string>& keys) {
  for (const std::string& key : keys) {
    SCOPED_TRACE(absl::StrCat("key=", key));
    const DocumentKey document_key = DocumentKey::FromPathString(key);
    EXPECT_TRUE(this->cache_->GetOverlay(document_key));
  }
}

void DocumentOverlayCacheTestBase::ExpectCacheDoesNotContainOverlaysFor(
    const std::vector<std::string>& keys) {
  for (const std::string& key : keys) {
    SCOPED_TRACE(absl::StrCat("key=", key));
    const DocumentKey document_key = DocumentKey::FromPathString(key);
    EXPECT_FALSE(this->cache_->GetOverlay(document_key));
  }
}

int DocumentOverlayCacheTestBase::GetOverlayCount() const {
  return DocumentOverlayCacheTestHelper::GetOverlayCount(*cache_);
}

DocumentOverlayCacheTest::DocumentOverlayCacheTest()
    : DocumentOverlayCacheTestBase(GetParam()()) {
}

namespace {

void VerifyOverlayContains(
    const DocumentOverlayCache::OverlayByDocumentKeyMap& overlays,
    const std::unordered_set<std::string>& keys) {
  using DocumentKeySet =
      std::unordered_set<DocumentKey, model::DocumentKeyHash>;

  DocumentKeySet actual_keys;
  for (const auto& overlays_entry : overlays) {
    actual_keys.insert(overlays_entry.first);
  }

  DocumentKeySet expected_keys;
  for (const auto& key : keys) {
    expected_keys.insert(DocumentKey::FromPathString(key));
  }

  EXPECT_THAT(actual_keys, UnorderedElementsAreArray(expected_keys));
}

TEST(DocumentOverlayCacheTest, TypeTraits) {
  static_assert(!std::is_constructible<DocumentOverlayCache>::value,
                "is_constructible");
  static_assert(std::is_abstract<DocumentOverlayCache>::value, "is_abstract");
  static_assert(std::has_virtual_destructor<DocumentOverlayCache>::value,
                "has_virtual_destructor");
}

TEST_P(DocumentOverlayCacheTest, ReturnsNullWhenOverlayIsNotFound) {
  this->persistence_->Run("Test", [&] {
    EXPECT_FALSE(
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1")));
  });
}

TEST_P(DocumentOverlayCacheTest, CanReadSavedOverlay) {
  this->persistence_->Run("Test", [&] {
    Mutation mutation = PatchMutation("coll/doc1", Map("foo", "bar"));
    this->SaveOverlaysWithMutations(2, {mutation});

    auto overlay_opt =
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1"));

    ASSERT_TRUE(overlay_opt);
    EXPECT_EQ(mutation, overlay_opt.value().mutation());
  });
}

TEST_P(DocumentOverlayCacheTest, CanReadSavedOverlays) {
  this->persistence_->Run("Test", [&] {
    Mutation m1 = PatchMutation("coll/doc1", Map("foo", "bar"));
    Mutation m2 = SetMutation("coll/doc2", Map("foo", "bar"));
    Mutation m3 = DeleteMutation("coll/doc3");
    this->SaveOverlaysWithMutations(3, {m1, m2, m3});

    auto overlay_opt1 =
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1"));
    auto overlay_opt2 =
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc2"));
    auto overlay_opt3 =
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc3"));

    ASSERT_TRUE(overlay_opt1);
    EXPECT_EQ(m1, overlay_opt1.value().mutation());
    ASSERT_TRUE(overlay_opt2);
    EXPECT_EQ(m2, overlay_opt2.value().mutation());
    ASSERT_TRUE(overlay_opt3);
    EXPECT_EQ(m3, overlay_opt3.value().mutation());
  });
}

TEST_P(DocumentOverlayCacheTest, GetOverlayExactlyMatchesTheGivenDocumentKey) {
  this->persistence_->Run("Test", [&] {
    this->SaveOverlaysWithSetMutations(1, {"coll/doc1/sub/doc2"});

    EXPECT_FALSE(
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/d")));
    EXPECT_FALSE(
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1")));
    EXPECT_FALSE(
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1ZZ")));

    const DocumentKey document_key =
        DocumentKey::FromPathString("coll/doc1/sub/doc2");
    auto overlay_opt = this->cache_->GetOverlay(document_key);
    ASSERT_TRUE(overlay_opt);
    EXPECT_EQ(overlay_opt->key(), document_key);
  });
}

TEST_P(DocumentOverlayCacheTest, SavingOverlayOverwrites) {
  this->persistence_->Run("Test", [&] {
    Mutation m1 = PatchMutation("coll/doc1", Map("foo", "bar"));
    Mutation m2 = SetMutation("coll/doc1", Map("foo", "set", "bar", 42));
    this->SaveOverlaysWithMutations(2, {m1});
    this->SaveOverlaysWithMutations(2, {m2});

    auto overlay_opt =
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1"));

    ASSERT_TRUE(overlay_opt);
    EXPECT_EQ(m2, overlay_opt.value().mutation());
  });
}

TEST_P(DocumentOverlayCacheTest, DeleteRepeatedlyWorks) {
  this->persistence_->Run("Test", [&] {
    Mutation mutation = PatchMutation("coll/doc1", Map("foo", "bar"));
    this->SaveOverlaysWithMutations(2, {mutation});

    this->cache_->RemoveOverlaysForBatchId(2);
    EXPECT_FALSE(
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1")));
    EXPECT_EQ(this->GetOverlayCount(), 0);

    this->cache_->RemoveOverlaysForBatchId(2);
    EXPECT_FALSE(
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1")));
    EXPECT_EQ(this->GetOverlayCount(), 0);
  });
}

TEST_P(DocumentOverlayCacheTest, GetAllOverlaysForCollection) {
  this->persistence_->Run("Test", [&] {
    Mutation m1 = PatchMutation("coll/doc1", Map("foo", "bar"));
    Mutation m2 = SetMutation("coll/doc2", Map("foo", "bar"));
    Mutation m3 = DeleteMutation("coll/doc3");
    // m4 and m5 are not under "coll"
    Mutation m4 = SetMutation("coll/doc1/sub/sub_doc", Map("foo", "bar"));
    Mutation m5 = SetMutation("other/doc1", Map("foo", "bar"));
    this->SaveOverlaysWithMutations(3, {m1, m2, m3, m4, m5});

    {
      SCOPED_TRACE("verify collection overlay");
      const auto overlays = this->cache_->GetOverlays(ResourcePath{"coll"}, -1);
      VerifyOverlayContains(overlays, {"coll/doc1", "coll/doc2", "coll/doc3"});
    }

    {
      SCOPED_TRACE("verify subcollection overlay");
      const auto overlays =
          this->cache_->GetOverlays(ResourcePath{"coll", "doc1", "sub"}, -1);
      VerifyOverlayContains(overlays, {"coll/doc1/sub/sub_doc"});
    }

    {
      SCOPED_TRACE("verify no incorrect matches of collection name prefixes 1");
      const auto overlays =
          this->cache_->GetOverlays(ResourcePath{"collZZZ"}, -1);
      VerifyOverlayContains(overlays, {});
    }

    {
      SCOPED_TRACE("verify no incorrect matches of collection name prefixes 2");
      const auto overlays = this->cache_->GetOverlays(ResourcePath{"c"}, -1);
      VerifyOverlayContains(overlays, {});
    }
  });
}

TEST_P(DocumentOverlayCacheTest, GetAllOverlaysSinceBatchId) {
  this->persistence_->Run("Test", [&] {
    this->SaveOverlaysWithSetMutations(2, {"coll/doc1", "coll/doc2"});
    this->SaveOverlaysWithSetMutations(3, {"coll/doc3"});
    this->SaveOverlaysWithSetMutations(4, {"coll/doc4"});

    const auto overlays = this->cache_->GetOverlays(ResourcePath{"coll"}, 2);

    SCOPED_TRACE("verify overlay");
    VerifyOverlayContains(overlays, {"coll/doc3", "coll/doc4"});
  });
}

TEST_P(DocumentOverlayCacheTest,
       GetAllOverlaysFromCollectionGroupEnforcesCollectionGroup) {
  this->persistence_->Run("Test", [&] {
    this->SaveOverlaysWithSetMutations(2, {"coll1/doc1", "coll2/doc1"});
    this->SaveOverlaysWithSetMutations(3, {"coll1/doc2"});
    this->SaveOverlaysWithSetMutations(4, {"coll2/doc2"});

    const auto overlays = this->cache_->GetOverlays("coll1", -1, 50);

    SCOPED_TRACE("verify overlay");
    VerifyOverlayContains(overlays, {"coll1/doc1", "coll1/doc2"});
  });
}

TEST_P(DocumentOverlayCacheTest,
       GetAllOverlaysFromCollectionGroupEnforcesBatchId) {
  this->persistence_->Run("Test", [&] {
    this->SaveOverlaysWithSetMutations(2, {"coll/doc1"});
    this->SaveOverlaysWithSetMutations(3, {"coll/doc2"});

    const auto overlays = this->cache_->GetOverlays("coll", 2, 50);

    SCOPED_TRACE("verify overlay");
    VerifyOverlayContains(overlays, {"coll/doc2"});
  });
}

TEST_P(DocumentOverlayCacheTest,
       GetAllOverlaysFromCollectionGroupEnforcesLimit) {
  this->persistence_->Run("Test", [&] {
    this->SaveOverlaysWithSetMutations(1, {"coll/doc1"});
    this->SaveOverlaysWithSetMutations(2, {"coll/doc2"});
    this->SaveOverlaysWithSetMutations(3, {"coll/doc3"});

    const auto overlays = this->cache_->GetOverlays("coll", -1, 2);

    SCOPED_TRACE("verify overlay");
    VerifyOverlayContains(overlays, {"coll/doc1", "coll/doc2"});
  });
}

TEST_P(DocumentOverlayCacheTest,
       GetAllOverlaysFromCollectionGroupWithLimitIncludesFullBatches) {
  this->persistence_->Run("Test", [&] {
    this->SaveOverlaysWithSetMutations(1, {"coll/doc1"});
    this->SaveOverlaysWithSetMutations(2, {"coll/doc2", "coll/doc3"});

    const auto overlays = this->cache_->GetOverlays("coll", -1, 2);

    SCOPED_TRACE("verify overlay");
    VerifyOverlayContains(overlays, {"coll/doc1", "coll/doc2", "coll/doc3"});
  });
}

TEST_P(DocumentOverlayCacheTest, UpdateDocumentOverlay) {
  this->persistence_->Run("Test", [&] {
    Mutation mutation1 = PatchMutation("coll/doc", Map("foo", "bar1"));
    Mutation mutation2 = PatchMutation("coll/doc", Map("foo", "bar2"));
    this->SaveOverlaysWithMutations(1, {mutation1});
    this->SaveOverlaysWithMutations(2, {mutation2});

    // Verify that `GetOverlay()` returns the updated mutation.
    auto overlay_opt =
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc"));
    EXPECT_TRUE(overlay_opt);
    if (overlay_opt) {
      EXPECT_EQ(mutation2, overlay_opt.value().mutation());
    }

    // Verify that `RemoveOverlaysForBatchId()` removes the overlay completely.
    this->cache_->RemoveOverlaysForBatchId(2);
    EXPECT_FALSE(
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc")));
    EXPECT_EQ(this->GetOverlayCount(), 0);
  });
}

TEST_P(DocumentOverlayCacheTest, OverwriteEntryUpdatesIndexes) {
  this->persistence_->Run("Test", [&] {
    Mutation mutation1 = PatchMutation("coll/doc1", Map("foo", "bar"));
    this->SaveOverlaysWithMutations(100, {mutation1});
    Mutation mutation2 = PatchMutation("coll/doc1", Map("biz", "baz"));
    this->SaveOverlaysWithMutations(101, {mutation2});
    const DocumentKey document_key = mutation1.key();

    ASSERT_EQ(this->cache_->GetOverlay(document_key), Overlay(101, mutation2));
    this->cache_->RemoveOverlaysForBatchId(101);
    ASSERT_FALSE(this->cache_->GetOverlay(document_key));

    // Add a new overlay for the same document and ensure that removing the
    // original batch ID with which it was associated has no effects. This
    // verifies that overwriting an overlay in the database removes the old
    // index entry (something I had forgotten in my initial implementation).
    Mutation mutation3 = PatchMutation("coll/doc1", Map("xxx", "yyy"));
    this->SaveOverlaysWithMutations(200, {mutation3});
    this->cache_->RemoveOverlaysForBatchId(100);
    ASSERT_EQ(this->cache_->GetOverlay(document_key), Overlay(200, mutation3));
    EXPECT_EQ(this->GetOverlayCount(), 1);
  });
}

TEST_P(DocumentOverlayCacheTest, RemoveOverlaysUntilEmpty) {
  this->persistence_->Run("Test", [&] {
    Mutation mutation1a = PatchMutation("coll/doc1a", Map("foo", "bar"));
    Mutation mutation1b = PatchMutation("coll/doc1b", Map("foo", "bar"));
    this->SaveOverlaysWithMutations(1, {mutation1a, mutation1b});
    Mutation mutation2a = PatchMutation("coll/doc2a", Map("foo", "bar"));
    Mutation mutation2b = PatchMutation("coll/doc2b", Map("foo", "bar"));
    this->SaveOverlaysWithMutations(2, {mutation2a, mutation2b});
    Mutation mutation3a = PatchMutation("coll/doc3a", Map("foo", "bar"));
    Mutation mutation3b = PatchMutation("coll/doc3b", Map("foo", "bar"));
    this->SaveOverlaysWithMutations(3, {mutation3a, mutation3b});

    {
      SCOPED_TRACE("RemoveOverlaysForBatchId(2)");
      this->cache_->RemoveOverlaysForBatchId(2);
      this->ExpectCacheContainsOverlaysFor(
          {"coll/doc1a", "coll/doc1b", "coll/doc3a", "coll/doc3b"});
      this->ExpectCacheDoesNotContainOverlaysFor({"coll/doc2a", "coll/doc2b"});
      EXPECT_EQ(this->GetOverlayCount(), 4);
    }

    {
      SCOPED_TRACE("RemoveOverlaysForBatchId(3)");
      this->cache_->RemoveOverlaysForBatchId(3);
      this->ExpectCacheContainsOverlaysFor({"coll/doc1a", "coll/doc1b"});
      this->ExpectCacheDoesNotContainOverlaysFor(
          {"coll/doc2a", "coll/doc2b", "coll/doc3a", "coll/doc3b"});
      EXPECT_EQ(this->GetOverlayCount(), 2);
    }

    {
      SCOPED_TRACE("RemoveOverlaysForBatchId(1)");
      this->cache_->RemoveOverlaysForBatchId(1);
      this->ExpectCacheDoesNotContainOverlaysFor({"coll/doc1a", "coll/doc1b",
                                                  "coll/doc2a", "coll/doc2b",
                                                  "coll/doc3a", "coll/doc3b"});
      EXPECT_EQ(this->GetOverlayCount(), 0);
    }
  });
}

TEST_P(DocumentOverlayCacheTest, SaveDoesntAffectSubCollections) {
  this->persistence_->Run("Test", [&] {
    Mutation mutation1 =
        PatchMutation("coll/doc/subcoll/subdoc", Map("foo", "bar1"));
    Mutation mutation2 = PatchMutation("coll/doc", Map("foo", "bar2"));
    this->SaveOverlaysWithMutations(1, {mutation1});
    this->SaveOverlaysWithMutations(2, {mutation2});

    // Verify that `GetOverlay()` returns the correct mutations.
    {
      auto overlay_opt = this->cache_->GetOverlay(
          DocumentKey::FromPathString("coll/doc/subcoll/subdoc"));
      EXPECT_TRUE(overlay_opt);
      if (overlay_opt) {
        EXPECT_EQ(overlay_opt.value().mutation(), mutation1);
      }
    }
    {
      auto overlay_opt =
          this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc"));
      EXPECT_TRUE(overlay_opt);
      if (overlay_opt) {
        EXPECT_EQ(overlay_opt.value().mutation(), mutation2);
      }
    }
  });
}

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase
