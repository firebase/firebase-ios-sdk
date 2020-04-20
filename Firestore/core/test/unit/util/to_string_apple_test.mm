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

#include "Firestore/core/src/util/to_string.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(ToStringAppleTest, ObjCTypes) {
  EXPECT_EQ(ToString(@123), "123");
  EXPECT_EQ(ToString(@"foo"), "foo");

  NSArray<NSNumber*>* objc_array = @[ @1, @2, @3 ];
  EXPECT_EQ(ToString(objc_array), "(\n    1,\n    2,\n    3\n)");
}

TEST(ToStringAppleTest, Nested) {
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

}  // namespace util
}  // namespace firestore
}  // namespace firebase
