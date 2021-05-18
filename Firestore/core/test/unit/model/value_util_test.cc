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

#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
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

uint64_t ToBits(double value) {
  return absl::bit_cast<uint64_t>(value);
}

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
  void Add(std::vector<std::vector<google_firestore_v1_Value>>& groups,
           Args... values) {
    std::vector<google_firestore_v1_Value> group{
        Value(std::forward<Args>(values))...};
    groups.emplace_back(group);
  }

  void VerifyEquality(std::vector<google_firestore_v1_Value>& left,
                      std::vector<google_firestore_v1_Value>& right,
                      bool expected_equals) {
    for (const auto& val1 : left) {
      for (const auto& val2 : right) {
        if (expected_equals) {
          EXPECT_EQ(val1, val2);
        } else {
          EXPECT_NE(val1, val2);
        }
      }
    }
  }

  void VerifyOrdering(std::vector<google_firestore_v1_Value>& left,
                      std::vector<google_firestore_v1_Value>& right,
                      ComparisonResult expected_result) {
    for (const auto& val1 : left) {
      for (const auto& val2 : right) {
        EXPECT_EQ(expected_result, Compare(val1, val2))
            << "Order check failed for '" << CanonicalId(val1) << "' and '"
            << CanonicalId(val2) << "' (expected "
            << static_cast<int>(expected_result) << ")";
        EXPECT_EQ(util::ReverseOrder(expected_result), Compare(val2, val1))
            << "Reverse order check failed for '" << CanonicalId(val1)
            << "' and '" << CanonicalId(val2) << "' (expected "
            << static_cast<int>(util::ReverseOrder(expected_result)) << ")";
      }
    }
  }

  void VerifyCanonicalId(const google_firestore_v1_Value& value,
                         const std::string& expected_canonical_id) {
    std::string actual_canonical_id = CanonicalId(value);
    EXPECT_EQ(expected_canonical_id, actual_canonical_id);
  }

  void VerifyDeepClone(const google_firestore_v1_Value& value) {
    nanopb::Message<google_firestore_v1_Value> clone1;

    [&] {
      nanopb::Message<google_firestore_v1_Value> clone2{DeepClone(value)};
      EXPECT_EQ(value, *clone2);
      clone1 = nanopb::Message<google_firestore_v1_Value>{DeepClone(*clone2)};
    }();

    // `clone2` is destroyed at this point, but `clone1` should be still valid.
    EXPECT_EQ(value, *clone1);
  }

 private:
  remote::Serializer serializer{DbId()};
};

TEST(FieldValueTest, ValueHelpers) {
  // Validates that the Value helpers in testutil produce the right types
  google_firestore_v1_Value bool_value = Value(true);
  ASSERT_EQ(GetTypeOrder(bool_value), TypeOrder::kBoolean);
  EXPECT_EQ(bool_value.boolean_value, true);

  google_firestore_v1_Value int_value = Value(5);
  ASSERT_EQ(GetTypeOrder(int_value), TypeOrder::kNumber);
  EXPECT_EQ(int_value.integer_value, 5);

  google_firestore_v1_Value long_value = Value(LONG_MAX);
  ASSERT_EQ(GetTypeOrder(long_value), TypeOrder::kNumber);
  EXPECT_EQ(long_value.integer_value, LONG_MAX);

  google_firestore_v1_Value long_long_value = Value(LLONG_MAX);
  ASSERT_EQ(GetTypeOrder(long_long_value), TypeOrder::kNumber);
  EXPECT_EQ(long_long_value.integer_value, LLONG_MAX);

  google_firestore_v1_Value double_value = Value(2.0);
  ASSERT_EQ(GetTypeOrder(double_value), TypeOrder::kNumber);
  EXPECT_EQ(double_value.double_value, 2.0);
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
  std::vector<std::vector<google_firestore_v1_Value>> equals_group;

  Add(equals_group, Value(nullptr), Value(nullptr));
  Add(equals_group, Value(false), Value(false));
  Add(equals_group, Value(true), Value(true));
  Add(equals_group, Value(std::numeric_limits<double>::quiet_NaN()),
      Value(ToDouble(kCanonicalNanBits)), Value(ToDouble(kAlternateNanBits)),
      Value(std::nan("1")), Value(std::nan("2")));
  // -0.0 and 0.0 compare the same but are not equal.
  Add(equals_group, Value(-0.0));
  Add(equals_group, Value(0.0));
  Add(equals_group, Value(1), Value(1LL));
  // Doubles and Longs aren't equal (even though they compare same).
  Add(equals_group, Value(1.0), Value(1.0));
  Add(equals_group, Value(1.1), Value(1.1));
  Add(equals_group, Value(BlobValue(0, 1, 1)));
  Add(equals_group, Value(BlobValue(0, 1)));
  Add(equals_group, Value("string"), Value("string"));
  Add(equals_group, Value("strin"));
  Add(equals_group, Value(std::string("strin\0", 6)));
  // latin small letter e + combining acute accent
  Add(equals_group, Value("e\u0301b"));
  // latin small letter e with acute accent
  Add(equals_group, Value("\u00e9a"));
  Add(equals_group, Value(Timestamp::FromTimePoint(kDate1)),
      Value(kTimestamp1));
  Add(equals_group, Value(Timestamp::FromTimePoint(kDate2)),
      Value(kTimestamp2));
  // NOTE: ServerTimestampValues can't be parsed via Value().
  Add(equals_group, EncodeServerTimestamp(kTimestamp1, absl::nullopt),
      EncodeServerTimestamp(kTimestamp1, absl::nullopt));
  Add(equals_group, EncodeServerTimestamp(kTimestamp2, absl::nullopt));
  Add(equals_group, Value(GeoPoint(0, 1)), Value(GeoPoint(0, 1)));
  Add(equals_group, Value(GeoPoint(1, 0)));
  Add(equals_group, RefValue(DbId(), Key("coll/doc1")),
      RefValue(DbId(), Key("coll/doc1")));
  Add(equals_group, RefValue(DbId(), Key("coll/doc2")));
  Add(equals_group, RefValue(DbId("project/baz"), Key("coll/doc2")));
  Add(equals_group, Array("foo", "bar"), Array("foo", "bar"));
  Add(equals_group, Array("foo", "bar", "baz"));
  Add(equals_group, Array("foo"));
  Add(equals_group, Map("bar", 1, "foo", 2), Map("foo", 2, "bar", 1));
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

TEST_F(ValueUtilTest, Ordering) {
  // Create a matrix that defines a comparison group. The outer vector has
  // multiple rows and each row can have an arbitrary number of entries.
  // The elements within a row must compare equal to each other, but order after
  // all elements in previous groups and before all elements in later groups.
  std::vector<std::vector<google_firestore_v1_Value>> comparison_groups;

  // null first
  Add(comparison_groups, Value(nullptr));

  // booleans
  Add(comparison_groups, Value(false));
  Add(comparison_groups, Value(true));

  // numbers
  Add(comparison_groups, Value(-1e20));
  Add(comparison_groups, Value(LLONG_MIN));
  Add(comparison_groups, Value(-0.1));
  // Zeros all compare the same.
  Add(comparison_groups, Value(-0.0), Value(0.0), Value(0L));
  Add(comparison_groups, Value(0.1));
  // Doubles and longs Compare() the same.
  Add(comparison_groups, Value(1.0), Value(1L));
  Add(comparison_groups, Value(LLONG_MAX));
  Add(comparison_groups, Value(1e20));

  // dates
  Add(comparison_groups, Value(kTimestamp1));
  Add(comparison_groups, Value(kTimestamp2));

  // server timestamps come after all concrete timestamps.
  // NOTE: server timestamps can't be parsed with Value().
  Add(comparison_groups, EncodeServerTimestamp(kTimestamp1, absl::nullopt));
  Add(comparison_groups, EncodeServerTimestamp(kTimestamp2, absl::nullopt));

  // strings
  Add(comparison_groups, Value(""));
  Add(comparison_groups, Value("\001\ud7ff\ue000\uffff"));
  Add(comparison_groups, Value("(╯°□°）╯︵ ┻━┻"));
  Add(comparison_groups, Value("a"));
  Add(comparison_groups, Value(std::string("abc\0 def", 8)));
  Add(comparison_groups, Value("abc def"));
  // latin small letter e + combining acute accent + latin small letter b
  Add(comparison_groups, Value("e\u0301b"));
  Add(comparison_groups, Value("æ"));
  // latin small letter e with acute accent + latin small letter a
  Add(comparison_groups, Value("\u00e9a"));

  // blobs
  Add(comparison_groups, Value(BlobValue()));
  Add(comparison_groups, Value(BlobValue(0)));
  Add(comparison_groups, Value(BlobValue(0, 1, 2, 3, 4)));
  Add(comparison_groups, Value(BlobValue(0, 1, 2, 4, 3)));
  Add(comparison_groups, Value(BlobValue(255)));

  // resource names
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c1/doc2")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c10/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d1"), Key("c2/doc1")));
  Add(comparison_groups, RefValue(DbId("p1/d2"), Key("c1/doc1")));
  Add(comparison_groups, RefValue(DbId("p2/d1"), Key("c1/doc1")));

  // geo points
  Add(comparison_groups, Value(GeoPoint(-90, -180)));
  Add(comparison_groups, Value(GeoPoint(-90, 0)));
  Add(comparison_groups, Value(GeoPoint(-90, 180)));
  Add(comparison_groups, Value(GeoPoint(0, -180)));
  Add(comparison_groups, Value(GeoPoint(0, 0)));
  Add(comparison_groups, Value(GeoPoint(0, 180)));
  Add(comparison_groups, Value(GeoPoint(1, -180)));
  Add(comparison_groups, Value(GeoPoint(1, 0)));
  Add(comparison_groups, Value(GeoPoint(1, 180)));
  Add(comparison_groups, Value(GeoPoint(90, -180)));
  Add(comparison_groups, Value(GeoPoint(90, 0)));
  Add(comparison_groups, Value(GeoPoint(90, 180)));

  // arrays
  Add(comparison_groups, Array("bar"));
  Add(comparison_groups, Array("foo", 1));
  Add(comparison_groups, Array("foo", 2));
  Add(comparison_groups, Array("foo", "0"));

  // objects
  Add(comparison_groups, Map("bar", 0));
  Add(comparison_groups, Map("bar", 0, "foo", 1));
  Add(comparison_groups, Map("foo", 1));
  Add(comparison_groups, Map("foo", 2));
  Add(comparison_groups, Map("foo", "0"));

  for (size_t i = 0; i < comparison_groups.size(); ++i) {
    for (size_t j = i; j < comparison_groups.size(); ++j) {
      VerifyOrdering(
          comparison_groups[i], comparison_groups[j],
          i == j ? ComparisonResult::Same : ComparisonResult::Ascending);
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

}  // namespace

}  // namespace model
}  // namespace firestore
}  // namespace firebase
