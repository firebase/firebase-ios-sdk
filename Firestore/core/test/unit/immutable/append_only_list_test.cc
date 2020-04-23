/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/immutable/append_only_list.h"

#include "Firestore/core/test/unit/immutable/testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace immutable {

using IntList = AppendOnlyList<int>;

TEST(AppendOnlyListTest, DefaultConstructs) {
  IntList list;
  EXPECT_TRUE(list.empty());
  EXPECT_EQ(0, list.size());
  EXPECT_EQ(list.begin(), list.end());
}

TEST(AppendOnlyListTest, AppendDoesNotModifyOriginal) {
  IntList empty;

  // Appending does not modify the original list
  IntList not_empty = empty.push_back(1);
  EXPECT_EQ(0, empty.size());
  EXPECT_EQ(1, not_empty.size());
}

TEST(AppendOnlyListTest, AppendToEndShares) {
  IntList initial{0, 1};
  initial = initial.push_back(2);

  // Doubling behavior should leave unused capacity
  ASSERT_LT(initial.size(), initial.capacity());

  IntList actual = initial.push_back(3);

  ASSERT_NE(nullptr, actual.begin());
  EXPECT_EQ(initial.begin(), actual.begin());

  EXPECT_EQ(Sequence(4), Collect(actual));
}

TEST(AppendOnlyListTest, PopBack) {
  IntList original{0, 1, 2};
  EXPECT_EQ(3, original.size());

  IntList smaller = original.pop_back();
  EXPECT_EQ(2, smaller.size());
  EXPECT_EQ(Sequence(2), Collect(smaller));
  EXPECT_EQ(original.begin(), smaller.begin());

  IntList even_smaller = smaller.pop_back();
  EXPECT_EQ(1, even_smaller.size());
  EXPECT_EQ(Sequence(1), Collect(even_smaller));
  EXPECT_EQ(original.begin(), even_smaller.begin());

  IntList empty = even_smaller.pop_back();
  EXPECT_EQ(0, empty.size());
  EXPECT_EQ(nullptr, empty.begin());

  IntList empty2 = empty.pop_back();
  EXPECT_EQ(0, empty2.size());
  EXPECT_EQ(nullptr, empty2.begin());
}

TEST(AppendOnlyListTest, AppendToMiddleCopies) {
  // Set up original to have extra capacity so that we can append without
  // copying the backing vector.
  IntList original{0, 1};
  original = original.push_back(2);

  IntList smaller = original.pop_back();

  IntList original2 = original.push_back(3);
  IntList smaller2 = smaller.push_back(3);

  EXPECT_EQ((IntList{0, 1, 2, 3}), original2);
  EXPECT_EQ((IntList{0, 1, 3}), smaller2);

  EXPECT_EQ(original.begin(), original2.begin());

  // Popping from original will make smaller share. Appending to smaller will
  // force it to copy.
  EXPECT_EQ(original.begin(), smaller.begin());
  EXPECT_NE(smaller.begin(), smaller2.begin());
}

TEST(AppendOnlyListTest, Emplaces) {
  using PairList = AppendOnlyList<std::pair<int, int>>;
  PairList empty;

  PairList appended = empty.emplace_back(1, 2);
  EXPECT_EQ(std::make_pair(1, 2), appended.front());

  PairList appended2 = empty.emplace_back(3, 4);
  EXPECT_EQ(std::make_pair(3, 4), appended2.back());
}

TEST(AppendOnlyListTest, AvoidsIteratorInvalidation) {
  const size_t iterations = 10;
  std::vector<IntList> lists;
  std::vector<IntList::const_iterator> iterators;

  lists.emplace_back();
  iterators.push_back(lists.back().begin());

  // At each iteration, push_back onto the list
  for (size_t i = 0; i < iterations; i++) {
    lists.push_back(lists.back().push_back(0));
    iterators.push_back(lists.back().begin());
  }

  for (size_t i = 0; i < iterations; i++) {
    ASSERT_EQ(iterators[i], lists[i].begin()) << "iteration " << i;
  }
}

TEST(AppendOnlyListTest, ReservePreventsReallocation) {
  IntList empty;
  IntList one = empty.push_back(1);
  IntList two = one.push_back(2);
  ASSERT_NE(one.begin(), two.begin());

  IntList reserved = empty.reserve(2);
  IntList reserved_one = reserved.push_back(1);
  IntList reserved_two = reserved_one.push_back(2);
  ASSERT_EQ(reserved_one.begin(), reserved_two.begin());
}

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
