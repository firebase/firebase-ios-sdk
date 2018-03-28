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
  // TODO(mcg): increase beyond what ArraySortedMap supports
  static const SizeType kFixedSize = SortedMapBase::kFixedSize;
};

template <typename IntMap>
class SortedMapTest : public ::testing::Test {
 public:
  template <typename Integer = SizeType>
  Integer fixed_size() {
    return static_cast<Integer>(TestPolicy<IntMap>::kFixedSize);
  }
};

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

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
