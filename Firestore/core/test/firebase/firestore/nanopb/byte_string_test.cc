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

#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"

#include <cstdint>
#include <cstdlib>

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {

using testing::ContainerEq;

namespace {

std::vector<uint8_t> ToVector(const std::string& str) {
  auto begin = reinterpret_cast<const uint8_t*>(str.data());
  return {begin, begin + str.size()};
}

}  // namespace

TEST(ByteStringTest, DefaultConstructor) {
  ByteString str;
  EXPECT_EQ(nullptr, str.data());
}

TEST(ByteStringTest, FromStdString) {
  std::string original{"foo"};
  ByteString copy{original};
  EXPECT_THAT(copy.ToVector(), ContainerEq(ToVector(original)));

  original = "bar";
  EXPECT_THAT(copy.ToVector(), ContainerEq(ToVector("foo")));
}

TEST(ByteStringTest, FromCString) {
  char original[] = {'f', 'o', 'o', '\0'};
  ByteString copy{original};
  EXPECT_THAT(copy.ToVector(), ContainerEq(ToVector(original)));

  original[0] = 'b';
  EXPECT_THAT(copy.ToVector(), ContainerEq(ToVector("foo")));
}

TEST(ByteStringTest, WrapByteNullTerminatedArray) {
  auto original =
      static_cast<pb_bytes_array_t*>(malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(4)));
  memcpy(original->bytes, "foo", 4);  // null terminator
  original->size = 3;

  ByteString wrapper = ByteString::Take(original);
  EXPECT_THAT(wrapper.ToVector(), ContainerEq(ToVector("foo")));

  original->bytes[0] = 'b';
  EXPECT_THAT(wrapper.ToVector(), ContainerEq(ToVector("boo")));
}

TEST(ByteStringTest, WrapByteUnterminatedArray) {
  auto original =
      static_cast<pb_bytes_array_t*>(malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(3)));
  memcpy(original->bytes, "foo", 3);  // no null terminator
  original->size = 3;

  ByteString wrapper = ByteString::Take(original);
  EXPECT_THAT(wrapper.ToVector(), ContainerEq(ToVector("foo")));

  // This isn't expected usage normally, but it's a way to verify that the
  // contents weren't copied.
  original->bytes[0] = 'b';
  EXPECT_THAT(wrapper.ToVector(), ContainerEq(ToVector("boo")));
}

TEST(ByteStringTest, Release) {
  ByteString value{"foo"};

  pb_bytes_array_t* released = value.release();
  EXPECT_EQ(released->size, 3);
  EXPECT_EQ(memcmp(released->bytes, "foo", 3), 0);
  EXPECT_EQ(value.get(), nullptr);

  std::free(released);
}

TEST(ByteStringTest, Comparison) {
  ByteString abc{"abc"};
  ByteString def{"def"};

  ByteString abc2{"abc"};

  EXPECT_TRUE(abc == abc);
  EXPECT_TRUE(abc == abc2);
  EXPECT_TRUE(abc != def);

  EXPECT_TRUE(abc < def);
  EXPECT_TRUE(abc <= def);
  EXPECT_TRUE(abc <= abc2);

  EXPECT_TRUE(def > abc);
  EXPECT_TRUE(def >= abc);
  EXPECT_TRUE(abc2 >= abc);
}

}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase
