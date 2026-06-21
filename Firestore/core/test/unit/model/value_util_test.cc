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
using testutil::DbId;
using testutil::kCanonicalNanBits;
using testutil::Key;
using testutil::Map;
using testutil::time_point;
using testutil::Value;
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
        if (expected_result != Compare(left->values[i], right->values[j])) {
          std::cout << "here" << std::endl;
        }
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
  Add(equals_group, Map("bar", 1, "foo", 2), Map("bar", 1, "foo", 2));
  Add(equals_group, Map("bar", 2, "foo", 1));
  Add(equals_group, Map("bar", 1));
  Add(equals_group, Map("foo", 1));

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

  // booleans
  Add(comparison_groups, false);
  Add(comparison_groups, true);

  // numbers
  Add(comparison_groups, DeepClone(MinNumber()));
  Add(comparison_groups, -1e20);
  Add(comparison_groups, std::numeric_limits<int64_t>::min());
  Add(comparison_groups, -0.1);
  // Zeros all compare the same.
  Add(comparison_groups, -0.0, 0.0, 0L);
  Add(comparison_groups, 0.1);
  // Doubles and longs Compare() the same.
  Add(comparison_groups, 1.0, 1L);
  Add(comparison_groups, std::numeric_limits<int64_t>::max());
  Add(comparison_groups, 1e20);

  // dates
  Add(comparison_groups, DeepClone(MinTimestamp()));
  Add(comparison_groups, kTimestamp1);
  Add(comparison_groups, kTimestamp2);

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

  // resource names
  Add(comparison_groups, DeepClone(MinReference()));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc2")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c10/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c2/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d2"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p2/d1"), Key("c1/doc1")));

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
  Add(comparison_groups, DeepClone(MaxValue()));

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
  Add(comparison_groups, -0.0, 0.0, 0L);
  Add(comparison_groups, 0.1);
  // Doubles and longs Compare() the same.
  Add(comparison_groups, 1.0, 1L);
  Add(comparison_groups, std::numeric_limits<int64_t>::max());
  Add(comparison_groups, 1e20);
  Add(comparison_groups, DeepClone(MinTimestamp()));
  Add(comparison_groups, DeepClone(MinTimestamp()));

  // dates
  Add(comparison_groups, DeepClone(MinTimestamp()));
  Add(comparison_groups, kTimestamp1);
  Add(comparison_groups, kTimestamp2);

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
  Add(comparison_groups, DeepClone(MinReference()));

  // resource names
  Add(comparison_groups, DeepClone(MinReference()));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc2")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c10/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c2/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d2"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p2/d1"), Key("c1/doc1")));
  Add(comparison_groups, DeepClone(MinGeoPoint()));

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
  Add(comparison_groups, DeepClone(MinArray()));

  // arrays
  Add(comparison_groups, DeepClone(MinArray()));
  Add(comparison_groups, Array("bar"));
  Add(comparison_groups, Array("foo", 1));
  Add(comparison_groups, Array("foo", 2));
  Add(comparison_groups, Array("foo", "0"));
  Add(comparison_groups, DeepClone(MinVector()));

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
  Add(comparison_groups, DeepClone(MaxValue()));

  for (size_t i = 0; i < comparison_groups.size(); ++i) {
    for (size_t j = i; j < comparison_groups.size(); ++j) {
      VerifyRelaxedAscending(comparison_groups[i], comparison_groups[j]);
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
  VerifyCanonicalId(
      Map("__type__", "__vector__", "value", Array(1.0, 1.0, -2.0, 3.14)),
      "{__type__:__vector__,value:[1.0,1.0,-2.0,3.1]}");
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
