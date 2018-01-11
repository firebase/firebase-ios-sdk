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

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(FieldValue, NullType) {
  NullValue null_value;
  NullValue another_null;
  FieldValue value(null_value);
  EXPECT_EQ(FieldValue::TypeOrder::Null, value.type_order());
  EXPECT_EQ(FieldValue::Type::Null, value.type());
  EXPECT_EQ(0, Compare(null_value, another_null));
}

TEST(FieldValue, BooleanType) {
  BooleanValue true_value(true);
  BooleanValue another_true(true);
  BooleanValue false_value(false);
  BooleanValue another_false(false);
  FieldValue value(true_value);
  EXPECT_EQ(FieldValue::TypeOrder::Boolean, value.type_order());
  EXPECT_EQ(FieldValue::Type::Boolean, value.type());
  EXPECT_EQ(0, Compare(true_value, another_true));
  EXPECT_EQ(0, Compare(false_value, another_false));
  EXPECT_EQ(1, Compare(true_value, false_value));
  EXPECT_EQ(-1, Compare(false_value, true_value));
}

TEST(FieldValue, CompareMixedType) {
  FieldValue null_value;
  FieldValue true_value(BooleanValue(true));
  EXPECT_EQ(-1, Compare(null_value, true_value));
  EXPECT_EQ(1, Compare(true_value, null_value));
}

TEST(FieldValue, CompareWithOperator) {
  FieldValue small;
  FieldValue large(BooleanValue(true));

  EXPECT_TRUE(small < large);
  EXPECT_FALSE(small < small);
  EXPECT_FALSE(large < small);

  EXPECT_TRUE(small <= large);
  EXPECT_TRUE(small <= small);
  EXPECT_FALSE(large <= small);

  EXPECT_TRUE(small == small);
  EXPECT_FALSE(small == large);

  EXPECT_TRUE(small != large);
  EXPECT_FALSE(small != small);

  EXPECT_TRUE(large >= small);
  EXPECT_TRUE(small >= small);
  EXPECT_FALSE(small >= large);

  EXPECT_TRUE(large > small);
  EXPECT_FALSE(small > small);
  EXPECT_FALSE(small > large);
}

}  //  namespace model
}  //  namespace firestore
}  //  namespace firebase
