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

#include "bits.h"

#include <iostream>

#include "base/commandlineflags.h"
#include "testing/base/public/gunit.h"
#include "util/random/mt_random.h"

using Firestore::Bits;

DEFINE_int32(num_iterations, 10000, "Number of test iterations to run.");

class BitsTest : public testing::Test {
 public:
  BitsTest() : random_(testing::FLAGS_gunit_random_seed) {}

 protected:
  MTRandom random_;
};

TEST_F(BitsTest, Log2EdgeCases) {
  std::cout << "TestLog2EdgeCases" << std::endl;

  EXPECT_EQ(-1, Bits::Log2Floor(0));
  EXPECT_EQ(-1, Bits::Log2Floor64(0));

  for (int i = 0; i < 32; i++) {
    uint32 n = 1U << i;
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
    uint64 n = 1ULL << i;
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
  std::cout << "TestLog2Random" << std::endl;

  for (int i = 0; i < FLAGS_num_iterations; i++) {
    int maxbit = -1;
    uint32 n = 0;
    while (!random_.OneIn(32)) {
      int bit = random_.Uniform(32);
      n |= (1U << bit);
      maxbit = std::max(bit, maxbit);
    }
    EXPECT_EQ(maxbit, Bits::Log2Floor(n));
    if (n != 0) {
      EXPECT_EQ(maxbit, Bits::Log2FloorNonZero(n));
    }
  }
}

TEST_F(BitsTest, Log2Random64) {
  std::cout << "TestLog2Random64" << std::endl;

  for (int i = 0; i < FLAGS_num_iterations; i++) {
    int maxbit = -1;
    uint64 n = 0;
    while (!random_.OneIn(64)) {
      int bit = random_.Uniform(64);
      n |= (1ULL << bit);
      maxbit = std::max(bit, maxbit);
    }
    EXPECT_EQ(maxbit, Bits::Log2Floor64(n));
    if (n != 0) {
      EXPECT_EQ(maxbit, Bits::Log2FloorNonZero64(n));
    }
  }
}

TEST(Bits, Port32) {
  for (int shift = 0; shift < 32; shift++) {
    for (int delta = -1; delta <= +1; delta++) {
      const uint32 v = (static_cast<uint32>(1) << shift) + delta;
      EXPECT_EQ(Bits::Log2Floor_Portable(v), Bits::Log2Floor(v)) << v;
      if (v != 0) {
        EXPECT_EQ(Bits::Log2FloorNonZero_Portable(v), Bits::Log2FloorNonZero(v))
            << v;
      }
    }
  }
  static const uint32 M32 = kuint32max;
  EXPECT_EQ(Bits::Log2Floor_Portable(M32), Bits::Log2Floor(M32)) << M32;
  EXPECT_EQ(Bits::Log2FloorNonZero_Portable(M32), Bits::Log2FloorNonZero(M32))
      << M32;
}

TEST(Bits, Port64) {
  for (int shift = 0; shift < 64; shift++) {
    for (int delta = -1; delta <= +1; delta++) {
      const uint64 v = (static_cast<uint64>(1) << shift) + delta;
      EXPECT_EQ(Bits::Log2Floor64_Portable(v), Bits::Log2Floor64(v)) << v;
      if (v != 0) {
        EXPECT_EQ(Bits::Log2FloorNonZero64_Portable(v),
                  Bits::Log2FloorNonZero64(v))
            << v;
      }
    }
  }
  static const uint64 M64 = kuint64max;
  EXPECT_EQ(Bits::Log2Floor64_Portable(M64), Bits::Log2Floor64(M64)) << M64;
  EXPECT_EQ(Bits::Log2FloorNonZero64_Portable(M64),
            Bits::Log2FloorNonZero64(M64))
      << M64;
}
