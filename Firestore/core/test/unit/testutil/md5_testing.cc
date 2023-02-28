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

#include "Firestore/core/test/unit/testutil/md5_testing.h"

#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace testutil {
namespace md5 {

std::uint8_t UnsignedCharFromHexDigit(char digit) {
  switch (digit) {
    case '0':
      return 0x0;
    case '1':
      return 0x1;
    case '2':
      return 0x2;
    case '3':
      return 0x3;
    case '4':
      return 0x4;
    case '5':
      return 0x5;
    case '6':
      return 0x6;
    case '7':
      return 0x7;
    case '8':
      return 0x8;
    case '9':
      return 0x9;
    case 'a':
      return 0xA;
    case 'b':
      return 0xB;
    case 'c':
      return 0xC;
    case 'd':
      return 0xD;
    case 'e':
      return 0xE;
    case 'f':
      return 0xF;
  }
  HARD_FAIL("unrecognized hex digit: %s", std::to_string(digit));
}

std::array<std::uint8_t, 16> Uint8ArrayFromHexDigest(const std::string& s) {
  HARD_ASSERT(s.length() == 32);
  std::array<std::uint8_t, 16> result;
  for (int i = 0; i < 16; ++i) {
    std::uint8_t c1 = UnsignedCharFromHexDigit(s[i * 2]);
    std::uint8_t c2 = UnsignedCharFromHexDigit(s[(i * 2) + 1]);
    result[i] = (c1 << 4) | c2;
  }
  return result;
}

}  // namespace md5
}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
