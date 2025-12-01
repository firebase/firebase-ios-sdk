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
#include <limits>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Expr;
using model::DatabaseId;
using model::DocumentKey;
using model::MutableDocument;  // Used as PipelineInputOutput alias
using testing::_;
// Explicitly qualify testutil helpers to avoid ambiguity
using testutil::ComparisonValueTestData;
using testutil::EqualExpr;
using testutil::EvaluateExpr;
using testutil::GreaterThanExpr;
using testutil::GreaterThanOrEqualExpr;
using testutil::LessThanExpr;
using testutil::LessThanOrEqualExpr;
using testutil::NotEqualExpr;
using testutil::RefConstant;
using testutil::Returns;
using testutil::ReturnsError;
using testutil::ReturnsNull;
using testutil::SharedConstant;

// Base fixture for common setup
class ComparisonExpressionsTest : public ::testing::Test {
 protected:
  // Helper moved to expression_test_util.h
};

// Fixture for Equal function tests
class EqualFunctionTest : public ComparisonExpressionsTest {};

// Helper to get canonical ID for logging, handling potential non-constant exprs
std::string ExprId(const std::shared_ptr<Expr>& expr) {
  if (auto constant = std::dynamic_pointer_cast<const api::Constant>(expr)) {
    // Try accessing the underlying proto message via proto()
    return model::CanonicalId(constant->to_proto());
  } else if (auto field = std::dynamic_pointer_cast<const api::Field>(expr)) {
    return "Field(" + field->field_path().CanonicalString() + ")";
  }
  return "<unknown_expr_type>";
}

TEST_F(EqualFunctionTest, EquivalentValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*EqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "equal(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(EqualFunctionTest, LessThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*EqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "equal(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(EqualFunctionTest, GreaterThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*EqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "equal(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(EqualFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*EqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "equal(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

// --- Specific Equal Tests (Null, NaN, Missing, Error) ---

// Fixture for NotEqual function tests
class NotEqualFunctionTest : public ComparisonExpressionsTest {};

// Fixture for LessThan function tests
class LessThanFunctionTest : public ComparisonExpressionsTest {};

// Fixture for LessThanOrEqual function tests
class LessThanOrEqualFunctionTest : public ComparisonExpressionsTest {};

// Fixture for GreaterThan function tests
class GreaterThanFunctionTest : public ComparisonExpressionsTest {};

// Fixture for GreaterThanOrEqual function tests
class GreaterThanOrEqualFunctionTest : public ComparisonExpressionsTest {};

// --- Equal (==) Tests ---

TEST_F(EqualFunctionTest, NullEqualsNullReturnsNull) {
  EXPECT_THAT(EvaluateExpr(*EqualExpr({SharedConstant(model::NullValue()),
                                       SharedConstant(model::NullValue())})),
              ReturnsNull());
}

// Corresponds to eq.null_any_returnsNull in typescript
TEST_F(EqualFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*EqualExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "equal(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*EqualExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "equal(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr({SharedConstant(model::NullValue()),
                               std::make_shared<api::Field>("nonexistent")})),
      ReturnsError());
}

// Corresponds to eq.nan tests in typescript
TEST_F(EqualFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*EqualExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));  // NaN == NaN is false

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*EqualExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "equal(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*EqualExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "equal(" << ExprId(num_val) << ", NaN)";
  }

  for (const auto& other_val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    bool is_numeric = false;
    for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
      if (other_val == num_val) {
        is_numeric = true;
        break;
      }
    }
    if (!is_numeric) {
      EXPECT_THAT(EvaluateExpr(*EqualExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "equal(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*EqualExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "equal(" << ExprId(other_val) << ", NaN)";
    }
  }

  EXPECT_THAT(EvaluateExpr(*EqualExpr(
                  {SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN()))),
                   SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN())))})),
              Returns(testutil::Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr(
          {SharedConstant(testutil::Map(
               "foo",
               testutil::Value(std::numeric_limits<double>::quiet_NaN()))),
           SharedConstant(testutil::Map(
               "foo",
               testutil::Value(std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(false)));
}

// Corresponds to eq.nullInArray_equality / eq.nullInMap_equality /
// eq.null_missingInMap_equality
TEST_F(EqualFunctionTest, NullContainerEquality) {
  auto null_array = SharedConstant(testutil::Array(testutil::Value(nullptr)));
  EXPECT_THAT(EvaluateExpr(*EqualExpr(
                  {null_array, SharedConstant(static_cast<int64_t>(1LL))})),
              Returns(testutil::Value(false)));
  EXPECT_THAT(EvaluateExpr(*EqualExpr({null_array, SharedConstant("1")})),
              Returns(testutil::Value(false)));
  EXPECT_THAT(EvaluateExpr(
                  *EqualExpr({null_array, SharedConstant(model::NullValue())})),
              ReturnsNull());
  EXPECT_THAT(EvaluateExpr(*EqualExpr(
                  {null_array,
                   SharedConstant(std::numeric_limits<double>::quiet_NaN())})),
              Returns(testutil::Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr({null_array, SharedConstant(testutil::Array())})),
      Returns(testutil::Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr(
          {null_array, SharedConstant(testutil::Array(testutil::Value(
                           std::numeric_limits<double>::quiet_NaN())))})),
      ReturnsNull());
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr({null_array, SharedConstant(testutil::Array(
                                               testutil::Value(nullptr)))})),
      ReturnsNull());

  auto null_map =
      SharedConstant(testutil::Map("foo", testutil::Value(nullptr)));
  EXPECT_THAT(EvaluateExpr(*EqualExpr(
                  {null_map, SharedConstant(testutil::Map(
                                 "foo", testutil::Value(nullptr)))})),
              ReturnsNull());
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr({null_map, SharedConstant(testutil::Map())})),
      Returns(testutil::Value(false)));
}

// Corresponds to eq.error_ tests
TEST_F(EqualFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*EqualExpr({error_expr, val}), non_map_input),
                ReturnsError());
    EXPECT_THAT(EvaluateExpr(*EqualExpr({val, error_expr}), non_map_input),
                ReturnsError());
  }
  EXPECT_THAT(EvaluateExpr(*EqualExpr({error_expr, error_expr}), non_map_input),
              ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr({error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsError());
}

TEST_F(EqualFunctionTest, MissingFieldReturnsError) {
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr({std::make_shared<api::Field>("nonexistent"),
                               SharedConstant(testutil::Value(1LL))})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*EqualExpr({SharedConstant(testutil::Value(1LL)),
                               std::make_shared<api::Field>("nonexistent")})),
      ReturnsError());
}

// --- NotEqual (!=) Tests ---

TEST_F(NotEqualFunctionTest, EquivalentValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*NotEqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "not_equal(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(NotEqualFunctionTest, LessThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*NotEqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "not_equal(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(NotEqualFunctionTest, GreaterThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*NotEqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "not_equal(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(NotEqualFunctionTest, MixedTypeValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*NotEqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "not_equal(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

// --- Specific NotEqual Tests ---

TEST_F(NotEqualFunctionTest, NullNotEqualsNullReturnsNull) {
  EXPECT_THAT(EvaluateExpr(*NotEqualExpr({SharedConstant(model::NullValue()),
                                          SharedConstant(model::NullValue())})),
              ReturnsNull());
}

// Corresponds to neq.null_any_returnsNull
TEST_F(NotEqualFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*NotEqualExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "not_equal(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*NotEqualExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "not_equal(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(EvaluateExpr(
                  *NotEqualExpr({SharedConstant(model::NullValue()),
                                 std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

// Corresponds to neq.nan tests
TEST_F(NotEqualFunctionTest, NaNComparisonsReturnTrue) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*NotEqualExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(true)));  // NaN != NaN is true

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*NotEqualExpr({nan_expr, num_val})),
                Returns(testutil::Value(true)))
        << "not_equal(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*NotEqualExpr({num_val, nan_expr})),
                Returns(testutil::Value(true)))
        << "not_equal(" << ExprId(num_val) << ", NaN)";
  }

  for (const auto& other_val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    bool is_numeric = false;
    for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
      if (other_val == num_val) {
        is_numeric = true;
        break;
      }
    }
    if (!is_numeric) {
      EXPECT_THAT(EvaluateExpr(*NotEqualExpr({nan_expr, other_val})),
                  Returns(testutil::Value(true)))
          << "not_equal(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*NotEqualExpr({other_val, nan_expr})),
                  Returns(testutil::Value(true)))
          << "not_equal(" << ExprId(other_val) << ", NaN)";
    }
  }

  EXPECT_THAT(EvaluateExpr(*NotEqualExpr(
                  {SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN()))),
                   SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN())))})),
              Returns(testutil::Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*NotEqualExpr(
          {SharedConstant(testutil::Map(
               "foo",
               testutil::Value(std::numeric_limits<double>::quiet_NaN()))),
           SharedConstant(testutil::Map(
               "foo",
               testutil::Value(std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(true)));
}

// Corresponds to neq.error_ tests
TEST_F(NotEqualFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*NotEqualExpr({error_expr, val}), non_map_input),
                ReturnsError());
    EXPECT_THAT(EvaluateExpr(*NotEqualExpr({val, error_expr}), non_map_input),
                ReturnsError());
  }
  EXPECT_THAT(
      EvaluateExpr(*NotEqualExpr({error_expr, error_expr}), non_map_input),
      ReturnsError());
  EXPECT_THAT(EvaluateExpr(*NotEqualExpr({error_expr,
                                          SharedConstant(model::NullValue())}),
                           non_map_input),
              ReturnsError());
}

TEST_F(NotEqualFunctionTest, MissingFieldReturnsError) {
  EXPECT_THAT(
      EvaluateExpr(*NotEqualExpr({std::make_shared<api::Field>("nonexistent"),
                                  SharedConstant(testutil::Value(1LL))})),
      ReturnsError());
  EXPECT_THAT(EvaluateExpr(
                  *NotEqualExpr({SharedConstant(testutil::Value(1LL)),
                                 std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

// --- LessThan (<) Tests ---

TEST_F(LessThanFunctionTest, EquivalentValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "less_than(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(LessThanFunctionTest, LessThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    auto left_const =
        std::dynamic_pointer_cast<const api::Constant>(pair.first);
    auto right_const =
        std::dynamic_pointer_cast<const api::Constant>(pair.second);
    // Use model::Equals to check for non-equal comparable pairs
    EXPECT_THAT(EvaluateExpr(*LessThanExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "less_than(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(LessThanFunctionTest, GreaterThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "less_than(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(LessThanFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "less_than(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

// --- Specific LessThan Tests ---

TEST_F(LessThanFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*LessThanExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "less_than(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*LessThanExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "less_than(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(EvaluateExpr(*LessThanExpr({SharedConstant(model::NullValue()),
                                          SharedConstant(model::NullValue())})),
              ReturnsNull());
  EXPECT_THAT(EvaluateExpr(
                  *LessThanExpr({SharedConstant(model::NullValue()),
                                 std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

TEST_F(LessThanFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*LessThanExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "less_than(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*LessThanExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "less_than(" << ExprId(num_val) << ", NaN)";
  }
  for (const auto& other_val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    bool is_numeric = false;
    for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
      if (other_val == num_val) {
        is_numeric = true;
        break;
      }
    }
    if (!is_numeric) {
      EXPECT_THAT(EvaluateExpr(*LessThanExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "less_than(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*LessThanExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "less_than(" << ExprId(other_val) << ", NaN)";
    }
  }
  EXPECT_THAT(EvaluateExpr(*LessThanExpr(
                  {SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN()))),
                   SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN())))})),
              Returns(testutil::Value(false)));
}

TEST_F(LessThanFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanExpr({error_expr, val}), non_map_input),
                ReturnsError());
    EXPECT_THAT(EvaluateExpr(*LessThanExpr({val, error_expr}), non_map_input),
                ReturnsError());
  }
  EXPECT_THAT(
      EvaluateExpr(*LessThanExpr({error_expr, error_expr}), non_map_input),
      ReturnsError());
  EXPECT_THAT(EvaluateExpr(*LessThanExpr({error_expr,
                                          SharedConstant(model::NullValue())}),
                           non_map_input),
              ReturnsError());
}

TEST_F(LessThanFunctionTest, MissingFieldReturnsError) {
  EXPECT_THAT(
      EvaluateExpr(*LessThanExpr({std::make_shared<api::Field>("nonexistent"),
                                  SharedConstant(testutil::Value(1LL))})),
      ReturnsError());
  EXPECT_THAT(EvaluateExpr(
                  *LessThanExpr({SharedConstant(testutil::Value(1LL)),
                                 std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

// --- LessThanOrEqual (<=) Tests ---

TEST_F(LessThanOrEqualFunctionTest, EquivalentValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "less_than_or_equal(" << ExprId(pair.first) << ", "
        << ExprId(pair.second) << ")";
  }
}

TEST_F(LessThanOrEqualFunctionTest, LessThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "less_than_or_equal(" << ExprId(pair.first) << ", "
        << ExprId(pair.second) << ")";
  }
}

TEST_F(LessThanOrEqualFunctionTest, GreaterThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "less_than_or_equal(" << ExprId(pair.first) << ", "
        << ExprId(pair.second) << ")";
  }
}

TEST_F(LessThanOrEqualFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "less_than_or_equal(" << ExprId(pair.first) << ", "
        << ExprId(pair.second) << ")";
  }
}

// --- Specific LessThanOrEqual Tests ---

TEST_F(LessThanOrEqualFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr(
                    {SharedConstant(model::NullValue()), val})),
                ReturnsNull())
        << "less_than_or_equal(null, " << ExprId(val) << ")";
    EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr(
                    {val, SharedConstant(model::NullValue())})),
                ReturnsNull())
        << "less_than_or_equal(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(
      EvaluateExpr(*LessThanOrEqualExpr({SharedConstant(model::NullValue()),
                                         SharedConstant(model::NullValue())})),
      ReturnsNull());
  EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr(
                  {SharedConstant(model::NullValue()),
                   std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

TEST_F(LessThanOrEqualFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "less_than_or_equal(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "less_than_or_equal(" << ExprId(num_val) << ", NaN)";
  }
  for (const auto& other_val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    bool is_numeric = false;
    for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
      if (other_val == num_val) {
        is_numeric = true;
        break;
      }
    }
    if (!is_numeric) {
      EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "less_than_or_equal(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "less_than_or_equal(" << ExprId(other_val) << ", NaN)";
    }
  }
  EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr(
                  {SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN()))),
                   SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN())))})),
              Returns(testutil::Value(false)));
}

TEST_F(LessThanOrEqualFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*LessThanOrEqualExpr({error_expr, val}), non_map_input),
        ReturnsError());
    EXPECT_THAT(
        EvaluateExpr(*LessThanOrEqualExpr({val, error_expr}), non_map_input),
        ReturnsError());
  }
  EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr({error_expr, error_expr}),
                           non_map_input),
              ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*LessThanOrEqualExpr(
                       {error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsError());
}

TEST_F(LessThanOrEqualFunctionTest, MissingFieldReturnsError) {
  EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr(
                  {std::make_shared<api::Field>("nonexistent"),
                   SharedConstant(testutil::Value(1LL))})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*LessThanOrEqualExpr(
                  {SharedConstant(testutil::Value(1LL)),
                   std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

// --- GreaterThan (>) Tests ---

TEST_F(GreaterThanFunctionTest, EquivalentValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "greater_than(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(GreaterThanFunctionTest, LessThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "greater_than(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(GreaterThanFunctionTest, GreaterThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    // This set includes pairs like {1.0, 1} which compare as !GreaterThan.
    // We expect false for those, true otherwise.
    auto left_const =
        std::dynamic_pointer_cast<const api::Constant>(pair.first);
    auto right_const =
        std::dynamic_pointer_cast<const api::Constant>(pair.second);
    EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "greater_than(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

TEST_F(GreaterThanFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "greater_than(" << ExprId(pair.first) << ", " << ExprId(pair.second)
        << ")";
  }
}

// --- Specific GreaterThan Tests ---

TEST_F(GreaterThanFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*GreaterThanExpr(
                    {SharedConstant(model::NullValue()), val})),
                ReturnsNull())
        << "greater_than(null, " << ExprId(val) << ")";
    EXPECT_THAT(EvaluateExpr(*GreaterThanExpr(
                    {val, SharedConstant(model::NullValue())})),
                ReturnsNull())
        << "greater_than(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(
      EvaluateExpr(*GreaterThanExpr({SharedConstant(model::NullValue()),
                                     SharedConstant(model::NullValue())})),
      ReturnsNull());
  EXPECT_THAT(EvaluateExpr(*GreaterThanExpr(
                  {SharedConstant(model::NullValue()),
                   std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

TEST_F(GreaterThanFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "greater_than(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "greater_than(" << ExprId(num_val) << ", NaN)";
  }
  for (const auto& other_val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    bool is_numeric = false;
    for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
      if (other_val == num_val) {
        is_numeric = true;
        break;
      }
    }
    if (!is_numeric) {
      EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "greater_than(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*GreaterThanExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "greater_than(" << ExprId(other_val) << ", NaN)";
    }
  }
  EXPECT_THAT(EvaluateExpr(*GreaterThanExpr(
                  {SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN()))),
                   SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN())))})),
              Returns(testutil::Value(false)));
}

TEST_F(GreaterThanFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*GreaterThanExpr({error_expr, val}), non_map_input),
        ReturnsError());
    EXPECT_THAT(
        EvaluateExpr(*GreaterThanExpr({val, error_expr}), non_map_input),
        ReturnsError());
  }
  EXPECT_THAT(
      EvaluateExpr(*GreaterThanExpr({error_expr, error_expr}), non_map_input),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(
          *GreaterThanExpr({error_expr, SharedConstant(model::NullValue())}),
          non_map_input),
      ReturnsError());
}

TEST_F(GreaterThanFunctionTest, MissingFieldReturnsError) {
  EXPECT_THAT(EvaluateExpr(
                  *GreaterThanExpr({std::make_shared<api::Field>("nonexistent"),
                                    SharedConstant(testutil::Value(1LL))})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*GreaterThanExpr(
                  {SharedConstant(testutil::Value(1LL)),
                   std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

// --- GreaterThanOrEqual (>=) Tests ---

TEST_F(GreaterThanOrEqualFunctionTest, EquivalentValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(
        EvaluateExpr(*GreaterThanOrEqualExpr({pair.first, pair.second})),
        Returns(testutil::Value(true)))
        << "greater_than_or_equal(" << ExprId(pair.first) << ", "
        << ExprId(pair.second) << ")";
  }
}

TEST_F(GreaterThanOrEqualFunctionTest, LessThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(
        EvaluateExpr(*GreaterThanOrEqualExpr({pair.first, pair.second})),
        Returns(testutil::Value(false)))
        << "greater_than_or_equal(" << ExprId(pair.first) << ", "
        << ExprId(pair.second) << ")";
  }
}

TEST_F(GreaterThanOrEqualFunctionTest, GreaterThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(
        EvaluateExpr(*GreaterThanOrEqualExpr({pair.first, pair.second})),
        Returns(testutil::Value(true)))
        << "greater_than_or_equal(" << ExprId(pair.first) << ", "
        << ExprId(pair.second) << ")";
  }
}

TEST_F(GreaterThanOrEqualFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(
        EvaluateExpr(*GreaterThanOrEqualExpr({pair.first, pair.second})),
        Returns(testutil::Value(false)))
        << "greater_than_or_equal(" << ExprId(pair.first) << ", "
        << ExprId(pair.second) << ")";
  }
}

// --- Specific GreaterThanOrEqual Tests ---

TEST_F(GreaterThanOrEqualFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr(
                    {SharedConstant(model::NullValue()), val})),
                ReturnsNull())
        << "greater_than_or_equal(null, " << ExprId(val) << ")";
    EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr(
                    {val, SharedConstant(model::NullValue())})),
                ReturnsNull())
        << "greater_than_or_equal(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr(
                  {SharedConstant(model::NullValue()),
                   SharedConstant(model::NullValue())})),
              ReturnsNull());
  EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr(
                  {SharedConstant(model::NullValue()),
                   std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

TEST_F(GreaterThanOrEqualFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "greater_than_or_equal(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "greater_than_or_equal(" << ExprId(num_val) << ", NaN)";
  }
  for (const auto& other_val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    bool is_numeric = false;
    for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
      if (other_val == num_val) {
        is_numeric = true;
        break;
      }
    }
    if (!is_numeric) {
      EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "greater_than_or_equal(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "greater_than_or_equal(" << ExprId(other_val) << ", NaN)";
    }
  }
  EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr(
                  {SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN()))),
                   SharedConstant(testutil::Array(testutil::Value(
                       std::numeric_limits<double>::quiet_NaN())))})),
              Returns(testutil::Value(false)));
}

TEST_F(GreaterThanOrEqualFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*GreaterThanOrEqualExpr({error_expr, val}), non_map_input),
        ReturnsError());
    EXPECT_THAT(
        EvaluateExpr(*GreaterThanOrEqualExpr({val, error_expr}), non_map_input),
        ReturnsError());
  }
  EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr({error_expr, error_expr}),
                           non_map_input),
              ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*GreaterThanOrEqualExpr(
                       {error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsError());
}

TEST_F(GreaterThanOrEqualFunctionTest, MissingFieldReturnsError) {
  EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr(
                  {std::make_shared<api::Field>("nonexistent"),
                   SharedConstant(testutil::Value(1LL))})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*GreaterThanOrEqualExpr(
                  {SharedConstant(testutil::Value(1LL)),
                   std::make_shared<api::Field>("nonexistent")})),
              ReturnsError());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
