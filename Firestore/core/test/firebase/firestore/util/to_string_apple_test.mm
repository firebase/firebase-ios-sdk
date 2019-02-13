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

#import <Foundation/NSArray.h>

#include <map>
#include <string>
#include <vector>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

using model::DocumentKey;
using immutable::SortedMap;

TEST(ToStringTest, StdToString) {
  EXPECT_EQ(ToString(123), "123");
  EXPECT_EQ(ToString(std::string{"foo"}), "foo");
}

TEST(ToStringTest, ObjCTypes) {
  EXPECT_EQ(ToString(@123), "123");
  EXPECT_EQ(ToString(@"foo"), "foo");

  NSArray<NSNumber*>* objc_array = @[ @1, @2, @3 ];
  EXPECT_EQ(ToString(objc_array), "(\n    1,\n    2,\n    3\n)");
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

TEST(ToStringTest, CustomMap) {
  using MapT = SortedMap<int, std::string>;
  MapT sorted_map = MapT{}.insert(1, "foo").insert(2, "bar");
  EXPECT_EQ(ToString(sorted_map), "{1: foo, 2: bar}");
}

TEST(ToStringTest, Nested) {
  using Nested = std::map<int, NSArray<NSNumber*>*>;
  Nested foo1{
      {100, @[ @1, @2, @3 ]},
      {200, @[ @4, @5, @6 ]},
  };
  Nested foo2{
      {300, @[ @3, @2, @1 ]},
  };
  std::map<std::string, std::vector<Nested>> nested{
      {"bar", std::vector<Nested>{foo1}},
      {"baz", std::vector<Nested>{foo2}},
  };
  std::string expected = R"!({bar: [{100: (
    1,
    2,
    3
), 200: (
    4,
    5,
    6
)}], baz: [{300: (
    3,
    2,
    1
)}]})!";
  EXPECT_EQ(ToString(nested), expected);
}

class Foo {};
std::string ToString(const Foo&) {
  return "Foo";
}

TEST(ToStringTest, FreeFunctionToStringIsConsidered) {
  EXPECT_EQ(ToString(Foo{}), "Foo");
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
