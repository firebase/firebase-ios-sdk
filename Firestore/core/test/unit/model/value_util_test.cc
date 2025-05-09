/*
 * Copyright 2021 Google LLC
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

#include <limits>

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/test/unit/testutil/equals_tester.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "Firestore/core/test/unit/testutil/time_testing.h"
#include "absl/base/casts.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {
namespace {

using model::EncodeServerTimestamp;
using model::RefValue;
using nanopb::Message;
using testutil::Array;
using testutil::BlobValue;
using testutil::BsonBinaryData;
using testutil::BsonObjectId;
using testutil::BsonTimestamp;
using testutil::DbId;
using testutil::Int32;
using testutil::kCanonicalNanBits;
using testutil::Key;
using testutil::Map;
using testutil::MaxKey;
using testutil::MinKey;
using testutil::Regex;
using testutil::time_point;
using testutil::Value;
using testutil::VectorType;
using util::ComparisonResult;

namespace {

#if __APPLE__
uint64_t ToBits(double value) {
  return absl::bit_cast<uint64_t>(value);
}
#endif  // __APPLE__

double ToDouble(uint64_t value) {
  return absl::bit_cast<double>(value);
}

// All permutations of the 51 other non-MSB significand bits are also NaNs.
const uint64_t kAlternateNanBits = 0x7fff000000000000ULL;

const time_point kDate1 = testutil::MakeTimePoint(2016, 5, 20, 10, 20, 0);
const Timestamp kTimestamp1{1463739600, 0};

const time_point kDate2 = testutil::MakeTimePoint(2016, 10, 21, 15, 32, 0);
const Timestamp kTimestamp2{1477063920, 0};

}  // namespace

class ValueUtilTest : public ::testing::Test {
 public:
  template <typename... Args>
  void Add(std::vector<Message<google_firestore_v1_ArrayValue>>& groups,
           Args... values) {
    groups.emplace_back(Array(std::forward<Args>(values)...));
  }

  void VerifyEquality(Message<google_firestore_v1_ArrayValue>& left,
                      Message<google_firestore_v1_ArrayValue>& right,
                      bool expected_equals) {
    for (pb_size_t i = 0; i < left->values_count; ++i) {
      for (pb_size_t j = 0; j < right->values_count; ++j) {
        if (expected_equals) {
          EXPECT_EQ(left->values[i], right->values[j]);
        } else {
          EXPECT_NE(left->values[i], right->values[j]);
        }
      }
    }
  }

  // Verifies comparing `left` to `right` results into the `expected_result`.
  void VerifyExactOrdering(Message<google_firestore_v1_ArrayValue>& left,
                           Message<google_firestore_v1_ArrayValue>& right,
                           ComparisonResult expected_result) {
    for (pb_size_t i = 0; i < left->values_count; ++i) {
      for (pb_size_t j = 0; j < right->values_count; ++j) {
        EXPECT_EQ(expected_result, Compare(left->values[i], right->values[j]))
            << "Order check failed for '" << CanonicalId(left->values[i])
            << "' and '" << CanonicalId(right->values[j]) << "' (expected "
            << static_cast<int>(expected_result) << ")";
        EXPECT_EQ(util::ReverseOrder(expected_result),
                  Compare(right->values[j], left->values[i]))
            << "Reverse order check failed for '"
            << CanonicalId(left->values[i]) << "' and '"
            << CanonicalId(right->values[j]) << "' (expected "
            << static_cast<int>(util::ReverseOrder(expected_result)) << ")";
      }
    }
  }

  // Verifies `left` is either smaller or the same as `right`.
  void VerifyRelaxedAscending(Message<google_firestore_v1_ArrayValue>& left,
                              Message<google_firestore_v1_ArrayValue>& right) {
    for (pb_size_t i = 0; i < left->values_count; ++i) {
      for (pb_size_t j = 0; j < right->values_count; ++j) {
        // Verifies the compare result is not `Descending`, which means left
        // is smaller or equal to right.
        EXPECT_NE(ComparisonResult::Descending,
                  Compare(left->values[i], right->values[j]))
            << "Order check failed for '" << CanonicalId(left->values[i])
            << "' and '" << CanonicalId(right->values[j])
            << "' (expected same or ascending)";
        // Reversed order check should also pass.
        EXPECT_NE(ComparisonResult::Ascending,
                  Compare(right->values[j], left->values[i]))
            << "Reverse order check failed for '"
            << CanonicalId(left->values[i]) << "' and '"
            << CanonicalId(right->values[j])
            << "' (expected same or ascending)";
      }
    }
  }

  void VerifyCanonicalId(nanopb::Message<google_firestore_v1_Value> value,
                         const std::string& expected_canonical_id) {
    std::string actual_canonical_id = CanonicalId(*value);
    EXPECT_EQ(expected_canonical_id, actual_canonical_id);
  }

  void VerifyDeepClone(nanopb::Message<google_firestore_v1_Value> value) {
    nanopb::Message<google_firestore_v1_Value> clone1;

    [&] {
      nanopb::Message<google_firestore_v1_Value> clone2 = DeepClone(*value);
      EXPECT_EQ(*value, *clone2);
      clone1 = DeepClone(*clone2);
    }();

    // `clone2` is destroyed at this point, but `clone1` should be still valid.
    EXPECT_EQ(*value, *clone1);
  }

 private:
  remote::Serializer serializer{DbId()};
};

TEST(FieldValueTest, ValueHelpers) {
  // Validates that the Value helpers in testutil produce the right types
  auto bool_value = Value(true);
  ASSERT_EQ(GetTypeOrder(*bool_value), TypeOrder::kBoolean);
  EXPECT_EQ(bool_value->boolean_value, true);

  auto int_value = Value(5);
  ASSERT_EQ(GetTypeOrder(*int_value), TypeOrder::kNumber);
  EXPECT_EQ(int_value->integer_value, 5);

  auto long_value = Value(std::numeric_limits<int32_t>::max());
  ASSERT_EQ(GetTypeOrder(*long_value), TypeOrder::kNumber);
  EXPECT_EQ(long_value->integer_value, std::numeric_limits<int32_t>::max());

  auto long_long_value = Value(std::numeric_limits<int64_t>::max());
  ASSERT_EQ(GetTypeOrder(*long_long_value), TypeOrder::kNumber);
  EXPECT_EQ(long_long_value->integer_value,
            std::numeric_limits<int64_t>::max());

  auto double_value = Value(2.0);
  ASSERT_EQ(GetTypeOrder(*double_value), TypeOrder::kNumber);
  EXPECT_EQ(double_value->double_value, 2.0);

  auto map_value = Map("foo", "bar");
  ASSERT_EQ(GetTypeOrder(*map_value), TypeOrder::kMap);
  ASSERT_EQ(DetectMapType(*map_value), MapType::kNormal);

  auto max_value = DeepClone(InternalMaxValue());
  ASSERT_EQ(GetTypeOrder(*max_value), TypeOrder::kInternalMaxValue);
  ASSERT_EQ(DetectMapType(*max_value), MapType::kInternalMaxValue);

  auto server_timestamp = EncodeServerTimestamp(kTimestamp1, absl::nullopt);
  ASSERT_EQ(GetTypeOrder(*server_timestamp), TypeOrder::kServerTimestamp);
  ASSERT_EQ(DetectMapType(*server_timestamp), MapType::kServerTimestamp);

  auto vector_value = VectorType(100);
  ASSERT_EQ(GetTypeOrder(*vector_value), TypeOrder::kVector);
  ASSERT_EQ(DetectMapType(*vector_value), MapType::kVector);

  auto min_key_value = MinKey();
  ASSERT_EQ(GetTypeOrder(*min_key_value), TypeOrder::kMinKey);
  ASSERT_EQ(DetectMapType(*min_key_value), MapType::kMinKey);

  auto max_key_value = MaxKey();
  ASSERT_EQ(GetTypeOrder(*max_key_value), TypeOrder::kMaxKey);
  ASSERT_EQ(DetectMapType(*max_key_value), MapType::kMaxKey);

  auto regex_value = Regex("^foo", "x");
  ASSERT_EQ(GetTypeOrder(*regex_value), TypeOrder::kRegex);
  ASSERT_EQ(DetectMapType(*regex_value), MapType::kRegex);

  auto int32_value = Int32(1);
  ASSERT_EQ(GetTypeOrder(*int32_value), TypeOrder::kNumber);
  ASSERT_EQ(DetectMapType(*int32_value), MapType::kInt32);

  auto bson_object_id_value = BsonObjectId("foo");
  ASSERT_EQ(GetTypeOrder(*bson_object_id_value), TypeOrder::kBsonObjectId);
  ASSERT_EQ(DetectMapType(*bson_object_id_value), MapType::kBsonObjectId);

  auto bson_timestamp_value = BsonTimestamp(1, 2);
  ASSERT_EQ(GetTypeOrder(*bson_timestamp_value), TypeOrder::kBsonTimestamp);
  ASSERT_EQ(DetectMapType(*bson_timestamp_value), MapType::kBsonTimestamp);

  auto bson_binary_data_value = BsonBinaryData(1, {1, 2, 3});
  ASSERT_EQ(GetTypeOrder(*bson_binary_data_value), TypeOrder::kBsonBinaryData);
  ASSERT_EQ(DetectMapType(*bson_binary_data_value), MapType::kBsonBinaryData);
}

#if __APPLE__
// Validates that NSNumber/CFNumber normalize NaNs to the same values that
// Firestore does. This uses CoreFoundation's CFNumber instead of NSNumber just
// to keep the test in a single file.
TEST(FieldValueTest, CanonicalBitsAreCanonical) {
  double input = ToDouble(kAlternateNanBits);
  CFNumberRef number = CFNumberCreate(nullptr, kCFNumberDoubleType, &input);
  util::Defer cleanup([&] { util::SafeCFRelease(number); });

  double actual = 0.0;
  CFNumberGetValue(number, kCFNumberDoubleType, &actual);

  ASSERT_EQ(kCanonicalNanBits, ToBits(actual));
}
#endif  // __APPLE__

TEST_F(ValueUtilTest, Equality) {
  // Create a matrix that defines an equality group. The outer vector has
  // multiple rows and each row can have an arbitrary number of entries.
  // The elements within a row must equal each other, but not be equal
  // to all elements of other rows.
  std::vector<Message<google_firestore_v1_ArrayValue>> equals_group;

  Add(equals_group, nullptr, nullptr);
  Add(equals_group, MinKey(), MinKey());
  Add(equals_group, false, false);
  Add(equals_group, true, true);
  Add(equals_group, std::numeric_limits<double>::quiet_NaN(),
      ToDouble(kCanonicalNanBits), ToDouble(kAlternateNanBits), std::nan("1"),
      std::nan("2"));
  // -0.0 and 0.0 compare the same but are not equal.
  Add(equals_group, -0.0);
  Add(equals_group, 0.0);
  Add(equals_group, 1, 1LL);
  // Doubles and Longs aren't equal (even though they compare same).
  Add(equals_group, 1.0, 1.0);
  Add(equals_group, 1.1, 1.1);
  Add(equals_group, Int32(-1), Int32(-1));
  Add(equals_group, Int32(1), Int32(1));
  Add(equals_group, BlobValue(0, 1, 1));
  Add(equals_group, BlobValue(0, 1));
  Add(equals_group, "string", "string");
  Add(equals_group, "strin");
  Add(equals_group, std::string("strin\0", 6));
  // latin small letter e + combining acute accent
  Add(equals_group, "e\u0301b");
  // latin small letter e with acute accent
  Add(equals_group, "\u00e9a");
  Add(equals_group, Timestamp::FromTimePoint(kDate1), kTimestamp1);
  Add(equals_group, Timestamp::FromTimePoint(kDate2), kTimestamp2);
  // NOTE: ServerTimestampValues can't be parsed via .
  Add(equals_group, EncodeServerTimestamp(kTimestamp1, absl::nullopt),
      EncodeServerTimestamp(kTimestamp1, absl::nullopt));
  Add(equals_group, EncodeServerTimestamp(kTimestamp2, absl::nullopt));
  Add(equals_group, GeoPoint(0, 1), GeoPoint(0, 1));
  Add(equals_group, GeoPoint(1, 0));
  Add(equals_group, RefValue(DbId(), Key("coll/doc1")),
      RefValue(DbId(), Key("coll/doc1")));
  Add(equals_group, RefValue(DbId(), Key("coll/doc2")));
  Add(equals_group, RefValue(DbId("project/baz"), Key("coll/doc2")));
  Add(equals_group, Array("foo", "bar"), Array("foo", "bar"));
  Add(equals_group, Array("foo", "bar", "baz"));
  Add(equals_group, Array("foo"));
  Add(equals_group, Map("__type__", "__vector__", "value", Array()),
      DeepClone(MinVector()));
  Add(equals_group, Regex("foo", "bar"), Regex("foo", "bar"));
  Add(equals_group, BsonObjectId("bar"));
  Add(equals_group, BsonObjectId("foo"), BsonObjectId("foo"));
  Add(equals_group, BsonTimestamp(1, 3));
  Add(equals_group, BsonTimestamp(1, 2), BsonTimestamp(1, 2));
  Add(equals_group, BsonTimestamp(2, 3));
  Add(equals_group, BsonBinaryData(1, {7, 8, 9}));
  Add(equals_group, BsonBinaryData(128, {7, 8, 9}),
      BsonBinaryData(128, {7, 8, 9}));
  Add(equals_group, BsonBinaryData(128, {7, 8, 10}));
  Add(equals_group, Map("bar", 1, "foo", 2), Map("bar", 1, "foo", 2));
  Add(equals_group, Map("bar", 2, "foo", 1));
  Add(equals_group, Map("bar", 1));
  Add(equals_group, Map("foo", 1));
  Add(equals_group, MaxKey(), MaxKey());

  for (size_t i = 0; i < equals_group.size(); ++i) {
    for (size_t j = i; j < equals_group.size(); ++j) {
      VerifyEquality(equals_group[i], equals_group[j],
                     /* expected_equals= */ i == j);
    }
  }
}

TEST_F(ValueUtilTest, StrictOrdering) {
  // Create a matrix that defines a comparison group. The outer vector has
  // multiple rows and each row can have an arbitrary number of entries.
  // The elements within a row must compare equal to each other, but order after
  // all elements in previous groups and before all elements in later groups.
  std::vector<Message<google_firestore_v1_ArrayValue>> comparison_groups;

  // null first
  Add(comparison_groups, nullptr);

  // MinKey
  Add(comparison_groups, MinKey());

  // booleans
  Add(comparison_groups, false);
  Add(comparison_groups, true);

  // numbers
  Add(comparison_groups, DeepClone(MinNumber()));
  Add(comparison_groups, -1e20);
  Add(comparison_groups, std::numeric_limits<int64_t>::min());
  Add(comparison_groups, -0.1);
  // Zeros all compare the same.
  Add(comparison_groups, -0.0, 0.0, 0L, Int32(0));
  Add(comparison_groups, 0.1);
  // Doubles, longs, and Int32 Compare() the same.
  Add(comparison_groups, 1.0, 1L, Int32(1));
  Add(comparison_groups, Int32(2));
  Add(comparison_groups, Int32(2147483647));
  Add(comparison_groups, std::numeric_limits<int64_t>::max());
  Add(comparison_groups, 1e20);

  // dates
  Add(comparison_groups, DeepClone(MinTimestamp()));
  Add(comparison_groups, kTimestamp1);
  Add(comparison_groups, kTimestamp2);

  // BSON Timestamp
  Add(comparison_groups, DeepClone(MinBsonTimestamp()));
  Add(comparison_groups, BsonTimestamp(123, 4), BsonTimestamp(123, 4));
  Add(comparison_groups, BsonTimestamp(123, 5));
  Add(comparison_groups, BsonTimestamp(124, 0));

  // server timestamps come after all concrete timestamps.
  // NOTE: server timestamps can't be parsed with .
  Add(comparison_groups, EncodeServerTimestamp(kTimestamp1, absl::nullopt));
  Add(comparison_groups, EncodeServerTimestamp(kTimestamp2, absl::nullopt));

  // strings
  Add(comparison_groups, "");
  Add(comparison_groups, "\001\ud7ff\ue000\uffff");
  Add(comparison_groups, "(╯°□°）╯︵ ┻━┻");
  Add(comparison_groups, "a");
  Add(comparison_groups, std::string("abc\0 def", 8));
  Add(comparison_groups, "abc def");
  // latin small letter e + combining acute accent + latin small letter b
  Add(comparison_groups, "e\u0301b");
  Add(comparison_groups, "æ");
  // latin small letter e with acute accent + latin small letter a
  Add(comparison_groups, "\u00e9a");

  // blobs
  Add(comparison_groups, BlobValue());
  Add(comparison_groups, BlobValue(0));
  Add(comparison_groups, BlobValue(0, 1, 2, 3, 4));
  Add(comparison_groups, BlobValue(0, 1, 2, 4, 3));
  Add(comparison_groups, BlobValue(255));

  // BSON Binary Data
  Add(comparison_groups, DeepClone(MinBsonBinaryData()));
  Add(comparison_groups, BsonBinaryData(5, {1, 2, 3}),
      BsonBinaryData(5, {1, 2, 3}));
  Add(comparison_groups, BsonBinaryData(7, {1}));
  Add(comparison_groups, BsonBinaryData(7, {2}));

  // resource names
  Add(comparison_groups, DeepClone(MinReference()));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc2")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c10/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c2/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d2"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p2/d1"), Key("c1/doc1")));

  // BSON ObjectId
  Add(comparison_groups, DeepClone(MinBsonObjectId()));
  Add(comparison_groups, BsonObjectId("foo"), BsonObjectId("foo"));
  // TODO(types/ehsann): uncomment after string sort bug is fixed
  // Add(comparison_groups, BsonObjectId("Ḟoo"));
  // Add(comparison_groups, BsonObjectId("foo\u0301"));
  Add(comparison_groups, BsonObjectId("xyz"));

  // geo points
  Add(comparison_groups, GeoPoint(-90, -180));
  Add(comparison_groups, GeoPoint(-90, 0));
  Add(comparison_groups, GeoPoint(-90, 180));
  Add(comparison_groups, GeoPoint(0, -180));
  Add(comparison_groups, GeoPoint(0, 0));
  Add(comparison_groups, GeoPoint(0, 180));
  Add(comparison_groups, GeoPoint(1, -180));
  Add(comparison_groups, GeoPoint(1, 0));
  Add(comparison_groups, GeoPoint(1, 180));
  Add(comparison_groups, GeoPoint(90, -180));
  Add(comparison_groups, GeoPoint(90, 0));
  Add(comparison_groups, GeoPoint(90, 180));

  // regular expressions
  Add(comparison_groups, DeepClone(MinRegex()));
  Add(comparison_groups, Regex("a", "bar1")),
      Add(comparison_groups, Regex("foo", "bar1")),
      Add(comparison_groups, Regex("foo", "bar2")),
      Add(comparison_groups, Regex("go", "bar1")),

      // arrays
      Add(comparison_groups, DeepClone(MinArray()));
  Add(comparison_groups, Array("bar"));
  Add(comparison_groups, Array("foo", 1));
  Add(comparison_groups, Array("foo", 2));
  Add(comparison_groups, Array("foo", "0"));

  // vectors
  Add(comparison_groups, DeepClone(MinVector()));
  Add(comparison_groups, Map("__type__", "__vector__", "value", Array(100)));
  Add(comparison_groups,
      Map("__type__", "__vector__", "value", Array(1.0, 2.0, 3.0)));
  Add(comparison_groups,
      Map("__type__", "__vector__", "value", Array(1.0, 3.0, 2.0)));

  // objects
  Add(comparison_groups, DeepClone(MinMap()));
  Add(comparison_groups, Map("bar", 0));
  Add(comparison_groups, Map("bar", 0, "foo", 1));
  Add(comparison_groups, Map("foo", 1));
  Add(comparison_groups, Map("foo", 2));
  Add(comparison_groups, Map("foo", "0"));

  // MaxKey
  Add(comparison_groups, MaxKey());

  Add(comparison_groups, DeepClone(InternalMaxValue()));

  for (size_t i = 0; i < comparison_groups.size(); ++i) {
    for (size_t j = i; j < comparison_groups.size(); ++j) {
      VerifyExactOrdering(comparison_groups[i], comparison_groups[j],
                          /* expected_result= */ i == j
                              ? ComparisonResult::Same
                              : ComparisonResult::Ascending);
    }
  }
}

TEST_F(ValueUtilTest, RelaxedOrdering) {
  // Create a matrix that defines a comparison group. The outer vector has
  // multiple rows and each row can have an arbitrary number of entries.
  // The elements within a row must compare equal to each other, but order
  // the same or after all elements in previous groups and the same or before
  // all elements in later groups.
  std::vector<Message<google_firestore_v1_ArrayValue>> comparison_groups;

  // null first
  Add(comparison_groups, DeepClone(NullValue()));
  Add(comparison_groups, nullptr);

  // MinKey
  Add(comparison_groups, MinKey());
  Add(comparison_groups, DeepClone(MinBoolean()));

  // booleans
  Add(comparison_groups, DeepClone(MinBoolean()));
  Add(comparison_groups, false);
  Add(comparison_groups, true);
  Add(comparison_groups, DeepClone(MinNumber()));

  // numbers
  Add(comparison_groups, DeepClone(MinNumber()));
  Add(comparison_groups, DeepClone(MinNumber()));
  Add(comparison_groups, -1e20);
  Add(comparison_groups, std::numeric_limits<int64_t>::min());
  Add(comparison_groups, -0.1);
  // Zeros all compare the same.
  Add(comparison_groups, -0.0, 0.0, 0L, Int32(0));
  Add(comparison_groups, 0.1);
  // Doubles and longs Compare() the same.
  Add(comparison_groups, 1.0, 1L, Int32(1));
  Add(comparison_groups, Int32(2));
  Add(comparison_groups, Int32(2147483647));
  Add(comparison_groups, std::numeric_limits<int64_t>::max());
  Add(comparison_groups, 1e20);
  Add(comparison_groups, DeepClone(MinTimestamp()));
  Add(comparison_groups, DeepClone(MinTimestamp()));

  // dates
  Add(comparison_groups, DeepClone(MinTimestamp()));
  Add(comparison_groups, kTimestamp1);
  Add(comparison_groups, kTimestamp2);

  // BSON Timestamp
  Add(comparison_groups, DeepClone(MinBsonTimestamp()));
  Add(comparison_groups, BsonTimestamp(123, 4), BsonTimestamp(123, 4));
  Add(comparison_groups, BsonTimestamp(123, 5));
  Add(comparison_groups, BsonTimestamp(124, 0));

  // server timestamps come after all concrete timestamps.
  // NOTE: server timestamps can't be parsed with .
  Add(comparison_groups, EncodeServerTimestamp(kTimestamp1, absl::nullopt));
  Add(comparison_groups, EncodeServerTimestamp(kTimestamp2, absl::nullopt));
  Add(comparison_groups, DeepClone(MinString()));

  // strings
  Add(comparison_groups, DeepClone(MinString()));
  Add(comparison_groups, "");
  Add(comparison_groups, "\001\ud7ff\ue000\uffff");
  Add(comparison_groups, "(╯°□°）╯︵ ┻━┻");
  Add(comparison_groups, "a");
  Add(comparison_groups, std::string("abc\0 def", 8));
  Add(comparison_groups, "abc def");
  // latin small letter e + combining acute accent + latin small letter b
  Add(comparison_groups, "e\u0301b");
  Add(comparison_groups, "æ");
  // latin small letter e with acute accent + latin small letter a
  Add(comparison_groups, "\u00e9a");
  Add(comparison_groups, DeepClone(MinBytes()));

  // blobs
  Add(comparison_groups, DeepClone(MinBytes()));
  Add(comparison_groups, BlobValue());
  Add(comparison_groups, BlobValue(0));
  Add(comparison_groups, BlobValue(0, 1, 2, 3, 4));
  Add(comparison_groups, BlobValue(0, 1, 2, 4, 3));
  Add(comparison_groups, BlobValue(255));

  // BSON Binary Data
  Add(comparison_groups, DeepClone(MinBsonBinaryData()));
  Add(comparison_groups, BsonBinaryData(5, {1, 2, 3}),
      BsonBinaryData(5, {1, 2, 3}));
  Add(comparison_groups, BsonBinaryData(7, {1}));
  Add(comparison_groups, BsonBinaryData(7, {2}));

  // resource names
  Add(comparison_groups, DeepClone(MinReference()));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc2")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c10/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c2/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d2"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p2/d1"), Key("c1/doc1")));

  // BSON ObjectId
  Add(comparison_groups, DeepClone(MinBsonObjectId()));
  Add(comparison_groups, BsonObjectId("foo"), BsonObjectId("foo"));
  // TODO(types/ehsann): uncomment after string sort bug is fixed
  // Add(comparison_groups, BsonObjectId("Ḟoo"));
  // Add(comparison_groups, BsonObjectId("foo\u0301"));
  Add(comparison_groups, BsonObjectId("xyz"));

  // geo points
  Add(comparison_groups, DeepClone(MinGeoPoint()));
  Add(comparison_groups, GeoPoint(-90, -180));
  Add(comparison_groups, GeoPoint(-90, 0));
  Add(comparison_groups, GeoPoint(-90, 180));
  Add(comparison_groups, GeoPoint(0, -180));
  Add(comparison_groups, GeoPoint(0, 0));
  Add(comparison_groups, GeoPoint(0, 180));
  Add(comparison_groups, GeoPoint(1, -180));
  Add(comparison_groups, GeoPoint(1, 0));
  Add(comparison_groups, GeoPoint(1, 180));
  Add(comparison_groups, GeoPoint(90, -180));
  Add(comparison_groups, GeoPoint(90, 0));
  Add(comparison_groups, GeoPoint(90, 180));

  // regular expressions
  Add(comparison_groups, DeepClone(MinRegex()));
  Add(comparison_groups, Regex("a", "bar1")),
      Add(comparison_groups, Regex("foo", "bar1")),
      Add(comparison_groups, Regex("foo", "bar2")),
      Add(comparison_groups, Regex("go", "bar1")),

      // arrays
      Add(comparison_groups, DeepClone(MinArray()));
  Add(comparison_groups, Array("bar"));
  Add(comparison_groups, Array("foo", 1));
  Add(comparison_groups, Array("foo", 2));
  Add(comparison_groups, Array("foo", "0"));
  Add(comparison_groups, DeepClone(MinVector()));

  // vectors
  Add(comparison_groups, DeepClone(MinVector()));
  Add(comparison_groups, VectorType(100));
  Add(comparison_groups, VectorType(1.0, 2.0, 3.0));
  Add(comparison_groups, VectorType(1.0, 3.0, 2.0));

  // objects
  Add(comparison_groups, DeepClone(MinMap()));
  Add(comparison_groups, Map("bar", 0));
  Add(comparison_groups, Map("bar", 0, "foo", 1));
  Add(comparison_groups, Map("foo", 1));
  Add(comparison_groups, Map("foo", 2));
  Add(comparison_groups, Map("foo", "0"));

  // MaxKey
  Add(comparison_groups, MaxKey());

  // MaxValue (internal)
  Add(comparison_groups, DeepClone(InternalMaxValue()));

  for (size_t i = 0; i < comparison_groups.size(); ++i) {
    for (size_t j = i; j < comparison_groups.size(); ++j) {
      VerifyRelaxedAscending(comparison_groups[i], comparison_groups[j]);
    }
  }
}

TEST_F(ValueUtilTest, ComputesLowerBound) {
  auto GetLowerBoundMessage = [](Message<google_firestore_v1_Value> value) {
    return DeepClone(GetLowerBound(*value));
  };

  std::vector<Message<google_firestore_v1_ArrayValue>> groups;

  // Lower bound of null is null
  Add(groups, DeepClone(NullValue()),
      GetLowerBoundMessage(DeepClone(NullValue())));

  // Lower bound of MinKey is MinKey
  Add(groups, MinKey(), GetLowerBoundMessage(DeepClone(MinKeyValue())),
      DeepClone(MinKeyValue()));

  // Booleans
  Add(groups, false, GetLowerBoundMessage(Value(true)));
  Add(groups, true);

  // Numbers
  Add(groups, GetLowerBoundMessage(Value(0.0)), GetLowerBoundMessage(Value(0L)),
      GetLowerBoundMessage(Int32(0)), std::nan(""), DeepClone(MinNumber()));
  Add(groups, INT_MIN);

  // Timestamps
  Add(groups, GetLowerBoundMessage(Value(kTimestamp1)),
      DeepClone(MinTimestamp()));
  Add(groups, kTimestamp1);

  // BSON Timestamps
  Add(groups, GetLowerBoundMessage(BsonTimestamp(500, 600)),
      BsonTimestamp(0, 0), DeepClone(MinBsonTimestamp()));
  Add(groups, BsonTimestamp(1, 1));

  // Strings
  Add(groups, GetLowerBoundMessage(Value("Z")), "", DeepClone(MinString()));
  Add(groups, "\u0000");

  // Blobs
  Add(groups, GetLowerBoundMessage(BlobValue(1, 2, 3)), BlobValue(),
      DeepClone(MinBytes()));
  Add(groups, BlobValue(0));

  // BSON Binary Data
  Add(groups, GetLowerBoundMessage(BsonBinaryData(128, {128, 128})),
      DeepClone(MinBsonBinaryData()));
  Add(groups, BsonBinaryData(0, {0}));

  // References
  Add(groups, GetLowerBoundMessage(RefValue(DbId("p1/d1"), Key("c1/doc1"))),
      DeepClone(MinReference()));
  Add(groups, RefValue(DbId(), Key("a/a")));

  // BSON Object Ids
  Add(groups, GetLowerBoundMessage(BsonObjectId("ZZZ")), BsonObjectId(""),
      DeepClone(MinBsonObjectId()));
  Add(groups, BsonObjectId("a"));

  // GeoPoints
  Add(groups, GetLowerBoundMessage(Value(GeoPoint(30, 60))),
      GeoPoint(-90, -180), DeepClone(MinGeoPoint()));
  Add(groups, GeoPoint(-90, 0));

  // Regular Expressions
  Add(groups, GetLowerBoundMessage(Regex("ZZZ", "i")), Regex("", ""),
      DeepClone(MinRegex()));
  Add(groups, Regex("a", "i"));

  // Arrays
  Add(groups, GetLowerBoundMessage(Value(Array())), Array(),
      DeepClone(MinArray()));
  Add(groups, Array(false));

  // Vectors
  Add(groups, GetLowerBoundMessage(VectorType(1.0)), VectorType(),
      DeepClone(MinVector()));
  Add(groups, VectorType(1.0));

  // Maps
  Add(groups, GetLowerBoundMessage(Map()), Map(), DeepClone(MinMap()));
  Add(groups, Map("a", "b"));

  // MaxKey
  Add(groups, MaxKey(), GetLowerBoundMessage(DeepClone(MaxKeyValue())),
      DeepClone(MaxKeyValue()));

  for (size_t i = 0; i < groups.size(); ++i) {
    for (size_t j = i; j < groups.size(); ++j) {
      VerifyRelaxedAscending(groups[i], groups[j]);
    }
  }
}

TEST_F(ValueUtilTest, ComputesUpperBound) {
  auto GetUpperBoundMessage = [](Message<google_firestore_v1_Value> value) {
    return DeepClone(GetUpperBound(*value));
  };

  std::vector<Message<google_firestore_v1_ArrayValue>> groups;

  // Null first
  Add(groups, DeepClone(NullValue()));

  // The upper bound of null is MinKey
  Add(groups, MinKey(), GetUpperBoundMessage(DeepClone(NullValue())));

  // The upper bound of MinKey is boolean `false`
  Add(groups, false, GetUpperBoundMessage(MinKey()));

  // Booleans
  Add(groups, true);
  Add(groups, GetUpperBoundMessage(Value(false)));

  // Numbers
  Add(groups, INT_MAX);
  Add(groups, GetUpperBoundMessage(Value(INT_MAX)),
      GetUpperBoundMessage(Value(0L)), GetUpperBoundMessage(Int32(0)),
      GetUpperBoundMessage(Value(std::nan(""))));

  // Timestamps
  Add(groups, kTimestamp1);
  Add(groups, GetUpperBoundMessage(Value(kTimestamp1)));

  // BSON Timestamps
  Add(groups, BsonTimestamp(4294967295, 4294967295));  // largest BSON Timestamp
  Add(groups, GetUpperBoundMessage(DeepClone(MinBsonTimestamp())));

  // Strings
  Add(groups, "\u0000");
  Add(groups, GetUpperBoundMessage(DeepClone(MinString())));

  // Blobs
  Add(groups, BlobValue(255));
  Add(groups, GetUpperBoundMessage(BlobValue()));

  // BSON Binary Data
  Add(groups, BsonBinaryData(255, {255, 255}));
  Add(groups, GetUpperBoundMessage(DeepClone(MinBsonBinaryData())));

  // References
  Add(groups, DeepClone(MinReference()));
  Add(groups, RefValue(DbId(), Key("c/d")));
  Add(groups, GetUpperBoundMessage(RefValue(DbId(), Key("a/b"))));

  // BSON Object Ids
  Add(groups, BsonObjectId("foo"));
  Add(groups, GetUpperBoundMessage(DeepClone(MinBsonObjectId())));

  // GeoPoints
  Add(groups, GeoPoint(90, 180));
  Add(groups, GetUpperBoundMessage(DeepClone(MinGeoPoint())));

  // Regular Expressions
  Add(groups, Regex("a", "i"));
  Add(groups, GetUpperBoundMessage(DeepClone(MinRegex())));

  // Arrays
  Add(groups, Array(false));
  Add(groups, GetUpperBoundMessage(DeepClone(MinArray())));

  // Vectors
  Add(groups, VectorType(1.0, 2.0, 3.0));
  Add(groups, GetUpperBoundMessage(DeepClone(MinVector())));

  // Maps
  Add(groups, Map("a", "b"));
  Add(groups, GetUpperBoundMessage(DeepClone(MinMap())));

  // MaxKey
  Add(groups, MaxKey());

  // The upper bound of MaxKey is internal max value.
  Add(groups, GetUpperBoundMessage(DeepClone(MaxKeyValue())));

  for (size_t i = 0; i < groups.size(); ++i) {
    for (size_t j = i; j < groups.size(); ++j) {
      VerifyRelaxedAscending(groups[i], groups[j]);
    }
  }
}

TEST_F(ValueUtilTest, CanonicalId) {
  VerifyCanonicalId(Value(nullptr), "null");
  VerifyCanonicalId(Value(true), "true");
  VerifyCanonicalId(Value(false), "false");
  VerifyCanonicalId(Value(1), "1");
  VerifyCanonicalId(Value(1.0), "1.0");
  VerifyCanonicalId(Value(Timestamp(30, 1000)), "time(30,1000)");
  VerifyCanonicalId(Value("a"), "a");
  VerifyCanonicalId(Value(std::string("a\0b", 3)), std::string("a\0b", 3));
  VerifyCanonicalId(Value(BlobValue(1, 2, 3)), "010203");
  VerifyCanonicalId(RefValue(DbId("p1/d1"), Key("c1/doc1")), "c1/doc1");
  VerifyCanonicalId(Value(GeoPoint(30, 60)), "geo(30.0,60.0)");
  VerifyCanonicalId(Value(Array(1, 2, 3)), "[1,2,3]");
  VerifyCanonicalId(Map("a", 1, "b", 2, "c", "3"), "{a:1,b:2,c:3}");
  VerifyCanonicalId(Map("a", Array("b", Map("c", GeoPoint(30, 60)))),
                    "{a:[b,{c:geo(30.0,60.0)}]}");
  VerifyCanonicalId(VectorType(1.0, 1.0, -2.0, 3.14),
                    "{__type__:__vector__,value:[1.0,1.0,-2.0,3.1]}");
  VerifyCanonicalId(MinKey(), "{__min__:null}");
  VerifyCanonicalId(MaxKey(), "{__max__:null}");
  VerifyCanonicalId(Regex("^foo", "x"), "{__regex__:{pattern:^foo,options:x}}");
  VerifyCanonicalId(Int32(123), "{__int__:123}");
  VerifyCanonicalId(BsonObjectId("foo"), "{__oid__:foo}");
  VerifyCanonicalId(BsonTimestamp(1, 2),
                    "{__request_timestamp__:{seconds:1,increment:2}}");
  // Binary representation: 128 = 0x80, 2 = 0x02, 3 = 0x03, 4 = 0x04
  VerifyCanonicalId(BsonBinaryData(128, {2, 3, 4}), "{__binary__:80020304}");
}

TEST_F(ValueUtilTest, DeepClone) {
  VerifyDeepClone(Value(nullptr));
  VerifyDeepClone(Value(true));
  VerifyDeepClone(Value(false));
  VerifyDeepClone(Value(1));
  VerifyDeepClone(Value(1.0));
  VerifyDeepClone(Value(Timestamp(30, 1000)));
  VerifyDeepClone(Value("a"));
  VerifyDeepClone(Value(std::string("a\0b", 3)));
  VerifyDeepClone(Value(BlobValue(1, 2, 3)));
  VerifyDeepClone(RefValue(DbId("p1/d1"), Key("c1/doc1")));
  VerifyDeepClone(Value(GeoPoint(30, 60)));
  VerifyDeepClone(Value(Array(1, 2, 3)));
  VerifyDeepClone(Map("a", 1, "b", 2, "c", "3"));
  VerifyDeepClone(Map("a", Array("b", Map("c", GeoPoint(30, 60)))));
}

TEST_F(ValueUtilTest, CompareMaps) {
  auto left_1 = Map("a", 7, "b", 0);
  auto right_1 = Map("a", 7, "b", 0);
  EXPECT_EQ(model::Compare(*left_1, *right_1), ComparisonResult::Same);

  auto left_2 = Map("a", 3, "b", 5);
  auto right_2 = Map("b", 5, "a", 3);
  EXPECT_EQ(model::Compare(*left_2, *right_2), ComparisonResult::Same);

  auto left_3 = Map("a", 8, "b", 10, "c", 5);
  auto right_3 = Map("a", 8, "b", 10);
  EXPECT_EQ(model::Compare(*left_3, *right_3), ComparisonResult::Descending);

  auto left_4 = Map("a", 7, "b", 0);
  auto right_4 = Map("a", 7, "b", 10);
  EXPECT_EQ(model::Compare(*left_4, *right_4), ComparisonResult::Ascending);
}

}  // namespace

}  // namespace model
}  // namespace firestore
}  // namespace firebase
