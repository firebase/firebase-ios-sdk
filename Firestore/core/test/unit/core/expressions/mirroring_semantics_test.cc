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

#include <functional>  // For std::function
#include <limits>      // For std::numeric_limits
#include <memory>      // For std::shared_ptr
#include <string>
#include <utility>  // For std::move
#include <vector>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/field_path.h"  // Correct include for FieldPath
#include "Firestore/core/src/util/string_format.h"  // Include for StringFormat
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Expr;
using api::Field;  // Correct expression type for field access
using api::FunctionExpr;
using model::FieldPath;  // Use FieldPath model type
using testing::_;
using testutil::AddExpr;
using testutil::ArrayContainsAllExpr;
using testutil::ArrayContainsAnyExpr;
using testutil::ArrayContainsExpr;
using testutil::ArrayLengthExpr;
using testutil::ByteLengthExpr;
using testutil::CharLengthExpr;
using testutil::DivideExpr;
using testutil::EndsWithExpr;
using testutil::EqAnyExpr;
using testutil::EqExpr;
using testutil::EvaluateExpr;
using testutil::GteExpr;
using testutil::GtExpr;
using testutil::IsNanExpr;
using testutil::IsNotNanExpr;
using testutil::LikeExpr;
using testutil::LteExpr;
using testutil::LtExpr;
using testutil::ModExpr;
using testutil::MultiplyExpr;
using testutil::NeqExpr;
using testutil::NotEqAnyExpr;
using testutil::RegexContainsExpr;
using testutil::RegexMatchExpr;
using testutil::Returns;
using testutil::ReturnsError;
using testutil::ReturnsNull;
using testutil::ReverseExpr;
using testutil::SharedConstant;
using testutil::StartsWithExpr;
using testutil::StrConcatExpr;
using testutil::StrContainsExpr;
using testutil::SubtractExpr;
using testutil::TimestampToUnixMicrosExpr;
using testutil::TimestampToUnixMillisExpr;
using testutil::TimestampToUnixSecondsExpr;
using testutil::ToLowerExpr;
using testutil::ToUpperExpr;
using testutil::TrimExpr;
using testutil::UnixMicrosToTimestampExpr;
using testutil::UnixMillisToTimestampExpr;
using testutil::UnixSecondsToTimestampExpr;
using testutil::Value;
using util::StringFormat;  // Using declaration for StringFormat

// Base fixture for mirroring semantics tests
class MirroringSemanticsTest : public ::testing::Test {
 protected:
  // Define common input expressions
  const std::shared_ptr<Expr> NULL_INPUT = SharedConstant(nullptr);
  // Error: Integer division by zero
  const std::shared_ptr<Expr> ERROR_INPUT =
      DivideExpr({SharedConstant(1LL), SharedConstant(0LL)});
  // Unset: Field that doesn't exist in the default test document
  const std::shared_ptr<Expr> UNSET_INPUT =
      std::make_shared<Field>("non-existent-field");
  // Valid: A simple valid input for binary tests
  const std::shared_ptr<Expr> VALID_INPUT = SharedConstant(42LL);
};

// --- Unary Function Tests ---

TEST_F(MirroringSemanticsTest, UnaryFunctionInputMirroring) {
  using UnaryBuilder =
      std::function<std::shared_ptr<Expr>(std::shared_ptr<Expr>)>;

  const std::vector<UnaryBuilder> unary_function_builders = {
      [](auto v) { return IsNanExpr(v); },
      [](auto v) { return IsNotNanExpr(v); },
      [](auto v) { return ArrayLengthExpr(v); },
      [](auto v) { return ReverseExpr(v); },
      [](auto v) { return CharLengthExpr(v); },
      [](auto v) { return ByteLengthExpr(v); },
      [](auto v) { return ToLowerExpr(v); },
      [](auto v) { return ToUpperExpr(v); },
      [](auto v) { return TrimExpr(v); },
      [](auto v) { return UnixMicrosToTimestampExpr(v); },
      [](auto v) { return TimestampToUnixMicrosExpr(v); },
      [](auto v) { return UnixMillisToTimestampExpr(v); },
      [](auto v) { return TimestampToUnixMillisExpr(v); },
      [](auto v) { return UnixSecondsToTimestampExpr(v); },
      [](auto v) { return TimestampToUnixSecondsExpr(v); }};

  struct TestCase {
    std::shared_ptr<Expr> input_expr;
    testing::Matcher<const EvaluateResult&> expected_matcher;
    std::string description;
  };

  const std::vector<TestCase> test_cases = {
      {NULL_INPUT, ReturnsNull(), "NULL"},
      {ERROR_INPUT, ReturnsError(), "ERROR"},
      {UNSET_INPUT, ReturnsError(), "UNSET"}  // Unary ops expect resolved args
  };

  for (const auto& builder : unary_function_builders) {
    // Get function name for better error messages (requires a dummy call)
    std::string func_name = "unknown";
    auto dummy_expr = builder(SharedConstant("dummy"));
    if (auto func_expr = std::dynamic_pointer_cast<FunctionExpr>(dummy_expr)) {
      func_name = func_expr->name();
    }

    for (const auto& test_case : test_cases) {
      SCOPED_TRACE(StringFormat("Function: %s, Input: %s", func_name,
                                test_case.description));

      std::shared_ptr<Expr> expr_to_evaluate;
      expr_to_evaluate = builder(test_case.input_expr);
      EXPECT_THAT(EvaluateExpr(*expr_to_evaluate), test_case.expected_matcher);
    }
  }
}

// --- Binary Function Tests ---

TEST_F(MirroringSemanticsTest, BinaryFunctionInputMirroring) {
  using BinaryBuilder = std::function<std::shared_ptr<Expr>(
      std::shared_ptr<Expr>, std::shared_ptr<Expr>)>;

  // Note: Variadic functions like add, multiply, str_concat are tested
  // with their base binary case here.
  const std::vector<BinaryBuilder> binary_function_builders = {
      // Arithmetic (Variadic, base is binary)
      [](auto v1, auto v2) { return AddExpr({v1, v2}); },
      [](auto v1, auto v2) { return SubtractExpr({v1, v2}); },
      [](auto v1, auto v2) { return MultiplyExpr({v1, v2}); },
      [](auto v1, auto v2) { return DivideExpr({v1, v2}); },
      [](auto v1, auto v2) { return ModExpr({v1, v2}); },
      // Comparison
      [](auto v1, auto v2) { return EqExpr({v1, v2}); },
      [](auto v1, auto v2) { return NeqExpr({v1, v2}); },
      [](auto v1, auto v2) { return LtExpr({v1, v2}); },
      [](auto v1, auto v2) { return LteExpr({v1, v2}); },
      [](auto v1, auto v2) { return GtExpr({v1, v2}); },
      [](auto v1, auto v2) { return GteExpr({v1, v2}); },
      // Array
      [](auto v1, auto v2) { return ArrayContainsExpr({v1, v2}); },
      [](auto v1, auto v2) { return ArrayContainsAllExpr({v1, v2}); },
      [](auto v1, auto v2) { return ArrayContainsAnyExpr({v1, v2}); },
      [](auto v1, auto v2) { return EqAnyExpr(v1, v2); },
      [](auto v1, auto v2) { return NotEqAnyExpr(v1, v2); },
      // String
      [](auto v1, auto v2) { return LikeExpr(v1, v2); },
      [](auto v1, auto v2) { return RegexContainsExpr(v1, v2); },
      [](auto v1, auto v2) { return RegexMatchExpr(v1, v2); },
      [](auto v1, auto v2) { return StrContainsExpr(v1, v2); },
      [](auto v1, auto v2) { return StartsWithExpr(v1, v2); },
      [](auto v1, auto v2) { return EndsWithExpr(v1, v2); },
      [](auto v1, auto v2) { return StrConcatExpr({v1, v2}); }
      // TODO(b/351084804): mapGet is not implemented yet
  };

  struct BinaryTestCase {
    std::shared_ptr<Expr> left;
    std::shared_ptr<Expr> right;
    testing::Matcher<const EvaluateResult&> expected_matcher;
    std::string description;
  };

  const std::vector<BinaryTestCase> test_cases = {
      // Rule 1: NULL, NULL -> NULL
      {NULL_INPUT, NULL_INPUT, ReturnsNull(), "NULL, NULL -> NULL"},
      // Rule 2: Error/Unset propagation
      {NULL_INPUT, ERROR_INPUT, ReturnsError(), "NULL, ERROR -> ERROR"},
      {ERROR_INPUT, NULL_INPUT, ReturnsError(), "ERROR, NULL -> ERROR"},
      {NULL_INPUT, UNSET_INPUT, ReturnsError(), "NULL, UNSET -> ERROR"},
      {UNSET_INPUT, NULL_INPUT, ReturnsError(), "UNSET, NULL -> ERROR"},
      {ERROR_INPUT, ERROR_INPUT, ReturnsError(), "ERROR, ERROR -> ERROR"},
      {ERROR_INPUT, UNSET_INPUT, ReturnsError(), "ERROR, UNSET -> ERROR"},
      {UNSET_INPUT, ERROR_INPUT, ReturnsError(), "UNSET, ERROR -> ERROR"},
      {UNSET_INPUT, UNSET_INPUT, ReturnsError(), "UNSET, UNSET -> ERROR"},
      {VALID_INPUT, ERROR_INPUT, ReturnsError(), "VALID, ERROR -> ERROR"},
      {ERROR_INPUT, VALID_INPUT, ReturnsError(), "ERROR, VALID -> ERROR"},
      {VALID_INPUT, UNSET_INPUT, ReturnsError(), "VALID, UNSET -> ERROR"},
      {UNSET_INPUT, VALID_INPUT, ReturnsError(), "UNSET, VALID -> ERROR"}};

  for (const auto& builder : binary_function_builders) {
    // Get function name for better error messages (requires a dummy call)
    std::string func_name = "unknown";
    auto dummy_expr =
        builder(SharedConstant("dummy1"), SharedConstant("dummy2"));
    if (auto func_expr = std::dynamic_pointer_cast<FunctionExpr>(dummy_expr)) {
      func_name = func_expr->name();
    }

    for (const auto& test_case : test_cases) {
      SCOPED_TRACE(StringFormat("Function: %s, Case: %s", func_name,
                                test_case.description));

      std::shared_ptr<Expr> expr_to_evaluate;
      expr_to_evaluate = builder(test_case.left, test_case.right);

      EXPECT_THAT(EvaluateExpr(*expr_to_evaluate), test_case.expected_matcher);
    }
  }
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
