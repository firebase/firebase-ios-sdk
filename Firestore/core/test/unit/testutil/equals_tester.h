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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_EQUALS_TESTER_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_EQUALS_TESTER_H_

#include <utility>
#include <vector>

#include "Firestore/core/src/util/hashing.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace testutil {

using testing::Each;
using testing::Eq;
using testing::Not;

MATCHER_P(HashEq, other, "has equal hash") {
  return util::Hash(arg) == util::Hash(other);
}

/**
 * Tester for operator== and Hash() methods of a class.
 *
 * To use, create a new EqualsTester and add equality groups where each group
 * contains objects that are supposed to be equal to each other, and objects of
 * different groups are expected to be unequal. For example:
 *
 *     EqualsTester<std::string>()
 *         .AddEqualityGroup("hello", "h" + "ello")
 *         .AddEqualityGroup("world", "wor" + "ld")
 *         .TestEquals();
 *
 * This tests:
 *
 *   * comparing each object against itself returns true
 *   * comparing each pair of objects within the same equality group returns
 *     true
 *   * comparing each pair of objects from different equality groups returns
 *     false
 *   * the hash code of any two equal objects are equal
 *
 * This is a simplified port of EqualsTester from Guava, adapted for C++, where
 * equality is not defined in a way that varies at run-time. As a result, checks
 * for handling null or incompatible classes are not included.
 */
template <typename T>
class EqualsTester {
 public:
  template <typename... Ts>
  EqualsTester& AddEqualityGroup(Ts... elements) {
    std::vector<T> group{elements...};
    groups_.push_back(std::move(group));
    return *this;
  }

  EqualsTester& TestEquals() {
    for (size_t i = 0; i < groups_.size(); ++i) {
      const std::vector<T>& group = groups_[i];
      for (const T& item : group) {
        // Verify that all items in the group are equal.
        EXPECT_THAT(group, Each(Eq(item)));
        EXPECT_THAT(group, Each(HashEq(item)));

        // Verify that all items in other groups are unequal.
        for (size_t j = 0; j < groups_.size(); ++j) {
          if (i == j) continue;

          const std::vector<T>& other_group = groups_[j];
          EXPECT_THAT(other_group, Each(Not(Eq(item))));
        }
      }
    }
    return *this;
  }

 private:
  std::vector<std::vector<T>> groups_;
};

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_EQUALS_TESTER_H_
