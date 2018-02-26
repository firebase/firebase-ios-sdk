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

#include <limits.h>

#include <vector>

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
  const FieldValue empty =
      FieldValue::ObjectValue(std::map<const std::string, const FieldValue>{});
  std::map<const std::string, const FieldValue> object{
      {"null", FieldValue::NullValue()},
      {"true", FieldValue::TrueValue()},
      {"false", FieldValue::FalseValue()}};
  // copy the map
  const FieldValue small = FieldValue::ObjectValue(object);
  std::map<const std::string, const FieldValue> another_object{
      {"null", FieldValue::NullValue()}, {"true", FieldValue::FalseValue()}};
  // move the array
  const FieldValue large = FieldValue::ObjectValue(std::move(another_object));
  EXPECT_EQ(Type::Object, empty.type());
  EXPECT_EQ(Type::Object, small.type());
  EXPECT_EQ(Type::Object, large.type());
  EXPECT_TRUE(empty < small);
  EXPECT_FALSE(small < empty);
  EXPECT_FALSE(small < small);
  EXPECT_TRUE(small < large);
  EXPECT_FALSE(large < small);
}

TEST(FieldValue, Copy) {
  FieldValue clone = FieldValue::TrueValue();
  const FieldValue null_value = FieldValue::NullValue();
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);
  EXPECT_EQ(FieldValue::NullValue(), null_value);
  clone = clone;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue true_value = FieldValue::TrueValue();
  clone = true_value;
  EXPECT_EQ(FieldValue::TrueValue(), clone);
  EXPECT_EQ(FieldValue::TrueValue(), true_value);
  clone = clone;
  EXPECT_EQ(FieldValue::TrueValue(), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue nan_value = FieldValue::NanValue();
  clone = nan_value;
  EXPECT_EQ(FieldValue::NanValue(), clone);
  EXPECT_EQ(FieldValue::NanValue(), nan_value);
  clone = clone;
  EXPECT_EQ(FieldValue::NanValue(), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue integer_value = FieldValue::IntegerValue(1L);
  clone = integer_value;
  EXPECT_EQ(FieldValue::IntegerValue(1L), clone);
  EXPECT_EQ(FieldValue::IntegerValue(1L), integer_value);
  clone = clone;
  EXPECT_EQ(FieldValue::IntegerValue(1L), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue double_value = FieldValue::DoubleValue(1.0);
  clone = double_value;
  EXPECT_EQ(FieldValue::DoubleValue(1.0), clone);
  EXPECT_EQ(FieldValue::DoubleValue(1.0), double_value);
  clone = clone;
  EXPECT_EQ(FieldValue::DoubleValue(1.0), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue timestamp_value = FieldValue::TimestampValue({100, 200});
  clone = timestamp_value;
  EXPECT_EQ(FieldValue::TimestampValue({100, 200}), clone);
  EXPECT_EQ(FieldValue::TimestampValue({100, 200}), timestamp_value);
  clone = clone;
  EXPECT_EQ(FieldValue::TimestampValue({100, 200}), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue server_timestamp_value =
      FieldValue::ServerTimestampValue({1, 2}, {3, 4});
  clone = server_timestamp_value;
  EXPECT_EQ(FieldValue::ServerTimestampValue({1, 2}, {3, 4}), clone);
  EXPECT_EQ(FieldValue::ServerTimestampValue({1, 2}, {3, 4}),
            server_timestamp_value);
  clone = clone;
  EXPECT_EQ(FieldValue::ServerTimestampValue({1, 2}, {3, 4}), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue string_value = FieldValue::StringValue("abc");
  clone = string_value;
  EXPECT_EQ(FieldValue::StringValue("abc"), clone);
  EXPECT_EQ(FieldValue::StringValue("abc"), string_value);
  clone = clone;
  EXPECT_EQ(FieldValue::StringValue("abc"), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue blob_value = FieldValue::BlobValue(Bytes("abc"), 4);
  clone = blob_value;
  EXPECT_EQ(FieldValue::BlobValue(Bytes("abc"), 4), clone);
  EXPECT_EQ(FieldValue::BlobValue(Bytes("abc"), 4), blob_value);
  clone = clone;
  EXPECT_EQ(FieldValue::BlobValue(Bytes("abc"), 4), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const DatabaseId database_id("project", "database");
  const FieldValue reference_value = FieldValue::ReferenceValue(
      DocumentKey::FromPathString("root/abc"), &database_id);
  clone = reference_value;
  EXPECT_EQ(FieldValue::ReferenceValue(DocumentKey::FromPathString("root/abc"),
                                       &database_id),
            clone);
  EXPECT_EQ(FieldValue::ReferenceValue(DocumentKey::FromPathString("root/abc"),
                                       &database_id),
            reference_value);
  clone = clone;
  EXPECT_EQ(FieldValue::ReferenceValue(DocumentKey::FromPathString("root/abc"),
                                       &database_id),
            clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue geo_point_value = FieldValue::GeoPointValue({1, 2});
  clone = geo_point_value;
  EXPECT_EQ(FieldValue::GeoPointValue({1, 2}), clone);
  EXPECT_EQ(FieldValue::GeoPointValue({1, 2}), geo_point_value);
  clone = clone;
  EXPECT_EQ(FieldValue::GeoPointValue({1, 2}), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue array_value = FieldValue::ArrayValue(std::vector<FieldValue>{
      FieldValue::TrueValue(), FieldValue::FalseValue()});
  clone = array_value;
  EXPECT_EQ(FieldValue::ArrayValue(std::vector<FieldValue>{
                FieldValue::TrueValue(), FieldValue::FalseValue()}),
            clone);
  EXPECT_EQ(FieldValue::ArrayValue(std::vector<FieldValue>{
                FieldValue::TrueValue(), FieldValue::FalseValue()}),
            array_value);
  clone = clone;
  EXPECT_EQ(FieldValue::ArrayValue(std::vector<FieldValue>{
                FieldValue::TrueValue(), FieldValue::FalseValue()}),
            clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const FieldValue object_value =
      FieldValue::ObjectValue(std::map<const std::string, const FieldValue>{
          {"true", FieldValue::TrueValue()},
          {"false", FieldValue::FalseValue()}});
  clone = object_value;
  EXPECT_EQ(
      FieldValue::ObjectValue(std::map<const std::string, const FieldValue>{
          {"true", FieldValue::TrueValue()},
          {"false", FieldValue::FalseValue()}}),
      clone);
  EXPECT_EQ(
      FieldValue::ObjectValue(std::map<const std::string, const FieldValue>{
          {"true", FieldValue::TrueValue()},
          {"false", FieldValue::FalseValue()}}),
      object_value);
  clone = clone;
  EXPECT_EQ(
      FieldValue::ObjectValue(std::map<const std::string, const FieldValue>{
          {"true", FieldValue::TrueValue()},
          {"false", FieldValue::FalseValue()}}),
      clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);
}

TEST(FieldValue, Move) {
  FieldValue clone = FieldValue::TrueValue();

  FieldValue null_value = FieldValue::NullValue();
  clone = std::move(null_value);
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue true_value = FieldValue::TrueValue();
  clone = std::move(true_value);
  EXPECT_EQ(FieldValue::TrueValue(), clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue nan_value = FieldValue::NanValue();
  clone = std::move(nan_value);
  EXPECT_EQ(FieldValue::NanValue(), clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue integer_value = FieldValue::IntegerValue(1L);
  clone = std::move(integer_value);
  EXPECT_EQ(FieldValue::IntegerValue(1L), clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue double_value = FieldValue::DoubleValue(1.0);
  clone = std::move(double_value);
  EXPECT_EQ(FieldValue::DoubleValue(1.0), clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue timestamp_value = FieldValue::TimestampValue({100, 200});
  clone = std::move(timestamp_value);
  EXPECT_EQ(FieldValue::TimestampValue({100, 200}), clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue string_value = FieldValue::StringValue("abc");
  clone = std::move(string_value);
  EXPECT_EQ(FieldValue::StringValue("abc"), clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue blob_value = FieldValue::BlobValue(Bytes("abc"), 4);
  clone = std::move(blob_value);
  EXPECT_EQ(FieldValue::BlobValue(Bytes("abc"), 4), clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);

  const DatabaseId database_id("project", "database");
  FieldValue reference_value = FieldValue::ReferenceValue(
      DocumentKey::FromPathString("root/abc"), &database_id);
  clone = std::move(reference_value);
  EXPECT_EQ(FieldValue::ReferenceValue(DocumentKey::FromPathString("root/abc"),
                                       &database_id),
            clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue geo_point_value = FieldValue::GeoPointValue({1, 2});
  clone = std::move(geo_point_value);
  EXPECT_EQ(FieldValue::GeoPointValue({1, 2}), clone);
  clone = null_value;
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue array_value = FieldValue::ArrayValue(std::vector<FieldValue>{
      FieldValue::TrueValue(), FieldValue::FalseValue()});
  clone = std::move(array_value);
  EXPECT_EQ(FieldValue::ArrayValue(std::vector<FieldValue>{
                FieldValue::TrueValue(), FieldValue::FalseValue()}),
            clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);

  FieldValue object_value =
      FieldValue::ObjectValue(std::map<const std::string, const FieldValue>{
          {"true", FieldValue::TrueValue()},
          {"false", FieldValue::FalseValue()}});
  clone = std::move(object_value);
  EXPECT_EQ(
      FieldValue::ObjectValue(std::map<const std::string, const FieldValue>{
          {"true", FieldValue::TrueValue()},
          {"false", FieldValue::FalseValue()}}),
      clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);
}

TEST(FieldValue, CompareMixedType) {
  const FieldValue null_value = FieldValue::NullValue();
  const FieldValue true_value = FieldValue::TrueValue();
  const FieldValue number_value = FieldValue::NanValue();
  const FieldValue timestamp_value = FieldValue::TimestampValue({100, 200});
  const FieldValue string_value = FieldValue::StringValue("abc");
  const FieldValue blob_value = FieldValue::BlobValue(Bytes("abc"), 4);
  const DatabaseId database_id("project", "database");
  const FieldValue reference_value = FieldValue::ReferenceValue(
      DocumentKey::FromPathString("root/abc"), &database_id);
  const FieldValue geo_point_value = FieldValue::GeoPointValue({1, 2});
  const FieldValue array_value =
      FieldValue::ArrayValue(std::vector<FieldValue>());
  const FieldValue object_value =
      FieldValue::ObjectValue(std::map<const std::string, const FieldValue>());
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

TEST(FieldValue, CompareWithOperator) {
  const FieldValue small = FieldValue::NullValue();
  const FieldValue large = FieldValue::TrueValue();

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

}  //  namespace model
}  //  namespace firestore
}  //  namespace firebase
