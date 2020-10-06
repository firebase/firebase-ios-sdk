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

#include "Firestore/core/src/util/secure_random.h"

#include "gtest/gtest.h"

using firebase::firestore::util::SecureRandom;

TEST(SecureRandomTest, ResultsAreBounded) {
  SecureRandom rng;

  // Verify that values are on the min/max closed interval.
  for (int i = 0; i < 1000; i++) {
    SecureRandom::result_type value = rng();
    EXPECT_GE(value, rng.min());
    EXPECT_LE(value, rng.max());
  }
}

TEST(SecureRandomTest, Uniform) {
  SecureRandom rng;
  int count[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

  for (int i = 0; i < 1000; i++) {
    count[rng.Uniform(10)]++;
  }
  for (int i = 0; i < 10; i++) {
    // Practically, each count should be close to 100.
    EXPECT_LT(50, count[i]) << count[i];
  }
}

TEST(SecureRandomTest, OneIn) {
  SecureRandom rng;
  int count = 0;

  for (int i = 0; i < 1000; i++) {
    if (rng.OneIn(10)) count++;
  }
  // Practically, count should be close to 100.
  EXPECT_LT(50, count) << count;
  EXPECT_GT(150, count) << count;
}
