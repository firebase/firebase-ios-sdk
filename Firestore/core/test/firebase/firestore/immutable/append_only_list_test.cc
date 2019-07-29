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

#include "Firestore/core/src/firebase/firestore/immutable/append_only_list.h"

#include "Firestore/core/test/firebase/firestore/immutable/testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace immutable {

using IntList = AppendOnlyList<int>;

/**
 * Creates a SortedMap by inserting a pair for each value in the vector.
 * Each pair will have the same key and value.
 */
template <typename Container>
Container ToList(const std::vector<int>& values) {
  Container result;
  for (const auto& value : values) {
    result = result.push_back(value);
  }
  return result;
}

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
  IntList original;
  original = original.push_back(0);

  IntList actual = original;
  std::vector<int> to_append = Sequence(1, 5);
  for (int value : to_append) {
    actual = actual.push_back(value);
  }

  ASSERT_NE(nullptr, actual.begin());
  EXPECT_EQ(original.begin(), actual.begin());

  EXPECT_EQ(Sequence(5), Collect(actual));
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
}

TEST(AppendOnlyListTest, AppendToMiddleCopies) {
  IntList original{0, 1};
  IntList smaller = original.pop_back();

  IntList original2 = original.push_back(2);
  IntList smaller2 = smaller.push_back(2);

  EXPECT_EQ((IntList{0, 1, 2}), original2);
  EXPECT_EQ((IntList{0, 2}), smaller2);

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

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
