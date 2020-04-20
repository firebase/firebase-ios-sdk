/*
 * Copyright 2017 Google
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

#include "Firestore/core/src/util/string_util.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(StringUtil, PrefixSuccessor) {
  EXPECT_EQ(PrefixSuccessor("a"), "b");
  EXPECT_EQ(PrefixSuccessor("aaAA"), "aaAB");
  EXPECT_EQ(PrefixSuccessor("aaa\xff"), "aab");
  EXPECT_EQ(PrefixSuccessor(std::string("\x00", 1)), "\x01");
  EXPECT_EQ(PrefixSuccessor("az\xe0"), "az\xe1");
  EXPECT_EQ(PrefixSuccessor("\xff\xff\xff"), "");
  EXPECT_EQ(PrefixSuccessor(""), "");
}

TEST(StringUtil, ImmediateSuccessor) {
  EXPECT_EQ(ImmediateSuccessor("hello"), std::string("hello\0", 6));
  EXPECT_EQ(ImmediateSuccessor(""), std::string("\0", 1));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
