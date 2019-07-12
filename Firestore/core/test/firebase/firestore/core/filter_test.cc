/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/firebase/firestore/core/filter.h"

#include "Firestore/core/src/firebase/firestore/core/field_filter.h"
#include "Firestore/core/src/firebase/firestore/core/nan_filter.h"
#include "Firestore/core/src/firebase/firestore/core/null_filter.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using testutil::Field;
using testutil::Filter;
using testutil::Resource;
using testutil::Value;

using Operator = Filter::Operator;

TEST(FilterTest, Equality) {
  FieldFilter filter(Field("f"), Operator::Equal, Value(1));
  EXPECT_EQ(filter, FieldFilter(Field("f"), Operator::Equal, Value(1)));
  EXPECT_NE(filter, FieldFilter(Field("g"), Operator::Equal, Value(1)));
  EXPECT_NE(filter, FieldFilter(Field("f"), Operator::GreaterThan, Value(1)));
  EXPECT_NE(filter, FieldFilter(Field("f"), Operator::Equal, Value(2)));
  EXPECT_NE(filter, NanFilter(Field("f")));
  EXPECT_NE(filter, NullFilter(Field("f")));

  NullFilter null_filter(Field("g"));
  EXPECT_EQ(null_filter, NullFilter(Field("g")));
  EXPECT_NE(null_filter, NullFilter(Field("h")));

  NanFilter nan_filter(Field("g"));
  EXPECT_EQ(nan_filter, NanFilter(Field("g")));
  EXPECT_NE(nan_filter, NanFilter(Field("h")));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
