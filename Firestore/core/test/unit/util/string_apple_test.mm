/*
 * Copyright 2018 Google LLC
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

#include "Firestore/core/src/util/string_apple.h"

#include <string>
#include <vector>

#include "Firestore/core/src/util/defer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

class StringAppleTest : public testing::Test {
 protected:
  std::vector<std::string> StringTestCases() {
    return std::vector<std::string>{
        "",
        "a",
        "abc def",
        u8"æ",
        // Note: Each one of the three embedded universal character names
        // (\u-escaped) maps to three chars, so the total length of the string
        // literal is 10 (ignoring the terminating null), and the resulting
        // string literal is the same as
        // '\0\xed\x9f\xbf\xee\x80\x80\xef\xbf\xbf'". The size of 10 must be
        // added, or else std::string will see the \0 at the start and assume
        // that's the end of the string.
        {u8"\0\ud7ff\ue000\uffff", 10},
        {"\0\xed\x9f\xbf\xee\x80\x80\xef\xbf\xbf", 10},
        u8"(╯°□°）╯︵ ┻━┻",
    };
  }
};

TEST_F(StringAppleTest, MakeStringFromCFStringRef) {
  for (const std::string& string_value : StringTestCases()) {
    CFStringRef cf_string = MakeCFString(string_value);
    Defer cleanup([&] { SafeCFRelease(cf_string); });

    std::string actual = MakeString(cf_string);
    EXPECT_EQ(string_value, actual);
  }
}

TEST_F(StringAppleTest, MakeStringFromNSString) {
  for (const std::string& string_value : StringTestCases()) {
    NSString* ns_string = MakeNSString(string_value);
    std::string actual = MakeString(ns_string);
    EXPECT_EQ(string_value, actual);
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
