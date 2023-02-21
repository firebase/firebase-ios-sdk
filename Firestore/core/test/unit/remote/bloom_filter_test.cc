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
#include "Firestore/core/src/remote/bloom_filter_exception.h"

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
  {
    BloomFilter bloomFilter1 = BloomFilter(std::vector<uint8_t>{1}, 0, 1);
    EXPECT_EQ(bloomFilter1.bit_count(), 8);
  }
  {
    BloomFilter bloomFilter2 = BloomFilter(std::vector<uint8_t>{1}, 7, 1);
    EXPECT_EQ(bloomFilter2.bit_count(), 1);
  }
}

/** Handle exception in creating bloomFilter instance*/
TEST_F(BloomFilterTest,
       ConstructorShouldThrowExceptionOnNonEmptyBloomFilterWithZeroHashCount) {
  EXPECT_THROW(BloomFilter(std::vector<uint8_t>{1}, 1, 0),
               BloomFilterException);
}

TEST_F(BloomFilterTest, ConstructorShouldThrowExceptionOnNegativePadding) {
  {
    EXPECT_THROW(BloomFilter(std::vector<uint8_t>{0}, -1, 1),
                 BloomFilterException);
  }
  {
    EXPECT_THROW(BloomFilter(std::vector<uint8_t>{1}, -1, 1),
                 BloomFilterException);
  }
}

TEST_F(BloomFilterTest, ConstructorShouldThrowExceptionOnNegativeHashCount) {
  {
    EXPECT_THROW(BloomFilter(std::vector<uint8_t>{0}, 0, -1),
                 BloomFilterException);
  }
  {
    EXPECT_THROW(BloomFilter(std::vector<uint8_t>{1}, 1, -1),
                 BloomFilterException);
  }
}

TEST_F(BloomFilterTest, ConstructorShouldThrowExceptionIfPaddingIsTooLarge) {
  EXPECT_THROW(BloomFilter(std::vector<uint8_t>{1}, 8, 1),
               BloomFilterException);
}

/* Test mightContain result */
TEST_F(BloomFilterTest, MightContainCanProcessNonStandardCharacters) {
  // A non-empty BloomFilter object with 1 insertion : "ÀÒ∑"
  BloomFilter bloomFilter = BloomFilter(std::vector<uint8_t>{237, 5}, 5, 8);
  EXPECT_TRUE(bloomFilter.MightContain("ÀÒ∑"));
  EXPECT_FALSE(bloomFilter.MightContain("Ò∑À"));
}

TEST_F(BloomFilterTest, MightContainOnEmptyBloomFilterShouldReturnFalse) {
  BloomFilter bloomFilter = BloomFilter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_FALSE(bloomFilter.MightContain(""));
  EXPECT_FALSE(bloomFilter.MightContain("a"));
}

TEST_F(BloomFilterTest,
       MightContainWithEmptyStringMightReturnFalsePositiveResult) {
  {
    BloomFilter bloomFilter1 = BloomFilter(std::vector<uint8_t>{1}, 1, 1);
    EXPECT_FALSE(bloomFilter1.MightContain(""));
  }
  {
    BloomFilter bloomFilter2 = BloomFilter(std::vector<uint8_t>{255}, 0, 16);
    EXPECT_TRUE(bloomFilter2.MightContain(""));
  }
}

}  // namespace remote
}  //  namespace firestore
}  //  namespace firebase
