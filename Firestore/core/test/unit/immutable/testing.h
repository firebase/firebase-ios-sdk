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

#ifndef FIRESTORE_CORE_TEST_UNIT_IMMUTABLE_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_IMMUTABLE_TESTING_H_

#include <algorithm>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

#include "Firestore/core/src/util/secure_random.h"
#include "absl/strings/str_cat.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace immutable {

template <typename K, typename V>
std::string Describe(const std::pair<K, V>& pair) {
  return absl::StrCat("(", pair.first, ", ", pair.second, ")");
}

// Describes the given item by its std::to_string implementation (if
// std::to_string is defined for V). The return type is not defined directly
// in terms of std::string in order to allow specialization failure to select
// a different overload.
template <typename V>
auto Describe(const V& item) -> decltype(std::to_string(item)) {
  return std::to_string(item);
}

template <typename Container, typename K>
testing::AssertionResult NotFound(const Container& map, const K& key) {
  if (map.contains(key)) {
    return testing::AssertionFailure()
           << "Should not have found " << key << " using contains()";
  }

  auto found = map.find(key);
  if (found == map.end()) {
    return testing::AssertionSuccess();
  } else {
    return testing::AssertionFailure()
           << "Should not have found " << Describe(*found);
  }
}

/**
 * Asserts that the given key is found in the given container and that it maps
 * to the given value. This only works with map-type containers where value_type
 * is `std::pair<K, V>`.
 */
template <typename Container, typename K, typename V>
testing::AssertionResult Found(const Container& map,
                               const K& key,
                               const V& expected) {
  if (!map.contains(key)) {
    return testing::AssertionFailure()
           << "Did not find key " << key << " using contains()";
  }

  auto found = map.find(key);
  if (found == map.end()) {
    return testing::AssertionFailure()
           << "Did not find key " << key << " using find()";
  }
  if (found->second == expected) {
    return testing::AssertionSuccess();
  } else {
    return testing::AssertionFailure() << "Found entry was (" << found->first
                                       << ", " << found->second << ")";
  }
}

/**
 * Asserts that the given key is found in the given container without
 * necessarily checking that the key maps to any value. This also makes
 * this compatible with non-mapped containers where K is the value_type.
 */
template <typename Container, typename K>
testing::AssertionResult Found(const Container& container, const K& key) {
  if (!container.contains(key)) {
    return testing::AssertionFailure()
           << "Did not find key " << key << " using contains()";
  }

  auto found = container.find(key);
  if (found == container.end()) {
    return testing::AssertionFailure()
           << "Did not find key " << key << " using find()";
  }
  if (*found == key) {
    return testing::AssertionSuccess();
  } else {
    return testing::AssertionFailure()
           << "Found entry was " << Describe(*found);
  }
}

/** Creates an empty vector (for readability). */
inline std::vector<int> Empty() {
  return {};
}

/**
 * Creates a vector containing a sequence of integers from the given starting
 * element up to, but not including, the given end element, with values
 * incremented by the given step.
 *
 * If step is negative the sequence is in descending order (but still starting
 * at start and ending before end).
 */
inline std::vector<int> Sequence(int start, int end, int step = 1) {
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
inline std::vector<int> Sequence(int num_elements) {
  return Sequence(0, num_elements);
}

/**
 * Creates a copy of the given vector with contents shuffled randomly.
 */
inline std::vector<int> Shuffled(const std::vector<int>& values) {
  std::vector<int> result{values};
  util::SecureRandom rng;
  std::shuffle(result.begin(), result.end(), rng);
  return result;
}

/**
 * Creates a copy of the given vector with contents sorted.
 */
inline std::vector<int> Sorted(const std::vector<int>& values) {
  std::vector<int> result{values};
  std::sort(result.begin(), result.end());
  return result;
}

/**
 * Creates a copy of the given vector with contents reversed.
 */
inline std::vector<int> Reversed(const std::vector<int>& values) {
  std::vector<int> result{values};
  std::reverse(result.begin(), result.end());
  return result;
}

/**
 * Creates a vector of pairs where each pair has the same first and second
 * corresponding to an element in the given vector.
 */
inline std::vector<std::pair<int, int>> Pairs(const std::vector<int>& values) {
  std::vector<std::pair<int, int>> result;
  for (auto&& value : values) {
    result.emplace_back(value, value);
  }
  return result;
}

/**
 * Creates a SortedMap by inserting a pair for each value in the vector.
 * Each pair will have the same key and value.
 */
template <typename Container>
Container ToMap(const std::vector<int>& values) {
  Container result;
  for (auto&& value : values) {
    result = result.insert(value, value);
  }
  return result;
}

template <typename Container>
std::vector<int> Keys(const Container& container) {
  std::vector<int> keys;
  for (const auto& element : container) {
    keys.push_back(element.first);
  }
  return keys;
}

/**
 * Appends the contents of the given container to a new vector.
 */
template <typename Container>
std::vector<typename Container::value_type> Collect(
    const Container& container) {
  return {container.begin(), container.end()};
}

#define ASSERT_SEQ_EQ(x, y) ASSERT_EQ((x), Collect(y));
#define EXPECT_SEQ_EQ(x, y) EXPECT_EQ((x), Collect(y));

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_IMMUTABLE_TESTING_H_
