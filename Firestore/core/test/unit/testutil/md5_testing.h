/*
 * Copyright 2023 Google LLC
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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_MD5_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_MD5_TESTING_H_

#include <array>
#include <cstdint>
#include <string>

namespace firebase {
namespace firestore {
namespace testutil {
namespace md5 {

// Gets the unsigned char corresponding to the given hex digit.
// The digit must be one of '0', '1', ... , '9', 'a', 'b', ... , 'f'.
// The lower 4 bits of the returned value will be set and the rest will be 0.
std::uint8_t UnsignedCharFromHexDigit(char digit);

// Calculates the 16-byte uint8_t array represented by the given hex
// string. The given string must be exactly 32 characters and each character
// must be one that is accepted by the UnsignedCharFromHexDigit() function.
// e.g. "fc3ff98e8c6a0d3087d515c0473f8677".
// The `md5sum` command from GNU coreutils can be used to generate a string to
// specify to this function.
// e.g.
// $ printf 'hello world!' | md5sum -
// fc3ff98e8c6a0d3087d515c0473f8677 -
std::array<std::uint8_t, 16> Uint8ArrayFromHexDigest(const std::string&);

}  // namespace md5
}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_MD5_TESTING_H_
