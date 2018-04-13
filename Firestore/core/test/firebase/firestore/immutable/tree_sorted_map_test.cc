/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/immutable/tree_sorted_map.h"

#include "Firestore/core/src/firebase/firestore/util/secure_random.h"
#include "Firestore/core/test/firebase/firestore/immutable/testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace immutable {
namespace impl {

using IntMap = TreeSortedMap<int, int>;

TEST(TreeSortedMap, EmptySize) {
  IntMap map;
  EXPECT_TRUE(map.empty());
  EXPECT_EQ(0u, map.size());
  EXPECT_EQ(Color::Black, map.root().color());
}

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
