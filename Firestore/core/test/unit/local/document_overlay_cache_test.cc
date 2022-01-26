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

namespace firebase {
namespace firestore {
namespace local {
namespace {

using model::DocumentKey;

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

  std::unique_ptr<DocumentOverlayCache> cache_;
};

TYPED_TEST_SUITE(DocumentOverlayCacheTest, ::testing::Types<MemoryDocumentOverlayCache>);

TYPED_TEST(DocumentOverlayCacheTest, ReturnsNullWhenOverlayIsNotFound) {
  const auto overlay = this->cache_->GetOverlay(DocumentKey::FromPathString("coll/doc1"));

  EXPECT_FALSE(overlay);
}

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase