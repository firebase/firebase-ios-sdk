/*
 * Copyright 2017 Google LLC
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

#include "Firestore/core/src/util/bits.h"

#include <algorithm>
#include <iostream>
#include <limits>

#include "Firestore/core/src/util/secure_random.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

const int kNumIterations = 10000;  // "Number of test iterations to run.

class BitsTest : public testing::Test {
 protected:
  SecureRandom random_;
};

TEST_F(BitsTest, Log2EdgeCases) {
  EXPECT_EQ(-1, Bits::Log2Floor(0));
  EXPECT_EQ(-1, Bits::Log2Floor64(0));

  for (int i = 0; i < 32; i++) {
    uint32_t n = 1U << i;
    EXPECT_EQ(i, Bits::Log2Floor(n));
    EXPECT_EQ(i, Bits::Log2FloorNonZero(n));
    if (n > 2) {
      EXPECT_EQ(i - 1, Bits::Log2Floor(n - 1));
      EXPECT_EQ(i, Bits::Log2Floor(n + 1));
      EXPECT_EQ(i - 1, Bits::Log2FloorNonZero(n - 1));
      EXPECT_EQ(i, Bits::Log2FloorNonZero(n + 1));
    }
  }

  for (int i = 0; i < 64; i++) {
    uint64_t n = 1ULL << i;
    EXPECT_EQ(i, Bits::Log2Floor64(n));
    EXPECT_EQ(i, Bits::Log2FloorNonZero64(n));
    if (n > 2) {
      EXPECT_EQ(i - 1, Bits::Log2Floor64(n - 1));
      EXPECT_EQ(i, Bits::Log2Floor64(n + 1));
      EXPECT_EQ(i - 1, Bits::Log2FloorNonZero64(n - 1));
      EXPECT_EQ(i, Bits::Log2FloorNonZero64(n + 1));
    }
  }
}

TEST_F(BitsTest, Log2Random) {
  for (int i = 0; i < kNumIterations; i++) {
    int max_bit = -1;
    uint32_t n = 0;
    while (!random_.OneIn(32u)) {
      int bit = static_cast<int>(random_.Uniform(32u));
      n |= (1U << bit);
      max_bit = std::max(bit, max_bit);
    }
    EXPECT_EQ(max_bit, Bits::Log2Floor(n));
    if (n != 0) {
      EXPECT_EQ(max_bit, Bits::Log2FloorNonZero(n));
    }
  }
}

TEST_F(BitsTest, Log2Random64) {
  for (int i = 0; i < kNumIterations; i++) {
    int max_bit = -1;
    uint64_t n = 0;
    while (!random_.OneIn(64u)) {
      int bit = static_cast<int>(random_.Uniform(64u));
      n |= (1ULL << bit);
      max_bit = std::max(bit, max_bit);
    }
    EXPECT_EQ(max_bit, Bits::Log2Floor64(n));
    if (n != 0) {
      EXPECT_EQ(max_bit, Bits::Log2FloorNonZero64(n));
    }
  }
}

TEST(Bits, Port32) {
  for (int shift = 0; shift < 32; shift++) {
    for (uint32_t delta = 0; delta <= 2; delta++) {
      const uint32_t v = (static_cast<uint32_t>(1) << shift) - 1 + delta;
      EXPECT_EQ(Bits::Log2Floor_Portable(v), Bits::Log2Floor(v)) << v;
      if (v != 0) {
        EXPECT_EQ(Bits::Log2FloorNonZero_Portable(v), Bits::Log2FloorNonZero(v))
            << v;
      }
    }
  }
  static const uint32_t M32 = std::numeric_limits<uint32_t>::max();
  EXPECT_EQ(Bits::Log2Floor_Portable(M32), Bits::Log2Floor(M32)) << M32;
  EXPECT_EQ(Bits::Log2FloorNonZero_Portable(M32), Bits::Log2FloorNonZero(M32))
      << M32;
}

TEST(Bits, Port64) {
  for (int shift = 0; shift < 64; shift++) {
    for (uint64_t delta = 0; delta <= 2; delta++) {
      const uint64_t v = (static_cast<uint64_t>(1) << shift) - 1 + delta;
      EXPECT_EQ(Bits::Log2Floor64_Portable(v), Bits::Log2Floor64(v)) << v;
      if (v != 0) {
        EXPECT_EQ(Bits::Log2FloorNonZero64_Portable(v),
                  Bits::Log2FloorNonZero64(v))
            << v;
      }
    }
  }
  static const uint64_t M64 = std::numeric_limits<uint64_t>::max();
  EXPECT_EQ(Bits::Log2Floor64_Portable(M64), Bits::Log2Floor64(M64)) << M64;
  EXPECT_EQ(Bits::Log2FloorNonZero64_Portable(M64),
            Bits::Log2FloorNonZero64(M64))
      << M64;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
