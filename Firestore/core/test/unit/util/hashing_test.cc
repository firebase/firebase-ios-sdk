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

#include "Firestore/core/src/util/hashing.h"

#include <map>
#include <string>

#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

struct HasHashMember {
  size_t Hash() const {
    return 42u;
  }
};

TEST(HashingTest, HasStdHash) {
  EXPECT_TRUE(impl::has_std_hash<float>::value);
  EXPECT_TRUE(impl::has_std_hash<double>::value);
  EXPECT_TRUE(impl::has_std_hash<int>::value);
  EXPECT_TRUE(impl::has_std_hash<int64_t>::value);
  EXPECT_TRUE(impl::has_std_hash<std::string>::value);
  EXPECT_TRUE(impl::has_std_hash<void*>::value);
  EXPECT_TRUE(impl::has_std_hash<const char*>::value);

  struct Foo {};
  EXPECT_FALSE(impl::has_std_hash<Foo>::value);
  EXPECT_FALSE(impl::has_std_hash<absl::string_view>::value);
  EXPECT_FALSE((impl::has_std_hash<std::map<std::string, std::string>>::value));
}

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
  size_t expected = std::hash<unsigned char>{}('a');
  expected = 31u * expected + std::hash<size_t>{}(1);
  ASSERT_EQ(expected, Hash(absl::string_view{"a"}));
}

TEST(HashingTest, SizeT) {
  size_t expected = std::hash<size_t>{}(42u);
  ASSERT_EQ(expected, Hash(size_t{42u}));
}

TEST(HashingTest, Array) {
  int values[] = {0, 1, 2};

  size_t expected = std::hash<int>{}(0);
  expected = 31u * expected + std::hash<int>{}(1);
  expected = 31u * expected + std::hash<int>{}(2);
  expected = 31u * expected + std::hash<size_t>{}(3);  // length of array
  ASSERT_EQ(expected, Hash(values));
}

TEST(HashingTest, HasHashMember) {
  ASSERT_EQ(static_cast<size_t>(42), Hash(HasHashMember{}));
}

TEST(HashingTest, RangeOfStdHashable) {
  std::vector<int> values{42};

  size_t expected = std::hash<int>{}(42);
  expected = 31u * expected + std::hash<size_t>{}(1);  // length of array
  ASSERT_EQ(expected, Hash(values));

  std::vector<int> values_leading_zero{0, 42};
  std::vector<int> values_trailing_zero{42, 0};

  EXPECT_NE(Hash(values), Hash(values_leading_zero));
  EXPECT_NE(Hash(values), Hash(values_trailing_zero));
  EXPECT_NE(Hash(values_leading_zero), Hash(values_trailing_zero));
}

TEST(HashingTest, RangeOfHashMember) {
  std::vector<HasHashMember> values{HasHashMember{}};

  // We trust the underlying Hash() member to do its thing, so unlike the other
  // examples, the 42u here is not run through std::hash<size_t>{}().
  size_t expected = 42u;
  expected = 31u * expected + std::hash<size_t>{}(1);  // length of array
  ASSERT_EQ(expected, Hash(values));
}

TEST(HashingTest, Optional) {
  absl::optional<int> value = 37;
  ASSERT_EQ(Hash(37), Hash(value));

  value.reset();
  ASSERT_EQ(-1171, Hash(value));
}

TEST(HashingTest, Enum) {
  enum class Enum {
    First,
    Second,
    Third,
  };

  Enum value = Enum::First;
  ASSERT_EQ(std::hash<int>{}(0), Hash(value));

  value = Enum::Second;
  ASSERT_EQ(std::hash<int>{}(1), Hash(value));

  ASSERT_EQ(std::hash<int>{}(2), Hash(Enum::Third));
}

TEST(HashingTest, Composite) {
  // Verify the result ends up as if hand-rolled
  EXPECT_EQ(std::hash<int>{}(1), Hash(1));

  size_t expected = std::hash<int>{}(1);
  expected = 31 * expected + std::hash<int>{}(0);
  EXPECT_EQ(expected, Hash(1, 0));

  expected = std::hash<int>{}(1);
  expected = 31 * expected + std::hash<int>{}(0);
  expected = 31 * expected + std::hash<int>{}(0);
  EXPECT_EQ(expected, Hash(1, 0, 0));

  expected = Hash(1);
  expected = 31u * expected + Hash(2);
  expected = 31u * expected + Hash(3);
  EXPECT_EQ(expected, Hash(1, 2, 3));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
