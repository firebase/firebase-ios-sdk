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

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"

#include <numeric>
#include <random>
#include <unordered_set>
#include <utility>

#include "Firestore/core/src/firebase/firestore/immutable/array_sorted_map.h"
#include "Firestore/core/src/firebase/firestore/immutable/tree_sorted_map.h"
#include "Firestore/core/src/firebase/firestore/util/secure_random.h"

#include "Firestore/core/test/firebase/firestore/immutable/testing.h"
#include "gtest/gtest.h"

using firebase::firestore::immutable::impl::SortedMapBase;

namespace firebase {
namespace firestore {
namespace immutable {

using SizeType = SortedMapBase::size_type;

template <typename MapType>
struct TestPolicy {
  static const SizeType kLargeSize = 100;
};

template <>
struct TestPolicy<impl::ArraySortedMap<int, int>> {
  // ArraySortedMap cannot insert more than this number
  static const SizeType kLargeSize = SortedMapBase::kFixedSize;
};

template <typename IntMap>
class SortedMapTest : public ::testing::Test {
 public:
  SortedMapBase::size_type large_size() const {
    return TestPolicy<IntMap>::kLargeSize;
  }

  int large_number() const {
    return static_cast<int>(large_size());
  }
};

// NOLINTNEXTLINE: must be a typedef for the gtest macros
typedef ::testing::Types<SortedMap<int, int>,
                         impl::ArraySortedMap<int, int>,
                         impl::TreeSortedMap<int, int>>
    TestedTypes;
TYPED_TEST_CASE(SortedMapTest, TestedTypes);

TYPED_TEST(SortedMapTest, EmptySize) {
  TypeParam map;
  EXPECT_TRUE(map.empty());
  EXPECT_EQ(0u, map.size());
}

TYPED_TEST(SortedMapTest, Empty) {
  TypeParam map = TypeParam{}.insert(10, 10).erase(10);
  EXPECT_TRUE(map.empty());
  EXPECT_EQ(0u, map.size());

  EXPECT_TRUE(NotFound(map, 1));
  EXPECT_TRUE(NotFound(map, 10));
}

TYPED_TEST(SortedMapTest, Size) {
  std::mt19937 rand;
  std::uniform_int_distribution<int> dist(0, 999);

  std::unordered_set<int> expected;

  TypeParam map;
  auto n = this->large_number();
  for (int i = 0; i < n; ++i) {
    int value = dist(rand);

    // The random number sequence can generate duplicates, so the expected size
    // won't necessarily depend upon `i`.
    expected.insert(value);

    map = map.insert(value, value);
    EXPECT_EQ(expected.size(), map.size());
  }
}

TYPED_TEST(SortedMapTest, Increasing) {
  int n = this->large_number();
  std::vector<int> to_insert = Sequence(n);
  TypeParam map = ToMap<TypeParam>(to_insert);
  ASSERT_EQ(this->large_size(), map.size());

  for (int i : to_insert) {
    map = map.erase(i);
    ASSERT_EQ(static_cast<size_t>(n - i - 1), map.size());
  }
  ASSERT_EQ(0u, map.size());

  std::vector<int> empty;
  ASSERT_EQ(Pairs(empty), Collect(map));
}

TYPED_TEST(SortedMapTest, Overwrite) {
  TypeParam map = TypeParam().insert(10, 10).insert(10, 8);

  ASSERT_TRUE(Found(map, 10, 8));
  ASSERT_FALSE(Found(map, 10, 10));
}

TYPED_TEST(SortedMapTest, BalanceProblem) {
  std::vector<int> to_insert{1, 7, 8, 5, 2, 6, 4, 0, 3};

  TypeParam map = ToMap<TypeParam>(to_insert);
  ASSERT_SEQ_EQ(Pairs(Sorted(to_insert)), map);
}

TYPED_TEST(SortedMapTest, EmptyRemoval) {
  TypeParam map;
  TypeParam new_map = map.erase(1);
  EXPECT_TRUE(new_map.empty());
  EXPECT_EQ(0u, new_map.size());
  EXPECT_TRUE(NotFound(new_map, 1));
}

TYPED_TEST(SortedMapTest, RemoveKeyValuePair) {
  TypeParam map = TypeParam{}.insert(1, 3).insert(2, 4);

  TypeParam new_map = map.erase(1);
  ASSERT_TRUE(Found(new_map, 2, 4));
  ASSERT_TRUE(NotFound(new_map, 1));

  // Make sure the original one is not mutated
  ASSERT_TRUE(Found(map, 1, 3));
  ASSERT_TRUE(Found(map, 2, 4));
}

TYPED_TEST(SortedMapTest, MoreRemovals) {
  TypeParam map = TypeParam()
                      .insert(1, 1)
                      .insert(50, 50)
                      .insert(3, 3)
                      .insert(4, 4)
                      .insert(7, 7)
                      .insert(9, 9)
                      .insert(1, 20)
                      .insert(18, 18)
                      .insert(3, 2)
                      .insert(4, 71)
                      .insert(7, 42)
                      .insert(9, 88);

  ASSERT_TRUE(Found(map, 7, 42));
  ASSERT_TRUE(Found(map, 3, 2));
  ASSERT_TRUE(Found(map, 1, 20));

  TypeParam s1 = map.erase(7);
  TypeParam s2 = map.erase(3);
  TypeParam s3 = map.erase(1);

  ASSERT_TRUE(NotFound(s1, 7));
  ASSERT_TRUE(Found(s1, 3, 2));
  ASSERT_TRUE(Found(s1, 1, 20));

  ASSERT_TRUE(Found(s2, 7, 42));
  ASSERT_TRUE(NotFound(s2, 3));
  ASSERT_TRUE(Found(s2, 1, 20));

  ASSERT_TRUE(Found(s3, 7, 42));
  ASSERT_TRUE(Found(s3, 3, 2));
  ASSERT_TRUE(NotFound(s3, 1));
}

TYPED_TEST(SortedMapTest, RemovesMiddle) {
  TypeParam map = TypeParam{}.insert(1, 1).insert(2, 2).insert(3, 3);
  ASSERT_TRUE(Found(map, 1, 1));
  ASSERT_TRUE(Found(map, 2, 2));
  ASSERT_TRUE(Found(map, 3, 3));

  TypeParam s1 = map.erase(2);
  ASSERT_TRUE(Found(s1, 1, 1));
  ASSERT_TRUE(NotFound(s1, 2));
  ASSERT_TRUE(Found(s1, 3, 3));
}

TYPED_TEST(SortedMapTest, InsertionAndRemovalOfMaxItems) {
  auto expected_size = this->large_size();
  int n = this->large_number();
  std::vector<int> to_insert = Shuffled(Sequence(n));
  std::vector<int> to_remove = Shuffled(to_insert);

  // Add them to the map
  TypeParam map = ToMap<TypeParam>(to_insert);
  ASSERT_EQ(expected_size, map.size())
      << "Check if all N objects are in the map";

  // check the order is correct
  ASSERT_SEQ_EQ(Pairs(Sorted(to_insert)), map);

  for (int i : to_remove) {
    map = map.erase(i);
  }
  ASSERT_EQ(0u, map.size()) << "Check we removed all of the items";
}

TYPED_TEST(SortedMapTest, EraseDoesNotInvalidateIterators) {
  std::vector<int> keys = Sequence(1, 4);
  TypeParam original = ToMap<TypeParam>(keys);

  auto begin = original.begin();
  auto end = original.end();
  ASSERT_EQ(Collect(original), (std::vector<std::pair<int, int>>{begin, end}));

  TypeParam erased = original.erase(2);
  ASSERT_EQ(erased.size(), original.size() - 1);
  ASSERT_EQ(Collect(original), (std::vector<std::pair<int, int>>{begin, end}));
}

TYPED_TEST(SortedMapTest, FindEmpty) {
  TypeParam map;
  EXPECT_TRUE(NotFound(map, 10));
}

TYPED_TEST(SortedMapTest, FindSpecificKey) {
  TypeParam map = TypeParam{}.insert(1, 3).insert(2, 4);

  ASSERT_TRUE(Found(map, 1, 3));
  ASSERT_TRUE(Found(map, 2, 4));
  ASSERT_TRUE(NotFound(map, 3));
}

TYPED_TEST(SortedMapTest, FindIndex) {
  std::vector<int> to_insert{1, 3, 4, 7, 9, 50};
  TypeParam map = ToMap<TypeParam>(to_insert);

  ASSERT_EQ(TypeParam::npos, map.find_index(0));
  ASSERT_EQ(0u, map.find_index(1));
  ASSERT_EQ(TypeParam::npos, map.find_index(2));
  ASSERT_EQ(1u, map.find_index(3));
  ASSERT_EQ(2u, map.find_index(4));
  ASSERT_EQ(TypeParam::npos, map.find_index(5));
  ASSERT_EQ(TypeParam::npos, map.find_index(6));
  ASSERT_EQ(3u, map.find_index(7));
  ASSERT_EQ(TypeParam::npos, map.find_index(8));
  ASSERT_EQ(4u, map.find_index(9));
  ASSERT_EQ(5u, map.find_index(50));
}

TYPED_TEST(SortedMapTest, MinMax) {
  TypeParam empty;
  auto min = empty.min();
  auto max = empty.max();
  ASSERT_EQ(empty.end(), min);
  ASSERT_EQ(empty.end(), max);
  ASSERT_EQ(min, max);

  TypeParam one = empty.insert(1, 1);
  min = one.min();
  max = one.max();
  ASSERT_NE(one.end(), min);
  ASSERT_NE(one.end(), max);
  ASSERT_EQ(1, min->first);
  ASSERT_EQ(1, max->first);

  // Just a regular iterator
  ++min;
  ASSERT_EQ(one.end(), min);

  TypeParam two = one.insert(2, 2);
  min = two.min();
  max = two.max();
  ASSERT_EQ(1, min->first);
  ASSERT_EQ(2, max->first);

  std::vector<int> to_insert = Sequence(this->large_number());
  TypeParam lots = ToMap<TypeParam>(to_insert);
  min = lots.min();
  max = lots.max();
  ASSERT_EQ(to_insert.front(), min->first);
  ASSERT_EQ(to_insert.back(), max->first);
}

TYPED_TEST(SortedMapTest, IteratorsAreDefaultConstructible) {
  // If this compiles the test has succeeded
  typename TypeParam::const_iterator iter;
  (void)iter;
}

TYPED_TEST(SortedMapTest, BeginEndEmpty) {
  TypeParam map;
  ASSERT_EQ(map.begin(), map.end());
}

TYPED_TEST(SortedMapTest, BeginEndOne) {
  TypeParam map = ToMap<TypeParam>(Sequence(1));
  auto begin = map.begin();
  auto end = map.end();

  ASSERT_NE(begin, end);
  ASSERT_EQ(0, begin->first);

  ++begin;
  ASSERT_EQ(begin, end);
}

TYPED_TEST(SortedMapTest, Iterates) {
  std::vector<int> to_insert = Sequence(this->large_number());
  TypeParam map = ToMap<TypeParam>(to_insert);
  auto iter = map.begin();
  auto end = map.end();

  std::vector<int> actual;
  for (; iter != end; ++iter) {
    actual.push_back(iter->first);
  }
  ASSERT_EQ(to_insert, actual);
}

TYPED_TEST(SortedMapTest, IteratorsUsingRangeBasedForLoop) {
  std::vector<int> to_insert = Sequence(this->large_number());
  TypeParam map = ToMap<TypeParam>(to_insert);

  std::vector<int> actual = Keys(map);
  ASSERT_EQ(to_insert, actual);
}

TYPED_TEST(SortedMapTest, CompatibleWithStdDistance) {
  int n = this->large_number();
  TypeParam map = ToMap<TypeParam>(Sequence(n));

  auto iter = map.begin();
  ASSERT_EQ(map.size(), static_cast<size_t>(std::distance(iter, map.end())));

  std::advance(iter, 1);
  ASSERT_EQ(map.size() - 1,
            static_cast<size_t>(std::distance(iter, map.end())));

  std::advance(iter, map.size() - 1);
  ASSERT_EQ(0u, static_cast<size_t>(std::distance(iter, map.end())));
}

TYPED_TEST(SortedMapTest, CompatibleWithStdAccumulate) {
  // World's worst way to compute triangular numbers...
  auto add = [](int lhs, const typename TypeParam::value_type& rhs) {
    return lhs + rhs.first;
  };

  TypeParam map = ToMap<TypeParam>(Sequence(6));
  int result = std::accumulate(map.begin(), map.end(), 0, add);
  ASSERT_EQ(15, result);
}

TYPED_TEST(SortedMapTest, CompatibleWithStdMismatch) {
  TypeParam lhs = TypeParam{}.insert(1, 1).insert(3, 3).insert(4, 4);
  TypeParam rhs = TypeParam{}.insert(1, 1).insert(2, 2).insert(4, 4);

  using Iter = typename TypeParam::const_iterator;

  // C++11 does not define an overload of std::mismatch that takes the end of
  // rhs, so rhs must be a sequence at least as long as lhs.
  std::pair<Iter, Iter> miss =
      std::mismatch(lhs.begin(), lhs.end(), rhs.begin());

  auto lhs_miss = lhs.begin();
  std::advance(lhs_miss, 1);

  auto rhs_miss = rhs.begin();
  std::advance(rhs_miss, 1);

  ASSERT_EQ(std::make_pair(lhs_miss, rhs_miss), miss);
}

TYPED_TEST(SortedMapTest, IteratorInvalidation) {
  // Tests that iterators are not invalidated by changes
  int n = this->large_number();
  TypeParam map = ToMap<TypeParam>(Sequence(0, n - 1, 2));
  size_t size = static_cast<size_t>(n) / 2;
  ASSERT_EQ(size, map.size());

  // Insert elements ahead of the current iteration position
  TypeParam result = map;
  for (const auto& element : map) {
    result = result.insert(element.first + 1, element.second + 1);
  }
  size *= 2;

  ASSERT_EQ(size, result.size());
}

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
