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

#include "Firestore/core/src/util/to_string.h"

#include <deque>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/immutable/sorted_map.h"
#include "Firestore/core/src/immutable/sorted_set.h"
#include "Firestore/core/src/model/document_key.h"
#include "absl/types/optional.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

using immutable::SortedMap;
using immutable::SortedSet;
using model::DocumentKey;

TEST(ToStringTest, SimpleTypes) {
  EXPECT_EQ(ToString(123), "123");
  EXPECT_EQ(ToString(1.5), "1.5");

  EXPECT_EQ(ToString("foo"), "foo");
  EXPECT_EQ(ToString(std::string{"foo"}), "foo");

  EXPECT_EQ(ToString(true), "true");

  EXPECT_EQ(ToString(nullptr), "null");

  // TODO(b/326402002): Below no longer passes after abseil upgrade
  // to 1.20240116.1 void* ptr = reinterpret_cast<void*>(0xBAAAAAAD);
  // EXPECT_EQ(ToString(ptr), "baaaaaad");
}

TEST(ToStringTest, CustomToString) {
  auto key = DocumentKey::FromSegments({"rooms", "firestore"});
  EXPECT_EQ(ToString(key), "rooms/firestore");
}

TEST(ToStringTest, Optional) {
  absl::optional<int> foo;
  EXPECT_EQ(ToString(foo), "nullopt");

  absl::optional<int> bar = 1;
  EXPECT_EQ(ToString(bar), "1");
}

TEST(ToStringTest, Container) {
  std::vector<DocumentKey> keys{
      DocumentKey::FromSegments({"foo", "bar"}),
      DocumentKey::FromSegments({"foo", "baz"}),
  };
  EXPECT_EQ(ToString(keys), "[foo/bar, foo/baz]");
}

TEST(ToStringTest, StdMap) {
  std::map<int, DocumentKey> key_map{
      {1, DocumentKey::FromSegments({"foo", "bar"})},
      {2, DocumentKey::FromSegments({"foo", "baz"})},
  };
  EXPECT_EQ(ToString(key_map), "{1: foo/bar, 2: foo/baz}");
}

TEST(ToStringTest, CustomMap) {
  using MapT = SortedMap<int, std::string>;
  MapT sorted_map = MapT{}.insert(1, "foo").insert(2, "bar");
  EXPECT_EQ(ToString(sorted_map), "{1: foo, 2: bar}");
}

TEST(ToStringTest, CustomSet) {
  using SetT = SortedSet<std::string>;
  SetT sorted_set = SetT{}.insert("foo").insert("bar");
  EXPECT_EQ(ToString(sorted_set), "[bar, foo]");
}

TEST(ToStringTest, MoreStdContainers) {
  std::deque<int> d{1, 2, 3, 4};
  EXPECT_EQ(ToString(d), "[1, 2, 3, 4]");

  std::set<int> s{5, 6, 7};
  EXPECT_EQ(ToString(s), "[5, 6, 7]");

  // Multimap with the same duplicate element twice to avoid dealing with order.
  std::unordered_multimap<int, std::string> mm{{3, "abc"}, {3, "abc"}};
  EXPECT_EQ(ToString(mm), "{3: abc, 3: abc}");
}

TEST(ToStringTest, Nested) {
  using Nested = std::map<int, std::vector<int>>;
  Nested foo1{
      {100, {1, 2, 3}},
      {200, {4, 5, 6}},
  };
  Nested foo2{
      {300, {3, 2, 1}},
  };
  std::map<std::string, std::vector<Nested>> nested{
      {"bar", std::vector<Nested>{foo1}},
      {"baz", std::vector<Nested>{foo2}},
  };
  std::string expected =
      "{bar: [{100: [1, 2, 3], 200: [4, 5, 6]}], "
      "baz: [{300: [3, 2, 1]}]}";
  EXPECT_EQ(ToString(nested), expected);
}

class Foo {};
std::string ToString(const Foo&) {
  return "Foo";
}

TEST(ToStringTest, FreeFunctionToStringIsConsidered) {
  EXPECT_EQ(ToString(Foo{}), "Foo");
}

struct Container {
  using value_type = int;

  explicit Container(std::vector<int>&& v) : v{std::move(v)} {
  }

  std::vector<int>::const_iterator begin() const {
    return v.begin();
  }
  std::vector<int>::const_iterator end() const {
    return v.end();
  }

  std::vector<int> v;
};

TEST(ToStringTest, Ordering) {
  struct CustomToString : public Container {
    using Container::Container;
    std::string ToString() const {
      return "CustomToString";
    }
  };

  EXPECT_EQ(ToString(Container{{1, 2, 3}}), "[1, 2, 3]");
  EXPECT_EQ(ToString(CustomToString{{1, 2, 3}}), "CustomToString");
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
