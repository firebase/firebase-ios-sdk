/*
 * Copyright 2018 Google LLC
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

#include "Firestore/core/src/immutable/sorted_set.h"

#include <random>
#include <unordered_set>

#include "Firestore/core/test/unit/immutable/testing.h"

namespace firebase {
namespace firestore {
namespace immutable {

using SizeType = SortedContainer::size_type;

template <typename K>
SortedSet<K> ToSet(const std::vector<K>& container) {
  SortedSet<K> result;
  for (auto&& entry : container) {
    result = result.insert(entry);
  }
  return result;
}

static const int kLargeNumber = 100;

TEST(SortedSetTest, EmptyBehavior) {
  SortedSet<int> set;

  EXPECT_TRUE(set.empty());
  EXPECT_EQ(0u, set.size());

  EXPECT_TRUE(NotFound(set, 1));
}

TEST(SortedSetTest, Size) {
  std::mt19937 rand;
  std::uniform_int_distribution<int> dist(0, 999);

  std::unordered_set<int> expected;

  SortedSet<int> set;
  for (int i = 0; i < kLargeNumber; ++i) {
    int value = dist(rand);

    // The random number sequence can generate duplicates, so the expected size
    // won't necessarily depend upon `i`.
    expected.insert(value);

    set = set.insert(value);
    EXPECT_EQ(expected.size(), set.size());
  }

  for (int i = 0; i < kLargeNumber; ++i) {
    int value = dist(rand);

    // The random number sequence can generate duplicates, so the expected size
    // won't necessarily depend upon `i`.
    expected.erase(value);

    set = set.erase(value);
    EXPECT_EQ(expected.size(), set.size());
  }
}

TEST(SortedSetSet, Find) {
  SortedSet<int> set = SortedSet<int>{}.insert(1).insert(2).insert(4);

  EXPECT_TRUE(NotFound(set, 0));
  EXPECT_TRUE(Found(set, 1));
  EXPECT_TRUE(Found(set, 2));
  EXPECT_TRUE(NotFound(set, 3));
  EXPECT_TRUE(Found(set, 4));
  EXPECT_TRUE(NotFound(set, 5));
}

TEST(SortedSetTest, IteratorsAreDefaultConstructible) {
  static_assert(
      std::is_default_constructible<SortedSet<int>::const_iterator>::value,
      "is default constructible");
}

TEST(SortedSetTest, Iterator) {
  std::vector<int> all = Sequence(kLargeNumber);
  SortedSet<int> set = ToSet(Shuffled(all));

  auto begin = set.begin();
  ASSERT_EQ(0, *begin);

  auto end = set.end();
  ASSERT_EQ(all.size(), static_cast<size_t>(std::distance(begin, end)));

  ASSERT_SEQ_EQ(all, set);
}

TEST(SortedSetTest, ValuesFrom) {
  std::vector<int> all = Sequence(2, 42, 2);
  SortedSet<int> set = ToSet(Shuffled(all));
  ASSERT_EQ(20u, set.size());

  // Test from before keys.
  ASSERT_SEQ_EQ(all, set.values_from(0));

  // Test from after keys.
  ASSERT_SEQ_EQ(Empty(), set.values_from(100));

  // Test from a key in the set: should start at that key.
  ASSERT_SEQ_EQ(Sequence(10, 42, 2), set.values_from(10));

  // Test from in between keys: should start just after that key.
  ASSERT_SEQ_EQ(Sequence(12, 42, 2), set.values_from(11));
}

TEST(SortedSetTest, ValuesIn) {
  std::vector<int> all = Sequence(2, 42, 2);
  SortedSet<int> set = ToSet(Shuffled(all));
  ASSERT_EQ(20u, set.size());

  // Constructs a sequence from `start` up to but not including `end` by 2.
  auto Seq = [](int start, int end) { return Sequence(start, end, 2); };

  ASSERT_SEQ_EQ(Empty(), set.values_in(0, 1));   // before to before
  ASSERT_SEQ_EQ(all, set.values_in(0, 100))      // before to after
  ASSERT_SEQ_EQ(Seq(2, 6), set.values_in(0, 6))  // before to in set
  ASSERT_SEQ_EQ(Seq(2, 8), set.values_in(0, 7))  // before to in between

  ASSERT_SEQ_EQ(Empty(), set.values_in(100, 0));    // after to before
  ASSERT_SEQ_EQ(Empty(), set.values_in(100, 110));  // after to after
  ASSERT_SEQ_EQ(Empty(), set.values_in(100, 6));    // after to in set
  ASSERT_SEQ_EQ(Empty(), set.values_in(100, 7));    // after to in between

  ASSERT_SEQ_EQ(Empty(), set.values_in(6, 0));       // in set to before
  ASSERT_SEQ_EQ(Seq(6, 42), set.values_in(6, 100));  // in set to after
  ASSERT_SEQ_EQ(Seq(6, 10), set.values_in(6, 10));   // in set to in set
  ASSERT_SEQ_EQ(Seq(6, 12), set.values_in(6, 11));   // in set to in between

  ASSERT_SEQ_EQ(Empty(), set.values_in(7, 0));       // in between to before
  ASSERT_SEQ_EQ(Seq(8, 42), set.values_in(7, 100));  // in between to after
  ASSERT_SEQ_EQ(Seq(8, 10), set.values_in(7, 10));   // in between to key in set
  ASSERT_SEQ_EQ(Seq(8, 14), set.values_in(7, 13));   // in between to in between
}

TEST(SortedSetTest, HashesStdHashable) {
  SortedSet<int> set;

  size_t result = util::Hash(set);
  (void)result;
}

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
