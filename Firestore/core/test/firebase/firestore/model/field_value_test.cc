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
  const FieldValue empty(std::vector<FieldValue>(0));
  std::vector<FieldValue> small_value_array = {
      FieldValue::NullValue(),
      FieldValue::BooleanValue(true),
      FieldValue::BooleanValue(false)
  };
  const FieldValue small(small_value_array);
  std::vector<FieldValue> large_value_array = {
      FieldValue::BooleanValue(true),
      FieldValue::BooleanValue(false)
  };
  const FieldValue large(large_value_array);
  EXPECT_EQ(Type::Array, empty.type());
  EXPECT_EQ(Type::Array, small.type());
  EXPECT_EQ(Type::Array, large.type());
  EXPECT_TRUE(empty < small);
  EXPECT_FALSE(small < empty);
  EXPECT_FALSE(small < small);
  EXPECT_TRUE(small < large);
  EXPECT_FALSE(large < small);
}

TEST(FieldValue, CompareMixedType) {
  const FieldValue null_value = FieldValue::NullValue();
  const FieldValue true_value = FieldValue::BooleanValue(true);
  const FieldValue array_value(std::vector<FieldValue>(0));
  EXPECT_TRUE(null_value < true_value);
  EXPECT_TRUE(true_value < array_value);
}

TEST(FieldValue, CompareWithOperator) {
  const FieldValue small = FieldValue::NullValue();
  const FieldValue large = FieldValue::BooleanValue(true);

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
