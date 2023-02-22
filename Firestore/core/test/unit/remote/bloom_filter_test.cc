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

using util::Status;
using util::StatusOr;

class BloomFilterTest : public ::testing::Test {};

TEST_F(BloomFilterTest, CanInstantiateEmptyBloomFilter) {
  BloomFilter bloom_Filter = BloomFilter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_EQ(bloom_Filter.bit_count(), 0);
}

TEST_F(BloomFilterTest, CanInstantiateNonEmptyBloomFilter) {
  {
    BloomFilter bloom_Filter_1 = BloomFilter(std::vector<uint8_t>{1}, 0, 1);
    EXPECT_EQ(bloom_Filter_1.bit_count(), 8);
  }
  {
    BloomFilter bloom_Filter_2 = BloomFilter(std::vector<uint8_t>{1}, 7, 1);
    EXPECT_EQ(bloom_Filter_2.bit_count(), 1);
  }
}

/* Test Create factory method with valid and invalid inputs */
TEST_F(BloomFilterTest, CreateMethodShouldReturnBloomFilterOnValidInputs) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 1, 1);
  EXPECT_TRUE(maybe_bloom_filter.ok());
  BloomFilter bloom_filter = maybe_bloom_filter.ValueOrDie();
  EXPECT_EQ(bloom_filter.bit_count(), 7);
}

TEST_F(BloomFilterTest, CreateMethodShouldReturnNotOKStatusOnNegativePadding) {
  {
    StatusOr<BloomFilter> maybe_bloom_filter_1 =
        BloomFilter::Create(std::vector<uint8_t>{0}, -1, 1);
    EXPECT_FALSE(maybe_bloom_filter_1.ok());
    EXPECT_EQ(maybe_bloom_filter_1.status().error_message(),
              "Invalid padding: -1");
  }
  {
    StatusOr<BloomFilter> maybe_bloom_filter_2 =
        BloomFilter::Create(std::vector<uint8_t>{1}, -1, 1);
    EXPECT_FALSE(maybe_bloom_filter_2.ok());
    EXPECT_EQ(maybe_bloom_filter_2.status().error_message(),
              "Invalid padding: -1");
  }
}

TEST_F(BloomFilterTest,
       CreateMethodShouldReturnNotOKStatusOnNegativeHashCount) {
  {
    StatusOr<BloomFilter> maybe_bloom_filter_1 =
        BloomFilter::Create(std::vector<uint8_t>{0}, 0, -1);
    EXPECT_FALSE(maybe_bloom_filter_1.ok());
    EXPECT_EQ(maybe_bloom_filter_1.status().error_message(),
              "Invalid hash count: -1");
  }
  {
    StatusOr<BloomFilter> maybe_bloom_filter_2 =
        BloomFilter::Create(std::vector<uint8_t>{1}, 1, -1);
    EXPECT_FALSE(maybe_bloom_filter_2.ok());
    EXPECT_EQ(maybe_bloom_filter_2.status().error_message(),
              "Invalid hash count: -1");
  }
}

TEST_F(BloomFilterTest, CreateMethodShouldReturnNotOKStatusOnZeroHashCount) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 1, 0);
  EXPECT_FALSE(maybe_bloom_filter.ok());
  EXPECT_EQ(maybe_bloom_filter.status().error_message(),
            "Invalid hash count: 0");
}

TEST_F(BloomFilterTest,
       CreateMethodShouldReturnNotOKStatusIfPaddingIsTooLarge) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 8, 1);
  EXPECT_FALSE(maybe_bloom_filter.ok());
  EXPECT_EQ(maybe_bloom_filter.status().error_message(), "Invalid padding: 8");
}

TEST_F(BloomFilterTest, MightContainCanProcessNonStandardCharacters) {
  // A non-empty BloomFilter object with 1 insertion : "ÀÒ∑"
  BloomFilter bloom_Filter = BloomFilter(std::vector<uint8_t>{237, 5}, 5, 8);
  EXPECT_TRUE(bloom_Filter.MightContain("ÀÒ∑"));
  EXPECT_FALSE(bloom_Filter.MightContain("Ò∑À"));
}

TEST_F(BloomFilterTest, MightContainOnEmptyBloomFilterShouldReturnFalse) {
  BloomFilter bloom_Filter = BloomFilter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_FALSE(bloom_Filter.MightContain(""));
  EXPECT_FALSE(bloom_Filter.MightContain("a"));
}

TEST_F(BloomFilterTest,
       MightContainWithEmptyStringMightReturnFalsePositiveResult) {
  {
    BloomFilter bloom_Filter_1 = BloomFilter(std::vector<uint8_t>{1}, 1, 1);
    EXPECT_FALSE(bloom_Filter_1.MightContain(""));
  }
  {
    BloomFilter bloom_Filter_2 = BloomFilter(std::vector<uint8_t>{255}, 0, 16);
    EXPECT_TRUE(bloom_Filter_2.MightContain(""));
  }
}

}  // namespace remote
}  //  namespace firestore
}  //  namespace firebase
