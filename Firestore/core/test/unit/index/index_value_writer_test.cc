/*
 * Copyright 2025 Google LLC
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

#include "Firestore/core/src/index/firestore_index_value_writer.h"
#include "Firestore/core/src/index/index_byte_encoder.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace index {

namespace {

using testutil::BsonBinaryData;
using testutil::BsonObjectId;
using testutil::BsonTimestamp;
using testutil::Int32;
using testutil::MaxKey;
using testutil::MinKey;
using testutil::Regex;
using testutil::VectorType;

TEST(IndexValueWriterTest, writeIndexValueSupportsVector) {
  // Value
  auto vector = VectorType(1, 2, 3);

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*vector, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kVector);  // Vector type
  index_byte_encoder->WriteLong(IndexType::kNumber);  // Number type
  index_byte_encoder->WriteLong(3);                   // Vector Length
  index_byte_encoder->WriteLong(IndexType::kString);
  index_byte_encoder->WriteString("value");
  index_byte_encoder->WriteLong(IndexType::kArray);
  index_byte_encoder->WriteLong(IndexType::kNumber);
  index_byte_encoder->WriteDouble(1);  // position 0
  index_byte_encoder->WriteLong(IndexType::kNumber);
  index_byte_encoder->WriteDouble(2);  // position 1
  index_byte_encoder->WriteLong(IndexType::kNumber);
  index_byte_encoder->WriteDouble(3);  // position 2
  index_byte_encoder->WriteLong(IndexType::kNotTruncated);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsEmptyVector) {
  // Value - Create an empty vector
  auto vector = VectorType();

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*vector, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);

  index_byte_encoder->WriteLong(IndexType::kVector);
  index_byte_encoder->WriteLong(IndexType::kNumber);
  index_byte_encoder->WriteLong(0);  // vector length
  index_byte_encoder->WriteLong(IndexType::kString);
  index_byte_encoder->WriteString("value");
  index_byte_encoder->WriteLong(IndexType::kArray);
  index_byte_encoder->WriteLong(IndexType::kNotTruncated);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsBsonObjectId) {
  // Value
  auto value = BsonObjectId("507f191e810c19729de860ea");

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kBsonObjectId);
  index_byte_encoder->WriteBytes(
      nanopb::MakeBytesArray("507f191e810c19729de860ea"));
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsBsonBinaryData) {
  // Value
  auto value = BsonBinaryData(1, {1, 2, 3});

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kBsonBinaryData);
  // Expected bytes: subtype (1) + data {1, 2, 3}
  const uint8_t binary_payload[] = {1, 1, 2, 3};
  index_byte_encoder->WriteBytes(
      nanopb::MakeBytesArray(binary_payload, sizeof(binary_payload)));
  index_byte_encoder->WriteLong(IndexType::kNotTruncated);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsBsonBinaryWithEmptyData) {
  // Value
  auto value = BsonBinaryData(1, {});

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kBsonBinaryData);
  // Expected bytes: subtype (1) only
  const uint8_t binary_payload[] = {1};
  index_byte_encoder->WriteBytes(
      nanopb::MakeBytesArray(binary_payload, sizeof(binary_payload)));
  index_byte_encoder->WriteLong(IndexType::kNotTruncated);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsBsonTimestamp) {
  // Value
  auto value = BsonTimestamp(1, 2);

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kBsonTimestamp);
  uint64_t timestamp_encoded = (1ULL << 32) | (2);
  index_byte_encoder->WriteLong(timestamp_encoded);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsLargestBsonTimestamp) {
  // Value
  auto value = BsonTimestamp(4294967295ULL, 4294967295ULL);

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kBsonTimestamp);
  uint64_t timestamp_encoded = (4294967295ULL << 32) | (4294967295ULL);
  index_byte_encoder->WriteLong(timestamp_encoded);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsSmallestBsonTimestamp) {
  // Value
  auto value = BsonTimestamp(0, 0);

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kBsonTimestamp);
  index_byte_encoder->WriteLong(0);  // (0 << 32 | 0)
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsRegex) {
  // Value
  auto value = Regex("^foo", "i");

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kRegex);
  index_byte_encoder->WriteString("^foo");
  index_byte_encoder->WriteString("i");
  index_byte_encoder->WriteLong(IndexType::kNotTruncated);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsInt32) {
  // Value
  auto value = Int32(1);

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kNumber);
  index_byte_encoder->WriteDouble(1.0);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsLargestInt32) {
  // Value
  auto value = Int32(2147483647);

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kNumber);
  index_byte_encoder->WriteDouble(2147483647.0);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsSmallestInt32) {
  // Value
  auto value = Int32(-2147483648);

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kNumber);
  index_byte_encoder->WriteDouble(-2147483648.0);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsMinKey) {
  // Value
  auto value = MinKey();

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kMinKey);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

TEST(IndexValueWriterTest, writeIndexValueSupportsMaxKey) {
  // Value
  auto value = MaxKey();

  // Actual
  IndexEncodingBuffer encoder;
  WriteIndexValue(*value, encoder.ForKind(model::Segment::Kind::kAscending));
  auto& actual_bytes = encoder.GetEncodedBytes();

  // Expected
  IndexEncodingBuffer expected_encoder;
  DirectionalIndexByteEncoder* index_byte_encoder =
      expected_encoder.ForKind(model::Segment::Kind::kAscending);
  index_byte_encoder->WriteLong(IndexType::kMaxKey);
  index_byte_encoder->WriteInfinity();
  auto& expected_bytes = expected_encoder.GetEncodedBytes();

  EXPECT_EQ(actual_bytes, expected_bytes);
}

}  // namespace
}  // namespace index
}  // namespace firestore
}  // namespace firebase
