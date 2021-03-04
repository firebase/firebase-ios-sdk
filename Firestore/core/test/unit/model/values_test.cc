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

#include "Firestore/core/src/model/values.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/test/unit/testutil/equals_tester.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "Firestore/core/test/unit/testutil/time_testing.h"
#include "absl/base/casts.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using testutil::Array;
using testutil::BlobValue;
using testutil::DbId;
using testutil::Key;
using testutil::Map;
using testutil::time_point;
using testutil::Value;
using util::ComparisonResult;

namespace {

double ToDouble(uint64_t value) {
  return absl::bit_cast<double>(value);
}

const uint64_t kNanBits = 0x7fff000000000000ULL;

}  // namespace

static time_point kDate1 = testutil::MakeTimePoint(2016, 5, 20, 10, 20, 0);
static Timestamp kTimestamp1{1463739600, 0};

static time_point kDate2 = testutil::MakeTimePoint(2016, 10, 21, 15, 32, 0);
static Timestamp kTimestamp2{1477063920, 0};

class ValuesTest : public ::testing::Test {
 public:
  ValuesTest() : serializer(DbId()) {
  }

  template <typename T>
  google_firestore_v1_Value Wrap(T input) {
    model::FieldValue fv = Value(input);
    return serializer.EncodeFieldValue(fv);
  }

  template <typename... Args>
  google_firestore_v1_Value WrapObject(Args... key_value_pairs) {
    FieldValue fv = testutil::WrapObject((key_value_pairs)...);
    return serializer.EncodeFieldValue(fv);
  }

  template <typename... Args>
  google_firestore_v1_Value WrapArray(Args... values) {
    std::vector<model::FieldValue> contents{Value(values)...};
    FieldValue fv = FieldValue::FromArray(std::move(contents));
    return serializer.EncodeFieldValue(fv);
  }

  google_firestore_v1_Value WrapReference(DatabaseId database_id,
                                          DocumentKey key) {
    google_firestore_v1_Value result{};
    result.which_value_type = google_firestore_v1_Value_reference_value_tag;
    result.reference_value =
        serializer.EncodeResourceName(database_id, key.path());
    return result;
  }

  google_firestore_v1_Value WrapServerTimestamp(
      const model::FieldValue& input) {
    // TODO(mrschmidt): Replace with EncodeFieldValue encoding when available
    return WrapObject("__type__", "server_timestamp", "__local_write_time__",
                      input.server_timestamp_value().local_write_time());
  }

  template <typename... Args>
  void Add(std::vector<std::vector<google_firestore_v1_Value>>& groups,
           Args... values) {
    std::vector<google_firestore_v1_Value> group{(values)...};
    groups.emplace_back(group);
  }

  void VerifyEquals(std::vector<google_firestore_v1_Value>& group) {
    for (size_t i = 0; i < group.size(); ++i) {
      for (size_t j = 0; j < group.size(); ++j) {
        EXPECT_TRUE(Values::Equals(group[i], group[j]));
      }
    }
  }

  void VerifyNotEquals(std::vector<google_firestore_v1_Value>& left,
                       std::vector<google_firestore_v1_Value>& right) {
    for (const auto& val1 : left) {
      for (const auto& val2 : right) {
        EXPECT_FALSE(Values::Equals(val1, val2));
      }
    }
  }

  void VerifyOrdering(std::vector<google_firestore_v1_Value>& left,
                      std::vector<google_firestore_v1_Value>& right,
                      ComparisonResult cmp) {
    for (const auto& val1 : left) {
      for (const auto& val2 : right) {
        EXPECT_EQ(cmp, Values::Compare(val1, val2));
      }
    }
  }

  void VerifyCanonicalId(const google_firestore_v1_Value& value,
                         const std::string& expected_canonical_id) {
    const std::string& actual_canonical_id = Values::CanonicalId(value);
    EXPECT_EQ(expected_canonical_id, actual_canonical_id);
  }

 private:
  remote::Serializer serializer;
};

TEST_F(ValuesTest, Equality) {
  std::vector<std::vector<google_firestore_v1_Value>> equals_group;

  Add(equals_group, Wrap(nullptr), Wrap(nullptr));
  Add(equals_group, Wrap(false), Wrap(false));
  Add(equals_group, Wrap(true), Wrap(true));
  Add(equals_group, Wrap(std::numeric_limits<double>::quiet_NaN()),
      Wrap(ToDouble(kCanonicalNanBits)), Wrap(ToDouble(kNanBits)),
      Wrap(std::nan("1")), Wrap(std::nan("2")));
  // -0.0 and 0.0 compare the same but are not equal.
  Add(equals_group, Wrap(-0.0));
  Add(equals_group, Wrap(0.0));
  Add(equals_group, Wrap(1), Wrap(1LL));
  // Doubles and Longs aren't equal (even though they compare same).
  Add(equals_group, Wrap(1.0), Wrap(1.0));
  Add(equals_group, Wrap(1.1), Wrap(1.1));
  // TODO fixme
  Add(equals_group, Wrap(BlobValue(0, 1, 1)));
  Add(equals_group, Wrap(BlobValue(0, 1)));
  Add(equals_group, Wrap("string"), Wrap("string"));
  Add(equals_group, Wrap("strin"));
  // latin small letter e + combining acute accent
  Add(equals_group, Wrap("e\u0301b"));
  // latin small letter e with acute accent
  Add(equals_group, Wrap("\u00e9a"));
  Add(equals_group, Wrap(Timestamp::FromTimePoint(kDate1)), Wrap(kTimestamp1));
  Add(equals_group, Wrap(Timestamp::FromTimePoint(kDate2)), Wrap(kTimestamp2));
  // NOTE: ServerTimestampValues can't be parsed via Wrap().
  Add(equals_group,
      WrapServerTimestamp(FieldValue::FromServerTimestamp(kTimestamp1)),
      WrapServerTimestamp(FieldValue::FromServerTimestamp(kTimestamp1)));
  Add(equals_group,
      WrapServerTimestamp(FieldValue::FromServerTimestamp(kTimestamp2)));
  Add(equals_group, Wrap(GeoPoint(0, 1)), Wrap(GeoPoint(0, 1)));
  Add(equals_group, Wrap(GeoPoint(1, 0)));
  Add(equals_group, WrapReference(DbId(), Key("coll/doc1")),
      WrapReference(DbId(), Key("coll/doc1")));
  Add(equals_group, WrapReference(DbId(), Key("coll/doc2")));
  Add(equals_group, WrapReference(DbId("project/baz"), Key("coll/doc2")));
  Add(equals_group, WrapArray("foo", "bar"), WrapArray("foo", "bar"));
  Add(equals_group, WrapArray("foo", "bar", "baz"));
  Add(equals_group, WrapArray("foo"));
  Add(equals_group, WrapObject("bar", 1, "foo", 2),
      WrapObject("foo", 2, "bar", 1));
  Add(equals_group, WrapObject("bar", 2, "foo", 1));
  Add(equals_group, WrapObject("bar", 1));
  Add(equals_group, WrapObject("foo", 1));

  for (size_t i = 0; i < equals_group.size(); ++i) {
    for (size_t j = i; j < equals_group.size(); ++j) {
      if (i == j) {
        VerifyEquals(equals_group[i]);
      } else {
        VerifyNotEquals(equals_group[i], equals_group[j]);
      }
    }
  }
}

TEST_F(ValuesTest, Ordering) {
  std::vector<std::vector<google_firestore_v1_Value>> comparison_groups;

  // null first
  Add(comparison_groups, Wrap(nullptr));

  // booleans
  Add(comparison_groups, Wrap(false));
  Add(comparison_groups, Wrap(true));

  // numbers
  Add(comparison_groups, Wrap(-1e20));
  Add(comparison_groups, Wrap(LLONG_MIN));
  Add(comparison_groups, Wrap(-0.1));
  // Zeros all compare the same.
  Add(comparison_groups, Wrap(-0.0), Wrap(0.0), Wrap(0L));
  Add(comparison_groups, Wrap(0.1));
  // Doubles and longs Compare() the same.
  Add(comparison_groups, Wrap(1.0), Wrap(1L));
  Add(comparison_groups, Wrap(LLONG_MAX));
  Add(comparison_groups, Wrap(1e20));

  // dates
  Add(comparison_groups, Wrap(kTimestamp1));
  Add(comparison_groups, Wrap(kTimestamp2));

  // server timestamps come after all concrete timestamps.
  // NOTE: server timestamps can't be parsed with Wrap().
  Add(comparison_groups,
      WrapServerTimestamp(FieldValue::FromServerTimestamp(kTimestamp1)));
  Add(comparison_groups,
      WrapServerTimestamp(FieldValue::FromServerTimestamp(kTimestamp2)));

  // strings
  Add(comparison_groups, Wrap(""));
  Add(comparison_groups, Wrap("\001\ud7ff\ue000\uffff"));
  Add(comparison_groups, Wrap("(╯°□°）╯︵ ┻━┻"));
  Add(comparison_groups, Wrap("a"));
  Add(comparison_groups, Wrap("abc def"));
  // latin small letter e + combining acute accent + latin small letter b
  Add(comparison_groups, Wrap("e\u0301b"));
  Add(comparison_groups, Wrap("æ"));
  // latin small letter e with acute accent + latin small letter a
  Add(comparison_groups, Wrap("\u00e9a"));

  // blobs
  Add(comparison_groups, Wrap(BlobValue()));
  Add(comparison_groups, Wrap(BlobValue(0)));
  Add(comparison_groups, Wrap(BlobValue(0, 1, 2, 3, 4)));
  Add(comparison_groups, Wrap(BlobValue(0, 1, 2, 4, 3)));
  Add(comparison_groups, Wrap(BlobValue(255)));

  // resource names
  Add(comparison_groups, WrapReference(DbId("p1/d1"), Key("c1/doc1")));
  Add(comparison_groups, WrapReference(DbId("p1/d1"), Key("c1/doc2")));
  Add(comparison_groups, WrapReference(DbId("p1/d1"), Key("c10/doc1")));
  Add(comparison_groups, WrapReference(DbId("p1/d1"), Key("c2/doc1")));
  Add(comparison_groups, WrapReference(DbId("p1/d2"), Key("c1/doc1")));
  Add(comparison_groups, WrapReference(DbId("p2/d1"), Key("c1/doc1")));

  // geo points
  Add(comparison_groups, Wrap(GeoPoint(-90, -180)));
  Add(comparison_groups, Wrap(GeoPoint(-90, 0)));
  Add(comparison_groups, Wrap(GeoPoint(-90, 180)));
  Add(comparison_groups, Wrap(GeoPoint(0, -180)));
  Add(comparison_groups, Wrap(GeoPoint(0, 0)));
  Add(comparison_groups, Wrap(GeoPoint(0, 180)));
  Add(comparison_groups, Wrap(GeoPoint(1, -180)));
  Add(comparison_groups, Wrap(GeoPoint(1, 0)));
  Add(comparison_groups, Wrap(GeoPoint(1, 180)));
  Add(comparison_groups, Wrap(GeoPoint(90, -180)));
  Add(comparison_groups, Wrap(GeoPoint(90, 0)));
  Add(comparison_groups, Wrap(GeoPoint(90, 180)));

  // arrays
  Add(comparison_groups, WrapArray("bar"));
  Add(comparison_groups, WrapArray("foo", 1));
  Add(comparison_groups, WrapArray("foo", 2));
  Add(comparison_groups, WrapArray("foo", "0"));

  // objects
  Add(comparison_groups, WrapObject("bar", 0));
  Add(comparison_groups, WrapObject("bar", 0, "foo", 1));
  Add(comparison_groups, WrapObject("foo", 1));
  Add(comparison_groups, WrapObject("foo", 2));
  Add(comparison_groups, WrapObject("foo", "0"));

  for (size_t i = 0; i < comparison_groups.size(); ++i) {
    for (size_t j = i; j < comparison_groups.size(); ++j) {
      if (i == j) {
        VerifyOrdering(comparison_groups[i], comparison_groups[i],
                       ComparisonResult::Same);
      } else {
        VerifyOrdering(comparison_groups[i], comparison_groups[j],
                       ComparisonResult::Ascending);
      }
    }
  }
}

TEST_F(ValuesTest, CanonicalId) {
  VerifyCanonicalId(Wrap(nullptr), "null");
  VerifyCanonicalId(Wrap(true), "true");
  VerifyCanonicalId(Wrap(false), "false");
  VerifyCanonicalId(Wrap(1), "1");
  VerifyCanonicalId(Wrap(1.0), "1.000000");
  VerifyCanonicalId(Wrap(Timestamp(30, 1000)), "time(30,1000)");
  VerifyCanonicalId(Wrap("a"), "a");
  VerifyCanonicalId(Wrap(BlobValue(1, 2, 3)), "010203");
  VerifyCanonicalId(WrapReference(DbId("p1/d1"), Key("c1/doc1")), "c1/doc1");
  VerifyCanonicalId(Wrap(GeoPoint(30, 60)), "geo(30.000000,60.000000)");
  VerifyCanonicalId(WrapArray(1, 2, 3), "[1,2,3]");
  VerifyCanonicalId(WrapObject("a", 1, "b", 2, "c", "3"), "{a:1,b:2,c:3}");
  VerifyCanonicalId(WrapObject("a", Array("b", Map("c", GeoPoint(30, 60)))),
                    "{a:[b,{c:geo(30.000000,60.000000)}]}");
}

TEST_F(ValuesTest, CanonicalIdIgnoresSortOrder) {
  VerifyCanonicalId(WrapObject("a", 1, "b", 2, "c", "3"), "{a:1,b:2,c:3}");
  VerifyCanonicalId(WrapObject("c", 3, "b", 2, "a", "1"), "{a:1,b:2,c:3}");
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
