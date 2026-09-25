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

#include "Firestore/core/src/model/transform_operation.h"

#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using testutil::Decimal128;
using testutil::Int32;
using testutil::Value;

using Type = TransformOperation::Type;

TEST(TransformOperationsTest, ServerTimestamp) {
  ServerTimestampTransform transform;
  EXPECT_EQ(Type::ServerTimestamp, transform.type());

  ServerTimestampTransform another;
  NumericIncrementTransform other(Value(1));
  EXPECT_EQ(transform, another);
  EXPECT_NE(transform, other);
}

TEST(TransformOperationsTest, NumericIncrement) {
  NumericIncrementTransform transform(Value(1));
  EXPECT_EQ(Type::Increment, transform.type());
  EXPECT_EQ(transform.operand(), *Value(1));

  NumericIncrementTransform dup(Value(1));
  NumericIncrementTransform other_val(Value(2));
  NumericIncrementTransform int32_transform(Int32(1));
  NumericIncrementTransform d128_transform(Decimal128("1.0"));

  EXPECT_EQ(transform, dup);
  EXPECT_NE(transform, other_val);
  EXPECT_NE(transform, int32_transform);
  EXPECT_NE(transform, d128_transform);
  EXPECT_NE(transform, ServerTimestampTransform());

  EXPECT_EQ(transform.Hash(), dup.Hash());
  EXPECT_FALSE(transform.ToString().empty());

  TransformOperation op = transform;
  NumericIncrementTransform recovered(op);
  EXPECT_EQ(recovered, transform);
  EXPECT_EQ(recovered.operand(), *Value(1));
}

TEST(TransformOperationsTest, NumericMinimum) {
  NumericMinimumTransform transform(Value(5));
  EXPECT_EQ(Type::Minimum, transform.type());
  EXPECT_EQ(transform.operand(), *Value(5));

  NumericMinimumTransform dup(Value(5));
  NumericMinimumTransform other_val(Value(10));
  NumericMinimumTransform int32_transform(Int32(5));
  NumericMinimumTransform d128_transform(Decimal128("5.0"));
  NumericIncrementTransform inc_transform(Value(5));

  EXPECT_EQ(transform, dup);
  EXPECT_NE(transform, other_val);
  EXPECT_NE(transform, int32_transform);
  EXPECT_NE(transform, d128_transform);
  EXPECT_NE(transform, inc_transform);
  EXPECT_NE(transform, ServerTimestampTransform());

  EXPECT_EQ(transform.Hash(), dup.Hash());
  EXPECT_FALSE(transform.ToString().empty());

  TransformOperation op = transform;
  NumericMinimumTransform recovered(op);
  EXPECT_EQ(recovered, transform);
  EXPECT_EQ(recovered.operand(), *Value(5));
}

TEST(TransformOperationsTest, NumericMaximum) {
  NumericMaximumTransform transform(Value(10));
  EXPECT_EQ(Type::Maximum, transform.type());
  EXPECT_EQ(transform.operand(), *Value(10));

  NumericMaximumTransform dup(Value(10));
  NumericMaximumTransform other_val(Value(20));
  NumericMaximumTransform int32_transform(Int32(10));
  NumericMaximumTransform d128_transform(Decimal128("10.0"));
  NumericMinimumTransform min_transform(Value(10));
  NumericIncrementTransform inc_transform(Value(10));

  EXPECT_EQ(transform, dup);
  EXPECT_NE(transform, other_val);
  EXPECT_NE(transform, int32_transform);
  EXPECT_NE(transform, d128_transform);
  EXPECT_NE(transform, min_transform);
  EXPECT_NE(transform, inc_transform);
  EXPECT_NE(transform, ServerTimestampTransform());

  EXPECT_EQ(transform.Hash(), dup.Hash());
  EXPECT_FALSE(transform.ToString().empty());

  TransformOperation op = transform;
  NumericMaximumTransform recovered(op);
  EXPECT_EQ(recovered, transform);
  EXPECT_EQ(recovered.operand(), *Value(10));
}

// TODO(mikelehen): Add ArrayTransform test once it no longer depends on
// FSTFieldValue and can be exposed to C++ code.

}  // namespace model
}  // namespace firestore
}  // namespace firebase
