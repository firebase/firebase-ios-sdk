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

typedef TreeSortedMap<int, int> IntMap;

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
  map = map.insert(1, 1);
  map = map.insert(2, 2);

  EXPECT_EQ(2, map.root().key());
  EXPECT_EQ(1, map.root().left().key());

  EXPECT_EQ(Color::Red, map.root().left().color());
}

TEST(TreeSortedMap, RotatesRight) {
  IntMap map;
  map = map.insert(3, 3);
  EXPECT_EQ(3, map.root().key());

  map = map.insert(2, 2);
  EXPECT_EQ(3, map.root().key());

  map = map.insert(1, 1);
  EXPECT_EQ(2, map.root().value());
}

TEST(TreeSortedMap, RotatesRightAndMaintainsColorInvariants) {
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

  EXPECT_EQ(Color::Black, map.root().left().left().color());

  // insert predecessor, rotation required
  map = map.insert(1, 2);
  EXPECT_EQ(2, map.root().key());
  EXPECT_EQ(Color::Black, map.root().color());
  EXPECT_EQ(Color::Black, map.root().left().color());
  EXPECT_EQ(Color::Black, map.root().right().color());
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

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
