/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/model/field_value.h"

#include <climits>
#include <vector>

#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using Type = FieldValue::Type;

namespace {

const uint8_t* Bytes(const char* value) {
  return reinterpret_cast<const uint8_t*>(value);
}

}  // namespace

TEST(FieldValue, NullType) {
  const FieldValue value = FieldValue::NullValue();
  EXPECT_EQ(Type::Null, value.type());
  EXPECT_FALSE(value < value);
}

TEST(FieldValue, BooleanType) {
  const FieldValue true_value = FieldValue::BooleanValue(true);
  const FieldValue false_value = FieldValue::BooleanValue(false);
  EXPECT_EQ(Type::Boolean, true_value.type());
  EXPECT_FALSE(true_value < true_value);
  EXPECT_FALSE(true_value < false_value);
  EXPECT_FALSE(false_value < false_value);
  EXPECT_TRUE(false_value < true_value);
}

TEST(FieldValue, NumberType) {
  const FieldValue nan_value = FieldValue::NanValue();
  const FieldValue integer_value = FieldValue::IntegerValue(10L);
  const FieldValue double_value = FieldValue::DoubleValue(10.1);
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
  EXPECT_TRUE(FieldValue::IntegerValue(1L) < FieldValue::IntegerValue(2L));
  EXPECT_FALSE(FieldValue::IntegerValue(1L) < FieldValue::IntegerValue(1L));
  EXPECT_FALSE(FieldValue::IntegerValue(2L) < FieldValue::IntegerValue(1L));
  // Doubles
  EXPECT_TRUE(FieldValue::DoubleValue(1.0) < FieldValue::DoubleValue(2.0));
  EXPECT_FALSE(FieldValue::DoubleValue(1.0) < FieldValue::DoubleValue(1.0));
  EXPECT_FALSE(FieldValue::DoubleValue(2.0) < FieldValue::DoubleValue(1.0));
  EXPECT_TRUE(FieldValue::NanValue() < FieldValue::DoubleValue(1.0));
  EXPECT_FALSE(FieldValue::NanValue() < FieldValue::NanValue());
  EXPECT_FALSE(FieldValue::DoubleValue(1.0) < FieldValue::NanValue());
  // Mixed
  EXPECT_TRUE(FieldValue::DoubleValue(-1e20) <
              FieldValue::IntegerValue(LLONG_MIN));
  EXPECT_FALSE(FieldValue::DoubleValue(1e20) <
               FieldValue::IntegerValue(LLONG_MAX));
  EXPECT_TRUE(FieldValue::DoubleValue(1.234) < FieldValue::IntegerValue(2L));
  EXPECT_FALSE(FieldValue::DoubleValue(2.345) < FieldValue::IntegerValue(1L));
  EXPECT_FALSE(FieldValue::DoubleValue(1.0) < FieldValue::IntegerValue(1L));
  EXPECT_FALSE(FieldValue::DoubleValue(1.234) < FieldValue::IntegerValue(1L));
  EXPECT_FALSE(FieldValue::IntegerValue(LLONG_MIN) <
               FieldValue::DoubleValue(-1e20));
  EXPECT_TRUE(FieldValue::IntegerValue(LLONG_MAX) <
              FieldValue::DoubleValue(1e20));
  EXPECT_FALSE(FieldValue::IntegerValue(1) < FieldValue::DoubleValue(1.0));
  EXPECT_TRUE(FieldValue::IntegerValue(1) < FieldValue::DoubleValue(1.234));
}

TEST(FieldValue, TimestampType) {
  const FieldValue o = FieldValue::TimestampValue(Timestamp());
  const FieldValue a = FieldValue::TimestampValue({100, 0});
  const FieldValue b = FieldValue::TimestampValue({200, 0});
  EXPECT_EQ(Type::Timestamp, a.type());
  EXPECT_TRUE(o < a);
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
  const FieldValue c = FieldValue::ServerTimestampValue({100, 0});
  const FieldValue d = FieldValue::ServerTimestampValue({200, 0}, {300, 0});
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

TEST(FieldValue, StringType) {
  const FieldValue a = FieldValue::StringValue("abc");
  std::string xyz("xyz");
  const FieldValue b = FieldValue::StringValue(xyz);
  const FieldValue c = FieldValue::StringValue(std::move(xyz));
  EXPECT_EQ(Type::String, a.type());
  EXPECT_EQ(Type::String, b.type());
  EXPECT_EQ(Type::String, c.type());
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
}

TEST(FieldValue, BlobType) {
  const FieldValue a = FieldValue::BlobValue(Bytes("abc"), 4);
  const FieldValue b = FieldValue::BlobValue(Bytes("def"), 4);
  EXPECT_EQ(Type::Blob, a.type());
  EXPECT_EQ(Type::Blob, b.type());
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
}

TEST(FieldValue, ReferenceType) {
  const DatabaseId id("project", "database");
  const FieldValue a =
      FieldValue::ReferenceValue(DocumentKey::FromPathString("root/abc"), &id);
  DocumentKey key = DocumentKey::FromPathString("root/def");
  const FieldValue b = FieldValue::ReferenceValue(key, &id);
  const FieldValue c = FieldValue::ReferenceValue(std::move(key), &id);
  EXPECT_EQ(Type::Reference, a.type());
  EXPECT_EQ(Type::Reference, b.type());
  EXPECT_EQ(Type::Reference, c.type());
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
}

TEST(FieldValue, GeoPointType) {
  const FieldValue a = FieldValue::GeoPointValue({1, 2});
  const FieldValue b = FieldValue::GeoPointValue({3, 4});
  EXPECT_EQ(Type::GeoPoint, a.type());
  EXPECT_EQ(Type::GeoPoint, b.type());
  EXPECT_TRUE(a < b);
  EXPECT_FALSE(a < a);
}

TEST(FieldValue, ArrayType) {
  const FieldValue empty = FieldValue::ArrayValue(std::vector<FieldValue>{});
  std::vector<FieldValue> array{FieldValue::NullValue(),
                                FieldValue::BooleanValue(true),
                                FieldValue::BooleanValue(false)};
  // copy the array
  const FieldValue small = FieldValue::ArrayValue(array);
  std::vector<FieldValue> another_array{FieldValue::BooleanValue(true),
                                        FieldValue::BooleanValue(false)};
  // move the array
  const FieldValue large = FieldValue::ArrayValue(std::move(another_array));
  EXPECT_EQ(Type::Array, empty.type());
  EXPECT_EQ(Type::Array, small.type());
  EXPECT_EQ(Type::Array, large.type());
  EXPECT_TRUE(empty < small);
  EXPECT_FALSE(small < empty);
  EXPECT_FALSE(small < small);
  EXPECT_TRUE(small < large);
  EXPECT_FALSE(large < small);
}

TEST(FieldValue, ObjectType) {
  const FieldValue empty = FieldValue::ObjectValueFromMap({});
  ObjectValue::Map object{{"null", FieldValue::NullValue()},
                          {"true", FieldValue::TrueValue()},
                          {"false", FieldValue::FalseValue()}};
  // copy the map
  const FieldValue small = FieldValue::ObjectValueFromMap(object);
  ObjectValue::Map another_object{{"null", FieldValue::NullValue()},
                                  {"true", FieldValue::FalseValue()}};
  // move the array
  const FieldValue large =
      FieldValue::ObjectValueFromMap(std::move(another_object));
  EXPECT_EQ(Type::Object, empty.type());
  EXPECT_EQ(Type::Object, small.type());
  EXPECT_EQ(Type::Object, large.type());
  EXPECT_TRUE(empty < small);
  EXPECT_FALSE(small < empty);
  EXPECT_FALSE(small < small);
  EXPECT_TRUE(small < large);
  EXPECT_FALSE(large < small);
}

}  //  namespace model
}  //  namespace firestore
}  //  namespace firebase
