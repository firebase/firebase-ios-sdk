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

#include "Firestore/core/src/core/expressions_eval.h"  // For EvaluateResult, CoreEq etc.

#include <initializer_list>
#include <limits>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/expressions.h"  // Include for api::Constant, api::Field
#include "Firestore/core/src/model/database_id.h"   // For DatabaseId
#include "Firestore/core/src/model/document_key.h"  // For DocumentKey
#include "Firestore/core/src/model/value_util.h"  // For value constants like NaNValue, TypeOrder, NullValue, CanonicalId, Equals
#include "Firestore/core/test/unit/testutil/expression_test_util.h"  // For EvaluateExpr, EqExpr, ComparisonValueTestData, RefConstant etc.
#include "Firestore/core/test/unit/testutil/testutil.h"  // For test helpers like Value, Array, Map, BlobValue, Doc
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
using testutil::EqExpr;
using testutil::EvaluateExpr;
using testutil::GteExpr;
using testutil::GtExpr;
using testutil::LteExpr;
using testutil::LtExpr;
using testutil::NeqExpr;
using testutil::RefConstant;
using testutil::Returns;
using testutil::ReturnsError;
using testutil::ReturnsNull;
using testutil::ReturnsUnset;
using testutil::SharedConstant;

// Base fixture for common setup
class ComparisonExpressionsTest : public ::testing::Test {
 protected:
  // Helper moved to expression_test_util.h
};

// Fixture for Eq function tests
class EqFunctionTest : public ComparisonExpressionsTest {};

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

TEST_F(EqFunctionTest, EquivalentValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*EqExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "eq(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(EqFunctionTest, LessThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*EqExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "eq(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(EqFunctionTest, GreaterThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*EqExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "eq(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(EqFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*EqExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "eq(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

// --- Specific Eq Tests (Null, NaN, Missing, Error) ---

// Fixture for Neq function tests
class NeqFunctionTest : public ComparisonExpressionsTest {};

// Fixture for Lt function tests
class LtFunctionTest : public ComparisonExpressionsTest {};

// Fixture for Lte function tests
class LteFunctionTest : public ComparisonExpressionsTest {};

// Fixture for Gt function tests
class GtFunctionTest : public ComparisonExpressionsTest {};

// Fixture for Gte function tests
class GteFunctionTest : public ComparisonExpressionsTest {};

// --- Eq (==) Tests ---

TEST_F(EqFunctionTest, NullEqualsNullReturnsNull) {
  EXPECT_THAT(EvaluateExpr(*EqExpr({SharedConstant(model::NullValue()),
                                    SharedConstant(model::NullValue())})),
              ReturnsNull());
}

// Corresponds to eq.null_any_returnsNull in typescript
TEST_F(EqFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*EqExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "eq(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*EqExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "eq(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(
      EvaluateExpr(*EqExpr({SharedConstant(model::NullValue()),
                            std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

// Corresponds to eq.nan tests in typescript
TEST_F(EqFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*EqExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));  // NaN == NaN is false

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*EqExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "eq(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*EqExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "eq(" << ExprId(num_val) << ", NaN)";
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
      EXPECT_THAT(EvaluateExpr(*EqExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "eq(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*EqExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "eq(" << ExprId(other_val) << ", NaN)";
    }
  }

  EXPECT_THAT(
      EvaluateExpr(*EqExpr({SharedConstant(testutil::Array(testutil::Value(
                                std::numeric_limits<double>::quiet_NaN()))),
                            SharedConstant(testutil::Array(testutil::Value(
                                std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*EqExpr(
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
TEST_F(EqFunctionTest, NullContainerEquality) {
  auto null_array = SharedConstant(testutil::Array(testutil::Value(nullptr)));
  EXPECT_THAT(EvaluateExpr(*EqExpr({null_array, SharedConstant(1LL)})),
              Returns(testutil::Value(false)));
  EXPECT_THAT(EvaluateExpr(*EqExpr({null_array, SharedConstant("1")})),
              Returns(testutil::Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*EqExpr({null_array, SharedConstant(model::NullValue())})),
      ReturnsNull());
  EXPECT_THAT(EvaluateExpr(*EqExpr(
                  {null_array,
                   SharedConstant(std::numeric_limits<double>::quiet_NaN())})),
              Returns(testutil::Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*EqExpr({null_array, SharedConstant(testutil::Array())})),
      Returns(testutil::Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*EqExpr(
          {null_array, SharedConstant(testutil::Array(testutil::Value(
                           std::numeric_limits<double>::quiet_NaN())))})),
      ReturnsNull());
  EXPECT_THAT(
      EvaluateExpr(*EqExpr({null_array, SharedConstant(testutil::Array(
                                            testutil::Value(nullptr)))})),
      ReturnsNull());

  auto null_map =
      SharedConstant(testutil::Map("foo", testutil::Value(nullptr)));
  EXPECT_THAT(
      EvaluateExpr(*EqExpr({null_map, SharedConstant(testutil::Map(
                                          "foo", testutil::Value(nullptr)))})),
      ReturnsNull());
  EXPECT_THAT(
      EvaluateExpr(*EqExpr({null_map, SharedConstant(testutil::Map())})),
      Returns(testutil::Value(false)));
}

// Corresponds to eq.error_ tests
TEST_F(EqFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*EqExpr({error_expr, val}), non_map_input),
                ReturnsUnset());
    EXPECT_THAT(EvaluateExpr(*EqExpr({val, error_expr}), non_map_input),
                ReturnsUnset());
  }
  EXPECT_THAT(EvaluateExpr(*EqExpr({error_expr, error_expr}), non_map_input),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*EqExpr({error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsUnset());
}

TEST_F(EqFunctionTest, MissingFieldReturnsUnset) {
  EXPECT_THAT(EvaluateExpr(*EqExpr({std::make_shared<api::Field>("nonexistent"),
                                    SharedConstant(testutil::Value(1LL))})),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*EqExpr({SharedConstant(testutil::Value(1LL)),
                            std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

// --- Neq (!=) Tests ---

TEST_F(NeqFunctionTest, EquivalentValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*NeqExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "neq(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(NeqFunctionTest, LessThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*NeqExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "neq(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(NeqFunctionTest, GreaterThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*NeqExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "neq(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(NeqFunctionTest, MixedTypeValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*NeqExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "neq(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

// --- Specific Neq Tests ---

TEST_F(NeqFunctionTest, NullNotEqualsNullReturnsNull) {
  EXPECT_THAT(EvaluateExpr(*NeqExpr({SharedConstant(model::NullValue()),
                                     SharedConstant(model::NullValue())})),
              ReturnsNull());
}

// Corresponds to neq.null_any_returnsNull
TEST_F(NeqFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*NeqExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "neq(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*NeqExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "neq(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(
      EvaluateExpr(*NeqExpr({SharedConstant(model::NullValue()),
                             std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

// Corresponds to neq.nan tests
TEST_F(NeqFunctionTest, NaNComparisonsReturnTrue) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*NeqExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(true)));  // NaN != NaN is true

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*NeqExpr({nan_expr, num_val})),
                Returns(testutil::Value(true)))
        << "neq(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*NeqExpr({num_val, nan_expr})),
                Returns(testutil::Value(true)))
        << "neq(" << ExprId(num_val) << ", NaN)";
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
      EXPECT_THAT(EvaluateExpr(*NeqExpr({nan_expr, other_val})),
                  Returns(testutil::Value(true)))
          << "neq(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*NeqExpr({other_val, nan_expr})),
                  Returns(testutil::Value(true)))
          << "neq(" << ExprId(other_val) << ", NaN)";
    }
  }

  EXPECT_THAT(
      EvaluateExpr(*NeqExpr({SharedConstant(testutil::Array(testutil::Value(
                                 std::numeric_limits<double>::quiet_NaN()))),
                             SharedConstant(testutil::Array(testutil::Value(
                                 std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*NeqExpr(
          {SharedConstant(testutil::Map(
               "foo",
               testutil::Value(std::numeric_limits<double>::quiet_NaN()))),
           SharedConstant(testutil::Map(
               "foo",
               testutil::Value(std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(true)));
}

// Corresponds to neq.error_ tests
TEST_F(NeqFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*NeqExpr({error_expr, val}), non_map_input),
                ReturnsUnset());
    EXPECT_THAT(EvaluateExpr(*NeqExpr({val, error_expr}), non_map_input),
                ReturnsUnset());
  }
  EXPECT_THAT(EvaluateExpr(*NeqExpr({error_expr, error_expr}), non_map_input),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*NeqExpr({error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsUnset());
}

TEST_F(NeqFunctionTest, MissingFieldReturnsUnset) {
  EXPECT_THAT(
      EvaluateExpr(*NeqExpr({std::make_shared<api::Field>("nonexistent"),
                             SharedConstant(testutil::Value(1LL))})),
      ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*NeqExpr({SharedConstant(testutil::Value(1LL)),
                             std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

// --- Lt (<) Tests ---

TEST_F(LtFunctionTest, EquivalentValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*LtExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "lt(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(LtFunctionTest, LessThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    auto left_const =
        std::dynamic_pointer_cast<const api::Constant>(pair.first);
    auto right_const =
        std::dynamic_pointer_cast<const api::Constant>(pair.second);
    // Use model::Equals to check for non-equal comparable pairs
    EXPECT_THAT(EvaluateExpr(*LtExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "lt(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(LtFunctionTest, GreaterThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*LtExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "lt(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(LtFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*LtExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "lt(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

// --- Specific Lt Tests ---

TEST_F(LtFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*LtExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "lt(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*LtExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "lt(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(EvaluateExpr(*LtExpr({SharedConstant(model::NullValue()),
                                    SharedConstant(model::NullValue())})),
              ReturnsNull());
  EXPECT_THAT(
      EvaluateExpr(*LtExpr({SharedConstant(model::NullValue()),
                            std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

TEST_F(LtFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*LtExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*LtExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "lt(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*LtExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "lt(" << ExprId(num_val) << ", NaN)";
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
      EXPECT_THAT(EvaluateExpr(*LtExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "lt(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*LtExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "lt(" << ExprId(other_val) << ", NaN)";
    }
  }
  EXPECT_THAT(
      EvaluateExpr(*LtExpr({SharedConstant(testutil::Array(testutil::Value(
                                std::numeric_limits<double>::quiet_NaN()))),
                            SharedConstant(testutil::Array(testutil::Value(
                                std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(false)));
}

TEST_F(LtFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*LtExpr({error_expr, val}), non_map_input),
                ReturnsUnset());
    EXPECT_THAT(EvaluateExpr(*LtExpr({val, error_expr}), non_map_input),
                ReturnsUnset());
  }
  EXPECT_THAT(EvaluateExpr(*LtExpr({error_expr, error_expr}), non_map_input),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*LtExpr({error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsUnset());
}

TEST_F(LtFunctionTest, MissingFieldReturnsUnset) {
  EXPECT_THAT(EvaluateExpr(*LtExpr({std::make_shared<api::Field>("nonexistent"),
                                    SharedConstant(testutil::Value(1LL))})),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*LtExpr({SharedConstant(testutil::Value(1LL)),
                            std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

// --- Lte (<=) Tests ---

TEST_F(LteFunctionTest, EquivalentValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*LteExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "lte(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(LteFunctionTest, LessThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*LteExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "lte(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(LteFunctionTest, GreaterThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*LteExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "lte(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(LteFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*LteExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "lte(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

// --- Specific Lte Tests ---

TEST_F(LteFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*LteExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "lte(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*LteExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "lte(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(EvaluateExpr(*LteExpr({SharedConstant(model::NullValue()),
                                     SharedConstant(model::NullValue())})),
              ReturnsNull());
  EXPECT_THAT(
      EvaluateExpr(*LteExpr({SharedConstant(model::NullValue()),
                             std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

TEST_F(LteFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*LteExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*LteExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "lte(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*LteExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "lte(" << ExprId(num_val) << ", NaN)";
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
      EXPECT_THAT(EvaluateExpr(*LteExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "lte(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*LteExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "lte(" << ExprId(other_val) << ", NaN)";
    }
  }
  EXPECT_THAT(
      EvaluateExpr(*LteExpr({SharedConstant(testutil::Array(testutil::Value(
                                 std::numeric_limits<double>::quiet_NaN()))),
                             SharedConstant(testutil::Array(testutil::Value(
                                 std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(false)));
}

TEST_F(LteFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*LteExpr({error_expr, val}), non_map_input),
                ReturnsUnset());
    EXPECT_THAT(EvaluateExpr(*LteExpr({val, error_expr}), non_map_input),
                ReturnsUnset());
  }
  EXPECT_THAT(EvaluateExpr(*LteExpr({error_expr, error_expr}), non_map_input),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*LteExpr({error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsUnset());
}

TEST_F(LteFunctionTest, MissingFieldReturnsUnset) {
  EXPECT_THAT(
      EvaluateExpr(*LteExpr({std::make_shared<api::Field>("nonexistent"),
                             SharedConstant(testutil::Value(1LL))})),
      ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*LteExpr({SharedConstant(testutil::Value(1LL)),
                             std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

// --- Gt (>) Tests ---

TEST_F(GtFunctionTest, EquivalentValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*GtExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "gt(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(GtFunctionTest, LessThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*GtExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "gt(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(GtFunctionTest, GreaterThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    // This set includes pairs like {1.0, 1} which compare as !GreaterThan.
    // We expect false for those, true otherwise.
    auto left_const =
        std::dynamic_pointer_cast<const api::Constant>(pair.first);
    auto right_const =
        std::dynamic_pointer_cast<const api::Constant>(pair.second);
    EXPECT_THAT(EvaluateExpr(*GtExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "gt(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(GtFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*GtExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "gt(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

// --- Specific Gt Tests ---

TEST_F(GtFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*GtExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "gt(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*GtExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "gt(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(EvaluateExpr(*GtExpr({SharedConstant(model::NullValue()),
                                    SharedConstant(model::NullValue())})),
              ReturnsNull());
  EXPECT_THAT(
      EvaluateExpr(*GtExpr({SharedConstant(model::NullValue()),
                            std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

TEST_F(GtFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*GtExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*GtExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "gt(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*GtExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "gt(" << ExprId(num_val) << ", NaN)";
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
      EXPECT_THAT(EvaluateExpr(*GtExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "gt(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*GtExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "gt(" << ExprId(other_val) << ", NaN)";
    }
  }
  EXPECT_THAT(
      EvaluateExpr(*GtExpr({SharedConstant(testutil::Array(testutil::Value(
                                std::numeric_limits<double>::quiet_NaN()))),
                            SharedConstant(testutil::Array(testutil::Value(
                                std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(false)));
}

TEST_F(GtFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*GtExpr({error_expr, val}), non_map_input),
                ReturnsUnset());
    EXPECT_THAT(EvaluateExpr(*GtExpr({val, error_expr}), non_map_input),
                ReturnsUnset());
  }
  EXPECT_THAT(EvaluateExpr(*GtExpr({error_expr, error_expr}), non_map_input),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*GtExpr({error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsUnset());
}

TEST_F(GtFunctionTest, MissingFieldReturnsUnset) {
  EXPECT_THAT(EvaluateExpr(*GtExpr({std::make_shared<api::Field>("nonexistent"),
                                    SharedConstant(testutil::Value(1LL))})),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*GtExpr({SharedConstant(testutil::Value(1LL)),
                            std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

// --- Gte (>=) Tests ---

TEST_F(GteFunctionTest, EquivalentValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::EquivalentValues()) {
    EXPECT_THAT(EvaluateExpr(*GteExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "gte(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(GteFunctionTest, LessThanValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::LessThanValues()) {
    EXPECT_THAT(EvaluateExpr(*GteExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "gte(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(GteFunctionTest, GreaterThanValuesReturnTrue) {
  for (const auto& pair : ComparisonValueTestData::GreaterThanValues()) {
    EXPECT_THAT(EvaluateExpr(*GteExpr({pair.first, pair.second})),
                Returns(testutil::Value(true)))
        << "gte(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

TEST_F(GteFunctionTest, MixedTypeValuesReturnFalse) {
  for (const auto& pair : ComparisonValueTestData::MixedTypeValues()) {
    EXPECT_THAT(EvaluateExpr(*GteExpr({pair.first, pair.second})),
                Returns(testutil::Value(false)))
        << "gte(" << ExprId(pair.first) << ", " << ExprId(pair.second) << ")";
  }
}

// --- Specific Gte Tests ---

TEST_F(GteFunctionTest, NullOperandReturnsNull) {
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(
        EvaluateExpr(*GteExpr({SharedConstant(model::NullValue()), val})),
        ReturnsNull())
        << "gte(null, " << ExprId(val) << ")";
    EXPECT_THAT(
        EvaluateExpr(*GteExpr({val, SharedConstant(model::NullValue())})),
        ReturnsNull())
        << "gte(" << ExprId(val) << ", null)";
  }
  EXPECT_THAT(EvaluateExpr(*GteExpr({SharedConstant(model::NullValue()),
                                     SharedConstant(model::NullValue())})),
              ReturnsNull());
  EXPECT_THAT(
      EvaluateExpr(*GteExpr({SharedConstant(model::NullValue()),
                             std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

TEST_F(GteFunctionTest, NaNComparisonsReturnFalse) {
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*GteExpr({nan_expr, nan_expr})),
              Returns(testutil::Value(false)));

  for (const auto& num_val : ComparisonValueTestData::NumericValues()) {
    EXPECT_THAT(EvaluateExpr(*GteExpr({nan_expr, num_val})),
                Returns(testutil::Value(false)))
        << "gte(NaN, " << ExprId(num_val) << ")";
    EXPECT_THAT(EvaluateExpr(*GteExpr({num_val, nan_expr})),
                Returns(testutil::Value(false)))
        << "gte(" << ExprId(num_val) << ", NaN)";
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
      EXPECT_THAT(EvaluateExpr(*GteExpr({nan_expr, other_val})),
                  Returns(testutil::Value(false)))
          << "gte(NaN, " << ExprId(other_val) << ")";
      EXPECT_THAT(EvaluateExpr(*GteExpr({other_val, nan_expr})),
                  Returns(testutil::Value(false)))
          << "gte(" << ExprId(other_val) << ", NaN)";
    }
  }
  EXPECT_THAT(
      EvaluateExpr(*GteExpr({SharedConstant(testutil::Array(testutil::Value(
                                 std::numeric_limits<double>::quiet_NaN()))),
                             SharedConstant(testutil::Array(testutil::Value(
                                 std::numeric_limits<double>::quiet_NaN())))})),
      Returns(testutil::Value(false)));
}

TEST_F(GteFunctionTest, ErrorHandling) {
  auto error_expr = std::make_shared<api::Field>("a.b");
  auto non_map_input = testutil::Doc("coll/doc", 1, testutil::Map("a", 123));

  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*GteExpr({error_expr, val}), non_map_input),
                ReturnsUnset());
    EXPECT_THAT(EvaluateExpr(*GteExpr({val, error_expr}), non_map_input),
                ReturnsUnset());
  }
  EXPECT_THAT(EvaluateExpr(*GteExpr({error_expr, error_expr}), non_map_input),
              ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*GteExpr({error_expr, SharedConstant(model::NullValue())}),
                   non_map_input),
      ReturnsUnset());
}

TEST_F(GteFunctionTest, MissingFieldReturnsUnset) {
  EXPECT_THAT(
      EvaluateExpr(*GteExpr({std::make_shared<api::Field>("nonexistent"),
                             SharedConstant(testutil::Value(1LL))})),
      ReturnsUnset());
  EXPECT_THAT(
      EvaluateExpr(*GteExpr({SharedConstant(testutil::Value(1LL)),
                             std::make_shared<api::Field>("nonexistent")})),
      ReturnsUnset());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
