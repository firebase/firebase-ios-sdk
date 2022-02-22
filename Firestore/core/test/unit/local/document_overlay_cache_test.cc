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
using model::ResourcePath;
using ::testing::UnorderedElementsAreArray;
using testutil::DeleteMutation;
using testutil::Map;
using testutil::PatchMutation;
using testutil::SetMutation;

DocumentOverlayCacheTestBase::DocumentOverlayCacheTestBase(
    std::unique_ptr<Persistence> persistence)
    : persistence_(std::move(persistence)),
      cache_(persistence_->document_overlay_cache(User("user"))) {
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

    this->cache_->RemoveOverlaysForBatchId(2);
    EXPECT_FALSE(
        this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1")));
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

    const auto overlays = this->cache_->GetOverlays(ResourcePath{"coll"}, -1);

    SCOPED_TRACE("verify overlay");
    VerifyOverlayContains(overlays, {"coll/doc1", "coll/doc2", "coll/doc3"});
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
  });
}

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase
