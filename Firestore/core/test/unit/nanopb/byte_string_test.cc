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

#include "Firestore/core/src/nanopb/byte_string.h"

#include <cstdint>
#include <cstdlib>

#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {

using testing::ContainerEq;

namespace {

struct free_deleter {
  template <typename T>
  void operator()(T* value) const {
    std::free(value);
  }
};

template <typename T>
using freed_ptr = std::unique_ptr<T, free_deleter>;

pb_bytes_array_t* MakeBytesArray(pb_size_t size) {
  return static_cast<pb_bytes_array_t*>(
      malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(size)));
}

std::vector<uint8_t> MakeVector(const std::string& str) {
  auto begin = reinterpret_cast<const uint8_t*>(str.data());
  return {begin, begin + str.size()};
}

MATCHER_P(BytesEq, n, "") {
  auto lhs = MakeVector(arg);
  auto rhs = MakeVector(n);
  return testing::ExplainMatchResult(ContainerEq(rhs), lhs, result_listener);
}

}  // namespace

TEST(ByteStringTest, DefaultConstructor) {
  ByteString str;
  EXPECT_EQ(str.get(), nullptr);

  // Even though the backing bytes array is null, data() should be non-null.
  EXPECT_NE(str.data(), nullptr);
  EXPECT_EQ(str.size(), 0);

  EXPECT_EQ(str.begin(), str.data());
  EXPECT_EQ(str.end(), str.begin());
}

TEST(ByteStringTest, Copy) {
  freed_ptr<pb_bytes_array_t> original(MakeBytesArray(4));
  memcpy(original->bytes, "foo", 4);  // null terminator
  original->size = 3;

  ByteString copy{original.get()};
  EXPECT_THAT(copy, BytesEq("foo"));
  EXPECT_NE(copy.get(), original.get());
}

TEST(ByteStringTest, FromStdString) {
  std::string original{"foo"};
  ByteString copy{original};
  EXPECT_THAT(copy, BytesEq(original));

  original = "bar";
  EXPECT_THAT(copy, BytesEq("foo"));
}

TEST(ByteStringTest, FromCString) {
  char original[] = {'f', 'o', 'o', '\0'};
  ByteString copy{original};
  EXPECT_THAT(copy, BytesEq(original));

  original[0] = 'b';
  EXPECT_THAT(copy, BytesEq("foo"));
}

TEST(ByteStringTest, TakesNullTerminatedByteArray) {
  auto original = MakeBytesArray(4);
  memcpy(original->bytes, "foo", 4);  // null terminator
  original->size = 3;

  ByteString wrapper = ByteString::Take(original);
  EXPECT_THAT(wrapper, BytesEq("foo"));

  original->bytes[0] = 'b';
  EXPECT_THAT(wrapper, BytesEq("boo"));
}

TEST(ByteStringTest, TakesUnterminatedByteArray) {
  auto original = MakeBytesArray(3);
  memcpy(original->bytes, "foo", 3);  // no null terminator
  original->size = 3;

  ByteString wrapper = ByteString::Take(original);
  EXPECT_THAT(wrapper, BytesEq("foo"));

  // Verify that Take did not copy.
  EXPECT_EQ(wrapper.get(), original);
}

TEST(ByteStringTest, TakesEmptyByteArray) {
  auto original = MakeBytesArray(0);
  original->size = 0;

  ByteString wrapper = ByteString::Take(original);
  EXPECT_THAT(wrapper, BytesEq(""));

  // Verify that Take did not copy. This also ensures that the original pointer
  // ends up managed by this instance. If Take chose to make bytes null when
  // the input is empty, it would have to free the input.
  EXPECT_EQ(wrapper.get(), original);
}

TEST(ByteStringTest, Release) {
  ByteString value{"foo"};

  pb_bytes_array_t* released = value.release();
  EXPECT_EQ(value.get(), nullptr);

  EXPECT_EQ(released->size, 3);
  EXPECT_EQ(memcmp(released->bytes, "foo", 3), 0);

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

TEST(ByteStringTest, ToString) {
  EXPECT_EQ(ByteString{""}.ToString(), "");
  EXPECT_EQ(ByteString{"abc"}.ToString(), "abc");
  EXPECT_EQ(ByteString{"abc\ndef"}.ToString(), "abc\\ndef");
  EXPECT_EQ(ByteString{"abc\002"}.ToString(), "abc\\002");
}

}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase
