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

  // TODO(wilhuff): re-add find
  // EXPECT_TRUE(NotFound(map, 1));
  // EXPECT_TRUE(NotFound(map, 10));
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
  std::vector<int> to_insert = Sequence(this->large_number());
  TypeParam map = ToMap<TypeParam>(to_insert);
  ASSERT_EQ(this->large_size(), map.size());

  for (int i : to_insert) {
    map = map.erase(i);
  }
  ASSERT_EQ(0u, map.size());
}

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
