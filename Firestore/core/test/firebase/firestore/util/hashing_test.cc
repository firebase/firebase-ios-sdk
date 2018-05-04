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

#include "Firestore/core/src/firebase/firestore/util/hashing.h"

#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

struct HasHashMember {
  size_t Hash() const {
    return 42;
  }
};

TEST(HashingTest, Int) {
  ASSERT_EQ(std::hash<int>{}(0), Hash(0));
}

TEST(HashingTest, Float) {
  ASSERT_EQ(std::hash<double>{}(1.0), Hash(1.0));
}

TEST(HashingTest, String) {
  ASSERT_EQ(std::hash<std::string>{}("foobar"), Hash(std::string{"foobar"}));
}

TEST(HashingTest, StringView) {
  // For StringView we expect the range-based hasher to kick in. This is
  // basically terrible, but no worse than Java's `String.hashCode()`. Another
  // possibility would be just to create a temporary std::string and std::hash
  // that, but that requires an explicit specialization. Since we're only
  // defining this for compatibility with Objective-C and not really sensitive
  // to performance or hash quality here, this is good enough.
  size_t expected = 'a';
  expected = 31u * expected + 1;
  ASSERT_EQ(expected, Hash(absl::string_view{"a"}));
}

TEST(HashingTest, SizeT) {
  ASSERT_EQ(42u, Hash(size_t{42u}));
}

TEST(HashingTest, Array) {
  int values[] = {0, 1, 2};

  size_t expected = 0;
  expected = 31 * expected + 1;
  expected = 31 * expected + 2;
  expected = 31 * expected + 3;  // length of array
  ASSERT_EQ(expected, Hash(values));
}

TEST(HashingTest, HasHashMember) {
  ASSERT_EQ(static_cast<size_t>(42), Hash(HasHashMember{}));
}

TEST(HashingTest, RangeOfStdHashable) {
  std::vector<int> values{42};
  ASSERT_EQ(31u * 42u + 1, Hash(values));

  std::vector<int> values_leading_zero{0, 42};
  std::vector<int> values_trailing_zero{42, 0};

  EXPECT_NE(Hash(values), Hash(values_leading_zero));
  EXPECT_NE(Hash(values), Hash(values_trailing_zero));
  EXPECT_NE(Hash(values_leading_zero), Hash(values_trailing_zero));
}

TEST(HashingTest, RangeOfHashMember) {
  std::vector<HasHashMember> values{HasHashMember{}};
  ASSERT_EQ(31u * 42u + 1, Hash(values));
}

TEST(HashingTest, Composite) {
  // Verify the result ends up as if hand-rolled
  EXPECT_EQ(1u, Hash(1));
  EXPECT_EQ(31u, Hash(1, 0));
  EXPECT_EQ(31u * 31u, Hash(1, 0, 0));

  size_t expected = Hash(1);
  expected = 31 * expected + Hash(2);
  expected = 31 * expected + Hash(3);
  EXPECT_EQ(expected, Hash(1, 2, 3));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
