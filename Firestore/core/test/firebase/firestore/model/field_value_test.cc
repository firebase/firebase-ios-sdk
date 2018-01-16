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

#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using Type = FieldValue::Type;

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

TEST(FieldValue, ArrayType) {
  const FieldValue empty =
      FieldValue::ArrayValue(std::vector<const FieldValue>{});
  std::vector<const FieldValue> array{FieldValue::NullValue(),
                                      FieldValue::BooleanValue(true),
                                      FieldValue::BooleanValue(false)};
  // copy the array
  const FieldValue small = FieldValue::ArrayValue(array);
  std::vector<const FieldValue> another_array{FieldValue::BooleanValue(true),
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

  const FieldValue array_value =
      FieldValue::ArrayValue(std::vector<const FieldValue>{
          FieldValue::TrueValue(), FieldValue::FalseValue()});
  clone = array_value;
  EXPECT_EQ(FieldValue::ArrayValue(std::vector<const FieldValue>{
                FieldValue::TrueValue(), FieldValue::FalseValue()}),
            clone);
  EXPECT_EQ(FieldValue::ArrayValue(std::vector<const FieldValue>{
                FieldValue::TrueValue(), FieldValue::FalseValue()}),
            array_value);
  clone = clone;
  EXPECT_EQ(FieldValue::ArrayValue(std::vector<const FieldValue>{
                FieldValue::TrueValue(), FieldValue::FalseValue()}),
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

  FieldValue array_value = FieldValue::ArrayValue(std::vector<const FieldValue>{
      FieldValue::TrueValue(), FieldValue::FalseValue()});
  clone = std::move(array_value);
  EXPECT_EQ(FieldValue::ArrayValue(std::vector<const FieldValue>{
                FieldValue::TrueValue(), FieldValue::FalseValue()}),
            clone);
  clone = FieldValue::NullValue();
  EXPECT_EQ(FieldValue::NullValue(), clone);
}

TEST(FieldValue, CompareMixedType) {
  const FieldValue null_value = FieldValue::NullValue();
  const FieldValue true_value = FieldValue::TrueValue();
  const FieldValue array_value =
      FieldValue::ArrayValue(std::vector<const FieldValue>());
  EXPECT_TRUE(null_value < true_value);
  EXPECT_TRUE(true_value < array_value);
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
