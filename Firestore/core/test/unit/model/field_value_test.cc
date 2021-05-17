/*
 * Copyright 2018 Google LLC
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

#include "Firestore/core/src/model/field_value.h"

#if __APPLE__
#import <CoreFoundation/CoreFoundation.h>
#endif  // __APPLE__

#include <chrono>  // NOLINT(build/c++11)
#include <climits>
#include <cmath>
#include <vector>

#include "Firestore/core/src/model/field_mask.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/equals_tester.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "Firestore/core/test/unit/testutil/time_testing.h"
#include "absl/base/casts.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using Type = FieldValue::Type;

using absl::nullopt;
using nanopb::ByteString;
using testing::Not;
using testutil::Array;
using testutil::BlobValue;
using testutil::DbId;
using testutil::Field;
using testutil::kCanonicalNanBits;
using testutil::Key;
using testutil::Map;
using testutil::time_point;
using testutil::Value;
using testutil::WrapObject;

using Sec = std::chrono::seconds;
using Ms = std::chrono::milliseconds;

namespace {

uint64_t ToBits(double value) {
  return absl::bit_cast<uint64_t>(value);
}

double ToDouble(uint64_t value) {
  return absl::bit_cast<double>(value);
}

// All permutations of the 51 other non-MSB significand bits are also NaNs.
const uint64_t kAlternateNanBits = 0x7fff000000000000ULL;

MATCHER(IsNan, "a NaN") {
  return std::isnan(arg);
}

}  // namespace

class FieldValueTest : public testing::Test {
 public:
  static FieldValue FromServerTimestamp(
      const Timestamp& local_write_time,
      absl::optional<FieldValue> previous_value = absl::nullopt) {
    return FieldValue::FromServerTimestamp(local_write_time, previous_value);
  }
};

TEST_F(FieldValueTest, ValueHelpers) {
  // Validates that the Value helpers in testutil produce the right types
  FieldValue bool_value = Value(true);
  ASSERT_EQ(bool_value.type(), Type::Boolean);
  EXPECT_EQ(bool_value.boolean_value(), true);

  FieldValue int_value = Value(5);
  ASSERT_EQ(int_value.type(), Type::Integer);
  EXPECT_EQ(int_value.integer_value(), 5);

  FieldValue long_value = Value(LONG_MAX);
  ASSERT_EQ(long_value.type(), Type::Integer);
  EXPECT_EQ(long_value.integer_value(), LONG_MAX);

  FieldValue long_long_value = Value(LLONG_MAX);
  ASSERT_EQ(long_long_value.type(), Type::Integer);
  EXPECT_EQ(long_long_value.integer_value(), LLONG_MAX);

  FieldValue double_value = Value(2.0);
  ASSERT_EQ(double_value.type(), Type::Double);
  EXPECT_EQ(double_value.double_value(), 2.0);
}

TEST_F(FieldValueTest, ExtractsFields) {
  ObjectValue value = WrapObject("foo", Map("a", 1, "b", true, "c", "string"));

  ASSERT_EQ(Type::Object, value.Get(Field("foo"))->type());

  EXPECT_EQ(Value(1), value.Get(Field("foo.a")));
  EXPECT_EQ(Value(true), value.Get(Field("foo.b")));
  EXPECT_EQ(Value("string"), value.Get(Field("foo.c")));

  EXPECT_EQ(nullopt, value.Get(Field("foo.a.b")));
  EXPECT_EQ(nullopt, value.Get(Field("bar")));
  EXPECT_EQ(nullopt, value.Get(Field("bar.a")));
}

TEST_F(FieldValueTest, ExtractsFieldMask) {
  ObjectValue value =
      WrapObject("a", "b", "map",
                 Map("a", 1, "b", true, "c", "string", "nested", Map("d", "e")),
                 "emptymap", Map());

  FieldMask expected_mask =
      FieldMask({Field("a"), Field("map.a"), Field("map.b"), Field("map.c"),
                 Field("map.nested.d"), Field("emptymap")});
  FieldMask actual_mask = value.ToFieldMask();

  EXPECT_EQ(expected_mask, actual_mask);
}

TEST_F(FieldValueTest, OverwritesExistingFields) {
  ObjectValue old = WrapObject("a", "old");
  ObjectValue mod = old.Set(Field("a"), Value("mod"));
  EXPECT_NE(old, mod);
  EXPECT_EQ(WrapObject("a", "old"), old);
  EXPECT_EQ(WrapObject("a", "mod"), mod);
}

TEST_F(FieldValueTest, AddsNewFields) {
  ObjectValue empty = ObjectValue::Empty();
  ObjectValue mod = empty.Set(Field("a"), Value("mod"));
  EXPECT_EQ(ObjectValue::Empty(), empty);
  EXPECT_EQ(WrapObject("a", "mod"), mod);

  ObjectValue old = mod;
  mod = old.Set(Field("b"), Value(1));
  EXPECT_EQ(WrapObject("a", "mod"), old);
  EXPECT_EQ(WrapObject("a", "mod", "b", 1), mod);
}

TEST_F(FieldValueTest, ImplicitlyCreatesObjects) {
  ObjectValue old = WrapObject("a", "old");
  ObjectValue mod = old.Set(Field("b.c.d"), Value("mod"));

  EXPECT_NE(old, mod);
  EXPECT_EQ(WrapObject("a", "old"), old);
  EXPECT_EQ(WrapObject("a", "old", "b", Map("c", Map("d", "mod"))), mod);
}

TEST_F(FieldValueTest, CanOverwritePrimitivesWithObjects) {
  ObjectValue old = WrapObject("a", Map("b", "old"));
  ObjectValue mod = old.Set(Field("a"), WrapObject("b", "mod"));
  EXPECT_NE(old, mod);
  EXPECT_EQ(WrapObject("a", Map("b", "old")), old);
  EXPECT_EQ(WrapObject("a", Map("b", "mod")), mod);
}

TEST_F(FieldValueTest, AddsToNestedObjects) {
  ObjectValue old = WrapObject("a", Map("b", "old"));
  ObjectValue mod = old.Set(Field("a.c"), Value("mod"));
  EXPECT_NE(old, mod);
  EXPECT_EQ(WrapObject("a", Map("b", "old")), old);
  EXPECT_EQ(WrapObject("a", Map("b", "old", "c", "mod")), mod);
}

TEST_F(FieldValueTest, DeletesKey) {
  ObjectValue old = WrapObject("a", 1, "b", 2);
  ObjectValue mod = old.Delete(Field("a"));

  EXPECT_NE(old, mod);
  EXPECT_EQ(WrapObject("a", 1, "b", 2), old);
  EXPECT_EQ(WrapObject("b", 2), mod);

  ObjectValue empty = mod.Delete(Field("b"));
  EXPECT_NE(mod, empty);
  EXPECT_EQ(WrapObject("b", 2), mod);
  EXPECT_EQ(ObjectValue::Empty(), empty);
}

TEST_F(FieldValueTest, DeletesHandleMissingKeys) {
  ObjectValue old = WrapObject("a", Map("b", 1, "c", 2));
  ObjectValue mod = old.Delete(Field("b"));
  EXPECT_EQ(mod, old);
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), mod);

  mod = old.Delete(Field("a.d"));
  EXPECT_EQ(mod, old);
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), mod);

  mod = old.Delete(Field("a.b.c"));
  EXPECT_EQ(mod, old);
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), mod);
}

TEST_F(FieldValueTest, DeletesNestedKeys) {
  FieldValue::Map orig = Map("a", Map("b", 1, "c", Map("d", 2, "e", 3)));
  ObjectValue old = WrapObject(orig);
  ObjectValue mod = old.Delete(Field("a.c.d"));

  EXPECT_NE(mod, old);

  FieldValue::Map second = Map("a", Map("b", 1, "c", Map("e", 3)));
  EXPECT_EQ(WrapObject(second), mod);

  old = mod;
  mod = old.Delete(Field("a.c"));

  EXPECT_NE(old, mod);
  EXPECT_EQ(WrapObject(second), old);

  FieldValue::Map third = Map("a", Map("b", 1));
  EXPECT_EQ(WrapObject(third), mod);

  old = mod;
  mod = old.Delete(Field("a"));

  EXPECT_NE(old, mod);
  EXPECT_EQ(WrapObject(third), old);
  EXPECT_EQ(ObjectValue::Empty(), mod);
}

#if defined(_WIN32)
#define timegm _mkgmtime

#elif defined(__ANDROID__)
// time.h doesn't necessarily define this properly, even though it's present
// from API 12 and up.
extern time_t timegm(struct tm*);
#endif

static time_point kDate1 = testutil::MakeTimePoint(2016, 5, 20, 10, 20, 0);
static Timestamp kTimestamp1{1463739600, 0};

static time_point kDate2 = testutil::MakeTimePoint(2016, 10, 21, 15, 32, 0);
static Timestamp kTimestamp2{1477063920, 0};

TEST_F(FieldValueTest, Equality) {
  // Avoid statically dividing by zero; MSVC considers this an error.
  double zero = 0.0;
  testutil::EqualsTester<FieldValue>()
      .AddEqualityGroup(FieldValue::Null(), Value(nullptr))
      .AddEqualityGroup(FieldValue::False(), Value(false))
      .AddEqualityGroup(FieldValue::True(), Value(true))
      .AddEqualityGroup(Value(0.0 / zero), Value(ToDouble(kCanonicalNanBits)),
                        Value(ToDouble(kAlternateNanBits)),
                        Value(std::nan("1")), Value(std::nan("2")))
      // -0.0 and 0.0 compare the same but are not equal.
      .AddEqualityGroup(Value(-0.0))
      .AddEqualityGroup(Value(0.0))
      .AddEqualityGroup(Value(1), FieldValue::FromInteger(1LL))
      // Doubles and Longs aren't equal (even though they compare same).
      .AddEqualityGroup(Value(1.0), FieldValue::FromDouble(1.0))
      .AddEqualityGroup(Value(1.1), FieldValue::FromDouble(1.1))
      .AddEqualityGroup(BlobValue(0, 1, 1))
      .AddEqualityGroup(BlobValue(0, 1))
      .AddEqualityGroup(Value("string"), FieldValue::FromString("string"))
      .AddEqualityGroup(Value("strin"))
      // latin small letter e + combining acute accent
      .AddEqualityGroup(Value("e\u0301b"))
      // latin small letter e with acute accent
      .AddEqualityGroup(Value("\u00e9a"))
      .AddEqualityGroup(Value(Timestamp::FromTimePoint(kDate1)),
                        Value(kTimestamp1))
      .AddEqualityGroup(Value(Timestamp::FromTimePoint(kDate2)),
                        Value(kTimestamp2))
      // NOTE: ServerTimestampValues can't be parsed via Value().
      .AddEqualityGroup(FieldValue::FromServerTimestamp(kTimestamp1),
                        FieldValue::FromServerTimestamp(kTimestamp1))
      .AddEqualityGroup(FieldValue::FromServerTimestamp(kTimestamp2))
      .AddEqualityGroup(Value(GeoPoint(0, 1)),
                        FieldValue::FromGeoPoint(GeoPoint(0, 1)))
      .AddEqualityGroup(Value(GeoPoint(1, 0)))
      .AddEqualityGroup(FieldValue::FromReference(DbId(), Key("coll/doc1")),
                        FieldValue::FromReference(DbId(), Key("coll/doc1")))
      .AddEqualityGroup(
          FieldValue::FromReference(DbId("project/bar"), Key("coll/doc2")))
      .AddEqualityGroup(
          FieldValue::FromReference(DbId("project/baz"), Key("coll/doc2")))
      .AddEqualityGroup(Array("foo", "bar"), Array("foo", "bar"))
      .AddEqualityGroup(Array("foo", "bar", "baz"))
      .AddEqualityGroup(Array("foo"))
      .AddEqualityGroup(WrapObject("bar", 1, "foo", 2),
                        WrapObject("foo", 2, "bar", 1))
      .AddEqualityGroup(WrapObject("bar", 2, "foo", 1))
      .AddEqualityGroup(WrapObject("bar", 1))
      .AddEqualityGroup(WrapObject("foo", 1))
      .TestEquals();
}

#if __APPLE__
// Validates that NSNumber/CFNumber normalize NaNs to the same values that
// Firestore does. This uses CoreFoundation's CFNumber instead of NSNumber just
// to keep the test in a single file.
TEST_F(FieldValueTest, CanonicalBitsAreCanonical) {
  double input = ToDouble(kAlternateNanBits);
  CFNumberRef number = CFNumberCreate(nullptr, kCFNumberDoubleType, &input);
  util::Defer cleanup([&] { util::SafeCFRelease(number); });

  double actual = 0.0;
  CFNumberGetValue(number, kCFNumberDoubleType, &actual);

  ASSERT_EQ(kCanonicalNanBits, ToBits(actual));
}
#endif  // __APPLE__

TEST_F(FieldValueTest, NormalizesNaNs) {
  // NOTE: With v1 query semantics, it's no longer as important that our NaN
  // representation matches the backend, since all NaNs are defined to sort as
  // equal, but we preserve the normalization and this test regardless for now.

  // Bedrock assumption: our canonical NaN bits are actually a NaN.
  double canonical = ToDouble(kCanonicalNanBits);
  double alternate = ToDouble(kAlternateNanBits);
  ASSERT_THAT(canonical, IsNan());
  ASSERT_THAT(alternate, IsNan());
  ASSERT_THAT(0.0, Not(IsNan()));

  // Round trip otherwise preserves NaNs
  EXPECT_EQ(kAlternateNanBits, ToBits(alternate));
  EXPECT_NE(kCanonicalNanBits, ToBits(alternate));

  // Creating a FieldValue from a double should normalize NaNs.
  auto Normalize = [](uint64_t bits) -> uint64_t {
    double value = ToDouble(bits);
    double normalized = FieldValue::FromDouble(value).double_value();
    return ToBits(normalized);
  };

  EXPECT_EQ(kCanonicalNanBits, Normalize(kAlternateNanBits));

  // A NaN that's canonical except it has the sign bit set (would be negative if
  // signs mattered)
  EXPECT_EQ(kCanonicalNanBits, Normalize(0xfff8000000000000ULL));

  // A signaling NaN with significand where MSB is 0, and some non-MSB bit is
  // one.
  EXPECT_EQ(kCanonicalNanBits, Normalize(0xfff4000000000000ULL));
}

TEST_F(FieldValueTest, ToString) {
  EXPECT_EQ("null", FieldValue::Null().ToString());
  EXPECT_EQ("nan", FieldValue::Nan().ToString());
  EXPECT_EQ("true", FieldValue::True().ToString());
  EXPECT_EQ("false", FieldValue::False().ToString());

  EXPECT_EQ("-1234", FieldValue::FromInteger(-1234).ToString());
  EXPECT_EQ("0", FieldValue::FromInteger(0).ToString());

  EXPECT_EQ("-0", FieldValue::FromDouble(-0.0).ToString());
  EXPECT_EQ("0", FieldValue::FromDouble(0.0).ToString());
  EXPECT_EQ("0.5", FieldValue::FromDouble(0.5).ToString());
  EXPECT_EQ("1e+10", FieldValue::FromDouble(1.0E10).ToString());

  EXPECT_EQ("Timestamp(seconds=12, nanoseconds=42)",
            FieldValue::FromTimestamp(Timestamp(12, 42)).ToString());

  EXPECT_EQ(
      "ServerTimestamp(local_write_time=Timestamp(seconds=12, "
      "nanoseconds=42))",
      FieldValue::FromServerTimestamp(Timestamp(12, 42)).ToString());

  EXPECT_EQ("", FieldValue::FromString("").ToString());
  EXPECT_EQ("foo", FieldValue::FromString("foo").ToString());

  // Bytes escaped as hex
  auto blob = FieldValue::FromBlob(ByteString("HI"));
  EXPECT_EQ("HI", blob.ToString());

  auto ref = FieldValue::FromReference(DatabaseId("p", "d"), Key("foo/bar"));
  EXPECT_EQ("Reference(key=foo/bar)", ref.ToString());

  auto geo_point = FieldValue::FromGeoPoint(GeoPoint(41.8781, -87.6298));
  EXPECT_EQ("GeoPoint(latitude=41.8781, longitude=-87.6298)",
            geo_point.ToString());

  auto array =
      FieldValue::FromArray({FieldValue::Null(), FieldValue::FromString("foo"),
                             FieldValue::FromInteger(42)});
  EXPECT_EQ("[null, foo, 42]", array.ToString());

  auto object = FieldValue::FromMap({{"key1", FieldValue::FromString("value")},
                                     {"key2", FieldValue::FromInteger(42)}});
  EXPECT_EQ("{key1: value, key2: 42}", object.ToString());
}

TEST_F(FieldValueTest, NullType) {
  const FieldValue value = FieldValue::Null();
  EXPECT_EQ(Type::Null, value.type());
  EXPECT_FALSE(value < value);
}

TEST_F(FieldValueTest, BooleanType) {
  const FieldValue true_value = FieldValue::FromBoolean(true);
  const FieldValue false_value = FieldValue::FromBoolean(false);
  EXPECT_EQ(Type::Boolean, true_value.type());
  EXPECT_FALSE(true_value < true_value);
  EXPECT_FALSE(true_value < false_value);
  EXPECT_FALSE(false_value < false_value);
  EXPECT_TRUE(false_value < true_value);
}

TEST_F(FieldValueTest, NumberType) {
  const FieldValue nan_value = FieldValue::Nan();
  const FieldValue integer_value = FieldValue::FromInteger(10L);
  const FieldValue double_value = FieldValue::FromDouble(10.1);
  EXPECT_EQ(Type::Double, nan_value.type());
  EXPECT_EQ(Type::Integer, integer_value.type());
  EXPECT_EQ(Type::Double, double_value.type());
  EXPECT_TRUE(nan_value < integer_value);
  EXPECT_TRUE(nan_value < double_value);
  EXPECT_FALSE(nan_value < nan_value);
  EXPECT_FALSE(integer_value < nan_value);
  EXPECT_FALSE(integer_value < nan_value);
  EXPECT_TRUE(integer_value < double_value);  // 10 < 10.1
  EXPECT_FALSE(double_value < integer_value);
  EXPECT_FALSE(integer_value < integer_value);
  EXPECT_FALSE(double_value < double_value);

  // Number comparison craziness
  // Integers
  EXPECT_TRUE(FieldValue::FromInteger(1L) < FieldValue::FromInteger(2L));
  EXPECT_FALSE(FieldValue::FromInteger(1L) < FieldValue::FromInteger(1L));
  EXPECT_FALSE(FieldValue::FromInteger(2L) < FieldValue::FromInteger(1L));
  // Doubles
  EXPECT_TRUE(FieldValue::FromDouble(1.0) < FieldValue::FromDouble(2.0));
  EXPECT_FALSE(FieldValue::FromDouble(1.0) < FieldValue::FromDouble(1.0));
  EXPECT_FALSE(FieldValue::FromDouble(2.0) < FieldValue::FromDouble(1.0));
  EXPECT_TRUE(FieldValue::Nan() < FieldValue::FromDouble(1.0));
  EXPECT_FALSE(FieldValue::Nan() < FieldValue::Nan());
  EXPECT_FALSE(FieldValue::FromDouble(1.0) < FieldValue::Nan());
  // Mixed
  EXPECT_TRUE(FieldValue::FromDouble(-1e20) <
              FieldValue::FromInteger(LLONG_MIN));
  EXPECT_FALSE(FieldValue::FromDouble(1e20) <
               FieldValue::FromInteger(LLONG_MAX));
  EXPECT_TRUE(FieldValue::FromDouble(1.234) < FieldValue::FromInteger(2L));
  EXPECT_FALSE(FieldValue::FromDouble(2.345) < FieldValue::FromInteger(1L));
  EXPECT_FALSE(FieldValue::FromDouble(1.0) < FieldValue::FromInteger(1L));
  EXPECT_FALSE(FieldValue::FromDouble(1.234) < FieldValue::FromInteger(1L));
  EXPECT_FALSE(FieldValue::FromInteger(LLONG_MIN) <
               FieldValue::FromDouble(-1e20));
  EXPECT_TRUE(FieldValue::FromInteger(LLONG_MAX) <
              FieldValue::FromDouble(1e20));
  EXPECT_FALSE(FieldValue::FromInteger(1) < FieldValue::FromDouble(1.0));
  EXPECT_TRUE(FieldValue::FromInteger(1) < FieldValue::FromDouble(1.234));
}

TEST_F(FieldValueTest, TimestampType) {
  const FieldValue o = FieldValue::FromTimestamp(Timestamp());
  const FieldValue a = FieldValue::FromTimestamp({100, 0});
  const FieldValue b = FieldValue::FromTimestamp({200, 0});
  EXPECT_EQ(Type::Timestamp, a.type());
  EXPECT_TRUE(o < a);
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
  const FieldValue c = FromServerTimestamp({100, 0});
  const FieldValue d =
      FromServerTimestamp({200, 0}, FieldValue::FromTimestamp({300, 0}));
  EXPECT_EQ(Type::ServerTimestamp, c.type());
  EXPECT_EQ(Type::ServerTimestamp, d.type());
  EXPECT_TRUE(c < d);
  EXPECT_FALSE(c < c);
  // Mixed
  EXPECT_TRUE(o < c);
  EXPECT_TRUE(a < c);
  EXPECT_TRUE(b < c);
  EXPECT_TRUE(b < d);
  EXPECT_FALSE(c < o);
  EXPECT_FALSE(c < a);
  EXPECT_FALSE(c < b);
  EXPECT_FALSE(d < b);
}

TEST_F(FieldValueTest, StringType) {
  const FieldValue a = FieldValue::FromString("abc");
  std::string xyz("xyz");
  const FieldValue b = FieldValue::FromString(xyz);
  const FieldValue c = FieldValue::FromString(std::move(xyz));
  EXPECT_EQ(Type::String, a.type());
  EXPECT_EQ(Type::String, b.type());
  EXPECT_EQ(Type::String, c.type());
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
}

TEST_F(FieldValueTest, BlobType) {
  const FieldValue a = FieldValue::FromBlob(ByteString("abc"));
  const FieldValue b = FieldValue::FromBlob(ByteString("def"));
  EXPECT_EQ(Type::Blob, a.type());
  EXPECT_EQ(Type::Blob, b.type());
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
}

TEST_F(FieldValueTest, ReferenceType) {
  DatabaseId id("project", "database");
  FieldValue a = FieldValue::FromReference(id, Key("root/abc"));
  DocumentKey key = Key("root/def");
  FieldValue b = FieldValue::FromReference(id, key);
  FieldValue c = FieldValue::FromReference(id, std::move(key));
  EXPECT_EQ(Type::Reference, a.type());
  EXPECT_EQ(Type::Reference, b.type());
  EXPECT_EQ(Type::Reference, c.type());
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
}

TEST_F(FieldValueTest, GeoPointType) {
  const FieldValue a = FieldValue::FromGeoPoint({1, 2});
  const FieldValue b = FieldValue::FromGeoPoint({3, 4});
  EXPECT_EQ(Type::GeoPoint, a.type());
  EXPECT_EQ(Type::GeoPoint, b.type());
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
}

TEST_F(FieldValueTest, ArrayType) {
  const FieldValue empty = FieldValue::FromArray(std::vector<FieldValue>{});
  std::vector<FieldValue> array{FieldValue::Null(),
                                FieldValue::FromBoolean(true),
                                FieldValue::FromBoolean(false)};
  // copy the array
  const FieldValue small = FieldValue::FromArray(array);
  std::vector<FieldValue> another_array{FieldValue::FromBoolean(true),
                                        FieldValue::FromBoolean(false)};
  // move the array
  const FieldValue large = FieldValue::FromArray(std::move(another_array));
  EXPECT_EQ(Type::Array, empty.type());
  EXPECT_EQ(Type::Array, small.type());
  EXPECT_EQ(Type::Array, large.type());
  EXPECT_TRUE(empty < small);
  EXPECT_FALSE(small < empty);
  EXPECT_FALSE(small < small);
  EXPECT_TRUE(small < large);
  EXPECT_FALSE(large < small);
}

TEST_F(FieldValueTest, ObjectType) {
  const ObjectValue empty = ObjectValue::Empty();
  FieldValue::Map object{{"null", FieldValue::Null()},
                         {"true", FieldValue::True()},
                         {"false", FieldValue::False()}};
  // copy the map
  const ObjectValue small = ObjectValue::FromMap(object);
  FieldValue::Map another_object{{"null", FieldValue::Null()},
                                 {"true", FieldValue::False()}};
  // move the array
  const ObjectValue large = ObjectValue::FromMap(std::move(another_object));
  EXPECT_TRUE(empty < small);
  EXPECT_FALSE(small < empty);
  EXPECT_FALSE(small < small);
  EXPECT_TRUE(small < large);
  EXPECT_FALSE(large < small);
}

TEST_F(FieldValueTest, Copy) {
  FieldValue clone = FieldValue::True();
  const FieldValue null_value = FieldValue::Null();
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);
  EXPECT_EQ(FieldValue::Null(), null_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue true_value = FieldValue::True();
  clone = true_value;
  EXPECT_EQ(FieldValue::True(), clone);
  EXPECT_EQ(FieldValue::True(), true_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::True(), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue nan_value = FieldValue::Nan();
  clone = nan_value;
  EXPECT_EQ(FieldValue::Nan(), clone);
  EXPECT_EQ(FieldValue::Nan(), nan_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::Nan(), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue integer_value = FieldValue::FromInteger(1L);
  clone = integer_value;
  EXPECT_EQ(FieldValue::FromInteger(1L), clone);
  EXPECT_EQ(FieldValue::FromInteger(1L), integer_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromInteger(1L), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue double_value = FieldValue::FromDouble(1.0);
  clone = double_value;
  EXPECT_EQ(FieldValue::FromDouble(1.0), clone);
  EXPECT_EQ(FieldValue::FromDouble(1.0), double_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromDouble(1.0), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue timestamp_value = FieldValue::FromTimestamp({100, 200});
  clone = timestamp_value;
  EXPECT_EQ(FieldValue::FromTimestamp({100, 200}), clone);
  EXPECT_EQ(FieldValue::FromTimestamp({100, 200}), timestamp_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromTimestamp({100, 200}), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue server_timestamp_value =
      FromServerTimestamp({1, 2}, FieldValue::FromTimestamp({3, 4}));
  clone = server_timestamp_value;
  EXPECT_EQ(FromServerTimestamp({1, 2}, FieldValue::FromTimestamp({3, 4})),
            clone);
  EXPECT_EQ(FromServerTimestamp({1, 2}, FieldValue::FromTimestamp({3, 4})),
            server_timestamp_value);
  clone = *&clone;
  EXPECT_EQ(FromServerTimestamp({1, 2}, FieldValue::FromTimestamp({3, 4})),
            clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue string_value = FieldValue::FromString("abc");
  clone = string_value;
  EXPECT_EQ(FieldValue::FromString("abc"), clone);
  EXPECT_EQ(FieldValue::FromString("abc"), string_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromString("abc"), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue blob_value = FieldValue::FromBlob(ByteString("abc"));
  clone = blob_value;
  EXPECT_EQ(FieldValue::FromBlob(ByteString("abc")), clone);
  EXPECT_EQ(FieldValue::FromBlob(ByteString("abc")), blob_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromBlob(ByteString("abc")), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  DatabaseId database_id("project", "database");
  FieldValue reference_value =
      FieldValue::FromReference(database_id, Key("root/abc"));
  clone = reference_value;
  EXPECT_EQ(FieldValue::FromReference(database_id, Key("root/abc")), clone);
  EXPECT_EQ(FieldValue::FromReference(database_id, Key("root/abc")),
            reference_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromReference(database_id, Key("root/abc")), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue geo_point_value = FieldValue::FromGeoPoint({1, 2});
  clone = geo_point_value;
  EXPECT_EQ(FieldValue::FromGeoPoint({1, 2}), clone);
  EXPECT_EQ(FieldValue::FromGeoPoint({1, 2}), geo_point_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromGeoPoint({1, 2}), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue array_value = FieldValue::FromArray(
      std::vector<FieldValue>{FieldValue::True(), FieldValue::False()});
  clone = array_value;
  EXPECT_EQ(FieldValue::FromArray(std::vector<FieldValue>{FieldValue::True(),
                                                          FieldValue::False()}),
            clone);
  EXPECT_EQ(FieldValue::FromArray(std::vector<FieldValue>{FieldValue::True(),
                                                          FieldValue::False()}),
            array_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromArray(std::vector<FieldValue>{FieldValue::True(),
                                                          FieldValue::False()}),
            clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);

  const FieldValue object_value = FieldValue::FromMap(
      {{"true", FieldValue::True()}, {"false", FieldValue::False()}});
  clone = object_value;
  EXPECT_EQ(FieldValue::FromMap(
                {{"true", FieldValue::True()}, {"false", FieldValue::False()}}),
            clone);
  EXPECT_EQ(FieldValue::FromMap(
                {{"true", FieldValue::True()}, {"false", FieldValue::False()}}),
            object_value);
  clone = *&clone;
  EXPECT_EQ(FieldValue::FromMap(
                {{"true", FieldValue::True()}, {"false", FieldValue::False()}}),
            clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::Null(), clone);
}

TEST_F(FieldValueTest, CompareMixedType) {
  const FieldValue null_value = FieldValue::Null();
  const FieldValue true_value = FieldValue::True();
  const FieldValue number_value = FieldValue::Nan();
  const FieldValue timestamp_value = FieldValue::FromTimestamp({100, 200});
  const FieldValue string_value = FieldValue::FromString("abc");
  const FieldValue blob_value = FieldValue::FromBlob(ByteString("abc"));
  const DatabaseId database_id("project", "database");
  const FieldValue reference_value =
      FieldValue::FromReference(database_id, Key("root/abc"));
  const FieldValue geo_point_value = FieldValue::FromGeoPoint({1, 2});
  const FieldValue array_value =
      FieldValue::FromArray(std::vector<FieldValue>());
  const FieldValue object_value = FieldValue::EmptyObject();
  EXPECT_TRUE(null_value < true_value);
  EXPECT_TRUE(true_value < number_value);
  EXPECT_TRUE(number_value < timestamp_value);
  EXPECT_TRUE(timestamp_value < string_value);
  EXPECT_TRUE(string_value < blob_value);
  EXPECT_TRUE(blob_value < reference_value);
  EXPECT_TRUE(reference_value < geo_point_value);
  EXPECT_TRUE(geo_point_value < array_value);
  EXPECT_TRUE(array_value < object_value);
}

TEST_F(FieldValueTest, CompareWithOperator) {
  const FieldValue small = FieldValue::Null();
  const FieldValue large = FieldValue::True();

  EXPECT_TRUE(small < large);
  EXPECT_FALSE(small < small);
  EXPECT_FALSE(large < small);

  EXPECT_TRUE(large > small);
  EXPECT_FALSE(small > small);
  EXPECT_FALSE(small > large);

  EXPECT_TRUE(large >= small);
  EXPECT_TRUE(small >= small);
  EXPECT_FALSE(small >= large);

  EXPECT_TRUE(small <= large);
  EXPECT_TRUE(small <= small);
  EXPECT_FALSE(large <= small);

  EXPECT_TRUE(small != large);
  EXPECT_FALSE(small != small);

  EXPECT_TRUE(small == small);
  EXPECT_FALSE(small == large);
}

TEST_F(FieldValueTest, IsSmallish) {
  // We expect the FV to use 4 bytes to track the type of the union, plus 8
  // bytes for the union contents themselves. The other 4 is for padding. We
  // want to keep FV as small as possible.
  EXPECT_LE(sizeof(FieldValue), 2 * sizeof(int64_t));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
