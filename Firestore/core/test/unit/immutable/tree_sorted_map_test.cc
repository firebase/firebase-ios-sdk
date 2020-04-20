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

#include "Firestore/core/src/immutable/tree_sorted_map.h"

#include <algorithm>

#include "Firestore/core/src/util/secure_random.h"
#include "Firestore/core/test/unit/immutable/testing.h"
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

TEST(TreeSortedMap, EmptyHasEmptyChildren) {
  IntMap map;
  IntMap::node_type left = map.root().left();
  ASSERT_TRUE(left.empty());

  IntMap::node_type right = map.root().right();
  ASSERT_TRUE(right.empty());
}

TEST(TreeSortedMap, PropertiesForEmpty) {
  IntMap empty;
  EXPECT_TRUE(empty.empty());
  EXPECT_EQ(0, empty.root().value());

  EXPECT_EQ(Color::Black, empty.root().color());
  EXPECT_FALSE(empty.root().red());
}

TEST(TreeSortedMap, PropertiesForNonEmpty) {
  IntMap empty;

  IntMap non_empty = empty.insert(1, 2);
  EXPECT_FALSE(non_empty.empty());
  EXPECT_EQ(1, non_empty.root().key());
  EXPECT_EQ(2, non_empty.root().value());

  // Root nodes are always black
  EXPECT_EQ(Color::Black, non_empty.root().color());
  EXPECT_FALSE(non_empty.root().red());
  EXPECT_TRUE(non_empty.root().left().empty());
  EXPECT_TRUE(non_empty.root().right().empty());
}

TEST(TreeSortedMap, RotatesLeft) {
  IntMap map;
  EXPECT_EQ(Color::Black, map.root().color());

  // root node, with two empty children
  map = map.insert(1, 1);
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Black, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());

  // insert successor, leans left, rotation required
  map = map.insert(2, 2);
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Red, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());

  // insert successor, balanced, color flip required
  map = map.insert(3, 3);
  EXPECT_EQ(2, map.root().key());
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Black, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());
}

TEST(TreeSortedMap, RotatesLeftWithSubtree) {
  // Build an initially balanced, all black tree
  IntMap map;
  map = map.insert(5, 5);
  map = map.insert(3, 3);
  map = map.insert(7, 7);
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Black, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());

  // left child of right, no rotation yet
  map = map.insert(6, 6);
  EXPECT_EQ(5, map.root().key());
  EXPECT_EQ(6, map.root().right().left().key());
  EXPECT_EQ(Color::Red, map.root().right().left().color());

  // right child of right, triggers a color flip in the right node and forces
  // a left rotation of the root
  map = map.insert(8, 8);
  EXPECT_EQ(7, map.root().key());
  EXPECT_EQ(Color::Black, map.root().color());

  EXPECT_EQ(5, map.root().left().key());
  EXPECT_EQ(Color::Red, map.root().left().color());

  EXPECT_EQ(3, map.root().left().left().key());
  EXPECT_EQ(Color::Black, map.root().left().left().color());

  EXPECT_EQ(6, map.root().left().right().key());
  EXPECT_EQ(Color::Black, map.root().left().right().color());

  EXPECT_EQ(8, map.root().right().key());
  EXPECT_EQ(Color::Black, map.root().right().color());
}

TEST(TreeSortedMap, RotatesRight) {
  IntMap map;
  EXPECT_EQ(Color::Black, map.root().color());

  // root node, with two empty children
  map = map.insert(3, 3);
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Black, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());

  // insert predecessor, leans left, no rotation
  map = map.insert(2, 2);
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Red, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());

  // insert predecessor, rotation required
  map = map.insert(1, 2);
  EXPECT_EQ(2, map.root().key());
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Black, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());
}

TEST(TreeSortedMap, RotatesRightWithSubtree) {
  // Build an initially balanced, all black tree
  IntMap map;
  map = map.insert(5, 5);
  map = map.insert(3, 3);
  map = map.insert(7, 7);
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Black, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());

  // insert left.left, no rotation yet
  map = map.insert(1, 1);
  EXPECT_EQ(5, map.root().key());
  EXPECT_EQ(1, map.root().left().left().key());
  EXPECT_EQ(Color::Red, map.root().left().left().color());

  // insert left.right, triggers a color flip in left but no rotation
  map = map.insert(4, 4);
  EXPECT_EQ(5, map.root().key());
  EXPECT_EQ(Color::Red, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().left().left().color());
  EXPECT_EQ(Color::Black, map.root().left().right().color());

  // insert left.left.left; still no rotation
  map = map.insert(0, 0);
  EXPECT_EQ(5, map.root().key());
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Red, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().left().left().color());
  EXPECT_EQ(Color::Red, map.root().left().left().left().color());

  EXPECT_EQ(Color::Black, map.root().right().color());

  // insert left.left.right:
  //   * triggers a color flip on left.left => Red
  //   * triggers right rotation at the root because left and left.left are Red
  //   * triggers a color flip on root => whole tree black
  map = map.insert(2, 2);
  EXPECT_EQ(3, map.root().key());
  EXPECT_EQ(Color::Black, map.root().color());

  EXPECT_EQ(1, map.root().left().key());
  EXPECT_EQ(Color::Black, map.root().left().color());

  EXPECT_EQ(0, map.root().left().left().key());
  EXPECT_EQ(Color::Black, map.root().left().left().color());

  EXPECT_EQ(2, map.root().left().right().key());
  EXPECT_EQ(Color::Black, map.root().left().right().color());

  EXPECT_EQ(5, map.root().right().key());
  EXPECT_EQ(Color::Black, map.root().right().color());

  EXPECT_EQ(4, map.root().right().left().key());
  EXPECT_EQ(Color::Black, map.root().right().left().color());

  EXPECT_EQ(7, map.root().right().right().key());
  EXPECT_EQ(Color::Black, map.root().right().right().color());
}

TEST(TreeSortedMap, InsertIsImmutable) {
  IntMap original = IntMap{}.insert(3, 3);

  IntMap modified = original.insert(2, 2).insert(1, 1);
  EXPECT_EQ(3, original.root().key());
  EXPECT_EQ(3, original.root().value());
  EXPECT_EQ(Color::Black, original.root().color());
  EXPECT_TRUE(original.root().left().empty());
  EXPECT_TRUE(original.root().right().empty());
}

TEST(TreeSortedMap, InitializerIsSorted) {
  IntMap map = IntMap::Create(
      std::vector<IntMap::value_type>{{3, 0}, {2, 0}, {1, 0}}, {});

  EXPECT_TRUE(std::is_sorted(map.begin(), map.end()));
}

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
