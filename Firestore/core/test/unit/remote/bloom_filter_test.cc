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

#include "Firestore/core/src/remote/bloom_filter.h"
#include <vector>
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

class BloomFilterTest : public ::testing::Test {};

TEST_F(BloomFilterTest, CanInstantiateEmptyBloomFilter) {
  BloomFilter bloomFilter = BloomFilter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_EQ(bloomFilter.bit_count(), 0);
}

TEST_F(BloomFilterTest, CanInstantiateNonEmptyBloomFilter) {
  BloomFilter bloomFilter = BloomFilter(std::vector<uint8_t>{1}, 1, 1);
  EXPECT_EQ(bloomFilter.bit_count(), 7);
}

TEST_F(BloomFilterTest, CanRunMightContain) {
  // A non-empty BloomFilter object with 1 insertion : "ÀÒ∑"
  BloomFilter bloomFilter = BloomFilter(std::vector<uint8_t>{237, 5}, 5, 8);
  EXPECT_TRUE(bloomFilter.MightContain("ÀÒ∑"));
  EXPECT_FALSE(bloomFilter.MightContain("Ò∑À"));
}

}  // namespace remote
}  //  namespace firestore
}  //  namespace firebase
