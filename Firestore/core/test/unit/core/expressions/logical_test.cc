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
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/value_util.h"  // For TrueValue, FalseValue, NullValue
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Expr;
using model::FieldPath;
// Removed: using model::FieldValue; // Use model::FieldValue explicitly
using testing::_;
using testutil::AddExpr;
using testutil::AndExpr;
using testutil::Array;
using testutil::ComparisonValueTestData;
using testutil::CondExpr;
using testutil::Doc;
using testutil::EqAnyExpr;
using testutil::EvaluateExpr;
using testutil::IsNanExpr;
using testutil::IsNotNanExpr;
using testutil::IsNotNullExpr;
using testutil::IsNullExpr;
using testutil::LogicalMaxExpr;
using testutil::LogicalMinExpr;
using testutil::Map;
using testutil::NotExpr;
using testutil::OrExpr;
using testutil::Returns;
using testutil::ReturnsError;  // Using ReturnsUnset as equivalent for now
// Removed: using testutil::ReturnsFalse;
// Removed: using testutil::ReturnsMin; // Use ReturnsNull for null comparisons
using testutil::ReturnsNull;
// Removed: using testutil::ReturnsTrue;
using testutil::ReturnsUnset;
using testutil::SharedConstant;
using testutil::Value;
using testutil::XorExpr;

// Helper function to create a Field expression using the specified path.
// Follows the instruction to use std::make_shared<api::Field> directly.
std::shared_ptr<Expr> Field(const std::string& path) {
  return std::make_shared<api::Field>(FieldPath::FromDotSeparatedString(path));
}

// Removed redundant Constant helper

// Predefined constants for convenience (defined directly)
const auto TrueExpr = testutil::SharedConstant(model::TrueValue());
const auto FalseExpr = testutil::SharedConstant(model::FalseValue());
const auto NullExpr = testutil::SharedConstant(model::NullValue());
const auto NanExpr =
    testutil::SharedConstant(Value(std::numeric_limits<double>::quiet_NaN()));

// Placeholder for an expression that results in an error/unset value during
// evaluation. Using a non-existent field path often achieves this with default
// test documents.
std::shared_ptr<Expr> ErrorExpr() {
  // Using a field path known to cause issues if the input doc isn't structured
  // correctly, or simply a non-existent field.
  return Field("error.field");
}

// Base fixture for logical expression tests
class LogicalExpressionsTest : public ::testing::Test {
 protected:
  // Add common setup/data if needed later
  // Example document for field path evaluation:
  model::MutableDocument test_doc_ =
      Doc("coll/doc", 1, Map("nanValue", Value(NAN), "field", Value("value")));
  model::MutableDocument error_doc_ =
      Doc("coll/doc", 1, Map("error", 123));  // Doc where error.field fails
};

// --- And (&&) Tests ---
class AndFunctionTest : public LogicalExpressionsTest {};

// 2 Operands
TEST_F(AndFunctionTest, FalseFalseIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({FalseExpr, FalseExpr})),
              Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseErrorIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, ErrorExpr()}), error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseTrueIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({FalseExpr, TrueExpr})),
              Returns(Value(false)));
}
TEST_F(AndFunctionTest, ErrorFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), FalseExpr}), error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, ErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), ErrorExpr()}), error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, ErrorTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), TrueExpr}), error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, TrueFalseIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({TrueExpr, FalseExpr})),
              Returns(Value(false)));
}
TEST_F(AndFunctionTest, TrueErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({TrueExpr, ErrorExpr()}), error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, TrueTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({TrueExpr, TrueExpr})),
              Returns(Value(true)));
}

// 3 Operands
TEST_F(AndFunctionTest, FalseFalseFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, FalseExpr, FalseExpr})),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseFalseErrorIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, FalseExpr, ErrorExpr()}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseFalseTrueIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, FalseExpr, TrueExpr})),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseErrorFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, ErrorExpr(), FalseExpr}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseErrorErrorIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseErrorTrueIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, ErrorExpr(), TrueExpr}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseTrueFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, TrueExpr, FalseExpr})),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseTrueErrorIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({FalseExpr, TrueExpr, ErrorExpr()}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, FalseTrueTrueIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({FalseExpr, TrueExpr, TrueExpr})),
              Returns(Value(false)));
}
TEST_F(AndFunctionTest, ErrorFalseFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), FalseExpr, FalseExpr}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, ErrorFalseErrorIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), FalseExpr, ErrorExpr()}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, ErrorFalseTrueIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), FalseExpr, TrueExpr}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, ErrorErrorFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), ErrorExpr(), FalseExpr}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, ErrorErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, ErrorErrorTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), ErrorExpr(), TrueExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, ErrorTrueFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), TrueExpr, FalseExpr}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, ErrorTrueErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), TrueExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, ErrorTrueTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({ErrorExpr(), TrueExpr, TrueExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, TrueFalseFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({TrueExpr, FalseExpr, FalseExpr})),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, TrueFalseErrorIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({TrueExpr, FalseExpr, ErrorExpr()}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, TrueFalseTrueIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({TrueExpr, FalseExpr, TrueExpr})),
              Returns(Value(false)));
}
TEST_F(AndFunctionTest, TrueErrorFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({TrueExpr, ErrorExpr(), FalseExpr}),
                   error_doc_),
      Returns(Value(false)));
}
TEST_F(AndFunctionTest, TrueErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({TrueExpr, ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, TrueErrorTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({TrueExpr, ErrorExpr(), TrueExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, TrueTrueFalseIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({TrueExpr, TrueExpr, FalseExpr})),
              Returns(Value(false)));
}
TEST_F(AndFunctionTest, TrueTrueErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::AndExpr({TrueExpr, TrueExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(AndFunctionTest, TrueTrueTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({TrueExpr, TrueExpr, TrueExpr})),
              Returns(Value(true)));
}

// Nested
TEST_F(AndFunctionTest, NestedAnd) {
  auto child = testutil::AndExpr({TrueExpr, FalseExpr});
  auto f = testutil::AndExpr({child, TrueExpr});
  EXPECT_THAT(EvaluateExpr(*f), Returns(Value(false)));
}

// Multiple Arguments (already covered by 3-operand tests)
TEST_F(AndFunctionTest, MultipleArguments) {
  EXPECT_THAT(EvaluateExpr(*testutil::AndExpr({TrueExpr, TrueExpr, TrueExpr})),
              Returns(Value(true)));
}

// --- Cond (? :) Tests ---
class CondFunctionTest : public LogicalExpressionsTest {};

TEST_F(CondFunctionTest, TrueConditionReturnsTrueCase) {
  auto expr = testutil::CondExpr(TrueExpr, SharedConstant(Value("true case")),
                                 ErrorExpr());
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value("true case")));
}

TEST_F(CondFunctionTest, FalseConditionReturnsFalseCase) {
  auto expr = testutil::CondExpr(FalseExpr, ErrorExpr(),
                                 SharedConstant(Value("false case")));
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value("false case")));
}

TEST_F(CondFunctionTest, ErrorConditionReturnsError) {
  auto expr = testutil::CondExpr(ErrorExpr(), ErrorExpr(),
                                 SharedConstant(Value("false")));
  // If condition is error, the whole expression is error
  EXPECT_THAT(EvaluateExpr(*expr, error_doc_), ReturnsError());
}

// --- EqAny Tests ---
class EqAnyFunctionTest : public LogicalExpressionsTest {};

TEST_F(EqAnyFunctionTest, ValueFoundInArray) {
  auto expr = testutil::EqAnyExpr(
      SharedConstant(Value("hello")),
      SharedConstant(Array(Value("hello"), Value("world"))));
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(true)));
}

TEST_F(EqAnyFunctionTest, ValueNotFoundInArray) {
  auto expr = testutil::EqAnyExpr(
      SharedConstant(Value(4LL)),
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true))));
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(false)));
}

TEST_F(EqAnyFunctionTest, NotEqAnyFunctionValueNotFoundInArray) {
  auto child = testutil::NotEqAnyExpr(
      SharedConstant(Value(4LL)),
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true))));
  EXPECT_THAT(EvaluateExpr(*child), Returns(Value(true)));
}

TEST_F(EqAnyFunctionTest, EquivalentNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::EqAnyExpr(
          SharedConstant(Value(42LL)),
          SharedConstant(Array(Value(42.0), Value("matang"), Value(true))))),
      Returns(Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*testutil::EqAnyExpr(
          SharedConstant(Value(42.0)),
          SharedConstant(Array(Value(42LL), Value("matang"), Value(true))))),
      Returns(Value(true)));
}

TEST_F(EqAnyFunctionTest, BothInputTypeIsArray) {
  auto search_array = SharedConstant(Array(Value(1LL), Value(2LL), Value(3LL)));
  auto values_array =
      SharedConstant(Array(Array(Value(1LL), Value(2LL), Value(3LL)),
                           Array(Value(4LL), Value(5LL), Value(6LL)),
                           Array(Value(7LL), Value(8LL), Value(9LL))));
  EXPECT_THAT(EvaluateExpr(*testutil::EqAnyExpr(search_array, values_array)),
              Returns(Value(true)));
}

TEST_F(EqAnyFunctionTest, ArrayNotFoundReturnsError) {
  // If any element in the values array evaluates to error/unset, the result is
  // error/unset
  auto expr = testutil::EqAnyExpr(SharedConstant(Value("matang")),
                                  Field("non-existent-field"));
  EXPECT_THAT(EvaluateExpr(*expr), ReturnsError());
}

TEST_F(EqAnyFunctionTest, ArrayIsEmptyReturnsFalse) {
  auto expr =
      testutil::EqAnyExpr(SharedConstant(Value(42LL)), SharedConstant(Array()));
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(false)));
}

TEST_F(EqAnyFunctionTest, SearchReferenceNotFoundReturnsError) {
  auto expr = testutil::EqAnyExpr(
      Field("non-existent-field"),
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true))));
  EXPECT_THAT(EvaluateExpr(*expr), ReturnsError());
}

TEST_F(EqAnyFunctionTest, SearchIsNull) {
  // Null comparison returns Null
  auto expr = testutil::EqAnyExpr(
      NullExpr, SharedConstant(Array(Value(nullptr), Value(1LL),
                                     Value("matang"), Value(true))));
  EXPECT_THAT(EvaluateExpr(*expr), ReturnsNull());
}

TEST_F(EqAnyFunctionTest, SearchIsNullEmptyValuesArrayReturnsNull) {
  // Null comparison returns Null
  auto expr = testutil::EqAnyExpr(NullExpr, SharedConstant(Array()));
  EXPECT_THAT(EvaluateExpr(*expr), ReturnsNull());
}

TEST_F(EqAnyFunctionTest, SearchIsNaN) {
  // NaN comparison always returns false
  auto expr = testutil::EqAnyExpr(
      NanExpr,
      SharedConstant(Array(Value(std::numeric_limits<double>::quiet_NaN()),
                           Value(42LL), Value(3.14))));
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(false)));
}

TEST_F(EqAnyFunctionTest, SearchIsEmptyArrayIsEmpty) {
  auto expr =
      testutil::EqAnyExpr(SharedConstant(Array()), SharedConstant(Array()));
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(false)));
}

TEST_F(EqAnyFunctionTest, SearchIsEmptyArrayContainsEmptyArrayReturnsTrue) {
  auto expr = testutil::EqAnyExpr(SharedConstant(Array()),
                                  SharedConstant(Array(Array())));
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(true)));
}

TEST_F(EqAnyFunctionTest, SearchIsMap) {
  auto search_map = SharedConstant(Map("foo", Value(42LL)));
  auto values_array =
      SharedConstant(Array(Array(Value(123LL), Map("foo", Value(123LL))),
                           Map("bar", Value(42LL)), Map("foo", Value(42LL))));
  EXPECT_THAT(EvaluateExpr(*testutil::EqAnyExpr(search_map, values_array)),
              Returns(Value(true)));
}

// --- IsNan / IsNotNan Tests ---
class IsNanFunctionTest : public LogicalExpressionsTest {};

TEST_F(IsNanFunctionTest, NanReturnsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(NanExpr)),
              Returns(Value(true)));
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(Field("nanValue")), test_doc_),
              Returns(Value(true)));
}

TEST_F(IsNanFunctionTest, NotNanReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(SharedConstant(Value(42.0)))),
              Returns(Value(false)));
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(SharedConstant(Value(42LL)))),
              Returns(Value(false)));
}

TEST_F(IsNanFunctionTest, IsNotNan) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::IsNotNanExpr(SharedConstant(Value(42.0)))),
      Returns(Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*testutil::IsNotNanExpr(SharedConstant(Value(42LL)))),
      Returns(Value(true)));
  EXPECT_THAT(EvaluateExpr(*testutil::IsNotNanExpr(NanExpr)),
              Returns(Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*testutil::IsNotNanExpr(Field("nanValue")), test_doc_),
      Returns(Value(false)));
}

TEST_F(IsNanFunctionTest, OtherNanRepresentationsReturnsTrue) {
  // Note: C++ standard doesn't guarantee specific results for Inf - Inf, etc.
  // Relying on NaN constant and NaN propagation.
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(SharedConstant(Value(NAN)))),
              Returns(Value(true)));

  // Test NaN propagation (e.g., NaN + 1 -> NaN)
  auto nan_plus_one = testutil::AddExpr({NanExpr, SharedConstant(Value(1LL))});
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(nan_plus_one)),
              Returns(Value(true)));

  // Test Inf - Inf (may not produce NaN reliably across platforms/compilers)
  // auto inf_minus_inf = testutil::AddExpr({SharedConstant(Value(INFINITY)),
  // SharedConstant(Value(-INFINITY))});
  // EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(inf_minus_inf)),
  // Returns(Value(true))); // This might fail
}

TEST_F(IsNanFunctionTest, NonNumericReturnsError) {
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(SharedConstant(Value(true)))),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(SharedConstant(Value("abc")))),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(NullExpr)), ReturnsNull());
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(SharedConstant(Array()))),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*testutil::IsNanExpr(SharedConstant(Map()))),
              ReturnsError());
}

// --- LogicalMaximum Tests ---
class LogicalMaximumFunctionTest : public LogicalExpressionsTest {};

TEST_F(LogicalMaximumFunctionTest, NumericType) {
  auto expr = testutil::LogicalMaxExpr(
      {SharedConstant(Value(1LL)),
       testutil::LogicalMaxExpr(
           {SharedConstant(Value(2.0)), SharedConstant(Value(3LL))})});
  EXPECT_THAT(EvaluateExpr(*expr),
              Returns(Value(3LL)));  // Max(1, Max(2.0, 3)) -> 3
}

TEST_F(LogicalMaximumFunctionTest, StringType) {
  auto expr = testutil::LogicalMaxExpr(
      {testutil::LogicalMaxExpr(
           {SharedConstant(Value("a")), SharedConstant(Value("b"))}),
       SharedConstant(Value("c"))});
  EXPECT_THAT(EvaluateExpr(*expr),
              Returns(Value("c")));  // Max(Max("a", "b"), "c") -> "c"
}

TEST_F(LogicalMaximumFunctionTest, MixedType) {
  // Type order: Null < Bool < Number < Timestamp < String < Blob < Ref <
  // GeoPoint < Array < Map
  auto expr = testutil::LogicalMaxExpr(
      {SharedConstant(Value(1LL)),
       testutil::LogicalMaxExpr(
           {SharedConstant(Value("1")), SharedConstant(Value(0LL))})});
  EXPECT_THAT(
      EvaluateExpr(*expr),
      Returns(Value("1")));  // Max(1, Max("1", 0)) -> "1" (String > Number)
}

TEST_F(LogicalMaximumFunctionTest, OnlyNullAndErrorReturnsNull) {
  auto expr = testutil::LogicalMaxExpr({NullExpr, ErrorExpr()});
  EXPECT_THAT(EvaluateExpr(*expr, error_doc_), ReturnsNull());
}

TEST_F(LogicalMaximumFunctionTest, NanAndNumbers) {
  // NaN is handled specially; it's skipped unless it's the only non-null/error
  // value.
  auto expr = testutil::LogicalMaxExpr({NanExpr, SharedConstant(Value(0LL))});
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(0LL)));  // Max(NaN, 0) -> 0
  auto expr2 = testutil::LogicalMaxExpr({SharedConstant(Value(0LL)), NanExpr});
  EXPECT_THAT(EvaluateExpr(*expr2), Returns(Value(0LL)));  // Max(0, NaN) -> 0
  auto expr3 = testutil::LogicalMaxExpr({NanExpr, NullExpr, ErrorExpr()});
  EXPECT_THAT(EvaluateExpr(*expr3, error_doc_),
              Returns(Value(NAN)));  // Max(NaN, Null, Error) -> NaN
  auto expr4 = testutil::LogicalMaxExpr({NanExpr, ErrorExpr()});
  EXPECT_THAT(EvaluateExpr(*expr4, error_doc_),
              Returns(Value(NAN)));  // Max(NaN, Error) -> NaN
}

TEST_F(LogicalMaximumFunctionTest, ErrorInputSkip) {
  auto expr =
      testutil::LogicalMaxExpr({ErrorExpr(), SharedConstant(Value(1LL))});
  EXPECT_THAT(EvaluateExpr(*expr, error_doc_), Returns(Value(1LL)));
}

TEST_F(LogicalMaximumFunctionTest, NullInputSkip) {
  auto expr = testutil::LogicalMaxExpr({NullExpr, SharedConstant(Value(1LL))});
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(1LL)));
}

TEST_F(LogicalMaximumFunctionTest, EquivalentNumerics) {
  auto expr = testutil::LogicalMaxExpr(
      {SharedConstant(Value(1LL)), SharedConstant(Value(1.0))});
  // Max(1, 1.0) -> 1 (or 1.0, they are equivalent, result depends on internal
  // order) Let's check if it's equivalent to 1LL
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(1LL)));
}

// --- LogicalMinimum Tests ---
class LogicalMinimumFunctionTest : public LogicalExpressionsTest {};

TEST_F(LogicalMinimumFunctionTest, NumericType) {
  auto expr = testutil::LogicalMinExpr(
      {SharedConstant(Value(1LL)),
       testutil::LogicalMinExpr(
           {SharedConstant(Value(2.0)), SharedConstant(Value(3LL))})});
  EXPECT_THAT(EvaluateExpr(*expr),
              Returns(Value(1LL)));  // Min(1, Min(2.0, 3)) -> 1
}

TEST_F(LogicalMinimumFunctionTest, StringType) {
  auto expr = testutil::LogicalMinExpr(
      {testutil::LogicalMinExpr(
           {SharedConstant(Value("a")), SharedConstant(Value("b"))}),
       SharedConstant(Value("c"))});
  EXPECT_THAT(EvaluateExpr(*expr),
              Returns(Value("a")));  // Min(Min("a", "b"), "c") -> "a"
}

TEST_F(LogicalMinimumFunctionTest, MixedType) {
  // Type order: Null < Bool < Number < Timestamp < String < Blob < Ref <
  // GeoPoint < Array < Map
  auto expr = testutil::LogicalMinExpr(
      {SharedConstant(Value(1LL)),
       testutil::LogicalMinExpr(
           {SharedConstant(Value("1")), SharedConstant(Value(0LL))})});
  EXPECT_THAT(
      EvaluateExpr(*expr),
      Returns(Value(0LL)));  // Min(1, Min("1", 0)) -> 0 (Number < String)
}

TEST_F(LogicalMinimumFunctionTest, OnlyNullAndErrorReturnsNull) {
  auto expr = testutil::LogicalMinExpr({NullExpr, ErrorExpr()});
  EXPECT_THAT(EvaluateExpr(*expr, error_doc_), ReturnsNull());
}

TEST_F(LogicalMinimumFunctionTest, NanAndNumbers) {
  // NaN is handled specially; it's considered the minimum unless skipped.
  auto expr = testutil::LogicalMinExpr({NanExpr, SharedConstant(Value(0LL))});
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(NAN)));  // Min(NaN, 0) -> NaN
  auto expr2 = testutil::LogicalMinExpr({SharedConstant(Value(0LL)), NanExpr});
  EXPECT_THAT(EvaluateExpr(*expr2), Returns(Value(NAN)));  // Min(0, NaN) -> NaN
  auto expr3 = testutil::LogicalMinExpr({NanExpr, NullExpr, ErrorExpr()});
  EXPECT_THAT(EvaluateExpr(*expr3, error_doc_),
              Returns(Value(NAN)));  // Min(NaN, Null, Error) -> NaN
  auto expr4 = testutil::LogicalMinExpr({NanExpr, ErrorExpr()});
  EXPECT_THAT(EvaluateExpr(*expr4, error_doc_),
              Returns(Value(NAN)));  // Min(NaN, Error) -> NaN
}

TEST_F(LogicalMinimumFunctionTest, ErrorInputSkip) {
  auto expr =
      testutil::LogicalMinExpr({ErrorExpr(), SharedConstant(Value(1LL))});
  EXPECT_THAT(EvaluateExpr(*expr, error_doc_), Returns(Value(1LL)));
}

TEST_F(LogicalMinimumFunctionTest, NullInputSkip) {
  auto expr = testutil::LogicalMinExpr({NullExpr, SharedConstant(Value(1LL))});
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(1LL)));
}

TEST_F(LogicalMinimumFunctionTest, EquivalentNumerics) {
  auto expr = testutil::LogicalMinExpr(
      {SharedConstant(Value(1LL)), SharedConstant(Value(1.0))});
  // Min(1, 1.0) -> 1 (or 1.0, they are equivalent)
  EXPECT_THAT(EvaluateExpr(*expr), Returns(Value(1LL)));
}

// --- Not (!) Tests ---
class NotFunctionTest : public LogicalExpressionsTest {};

TEST_F(NotFunctionTest, TrueToFalse) {
  // Using EqExpr from comparison_test helpers for simplicity
  auto true_cond = testutil::EqExpr(
      {SharedConstant(Value(1LL)), SharedConstant(Value(1LL))});
  EXPECT_THAT(EvaluateExpr(*testutil::NotExpr(true_cond)),
              Returns(Value(false)));
}

TEST_F(NotFunctionTest, FalseToTrue) {
  // Using NeqExpr from comparison_test helpers for simplicity
  auto false_cond = testutil::NeqExpr(
      {SharedConstant(Value(1LL)), SharedConstant(Value(1LL))});
  EXPECT_THAT(EvaluateExpr(*testutil::NotExpr(false_cond)),
              Returns(Value(true)));
}

TEST_F(NotFunctionTest, NotErrorIsError) {
  EXPECT_THAT(EvaluateExpr(*testutil::NotExpr(ErrorExpr()), error_doc_),
              ReturnsError());
}

// --- Or (||) Tests ---
class OrFunctionTest : public LogicalExpressionsTest {};

// 2 Operands
TEST_F(OrFunctionTest, FalseFalseIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({FalseExpr, FalseExpr})),
              Returns(Value(false)));
}
TEST_F(OrFunctionTest, FalseErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({FalseExpr, ErrorExpr()}), error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, FalseTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({FalseExpr, TrueExpr})),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, ErrorFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), FalseExpr}), error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, ErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), ErrorExpr()}), error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, ErrorTrueIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), TrueExpr}), error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueFalseIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, FalseExpr})),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueErrorIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({TrueExpr, ErrorExpr()}), error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, TrueExpr})),
              Returns(Value(true)));
}

// 3 Operands
TEST_F(OrFunctionTest, FalseFalseFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({FalseExpr, FalseExpr, FalseExpr})),
      Returns(Value(false)));
}
TEST_F(OrFunctionTest, FalseFalseErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({FalseExpr, FalseExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, FalseFalseTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({FalseExpr, FalseExpr, TrueExpr})),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, FalseErrorFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({FalseExpr, ErrorExpr(), FalseExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, FalseErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({FalseExpr, ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, FalseErrorTrueIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({FalseExpr, ErrorExpr(), TrueExpr}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, FalseTrueFalseIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({FalseExpr, TrueExpr, FalseExpr})),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, FalseTrueErrorIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({FalseExpr, TrueExpr, ErrorExpr()}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, FalseTrueTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({FalseExpr, TrueExpr, TrueExpr})),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, ErrorFalseFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), FalseExpr, FalseExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, ErrorFalseErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), FalseExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, ErrorFalseTrueIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), FalseExpr, TrueExpr}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, ErrorErrorFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), ErrorExpr(), FalseExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, ErrorErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(OrFunctionTest, ErrorErrorTrueIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), ErrorExpr(), TrueExpr}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, ErrorTrueFalseIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), TrueExpr, FalseExpr}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, ErrorTrueErrorIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({ErrorExpr(), TrueExpr, ErrorExpr()}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, ErrorTrueTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({ErrorExpr(), TrueExpr, TrueExpr}),
                           error_doc_),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueFalseFalseIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, FalseExpr, FalseExpr})),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueFalseErrorIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({TrueExpr, FalseExpr, ErrorExpr()}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueFalseTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, FalseExpr, TrueExpr})),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueErrorFalseIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({TrueExpr, ErrorExpr(), FalseExpr}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueErrorErrorIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::OrExpr({TrueExpr, ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueErrorTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, ErrorExpr(), TrueExpr}),
                           error_doc_),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueTrueFalseIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, TrueExpr, FalseExpr})),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueTrueErrorIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, TrueExpr, ErrorExpr()}),
                           error_doc_),
              Returns(Value(true)));
}
TEST_F(OrFunctionTest, TrueTrueTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, TrueExpr, TrueExpr})),
              Returns(Value(true)));
}

// Nested
TEST_F(OrFunctionTest, NestedOr) {
  auto child = testutil::OrExpr({TrueExpr, FalseExpr});
  auto f = testutil::OrExpr({child, FalseExpr});
  EXPECT_THAT(EvaluateExpr(*f), Returns(Value(true)));
}

// Multiple Arguments (already covered by 3-operand tests)
TEST_F(OrFunctionTest, MultipleArguments) {
  EXPECT_THAT(EvaluateExpr(*testutil::OrExpr({TrueExpr, FalseExpr, TrueExpr})),
              Returns(Value(true)));
}

// --- Xor Tests ---
class XorFunctionTest : public LogicalExpressionsTest {};

// 2 Operands
TEST_F(XorFunctionTest, FalseFalseIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({FalseExpr, FalseExpr})),
              Returns(Value(false)));
}
TEST_F(XorFunctionTest, FalseErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, ErrorExpr()}), error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, FalseTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({FalseExpr, TrueExpr})),
              Returns(Value(true)));
}
TEST_F(XorFunctionTest, ErrorFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), FalseExpr}), error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), ErrorExpr()}), error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), TrueExpr}), error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, TrueFalseIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({TrueExpr, FalseExpr})),
              Returns(Value(true)));
}
TEST_F(XorFunctionTest, TrueErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({TrueExpr, ErrorExpr()}), error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, TrueTrueIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({TrueExpr, TrueExpr})),
              Returns(Value(false)));
}

// 3 Operands (XOR is true if an odd number of inputs are true)
TEST_F(XorFunctionTest, FalseFalseFalseIsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, FalseExpr, FalseExpr})),
      Returns(Value(false)));  // 0 true -> false
}
TEST_F(XorFunctionTest, FalseFalseErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, FalseExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, FalseFalseTrueIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, FalseExpr, TrueExpr})),
      Returns(Value(true)));  // 1 true -> true
}
TEST_F(XorFunctionTest, FalseErrorFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, ErrorExpr(), FalseExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, FalseErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, FalseErrorTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, ErrorExpr(), TrueExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, FalseTrueFalseIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, TrueExpr, FalseExpr})),
      Returns(Value(true)));  // 1 true -> true
}
TEST_F(XorFunctionTest, FalseTrueErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({FalseExpr, TrueExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, FalseTrueTrueIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({FalseExpr, TrueExpr, TrueExpr})),
              Returns(Value(false)));  // 2 true -> false
}
TEST_F(XorFunctionTest, ErrorFalseFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), FalseExpr, FalseExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorFalseErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), FalseExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorFalseTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), FalseExpr, TrueExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorErrorFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), ErrorExpr(), FalseExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorErrorTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), ErrorExpr(), TrueExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorTrueFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), TrueExpr, FalseExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorTrueErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), TrueExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, ErrorTrueTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({ErrorExpr(), TrueExpr, TrueExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, TrueFalseFalseIsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({TrueExpr, FalseExpr, FalseExpr})),
      Returns(Value(true)));  // 1 true -> true
}
TEST_F(XorFunctionTest, TrueFalseErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({TrueExpr, FalseExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, TrueFalseTrueIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({TrueExpr, FalseExpr, TrueExpr})),
              Returns(Value(false)));  // 2 true -> false
}
TEST_F(XorFunctionTest, TrueErrorFalseIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({TrueExpr, ErrorExpr(), FalseExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, TrueErrorErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({TrueExpr, ErrorExpr(), ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, TrueErrorTrueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({TrueExpr, ErrorExpr(), TrueExpr}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, TrueTrueFalseIsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({TrueExpr, TrueExpr, FalseExpr})),
              Returns(Value(false)));  // 2 true -> false
}
TEST_F(XorFunctionTest, TrueTrueErrorIsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::XorExpr({TrueExpr, TrueExpr, ErrorExpr()}),
                   error_doc_),
      ReturnsError());
}
TEST_F(XorFunctionTest, TrueTrueTrueIsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({TrueExpr, TrueExpr, TrueExpr})),
              Returns(Value(true)));  // 3 true -> true
}

// Nested
TEST_F(XorFunctionTest, NestedXor) {
  auto child = testutil::XorExpr({TrueExpr, FalseExpr});  // child -> true
  auto f = testutil::XorExpr({child, TrueExpr});  // xor(true, true) -> false
  EXPECT_THAT(EvaluateExpr(*f), Returns(Value(false)));
}

// Multiple Arguments (already covered by 3-operand tests)
TEST_F(XorFunctionTest, MultipleArguments) {
  EXPECT_THAT(EvaluateExpr(*testutil::XorExpr({TrueExpr, FalseExpr, TrueExpr})),
              Returns(Value(false)));  // 2 true -> false
}

// --- IsNull Tests ---
class IsNullFunctionTest : public LogicalExpressionsTest {};

TEST_F(IsNullFunctionTest, NullReturnsTrue) {
  EXPECT_THAT(EvaluateExpr(*testutil::IsNullExpr(NullExpr)),
              Returns(Value(true)));
}

TEST_F(IsNullFunctionTest, ErrorReturnsError) {
  EXPECT_THAT(EvaluateExpr(*testutil::IsNullExpr(ErrorExpr()), error_doc_),
              ReturnsError());
}

TEST_F(IsNullFunctionTest, UnsetReturnsError) {
  EXPECT_THAT(EvaluateExpr(*testutil::IsNullExpr(Field("non-existent-field"))),
              ReturnsError());
}

TEST_F(IsNullFunctionTest, AnythingButNullReturnsFalse) {
  // Use the test data from ComparisonValueTestData
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*testutil::IsNullExpr(val)),
                Returns(Value(false)));
  }
  // Explicitly test NaN as well
  EXPECT_THAT(EvaluateExpr(*testutil::IsNullExpr(NanExpr)),
              Returns(Value(false)));
}

// --- IsNotNull Tests ---
class IsNotNullFunctionTest : public LogicalExpressionsTest {};

TEST_F(IsNotNullFunctionTest, NullReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*testutil::IsNotNullExpr(NullExpr)),
              Returns(Value(false)));
}

TEST_F(IsNotNullFunctionTest, ErrorReturnsError) {
  EXPECT_THAT(EvaluateExpr(*testutil::IsNotNullExpr(ErrorExpr()), error_doc_),
              ReturnsError());
}

TEST_F(IsNotNullFunctionTest, UnsetReturnsError) {
  EXPECT_THAT(
      EvaluateExpr(*testutil::IsNotNullExpr(Field("non-existent-field"))),
      ReturnsError());
}

TEST_F(IsNotNullFunctionTest, AnythingButNullReturnsTrue) {
  // Use the test data from ComparisonValueTestData
  for (const auto& val :
       ComparisonValueTestData::AllSupportedComparableValues()) {
    EXPECT_THAT(EvaluateExpr(*testutil::IsNotNullExpr(val)),
                Returns(Value(true)));
  }
  // Explicitly test NaN as well
  EXPECT_THAT(EvaluateExpr(*testutil::IsNotNullExpr(NanExpr)),
              Returns(Value(true)));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
