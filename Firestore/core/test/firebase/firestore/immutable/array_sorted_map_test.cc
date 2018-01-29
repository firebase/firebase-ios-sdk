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

#include "Firestore/core/src/firebase/firestore/immutable/array_sorted_map.h"

#include <numeric>
#include <random>

#include "Firestore/core/src/firebase/firestore/util/secure_random.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace immutable {

typedef ArraySortedMap<int, int> IntMap;
constexpr IntMap::size_type kFixedSize = IntMap::kFixedSize;

template <typename K, typename V>
testing::AssertionResult NotFound(const ArraySortedMap<K, V>& set,
                                  const K& key) {
  auto found = set.find(key);
  if (found == set.end()) {
    return testing::AssertionSuccess();
  } else {
    return testing::AssertionFailure()
           << "Should not have found (" << found->first << ", " << found->second
           << ") @ " << found;
  }
}

template <typename K, typename V>
testing::AssertionResult Found(const ArraySortedMap<K, V>& map,
                               const K& key,
                               const V& expected) {
  auto found = map.find(key);
  if (found == map.end()) {
    return testing::AssertionFailure() << "Did not find key " << key;
  }
  if (found->second == expected) {
    return testing::AssertionSuccess();
  } else {
    return testing::AssertionFailure() << "Found entry was (" << found->first
                                       << ", " << found->second << ")";
  }
}

/**
 * Creates a vector containing a sequence of integers from the given starting
 * element up to, but not including, the given end element, with values
 * incremented by the given step.
 *
 * If step is negative the sequence is in descending order (but still starting
 * at start and ending before end).
 */
std::vector<int> Sequence(int start, int end, int step = 1) {
  std::vector<int> result;
  if (step > 0) {
    for (int i = start; i < end; i += step) {
      result.push_back(i);
    }
  } else {
    for (int i = start; i > end; i += step) {
      result.push_back(i);
    }
  }
  return result;
}

/**
 * Creates a vector containing a sequence of integers with the given number of
 * elements, from zero up to, but not including the given value.
 */
std::vector<int> Sequence(int num_elements) {
  return Sequence(0, num_elements);
}

/**
 * Creates a copy of the given vector with contents shuffled randomly.
 */
std::vector<int> Shuffled(const std::vector<int>& values) {
  std::vector<int> result(values);
  util::SecureRandom rng;
  std::shuffle(result.begin(), result.end(), rng);
  return result;
}

/**
 * Creates a copy of the given vector with contents sorted.
 */
std::vector<int> Sorted(const std::vector<int>& values) {
  std::vector<int> result(values);
  std::sort(result.begin(), result.end());
  return result;
}

/**
 * Creates a vector of pairs where each pair has the same first and second
 * corresponding to an element in the given vector.
 */
std::vector<std::pair<int, int>> Pairs(const std::vector<int>& values) {
  std::vector<std::pair<int, int>> result;
  for (auto&& value : values) {
    result.emplace_back(value, value);
  }
  return result;
}

/**
 * Creates an ArraySortedMap by inserting a pair for each value in the vector.
 * Each pair will have the same key and value.
 */
IntMap ToMap(const std::vector<int>& values) {
  IntMap result;
  for (auto&& value : values) {
    result = result.insert(value, value);
  }
  return result;
}

/**
 * Appends the contents of the given container to a new vector.
 */
template <typename Container>
std::vector<typename Container::value_type> Append(const Container& container) {
  std::vector<typename Container::value_type> result;
  result.insert(result.begin(), container.begin(), container.end());
  return result;
}

// TODO(wilhuff): ReverseTraversal

#define ASSERT_SEQ_EQ(x, y) ASSERT_EQ((x), Append(y));
#define EXPECT_SEQ_EQ(x, y) EXPECT_EQ((x), Append(y));

TEST(ArraySortedMap, SearchForSpecificKey) {
  IntMap map{{1, 3}, {2, 4}};

  ASSERT_TRUE(Found(map, 1, 3));
  ASSERT_TRUE(Found(map, 2, 4));
  ASSERT_TRUE(NotFound(map, 3));
}

TEST(ArraySortedMap, RemoveKeyValuePair) {
  IntMap map{{1, 3}, {2, 4}};

  IntMap new_map = map.erase(1);
  ASSERT_TRUE(Found(new_map, 2, 4));
  ASSERT_TRUE(NotFound(new_map, 1));

  // Make sure the original one is not mutated
  ASSERT_TRUE(Found(map, 1, 3));
  ASSERT_TRUE(Found(map, 2, 4));
}

TEST(ArraySortedMap, MoreRemovals) {
  IntMap map = IntMap()
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

  IntMap s1 = map.erase(7);
  IntMap s2 = map.erase(3);
  IntMap s3 = map.erase(1);

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

TEST(ArraySortedMap, RemovesMiddle) {
  IntMap map{{1, 1}, {2, 2}, {3, 3}};
  ASSERT_TRUE(Found(map, 1, 1));
  ASSERT_TRUE(Found(map, 2, 2));
  ASSERT_TRUE(Found(map, 3, 3));

  IntMap s1 = map.erase(2);
  ASSERT_TRUE(Found(s1, 1, 1));
  ASSERT_TRUE(NotFound(s1, 2));
  ASSERT_TRUE(Found(s1, 3, 3));
}

TEST(ArraySortedMap, Increasing) {
  auto total = static_cast<int>(kFixedSize);
  IntMap map;

  for (int i = 0; i < total; i++) {
    map = map.insert(i, i);
  }
  ASSERT_EQ(kFixedSize, map.size());

  for (int i = 0; i < total; i++) {
    map = map.erase(i);
  }
  ASSERT_EQ(0u, map.size());
}

TEST(ArraySortedMap, Override) {
  IntMap map = IntMap().insert(10, 10).insert(10, 8);

  ASSERT_TRUE(Found(map, 10, 8));
  ASSERT_FALSE(Found(map, 10, 10));
}

TEST(ArraySortedMap, ChecksSize) {
  std::vector<int> to_insert = Sequence(kFixedSize);
  IntMap map = ToMap(to_insert);

  // Replacing an existing entry should not hit increase size
  map = map.insert(5, 10);

  int next = kFixedSize;
  ASSERT_DEATH_IF_SUPPORTED(map.insert(next, next), "new_size <= fixed_size");
}

TEST(ArraySortedMap, Empty) {
  IntMap map = IntMap().insert(10, 10).erase(10);
  EXPECT_TRUE(map.empty());
  EXPECT_EQ(0u, map.size());
  EXPECT_TRUE(NotFound(map, 1));
  EXPECT_TRUE(NotFound(map, 10));
}

TEST(ArraySortedMap, EmptyGet) {
  IntMap map;
  EXPECT_TRUE(NotFound(map, 10));
}

TEST(ArraySortedMap, EmptySize) {
  IntMap map;
  EXPECT_TRUE(map.empty());
  EXPECT_EQ(0u, map.size());
}

TEST(ArraySortedMap, EmptyRemoval) {
  IntMap map;
  IntMap new_map = map.erase(1);
  EXPECT_TRUE(new_map.empty());
  EXPECT_EQ(0u, new_map.size());
  EXPECT_TRUE(NotFound(new_map, 1));
}

TEST(ArraySortedMap, InsertionAndRemovalOfMaxItems) {
  auto expected_size = kFixedSize;
  int n = static_cast<int>(expected_size);
  std::vector<int> to_insert = Shuffled(Sequence(n));
  std::vector<int> to_remove = Shuffled(to_insert);

  // Add them to the map
  IntMap map = ToMap(to_insert);
  ASSERT_EQ(expected_size, map.size())
      << "Check if all N objects are in the map";

  // check the order is correct
  ASSERT_SEQ_EQ(Pairs(Sorted(to_insert)), map);

  for (int i : to_remove) {
    map = map.erase(i);
  }
  ASSERT_EQ(0u, map.size()) << "Check we removed all of the items";
}

TEST(ArraySortedMap, BalanceProblem) {
  std::vector<int> to_insert{1, 7, 8, 5, 2, 6, 4, 0, 3};

  IntMap map = ToMap(to_insert);
  ASSERT_SEQ_EQ(Pairs(Sorted(to_insert)), map);
}

// TODO(wilhuff): PredecessorKey

// TODO(wilhuff): Iterators

// TODO(wilhuff): IndexOf

TEST(ArraySortedMap, AvoidsCopying) {
  IntMap map = IntMap().insert(10, 20);
  auto found = map.find(10);
  ASSERT_NE(found, map.end());
  EXPECT_EQ(20, found->second);

  // Verify that inserting something with equal keys and values just returns
  // the same underlying array.
  IntMap duped = map.insert(10, 20);
  auto duped_found = duped.find(10);

  // If everything worked correctly, the backing array should not have been
  // copied and the pointer to the entry with 10 as key should be the same.
  EXPECT_EQ(found, duped_found);
}

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
