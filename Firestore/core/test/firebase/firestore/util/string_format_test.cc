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

#include "Firestore/core/src/firebase/firestore/util/string_format.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(StringFormatTest, Empty) {
  EXPECT_EQ("", StringFormat(""));
  EXPECT_EQ("", StringFormat("%s", std::string().c_str()));
  EXPECT_EQ("", StringFormat("%s", ""));
}

TEST(StringFormatTest, String) {
  std::string value = StringFormat("Hello %s", "World");
  EXPECT_EQ("Hello World", value);
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

TEST(StringFormatTest, Pointer) {
  // pointers implicitly convert to bool. Make sure this doesn't happen in
  // this API.
  int value = 4;
  EXPECT_NE("Hello true", StringFormat("Hello %s", &value));
}

TEST(StringFormatTest, ToString) {
  struct Foo {
    std::string ToString() const {
      return "Foo";
    }
  };

  Foo foo;
  EXPECT_EQ("Hello Foo", StringFormat("Hello %s", foo.ToString()));
}

TEST(StringFormatTest, Mixed) {
  EXPECT_EQ("string=World, bool=true, int=42, float=1.5",
            StringFormat("string=%s, bool=%s, int=%s, float=%s", "World", true,
                         42, 1.5));
}

TEST(StringFormatTest, Invalid) {
  EXPECT_EQ("Hello <invalid>", StringFormat("Hello %@", 42));
}

TEST(StringFormatTest, Missing) {
  EXPECT_EQ("Hello <missing>", StringFormat("Hello %s"));
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
