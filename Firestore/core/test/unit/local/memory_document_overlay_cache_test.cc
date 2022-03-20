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

#include "Firestore/core/src/local/memory_document_overlay_cache.h"
#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/test/unit/local/document_overlay_cache_test.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

TEST(MemoryDocumentOverlayCacheTest, TypeTraits) {
  static_assert(!std::is_copy_constructible<MemoryDocumentOverlayCache>::value,
                "is_copy_constructible");
  static_assert(!std::is_move_constructible<MemoryDocumentOverlayCache>::value,
                "is_move_constructible");
  static_assert(!std::is_copy_assignable<MemoryDocumentOverlayCache>::value,
                "is_copy_assignable");
  static_assert(!std::is_move_assignable<MemoryDocumentOverlayCache>::value,
                "is_move_assignable");
}

std::unique_ptr<Persistence> PersistenceFactory() {
  return MemoryPersistenceWithEagerGcForTesting();
}

INSTANTIATE_TEST_SUITE_P(MemoryDocumentOverlayCacheTest,
                         DocumentOverlayCacheTest,
                         testing::Values(PersistenceFactory));

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase
