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

#include "Firestore/core/src/util/md5.h"
#include "Firestore/core/test/unit/testutil/md5_testing.h"

#include "gtest/gtest.h"

using firebase::firestore::testutil::md5::Uint8ArrayFromHexDigest;
using firebase::firestore::util::CalculateMd5Digest;

namespace {

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfEmptyString) {
  EXPECT_EQ(CalculateMd5Digest(""),
            Uint8ArrayFromHexDigest("d41d8cd98f00b204e9800998ecf8427e"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfA) {
  EXPECT_EQ(CalculateMd5Digest("a"),
            Uint8ArrayFromHexDigest("0cc175b9c0f1b6a831c399e269772661"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfABC) {
  EXPECT_EQ(CalculateMd5Digest("abc"),
            Uint8ArrayFromHexDigest("900150983cd24fb0d6963f7d28e17f72"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfHelloWorld) {
  EXPECT_EQ(CalculateMd5Digest("hello world!"),
            Uint8ArrayFromHexDigest("fc3ff98e8c6a0d3087d515c0473f8677"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfMessageDigest) {
  EXPECT_EQ(CalculateMd5Digest("message digest"),
            Uint8ArrayFromHexDigest("f96b697d7cb7938d525a2f31aaf161d0"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfLowercaseAlphabet) {
  EXPECT_EQ(CalculateMd5Digest("abcdefghijklmnopqrstuvwxyz"),
            Uint8ArrayFromHexDigest("c3fcd3d76192e4007dfb496cca67e13b"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfAlphabetLowerUpperNums) {
  EXPECT_EQ(
      CalculateMd5Digest(
          "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"),
      Uint8ArrayFromHexDigest("d174ab98d277d9f5a5611c2c9f419d9f"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfDigits) {
  EXPECT_EQ(CalculateMd5Digest("12345678901234567890123456789012345678901234567"
                               "890123456789012345678901234567890"),
            Uint8ArrayFromHexDigest("57edf4a22be3c955ac49da2e2107b67a"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfTheQuickBrownFox) {
  EXPECT_EQ(CalculateMd5Digest("the quick brown fox jumps over the lazy dog"),
            Uint8ArrayFromHexDigest("77add1d5f41223d5582fca736a5cb335"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfShortStringWithAllChars) {
  std::string s;
  for (int i = 0; i < 512; ++i) {
    s += static_cast<char>(i);
  }
  EXPECT_EQ(CalculateMd5Digest(s),
            Uint8ArrayFromHexDigest("f5c8e3c31c044bae0e65569560b54332"));
}

TEST(CalculateMd5DigestTest, ShouldReturnMd5DigestOfLongStringWithAllChars) {
  std::string s;
  for (int i = 0; i < 8192; ++i) {
    s += static_cast<char>(i);
  }
  EXPECT_EQ(CalculateMd5Digest(s),
            Uint8ArrayFromHexDigest("6556112372898c69e1de0bf689d8db26"));
}

}  // namespace
