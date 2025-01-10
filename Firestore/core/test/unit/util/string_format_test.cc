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

#include "Firestore/core/src/util/string_format.h"

#include <algorithm>
#include <sstream>
#include <string>

#include "absl/strings/string_view.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

using testing::HasSubstr;
using testing::MatchesRegex;

std::string lowercase(const std::string& str) {
  std::string lower_str = str;
  std::transform(lower_str.begin(), lower_str.end(), lower_str.begin(),
                 [](auto c) { return std::tolower(c); });
  return lower_str;
}

template <typename T>
std::string hex_address(const T* ptr) {
  std::ostringstream os;
  os << std::hex << reinterpret_cast<uintptr_t>(ptr);
  return os.str();
}

}  // namespace

TEST(StringFormatTest, Empty) {
  EXPECT_EQ("", StringFormat(""));
  EXPECT_EQ("", StringFormat("%s", std::string().c_str()));
  EXPECT_EQ("", StringFormat("%s", ""));
}

TEST(StringFormatTest, CString) {
  EXPECT_EQ("Hello World", StringFormat("Hello %s", "World"));
  EXPECT_EQ("Hello World", StringFormat("%s World", "Hello"));
  EXPECT_EQ("Hello World", StringFormat("Hello%sWorld", " "));

  const char* value = "World";
  EXPECT_EQ("Hello World", StringFormat("Hello %s", value));

  value = nullptr;
  EXPECT_EQ("Hello null", StringFormat("Hello %s", value));
}

TEST(StringFormatTest, String) {
  EXPECT_EQ("Hello World", StringFormat("Hello %s", std::string{"World"}));

  std::string value{"World"};
  EXPECT_EQ("Hello World", StringFormat("Hello %s", value));
}

TEST(StringFormatTest, StringView) {
  EXPECT_EQ("Hello World",
            StringFormat("Hello %s", absl::string_view{"World"}));
  EXPECT_EQ("Hello World",
            StringFormat("%s World", absl::string_view{"Hello"}));
  EXPECT_EQ("Hello World",
            StringFormat("Hello%sWorld", absl::string_view{" "}));
}

TEST(StringFormatTest, Int) {
  std::string value = StringFormat("Hello %s", 123);
  EXPECT_EQ("Hello 123", value);
}

TEST(StringFormatTest, Float) {
  std::string value = StringFormat("Hello %s", 1.5);
  EXPECT_EQ("Hello 1.5", value);
}

TEST(StringFormatTest, Bool) {
  EXPECT_EQ("Hello true", StringFormat("Hello %s", true));
  EXPECT_EQ("Hello false", StringFormat("Hello %s", false));
}

TEST(StringFormatTest, NullPointer) {
  // pointers implicitly convert to bool. Make sure this doesn't happen here.
  EXPECT_EQ("Hello null", StringFormat("Hello %s", nullptr));
}

TEST(StringFormatTest, NonNullPointer) {
  // pointers implicitly convert to bool. Make sure this doesn't happen here.
  int value = 4;

  const std::string formatted_string = StringFormat("Hello %s", &value);

  const std::string hex_address_regex = "(0x)?[0123456789abcdefABCDEF]+";
  EXPECT_THAT(formatted_string, MatchesRegex("Hello " + hex_address_regex));
  const std::string expected_hex_address = lowercase(hex_address(&value));
  EXPECT_THAT(lowercase(formatted_string), HasSubstr(expected_hex_address));
}

TEST(StringFormatTest, Mixed) {
  EXPECT_EQ("string=World, bool=true, int=42, float=1.5",
            StringFormat("string=%s, bool=%s, int=%s, float=%s", "World", true,
                         42, 1.5));
  EXPECT_EQ("World%true%42%1.5",
            StringFormat("%s%%%s%%%s%%%s", "World", true, 42, 1.5));
}

TEST(StringFormatTest, Hex) {
  EXPECT_EQ("test=42", StringFormat("test=%x", "B"));
}

TEST(StringFormatTest, Literal) {
  EXPECT_EQ("Hello %", StringFormat("Hello %%"));
  EXPECT_EQ("% World", StringFormat("%% World"));
}

TEST(StringFormatTest, Invalid) {
  EXPECT_EQ("Hello <invalid>", StringFormat("Hello %@", 42));
}

TEST(StringFormatTest, Missing) {
  EXPECT_EQ("Hello <missing>", StringFormat("Hello %s"));
}

TEST(StringFormatTest, Excess) {
  EXPECT_EQ("Hello World", StringFormat("Hello %s", "World", 42));
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
