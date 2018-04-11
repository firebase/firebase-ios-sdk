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

#include "Firestore/core/src/firebase/firestore/util/string_printf.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(StringPrintf, Empty) {
  EXPECT_EQ("", StringPrintf(""));
  EXPECT_EQ("", StringPrintf("%s", std::string().c_str()));
  EXPECT_EQ("", StringPrintf("%s", ""));
}

TEST(StringAppendFTest, Empty) {
  std::string value("Hello");
  const char* empty = "";
  StringAppendF(&value, "%s", empty);
  EXPECT_EQ("Hello", value);
}

TEST(StringAppendFTest, EmptyString) {
  std::string value("Hello");
  StringAppendF(&value, "%s", "");
  EXPECT_EQ("Hello", value);
}

TEST(StringAppendFTest, String) {
  std::string value("Hello");
  StringAppendF(&value, " %s", "World");
  EXPECT_EQ("Hello World", value);
}

TEST(StringAppendFTest, Int) {
  std::string value("Hello");
  StringAppendF(&value, " %d", 123);
  EXPECT_EQ("Hello 123", value);
}

TEST(StringPrintf, DontOverwriteErrno) {
  // Check that errno isn't overwritten unless we're printing
  // something significantly larger than what people are normally
  // printing in their badly written PLOG() statements.
  errno = ECHILD;
  std::string value = StringPrintf("Hello, %s!", "World");
  EXPECT_EQ(ECHILD, errno);
}

TEST(StringPrintf, LargeBuf) {
  // Check that the large buffer is handled correctly.
  size_t n = 2048;
  char* buf = new char[n + 1];
  memset(buf, ' ', n);
  buf[n] = 0;
  std::string value = StringPrintf("%s", buf);
  EXPECT_EQ(buf, value);
  delete[] buf;
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
