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

#include "Firestore/src/support/secure_random.h"

#include "gtest/gtest.h"

using firestore::SecureRandom;

TEST(SecureRandomTest, ResultsAreBounded) {
  SecureRandom rng;

  // Verify that values are on the min/max closed interval.
  for (int i = 0; i < 1000; i++) {
    SecureRandom::result_type value = rng();
    EXPECT_GE(value, rng.min());
    EXPECT_LE(value, rng.max());
  }
}
