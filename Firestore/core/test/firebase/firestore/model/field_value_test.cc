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
  NullValue null_value = NullValue::NulValue();
  NullValue another_null = NullValue::NulValue();
  EXPECT_EQ(FieldValue::TypeOrderNull, null_value.type_order());
  EXPECT_EQ(FieldValue::TypeNull, null_value.type());
  EXPECT_EQ(0, null_value.Compare(another_null));
}

TEST(FieldValue, BooleanType) {
  BooleanValue true_value = BooleanValue::TrueValue();
  BooleanValue another_true = BooleanValue::TrueValue();
  BooleanValue false_value = BooleanValue::FalseValue();
  BooleanValue another_false = BooleanValue::FalseValue();
  EXPECT_EQ(FieldValue::TypeOrderBoolean, true_value.type_order());
  EXPECT_EQ(FieldValue::TypeBoolean, true_value.type());
  EXPECT_EQ(0, true_value.Compare(another_true));
  EXPECT_EQ(0, false_value.Compare(another_false));
  EXPECT_EQ(1, true_value.Compare(false_value));
  EXPECT_EQ(-1, false_value.Compare(true_value));
}

TEST(FieldValue, CompareMixedType) {
  NullValue null_value = NullValue::NulValue();
  BooleanValue true_value = BooleanValue::TrueValue();
  EXPECT_EQ(-1, null_value.Compare(true_value));
  EXPECT_EQ(1, true_value.Compare(null_value));
}

}  //  namespace model
}  //  namespace firestore
}  //  namespace firebase
