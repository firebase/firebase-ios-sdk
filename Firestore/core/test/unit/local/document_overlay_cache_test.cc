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

#include <type_traits>

#include "Firestore/core/src/local/document_overlay_cache.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

TEST(DocumentOverlayCacheTest, TypeTraits) {
  static_assert(!std::is_constructible<DocumentOverlayCache>::value, "is_constructible");
  static_assert(std::is_abstract<DocumentOverlayCache>::value, "is_abstract");
  static_assert(std::has_virtual_destructor<DocumentOverlayCache>::value, "has_virtual_destructor");
}

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase