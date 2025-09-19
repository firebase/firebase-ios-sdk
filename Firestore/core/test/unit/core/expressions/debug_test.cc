/*
 * Copyright 2025 Google LLC
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

#include <initializer_list>
#include <limits>  // Required for quiet_NaN()
#include <memory>
#include <vector>

#include "Firestore/core/src/api/expressions.h"  // For api::Expr, api::IsError
#include "Firestore/core/src/core/expressions_eval.h"
// #include "Firestore/core/src/model/field_value.h" // Not needed,
// True/FalseValue are in value_util.h
#include "Firestore/core/src/model/value_util.h"  // For value constants like NullValue, TrueValue, FalseValue
#include "Firestore/core/test/unit/testutil/expression_test_util.h"  // For test helpers
#include "Firestore/core/test/unit/testutil/testutil.h"  // For test helpers like Value, Array, Map
#include "gmock/gmock.h"  // For matchers like Returns
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Expr;
using testutil::Array;
using testutil::ArrayLengthExpr;
using testutil::ComparisonValueTestData;
using testutil::Constant;  // Use testutil::Constant for consistency
using testutil::EvaluateExpr;
using testutil::ExistsExpr;
using testutil::Field;
using testutil::IsErrorExpr;
using testutil::Map;
using testutil::NotExpr;
using testutil::Returns;
using testutil::ReturnsError;
using testutil::ReturnsNull;
using testutil::ReturnsUnset;
using testutil::SharedConstant;
// Unset is represented by evaluating Field("non-existent-field")
using model::FalseValue;
using model::TrueValue;
using testutil::Value;

// Fixture for Debug function tests
class DebugTest : public ::testing::Test {};

// --- Exists Tests ---

TEST_F(DebugTest, AnythingButUnsetReturnsTrue) {
  for (const auto& value_expr :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*ExistsExpr(value_expr)),
                Returns(testutil::Value(true)));
  }
}

TEST_F(DebugTest, NullReturnsTrue) {
  EXPECT_THAT(EvaluateExpr(*ExistsExpr(SharedConstant(nullptr))),
              Returns(testutil::Value(true)));
}

TEST_F(DebugTest, ErrorReturnsError) {
  // Create an expression that evaluates to error (e.g., array_length on
  // non-array)
  auto error_producing_expr =
      testutil::ArrayLengthExpr(SharedConstant("notAnArray"));
  EXPECT_THAT(EvaluateExpr(*ExistsExpr(error_producing_expr)), ReturnsError());
}

TEST_F(DebugTest, UnsetWithNotExistsReturnsTrue) {
  auto unset_expr = std::make_shared<api::Field>("non-existent-field");
  auto exists_expr = ExistsExpr(unset_expr);
  EXPECT_THAT(EvaluateExpr(*NotExpr(exists_expr)), Returns(Value(true)));
}

TEST_F(DebugTest, UnsetReturnsFalse) {
  auto unset_expr = std::make_shared<api::Field>("non-existent-field");
  EXPECT_THAT(EvaluateExpr(*ExistsExpr(unset_expr)), Returns(Value(false)));
}

TEST_F(DebugTest, EmptyArrayReturnsTrue) {
  EXPECT_THAT(EvaluateExpr(*ExistsExpr(SharedConstant(Array()))),
              Returns(Value(true)));
}

TEST_F(DebugTest, EmptyMapReturnsTrue) {
  EXPECT_THAT(EvaluateExpr(*ExistsExpr(SharedConstant(Map()))),
              Returns(Value(true)));
}

// --- IsError Tests ---

TEST_F(DebugTest, IsErrorErrorReturnsTrue) {
  // Use ArrayLengthExpr on a non-array to generate an error
  auto error_producing_expr = ArrayLengthExpr(SharedConstant("notAnArray"));
  EXPECT_THAT(EvaluateExpr(*IsErrorExpr(error_producing_expr)),
              Returns(Value(true)));
}

TEST_F(DebugTest, IsErrorFieldMissingReturnsFalse) {
  // Evaluate with context that does *not* contain 'target'
  auto field_expr = std::make_shared<api::Field>("target");
  EXPECT_THAT(EvaluateExpr(*IsErrorExpr(field_expr)), Returns(Value(false)));
}

TEST_F(DebugTest, IsErrorNonErrorReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*IsErrorExpr(SharedConstant(42LL))),
              Returns(Value(false)));
}

TEST_F(DebugTest, IsErrorExplicitNullReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*IsErrorExpr(SharedConstant(nullptr))),
              Returns(Value(false)));
}

TEST_F(DebugTest, IsErrorUnsetReturnsFalse) {
  // Evaluating a non-existent field results in Unset, which is not an error
  auto unset_expr = std::make_shared<api::Field>("non-existent-field");
  EXPECT_THAT(EvaluateExpr(*IsErrorExpr(unset_expr)),
              Returns(Value(false)));  // Wrap FalseValue
}

TEST_F(DebugTest, IsErrorAnythingButErrorReturnsFalse) {
  for (const auto& value_expr :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*IsErrorExpr(value_expr)), Returns(Value(false)));
  }
  // Also test explicit null and integer 0 which might not be in the main list
  EXPECT_THAT(EvaluateExpr(*IsErrorExpr(SharedConstant(nullptr))),
              Returns(Value(false)));
  EXPECT_THAT(EvaluateExpr(*IsErrorExpr(SharedConstant(int64_t{0}))),
              Returns(Value(false)));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
