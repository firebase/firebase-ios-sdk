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
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

TEST(LevelDbDocumentOverlayCacheTest, TypeTraits) {
  static_assert(!std::is_copy_constructible<LevelDbDocumentOverlayCache>::value,
                "is_copy_constructible");
  static_assert(!std::is_move_constructible<LevelDbDocumentOverlayCache>::value,
                "is_move_constructible");
  static_assert(!std::is_copy_assignable<LevelDbDocumentOverlayCache>::value,
                "is_copy_assignable");
  static_assert(!std::is_move_assignable<LevelDbDocumentOverlayCache>::value,
                "is_move_assignable");
}

// TODO(dconeybe) Add the call to INSTANTIATE_TEST_SUITE_P to add the tests for
// LevelDbDocumentOverlayCache once its implementation is completed.
// See memory_document_overlay_cache_test.cc for guidance.

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase
