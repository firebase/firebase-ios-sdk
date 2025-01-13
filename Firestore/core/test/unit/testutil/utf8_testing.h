/*
 * Copyright 2025 Google LLC
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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_UTF8_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_UTF8_TESTING_H_

#include <string>

namespace firebase {
namespace firestore {
namespace testutil {

// TODO(c++20): Remove the #if check below and delete the #else block.
#if __cplusplus >= 202002L

// Creates a std::string whose contents are the bytes of the given null
// terminated string.
// e.g. std::string s = StringFromU8String(u8"foobar");
constexpr std::string StringFromU8String(const char8_t* s) {
  const std::u8string u8s(s);
  return std::string(u8s.begin(), u8s.end());
}

// Creates a std::string whose contents are the first count bytes of the given
// null terminated string.
// e.g. std::string s = StringFromU8String(u8"foobar", 4);
constexpr std::string StringFromU8String(const char8_t* s,
                                         std::string::size_type count) {
  const std::u8string u8s(s, count);
  return std::string(u8s.begin(), u8s.end());
}

#else  // __cplusplus >= 202002L

// Creates a std::string whose contents are the bytes of the given null
// terminated string.
// e.g. std::string s = StringFromU8String(u8"foobar");
inline std::string StringFromU8String(const char* s) {
  return std::string(s);
}

// Creates a std::string whose contents are the first count bytes of the given
// null terminated string.
// e.g. std::string s = StringFromU8String(u8"foobar", 4);
inline std::string StringFromU8String(const char* s,
                                      std::string::size_type count) {
  return std::string(s, count);
}

#endif  // __cplusplus >= 202002L

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_UTF8_TESTING_H_
