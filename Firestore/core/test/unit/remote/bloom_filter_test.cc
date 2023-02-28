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

#include <fstream>
#include <iostream>
#include <vector>

#include "Firestore/core/src/util/json_reader.h"
#include "Firestore/core/src/util/path.h"
#include "absl/strings/escaping.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {
using nlohmann::json;
using util::JsonReader;
using util::Path;
using util::Status;
using util::StatusOr;

TEST(BloomFilterUnitTest, CanInstantiateEmptyBloomFilter) {
  BloomFilter bloom_filter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_EQ(bloom_filter.bit_count(), 0);
}

TEST(BloomFilterUnitTest, CanInstantiateNonEmptyBloomFilter) {
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{1}, 0, 1);
    EXPECT_EQ(bloom_filter.bit_count(), 8);
  }
  {
    BloomFilter bloom_filter(std::vector<uint8_t>{1}, 7, 1);
    EXPECT_EQ(bloom_filter.bit_count(), 1);
  }
}

TEST(BloomFilterUnitTest, CreateShouldReturnBloomFilterOnValidInputs) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 1, 1);
  ASSERT_TRUE(maybe_bloom_filter.ok());
  BloomFilter bloom_filter = maybe_bloom_filter.ValueOrDie();
  EXPECT_EQ(bloom_filter.bit_count(), 7);
}

TEST(BloomFilterUnitTest, CreateShouldBeAbleToCreatEmptyBloomFilter) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{}, 0, 0);
  ASSERT_TRUE(maybe_bloom_filter.ok());
  BloomFilter bloom_filter = maybe_bloom_filter.ValueOrDie();
  EXPECT_EQ(bloom_filter.bit_count(), 0);
}

TEST(BloomFilterUnitTest, CreateShouldReturnNotOKStatusOnNegativePadding) {
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

TEST(BloomFilterUnitTest, CreateShouldReturnNotOKStatusOnNegativeHashCount) {
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

TEST(BloomFilterUnitTest, CreateShouldReturnNotOKStatusOnZeroHashCount) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 1, 0);
  ASSERT_FALSE(maybe_bloom_filter.ok());
  EXPECT_EQ(maybe_bloom_filter.status().error_message(),
            "Invalid hash count: 0");
}

TEST(BloomFilterUnitTest, CreateShouldReturnNotOKStatusIfPaddingIsTooLarge) {
  StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(std::vector<uint8_t>{1}, 8, 1);
  ASSERT_FALSE(maybe_bloom_filter.ok());
  EXPECT_EQ(maybe_bloom_filter.status().error_message(), "Invalid padding: 8");
}

TEST(BloomFilterUnitTest, MightContainCanProcessNonStandardCharacters) {
  // A non-empty BloomFilter object with 1 insertion : "ÀÒ∑"
  BloomFilter bloom_filter(std::vector<uint8_t>{237, 5}, 5, 8);
  EXPECT_TRUE(bloom_filter.MightContain("ÀÒ∑"));
  EXPECT_FALSE(bloom_filter.MightContain("Ò∑À"));
}

TEST(BloomFilterUnitTest, MightContainOnEmptyBloomFilterShouldReturnFalse) {
  BloomFilter bloom_filter(std::vector<uint8_t>{}, 0, 0);
  EXPECT_FALSE(bloom_filter.MightContain(""));
  EXPECT_FALSE(bloom_filter.MightContain("a"));
}

TEST(BloomFilterUnitTest,
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

class BloomFilterGoldenTest : public ::testing::Test {
 public:
  void RunGoldenTest(std::string& test_file) {
    size_t start_pos = test_file.find("bloom_filter_proto");
    if (start_pos == std::string::npos) {
      return;
    }
    std::string result_file = test_file;
    result_file.replace(start_pos, sizeof("bloom_filter_proto") - 1,
                        "membership_test_result");

    json test_file_json = ReadFile(test_file);
    json result_file_json = ReadFile(result_file);

    nlohmann::json bits = reader.OptionalObject("bits", test_file_json, {});
    std::string bitmap = reader.OptionalString("bitmap", bits, "");
    int padding = reader.OptionalInt("padding", bits, 0);
    int hash_count = reader.OptionalInt("hashCount", test_file_json, 0);
    std::string decoded;
    absl::Base64Unescape(bitmap, &decoded);
    std::vector<uint8_t> decoded_map(decoded.begin(), decoded.end());
    BloomFilter bloom_filter = BloomFilter(decoded_map, padding, hash_count);

    std::string membership_result =
        reader.OptionalString("membershipTestResults", result_file_json, "");

    for (size_t i = 0; i < membership_result.length(); i++) {
      bool expectedResult = membership_result[i] == '1';
      bool mightContainResult = bloom_filter.MightContain(
          GOLDEN_DOCUMENT_PREFIX_ + std::to_string(i));

      EXPECT_EQ(mightContainResult, expectedResult);
    }
  }

 private:
  std::string GOLDEN_DOCUMENT_PREFIX_ =
      "projects/project-1/databases/database-1/documents/coll/doc";
  Path GOLDEN_TEST_FOLDER_ = (Path::FromUtf8(__FILE__).Dirname())
                                 .AppendUtf8("bloom_filter_golden_test_data/");

  json ReadFile(std::string& file_name) {
    Path file_path = GOLDEN_TEST_FOLDER_.AppendUtf8(file_name);
    std::ifstream stream(file_path.native_value());
    return nlohmann::json::parse(stream);
  }

  JsonReader reader;
};

/**
 * Golden tests are generated by backend based on inserting n number of document
 * paths into a bloom filter.
 *
 * <p>Full document path is generated by concatenating documentPrefix and number
 * n, eg, projects/project-1/databases/database-1/documents/coll/doc12.
 *
 * <p>The test result is generated by checking the membership of documents from
 * documentPrefix+0 to documentPrefix+2n. The membership results from 0 to n is
 * expected to be true, and the membership results from n to 2n is expected to
 * be false with some false positive results.
 */
TEST_F(BloomFilterGoldenTest, GoldenTest1Document1FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_1_1_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest1Document01FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_1_01_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest1Document0001FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_1_0001_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest500Document1FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_500_1_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest500Document01FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_500_01_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest500Document0001FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_500_0001_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}

TEST_F(BloomFilterGoldenTest, GoldenTest5000Document1FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_5000_1_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest5000Document01FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_5000_01_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest5000Document0001FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_5000_0001_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}

TEST_F(BloomFilterGoldenTest, GoldenTest50000Document1FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_50000_1_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest50000Document01FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_50000_01_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}
TEST_F(BloomFilterGoldenTest, GoldenTest50000Document0001FalsePositiveRate) {
  std::string test_file =
      "Validation_BloomFilterTest_MD5_50000_0001_bloom_filter_proto.json";
  RunGoldenTest(test_file);
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
