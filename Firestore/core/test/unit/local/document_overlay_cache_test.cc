/*
 * Copyright 2022 Google
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

#include <memory>
#include <type_traits>

#include "absl/memory/memory.h"
#include "gtest/gtest.h"

#include "Firestore/core/src/local/document_overlay_cache.h"
#include "Firestore/core/src/local/memory_document_overlay_cache.h"
#include <Firestore/core/src/model/document_key.h>
#include <Firestore/core/src/model/mutation.h>
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/test/unit/testutil/testutil.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using local::DocumentOverlayCache;
using model::DocumentKey;
using model::Mutation;
using testutil::Map;
using testutil::DeleteMutation;
using testutil::PatchMutation;
using testutil::SetMutation;

TEST(DocumentOverlayCacheTest, TypeTraits) {
  static_assert(!std::is_constructible<DocumentOverlayCache>::value, "is_constructible");
  static_assert(std::is_abstract<DocumentOverlayCache>::value, "is_abstract");
  static_assert(std::has_virtual_destructor<DocumentOverlayCache>::value, "has_virtual_destructor");
}

// Since `DocumentOverlayCache` is a purely-abstract class, it is not tested
// directly; however, there are exactly two implementations of it. Both of those
// implementations share the same test suite. The test suite that follows is for
// both of those implementations (a.k.a. interface tests) inspired by
// https://github.com/google/googletest/blob/f45d5865/googletest/samples/sample6_unittest.cc

template <class T>
std::unique_ptr<DocumentOverlayCache> CreateDocumentOverlayCache();

template <class T>
std::unique_ptr<DocumentOverlayCache> CreateDocumentOverlayCache() {
  return absl::make_unique<MemoryDocumentOverlayCache>();
}

template <typename T>
class DocumentOverlayCacheTest : public ::testing::Test {
 protected:
  DocumentOverlayCacheTest() : cache_(CreateDocumentOverlayCache<T>()) {
  }

  void SaveOverlays(int largest_batch_id, const std::vector<Mutation>& mutations) {
    DocumentOverlayCache::MutationByDocumentKeyMap overlays;
    for (const auto& mutation : mutations) {
      ASSERT_TRUE(overlays.find(mutation.key()) == overlays.end());
      overlays.insert({mutation.key(), mutation});
    }
    this->cache_->SaveOverlays(largest_batch_id, std::move(overlays));
  }

  std::unique_ptr<DocumentOverlayCache> cache_;
};

TYPED_TEST_SUITE(DocumentOverlayCacheTest, ::testing::Types<MemoryDocumentOverlayCache>);

TYPED_TEST(DocumentOverlayCacheTest, ReturnsNullWhenOverlayIsNotFound) {
  EXPECT_FALSE(this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1")));
}

TYPED_TEST(DocumentOverlayCacheTest, CanReadSavedOverlay) {
  Mutation mutation = PatchMutation("coll/doc1", Map("foo", "bar"));
  this->SaveOverlays(2, {mutation});

  auto overlay_opt = this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1"));

  ASSERT_TRUE(overlay_opt);
  EXPECT_EQ(mutation, overlay_opt.value().get().mutation());
}

TYPED_TEST(DocumentOverlayCacheTest, CanReadSavedOverlays) {
  Mutation mutation1 = PatchMutation("coll/doc1", Map("foo", "bar"));
  Mutation mutation2 = SetMutation("coll/doc2", Map("foo", "bar"));
  Mutation mutation3 = DeleteMutation("coll/doc3");
  this->SaveOverlays(3, {mutation1, mutation2, mutation3});

  auto overlay_opt1 = this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1"));
  auto overlay_opt2 = this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc2"));
  auto overlay_opt3 = this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc3"));

  ASSERT_TRUE(overlay_opt1);
  EXPECT_EQ(mutation1, overlay_opt1.value().get().mutation());
  ASSERT_TRUE(overlay_opt2);
  EXPECT_EQ(mutation2, overlay_opt2.value().get().mutation());
  ASSERT_TRUE(overlay_opt3);
  EXPECT_EQ(mutation3, overlay_opt3.value().get().mutation());
}

TYPED_TEST(DocumentOverlayCacheTest, SavingOverlayOverwrites) {
  Mutation mutation1 = PatchMutation("coll/doc1", Map("foo", "bar"));
  Mutation mutation2 = SetMutation("coll/doc1", Map("foo", "set", "bar", 42));
  this->SaveOverlays(2, {mutation1});
  this->SaveOverlays(2, {mutation2});

  auto overlay_opt = this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1"));

  ASSERT_TRUE(overlay_opt);
  EXPECT_EQ(mutation2, overlay_opt.value().get().mutation());
}

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase