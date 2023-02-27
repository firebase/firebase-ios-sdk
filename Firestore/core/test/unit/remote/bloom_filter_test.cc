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
namespace {

using util::Status;
using util::StatusOr;

TEST(BloomFilterTest, CanInstantiateEmptyBloomFilter) {
  BloomFilter bloom_filter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_EQ(bloom_filter.bit_count(), 0);
}

TEST(BloomFilterTest, CanInstantiateNonEmptyBloomFilter) {
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{1}, 0, 1);
    EXPECT_EQ(bloom_filter.bit_count(), 8);
  }
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{1}, 7, 1);
    EXPECT_EQ(bloom_filter.bit_count(), 1);
  }
}

TEST(BloomFilterTest, CreateShouldReturnBloomFilterOnValidInputs) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 1, 1);
  ASSERT_TRUE(maybe_bloom_filter.ok());
  BloomFilter bloom_filter = maybe_bloom_filter.ValueOrDie();
  EXPECT_EQ(bloom_filter.bit_count(), 7);
}

TEST(BloomFilterTest, CreateShouldBeAbleToCreatEmptyBloomFilter) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{}, 0, 0);
  ASSERT_TRUE(maybe_bloom_filter.ok());
  BloomFilter bloom_filter = maybe_bloom_filter.ValueOrDie();
  EXPECT_EQ(bloom_filter.bit_count(), 0);
}

TEST(BloomFilterTest, CreateShouldReturnNotOKStatusOnNegativePadding) {
  {
    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::vector<uint8_t>{}, -1, 0);
    ASSERT_FALSE(maybe_bloom_filter.ok());
    EXPECT_EQ(maybe_bloom_filter.status().error_message(),
              "Invalid padding: -1");
  }
  {
    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::vector<uint8_t>{1}, -1, 1);
    ASSERT_FALSE(maybe_bloom_filter.ok());
    EXPECT_EQ(maybe_bloom_filter.status().error_message(),
              "Invalid padding: -1");
  }
}

TEST(BloomFilterTest, CreateShouldReturnNotOKStatusOnNegativeHashCount) {
  {
    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::vector<uint8_t>{}, 0, -1);
    ASSERT_FALSE(maybe_bloom_filter.ok());
    EXPECT_EQ(maybe_bloom_filter.status().error_message(),
              "Invalid hash count: -1");
  }
  {
    StatusOr<BloomFilter> maybe_bloom_filter =
        BloomFilter::Create(std::vector<uint8_t>{1}, 1, -1);
    ASSERT_FALSE(maybe_bloom_filter.ok());
    EXPECT_EQ(maybe_bloom_filter.status().error_message(),
              "Invalid hash count: -1");
  }
}

TEST(BloomFilterTest, CreateShouldReturnNotOKStatusOnZeroHashCount) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 1, 0);
  ASSERT_FALSE(maybe_bloom_filter.ok());
  EXPECT_EQ(maybe_bloom_filter.status().error_message(),
            "Invalid hash count: 0");
}

TEST(BloomFilterTest, CreateShouldReturnNotOKStatusIfPaddingIsTooLarge) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 8, 1);
  ASSERT_FALSE(maybe_bloom_filter.ok());
  EXPECT_EQ(maybe_bloom_filter.status().error_message(), "Invalid padding: 8");
}

TEST(BloomFilterTest, MightContainCanProcessNonStandardCharacters) {
  // A non-empty BloomFilter object with 1 insertion : "ÀÒ∑"
  BloomFilter bloom_filter(std::vector<uint8_t>{237, 5}, 5, 8);
  EXPECT_TRUE(bloom_filter.MightContain("ÀÒ∑"));
  EXPECT_FALSE(bloom_filter.MightContain("Ò∑À"));
}

TEST(BloomFilterTest, MightContainOnEmptyBloomFilterShouldReturnFalse) {
  BloomFilter bloom_filter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_FALSE(bloom_filter.MightContain(""));
  EXPECT_FALSE(bloom_filter.MightContain("a"));
}

TEST(BloomFilterTest,
     MightContainWithEmptyStringMightReturnFalsePositiveResult) {
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{1}, 1, 1);
    EXPECT_FALSE(bloom_filter.MightContain(""));
  }
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{255}, 0, 16);
    EXPECT_TRUE(bloom_filter.MightContain(""));
  }
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
