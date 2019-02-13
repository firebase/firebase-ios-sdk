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

#include <deque>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/immutable/sorted_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

using immutable::SortedMap;
using immutable::SortedSet;
using model::DocumentKey;

TEST(ToStringTest, StdToString) {
  EXPECT_EQ(ToString(123), "123");
  EXPECT_EQ(ToString(std::string{"foo"}), "foo");
}

TEST(ToStringTest, CustomToString) {
  DocumentKey key({"rooms", "firestore"});
  EXPECT_EQ(ToString(key), "rooms/firestore");
}

TEST(ToStringTest, Container) {
  std::vector<DocumentKey> keys{
      DocumentKey({"foo", "bar"}),
      DocumentKey({"foo", "baz"}),
  };
  EXPECT_EQ(ToString(keys), "[foo/bar, foo/baz]");
}

TEST(ToStringTest, StdMap) {
  std::map<int, DocumentKey> key_map{
      {1, DocumentKey({"foo", "bar"})},
      {2, DocumentKey({"foo", "baz"})},
  };
  EXPECT_EQ(ToString(key_map), "{1: foo/bar, 2: foo/baz}");
}

TEST(ToStringTest, EmptyContainer) {
  std::vector<int> v;
  EXPECT_EQ(ToString(v), "[]");

  std::map<int, int> m;
  EXPECT_EQ(ToString(m), "{}");
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

TEST(ToStringTest, Ordering) {
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

  struct Conversion : public Container {
    using Container::Container;
    operator std::string() const {
      return "Conversion";
    }
  };

  struct CustomToString : public Conversion {
    using Conversion::Conversion;
    std::string ToString() const {
      return "CustomToString";
    }
  };

  EXPECT_EQ(ToString(Container{{1, 2, 3}}), "[1, 2, 3]");
  EXPECT_EQ(ToString(Conversion{{1, 2, 3}}), "Conversion");
  EXPECT_EQ(ToString(CustomToString{{1, 2, 3}}), "CustomToString");
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
