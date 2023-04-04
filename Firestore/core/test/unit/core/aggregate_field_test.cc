/*
 * Copyright 2023 Google LLC
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

#include "Firestore/core/src/core/aggregate_field_1.h"
#include "Firestore/core/src/core/aggregate_field_2.h"
#include "Firestore/core/src/core/aggregate_field_3.h"
#include "Firestore/core/src/core/aggregate_field_4.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using testutil::AndFilters;
using testutil::Field;
using testutil::OrFilters;
using testutil::Query;
using testutil::Resource;
using testutil::Value;

namespace {

double double_val = 10.1;
int64_t long_val = 10;

// will be FieldValue
double __attribute__((unused)) get(AggregateBaseField1) {
  return double_val;
}

int64_t get(CountAggregateField1) {
  return long_val;
}

double __attribute__((unused)) get(std::shared_ptr<AggregateField2>) {
  return double_val;
}

int64_t get(std::shared_ptr<CountAggregateField2>) {
  return long_val;
}

double __attribute__((unused)) get(AggregateField3) {
  return double_val;
}

int64_t get(CountAggregateField3) {
  return long_val;
}

}  // namespace

TEST(AggregateTest1, Usage) {
  // create a list of aggregate fields
  // Note: AggregateBaseField1 is different from AggregateField
  std::vector<core::AggregateBaseField1> list = {
      core::AggregateField1::count(), core::AggregateField1::average()};
  EXPECT_EQ(list[0].type(),
            core::AggregateBaseField1::Type::kCountAggregateField);
  EXPECT_EQ(list[1].type(),
            core::AggregateBaseField1::Type::kAverageAggregateField);

  EXPECT_EQ(long_val, get(core::AggregateField1::count()));
}

TEST(AggregateTest2, Usage) {
  // create a list of aggregate fields
  std::vector<std::shared_ptr<AggregateField2>> list = {
      core::AggregateField2::count(), core::AggregateField2::average()};
  EXPECT_EQ(list[0]->type(), core::AggregateField2::Type::kCountAggregateField);
  EXPECT_EQ(list[1]->type(),
            core::AggregateField2::Type::kAverageAggregateField);

  EXPECT_EQ(long_val, get(core::AggregateField2::count()));
}

TEST(AggregateTest3, Usage) {
  // create a list of aggregate fields
  std::vector<AggregateField3> list = {CountAggregateField3(),
                                       AverageAggregateField3()};
  EXPECT_EQ(list[0].type(), core::AggregateField3::Type::kCountAggregateField);
  EXPECT_EQ(list[1].type(),
            core::AggregateField3::Type::kAverageAggregateField);

  EXPECT_EQ(long_val, get(CountAggregateField3()));
}

TEST(AggregateTest4, Usage) {
  // create a list of aggregate fields
  std::vector<AggregateField4> list = {AggregateField4::count(),
                                       AggregateField4::average()};
  EXPECT_EQ(list[0].type(), core::AggregateField4::Type::kCountAggregateField);
  EXPECT_EQ(list[1].type(),
            core::AggregateField4::Type::kAverageAggregateField);
  // Option 4 doesn't support function overload
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
