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

#include <string>
#include <vector>

#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/md5.h"

#include "gtest/gtest.h"

using firebase::firestore::util::CalculateMd5Digest;

namespace {

// Gets the unsigned char corresponding to the given hex digit.
// The digit must be one of '0', '1', ... , '9', 'a', 'b', ... , 'f'.
// The lower 4 bits of the returned value will be set and the rest will be 0.
unsigned char UnsignedCharFromHexDigit(char digit);

// Calculates the 16-byte unsigned char array represented by the given hex
// string. The given string must be exactly 32 characters and each character
// must be one that is accepted by the UnsignedCharFromHexDigit() function.
// e.g. "fc3ff98e8c6a0d3087d515c0473f8677".
// The `md5sum` command from GNU coreutils can be used to generate a string to
// specify to this function.
// e.g.
// $ printf 'hello world!' | md5sum -
// fc3ff98e8c6a0d3087d515c0473f8677 -
std::array<unsigned char, 16> UnsignedCharArrayFromHexDigest(
    const std::string&);

// Returns the md5 digest for the given string.
// This function does not "calculate" the digest, but rather has a hardcoded set
// of pre-calculated digests that it returns.
// It is an error if this function does not have a pre-calculated digest for the
// given string.
std::array<unsigned char, 16> GetPreComputedMd5Digest(const std::string&);

// Generates and returns a string with all possible characters with the given
// length. The given length must be at least 256.
std::string GetStringWithAllPossibleCharacters(int length);

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfEmptyString) {
  EXPECT_EQ(CalculateMd5Digest(""), GetPreComputedMd5Digest(""));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfA) {
  EXPECT_EQ(CalculateMd5Digest("a"), GetPreComputedMd5Digest("a"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfABC) {
  EXPECT_EQ(CalculateMd5Digest("abc"), GetPreComputedMd5Digest("abc"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfHelloWorld) {
  EXPECT_EQ(CalculateMd5Digest("hello world!"),
            GetPreComputedMd5Digest("hello world!"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfTheQuickBrownFox) {
  EXPECT_EQ(
      CalculateMd5Digest("the quick brown fox jumps over the lazy dog"),
      GetPreComputedMd5Digest("the quick brown fox jumps over the lazy dog"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfShortStringWithAllChars) {
  const std::string s = GetStringWithAllPossibleCharacters(512);
  EXPECT_EQ(CalculateMd5Digest(s), GetPreComputedMd5Digest(s));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfLongStringWithAllChars) {
  const std::string s = GetStringWithAllPossibleCharacters(8192);
  EXPECT_EQ(CalculateMd5Digest(s), GetPreComputedMd5Digest(s));
}

unsigned char UnsignedCharFromHexDigit(char digit) {
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
  };
  HARD_FAIL("unrecognized hex digit: %s", std::to_string(digit));
}

std::array<unsigned char, 16> UnsignedCharArrayFromHexDigest(
    const std::string& s) {
  HARD_ASSERT(s.length() == 32);
  std::array<unsigned char, 16> result;
  for (int i = 0; i < 16; ++i) {
    unsigned char c1 = UnsignedCharFromHexDigit(s[i * 2]);
    unsigned char c2 = UnsignedCharFromHexDigit(s[(i * 2) + 1]);
    result[i] = (c1 << 4) | c2;
  }
  return result;
}

std::array<unsigned char, 16> GetPreComputedMd5Digest(const std::string& s) {
  if (s == "") {
    return UnsignedCharArrayFromHexDigest("d41d8cd98f00b204e9800998ecf8427e");
  } else if (s == "hello world!") {
    return UnsignedCharArrayFromHexDigest("fc3ff98e8c6a0d3087d515c0473f8677");
  } else if (s == "a") {
    return UnsignedCharArrayFromHexDigest("0cc175b9c0f1b6a831c399e269772661");
  } else if (s == "abc") {
    return UnsignedCharArrayFromHexDigest("900150983cd24fb0d6963f7d28e17f72");
  } else if (s == "the quick brown fox jumps over the lazy dog") {
    return UnsignedCharArrayFromHexDigest("77add1d5f41223d5582fca736a5cb335");
  } else if (s == GetStringWithAllPossibleCharacters(512)) {
    return UnsignedCharArrayFromHexDigest("f5c8e3c31c044bae0e65569560b54332");
  } else if (s == GetStringWithAllPossibleCharacters(8192)) {
    return UnsignedCharArrayFromHexDigest("6556112372898c69e1de0bf689d8db26");
  } else {
    HARD_FAIL("no precomputed digest for string: %s", s);
    return {};
  }
}

std::string GetStringWithAllPossibleCharacters(int length) {
  HARD_ASSERT(length >= 256);
  std::string result;
  for (int i = 0; i < length; ++i) {
    result += static_cast<char>(i);
  }
  return result;
}

}  // namespace
