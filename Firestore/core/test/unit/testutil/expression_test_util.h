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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_EXPRESSION_TEST_UTIL_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_EXPRESSION_TEST_UTIL_H_

#include <algorithm>         // For std::sort
#include <initializer_list>  // For std::initializer_list
#include <limits>            // For std::numeric_limits
#include <memory>            // For std::shared_ptr, std::make_shared
#include <ostream>           // For std::ostream
#include <string>            // For std::string
#include <utility>           // For std::move, std::pair
#include <vector>

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/string_format.h"  // For StringFormat
#include "Firestore/core/test/unit/testutil/testutil.h"

#include "absl/strings/escaping.h"  // For absl::HexStringToBytes
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace testutil {

using api::Constant;
using api::EvaluateContext;
using api::Expr;
using api::FunctionExpr;
using core::EvaluableExpr;
using core::EvaluateResult;
using model::DatabaseId;
using model::DocumentKey;
using model::GetTypeOrder;
using model::MutableDocument;  // PipelineInputOutput is MutableDocument
using model::ObjectValue;
using model::SnapshotVersion;
using nanopb::Message;
using remote::Serializer;
using util::StringFormat;

// --- Constant Expression Helpers ---

inline std::shared_ptr<Expr> SharedConstant(int64_t value) {
  return std::make_shared<Constant>(Value(value));
}

inline std::shared_ptr<Expr> SharedConstant(double value) {
  return std::make_shared<Constant>(Value(value));
}

inline std::shared_ptr<Expr> SharedConstant(std::nullptr_t) {
  return std::make_shared<Constant>(Value(nullptr));
}

inline std::shared_ptr<Expr> SharedConstant(const char* value) {
  return std::make_shared<Constant>(Value(value));
}

inline std::shared_ptr<Expr> SharedConstant(bool value) {
  return std::make_shared<Constant>(Value(value));
}

inline std::shared_ptr<Expr> SharedConstant(Timestamp value) {
  return std::make_shared<Constant>(Value(value));
}

inline std::shared_ptr<Expr> SharedConstant(GeoPoint value) {
  return std::make_shared<Constant>(Value(value));
}

// Overload for google_firestore_v1_Value
inline std::shared_ptr<Expr> SharedConstant(
    const google_firestore_v1_Value& value) {
  // Constant expects a Message<Value>, so clone it.
  return std::make_shared<Constant>(model::DeepClone(value));
}

inline std::shared_ptr<Expr> SharedConstant(
    Message<google_firestore_v1_ArrayValue> value) {
  // Constant expects a Message<Value>, so clone it.
  return std::make_shared<Constant>(Value(std::move(value)));
}

inline std::shared_ptr<Expr> SharedConstant(
    Message<google_firestore_v1_Value> value) {
  // Constant expects a Message<Value>, so clone it.
  return std::make_shared<Constant>(std::move(value));
}

// Helper to create a Reference Value Constant for tests
// Needs to be defined before use in ENTITY_REF_VALUES if defined statically
inline std::shared_ptr<Expr> RefConstant(const std::string& path) {
  static const DatabaseId db_id("test-project", "test-database");
  // model::RefValue returns a Message<Value>, pass its content to
  // SharedConstant
  return SharedConstant(
      *model::RefValue(db_id, DocumentKey::FromPathString(path)));
}

inline std::shared_ptr<Expr> AddExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  return std::make_shared<FunctionExpr>(
      "add", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> SubtractExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  return std::make_shared<FunctionExpr>(
      "subtract", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> MultiplyExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  return std::make_shared<FunctionExpr>(
      "multiply", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> DivideExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  return std::make_shared<FunctionExpr>(
      "divide", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> ModExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  return std::make_shared<FunctionExpr>(
      "mod", std::vector<std::shared_ptr<Expr>>(params));
}

// --- Timestamp Expression Helpers ---

inline std::shared_ptr<Expr> UnixMicrosToTimestampExpr(
    std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "unix_micros_to_timestamp",
      std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> UnixMillisToTimestampExpr(
    std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "unix_millis_to_timestamp",
      std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> UnixSecondsToTimestampExpr(
    std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "unix_seconds_to_timestamp",
      std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> TimestampToUnixMicrosExpr(
    std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "timestamp_to_unix_micros",
      std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> TimestampToUnixMillisExpr(
    std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "timestamp_to_unix_millis",
      std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> TimestampToUnixSecondsExpr(
    std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "timestamp_to_unix_seconds",
      std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> TimestampAddExpr(std::shared_ptr<Expr> timestamp,
                                              std::shared_ptr<Expr> unit,
                                              std::shared_ptr<Expr> amount) {
  return std::make_shared<FunctionExpr>(
      "timestamp_add",
      std::vector<std::shared_ptr<Expr>>{std::move(timestamp), std::move(unit),
                                         std::move(amount)});
}

// --- Comparison Expression Helpers ---

inline std::shared_ptr<Expr> EqExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  HARD_ASSERT(params.size() == 2, "EqExpr requires exactly 2 parameters");
  return std::make_shared<FunctionExpr>(
      "eq", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> NeqExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  HARD_ASSERT(params.size() == 2, "NeqExpr requires exactly 2 parameters");
  return std::make_shared<FunctionExpr>(
      "neq", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> LtExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  HARD_ASSERT(params.size() == 2, "LtExpr requires exactly 2 parameters");
  return std::make_shared<FunctionExpr>(
      "lt", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> LteExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  HARD_ASSERT(params.size() == 2, "LteExpr requires exactly 2 parameters");
  return std::make_shared<FunctionExpr>(
      "lte", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> GtExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  HARD_ASSERT(params.size() == 2, "GtExpr requires exactly 2 parameters");
  return std::make_shared<FunctionExpr>(
      "gt", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> GteExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  HARD_ASSERT(params.size() == 2, "GteExpr requires exactly 2 parameters");
  return std::make_shared<FunctionExpr>(
      "gte", std::vector<std::shared_ptr<Expr>>(params));
}

// --- Array Expression Helpers ---

inline std::shared_ptr<Expr> ArrayContainsAllExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  return std::make_shared<FunctionExpr>(
      "array_contains_all", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> ArrayContainsAnyExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  return std::make_shared<FunctionExpr>(
      "array_contains_any", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> ArrayContainsExpr(
    std::initializer_list<std::shared_ptr<Expr>> params) {
  return std::make_shared<FunctionExpr>(
      "array_contains", std::vector<std::shared_ptr<Expr>>(params));
}

inline std::shared_ptr<Expr> ArrayLengthExpr(std::shared_ptr<Expr> array_expr) {
  return std::make_shared<FunctionExpr>(
      "array_length", std::vector<std::shared_ptr<Expr>>{array_expr});
}

// TODO(b/351084804): Add ArrayConcatExpr, ArrayReverseExpr, ArrayElementExpr
// when needed.

// --- Logical Expression Helpers ---

inline std::shared_ptr<Expr> AndExpr(
    std::vector<std::shared_ptr<Expr>> operands) {
  return std::make_shared<FunctionExpr>("and", std::move(operands));
}

inline std::shared_ptr<Expr> OrExpr(
    std::vector<std::shared_ptr<Expr>> operands) {
  return std::make_shared<FunctionExpr>("or", std::move(operands));
}

inline std::shared_ptr<Expr> XorExpr(
    std::vector<std::shared_ptr<Expr>> operands) {
  return std::make_shared<FunctionExpr>("xor", std::move(operands));
}

// Note: NotExpr already exists below in Debugging section, reusing that one.

inline std::shared_ptr<Expr> CondExpr(std::shared_ptr<Expr> condition,
                                      std::shared_ptr<Expr> true_case,
                                      std::shared_ptr<Expr> false_case) {
  return std::make_shared<FunctionExpr>(
      "cond",
      std::vector<std::shared_ptr<Expr>>{
          std::move(condition), std::move(true_case), std::move(false_case)});
}

inline std::shared_ptr<Expr> EqAnyExpr(std::shared_ptr<Expr> search,
                                       std::shared_ptr<Expr> values) {
  std::vector<std::shared_ptr<Expr>> operands;
  operands.push_back(std::move(search));
  operands.push_back(std::move(values));
  return std::make_shared<FunctionExpr>("eq_any", std::move(operands));
}

inline std::shared_ptr<Expr> NotEqAnyExpr(std::shared_ptr<Expr> search,
                                          std::shared_ptr<Expr> values) {
  std::vector<std::shared_ptr<Expr>> operands;
  operands.push_back(std::move(search));
  operands.push_back(std::move(values));
  return std::make_shared<FunctionExpr>("not_eq_any", std::move(operands));
}

inline std::shared_ptr<Expr> IsNanExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "is_nan", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> IsNotNanExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "is_not_nan", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> IsNullExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "is_null", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> IsNotNullExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "is_not_null", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> IsErrorExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "is_error", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> LogicalMaxExpr(
    std::vector<std::shared_ptr<Expr>> operands) {
  return std::make_shared<FunctionExpr>("logical_maximum", std::move(operands));
}

inline std::shared_ptr<Expr> LogicalMinExpr(
    std::vector<std::shared_ptr<Expr>> operands) {
  return std::make_shared<FunctionExpr>("logical_minimum", std::move(operands));
}

// --- Debugging Expression Helpers ---

inline std::shared_ptr<Expr> ExistsExpr(std::shared_ptr<Expr> param) {
  return std::make_shared<FunctionExpr>(
      "exists", std::vector<std::shared_ptr<Expr>>{param});
}

// Note: NotExpr defined here, used by logical tests as well.
inline std::shared_ptr<Expr> NotExpr(std::shared_ptr<Expr> param) {
  // Corrected to use FunctionExpr consistently
  return std::make_shared<FunctionExpr>(
      "not", std::vector<std::shared_ptr<Expr>>{std::move(param)});
}

// Helper to check if two expressions (assumed Constants) have comparable types.
// Assuming Constant::value() returns the nanopb::Message<Value> object.
inline bool IsTypeComparable(const std::shared_ptr<Expr>& left,
                             const std::shared_ptr<Expr>& right) {
  auto left_const = std::dynamic_pointer_cast<const Constant>(left);
  auto right_const = std::dynamic_pointer_cast<const Constant>(right);
  HARD_ASSERT(left_const && right_const,
              "IsTypeComparable expects Constant expressions");
  // Access the underlying nanopb message via *value()
  return GetTypeOrder(left_const->to_proto()) ==
         GetTypeOrder(right_const->to_proto());
}

// --- Comparison Test Data ---

// Defines pairs of expressions for comparison testing.
using ExprPair = std::pair<std::shared_ptr<Expr>, std::shared_ptr<Expr>>;

struct ComparisonValueTestData {
 private:
  // Define the base value lists matching TypeScript (assumed sorted internally)
  static const std::vector<std::shared_ptr<Expr>> BOOLEAN_VALUES;
  static const std::vector<std::shared_ptr<Expr>> NUMERIC_VALUES;
  static const std::vector<std::shared_ptr<Expr>> TIMESTAMP_VALUES;
  static const std::vector<std::shared_ptr<Expr>> STRING_VALUES;
  static const std::vector<std::shared_ptr<Expr>> BYTE_VALUES;
  static const std::vector<std::shared_ptr<Expr>> ENTITY_REF_VALUES;
  static const std::vector<std::shared_ptr<Expr>> GEO_VALUES;
  static const std::vector<std::shared_ptr<Expr>> ARRAY_VALUES;
  static const std::vector<std::shared_ptr<Expr>> MAP_VALUES;
  // Note: VECTOR_VALUES omitted as VectorValue is not yet supported in C++
  // expressions

 public:
  // A representative list of all comparable value types for null/error tests.
  // Excludes NullValue itself. Concatenated in TypeOrder.
  static const std::vector<std::shared_ptr<Expr>>&
  AllSupportedComparableValues() {
    static const std::vector<std::shared_ptr<Expr>> combined = [] {
      std::vector<std::shared_ptr<Expr>> all_values;
      // Concatenate in Firestore TypeOrder
      all_values.insert(all_values.end(), BOOLEAN_VALUES.begin(),
                        BOOLEAN_VALUES.end());
      all_values.insert(all_values.end(), NUMERIC_VALUES.begin(),
                        NUMERIC_VALUES.end());
      all_values.insert(all_values.end(), TIMESTAMP_VALUES.begin(),
                        TIMESTAMP_VALUES.end());
      all_values.insert(all_values.end(), STRING_VALUES.begin(),
                        STRING_VALUES.end());
      all_values.insert(all_values.end(), BYTE_VALUES.begin(),
                        BYTE_VALUES.end());
      all_values.insert(all_values.end(), ENTITY_REF_VALUES.begin(),
                        ENTITY_REF_VALUES.end());
      all_values.insert(all_values.end(), GEO_VALUES.begin(), GEO_VALUES.end());
      all_values.insert(all_values.end(), ARRAY_VALUES.begin(),
                        ARRAY_VALUES.end());
      all_values.insert(all_values.end(), MAP_VALUES.begin(), MAP_VALUES.end());
      // No sort needed if base lists are sorted and concatenated correctly.
      return all_values;
    }();
    return combined;
  }

  // Values that should compare as equal.
  static std::vector<ExprPair> EquivalentValues() {
    std::vector<ExprPair> results;
    const auto& all_values = AllSupportedComparableValues();
    for (const auto& value : all_values) {
      results.push_back({value, value});
    }

    results.push_back({SharedConstant(-42LL), SharedConstant(-42.0)});
    results.push_back({SharedConstant(-42.0), SharedConstant(-42LL)});
    results.push_back({SharedConstant(42LL), SharedConstant(42.0)});
    results.push_back({SharedConstant(42.0), SharedConstant(42LL)});

    results.push_back({SharedConstant(0.0), SharedConstant(-0.0)});
    results.push_back({SharedConstant(-0.0), SharedConstant(0.0)});

    results.push_back({SharedConstant(0LL), SharedConstant(-0.0)});
    results.push_back({SharedConstant(-0.0), SharedConstant(0LL)});

    results.push_back({SharedConstant(0LL), SharedConstant(0.0)});
    results.push_back({SharedConstant(0.0), SharedConstant(0LL)});

    return results;
  }

  // Values where left < right. Relies on AllSupportedComparableValues being
  // sorted.
  static std::vector<ExprPair> LessThanValues() {
    std::vector<ExprPair> results;
    const auto& all_values = AllSupportedComparableValues();
    for (size_t i = 0; i < all_values.size(); ++i) {
      for (size_t j = i + 1; j < all_values.size(); ++j) {
        const auto& left = all_values[i];
        const auto& right = all_values[j];
        if (IsTypeComparable(left, right)) {
          // Since all_values is sorted by type then value,
          // and i < j, if types are comparable, left < right.
          // This includes pairs like {1, 1.0} which compare as !lessThan.
          // The calling test needs to handle the expected result.
          results.push_back({left, right});
        }
      }
    }
    return results;
  }

  // Values where left > right. Relies on AllSupportedComparableValues being
  // sorted.
  static std::vector<ExprPair> GreaterThanValues() {
    std::vector<ExprPair> results;
    const auto& all_values = AllSupportedComparableValues();
    for (size_t i = 0; i < all_values.size(); ++i) {
      for (size_t j = i + 1; j < all_values.size(); ++j) {
        const auto& left = all_values[i];   // left is smaller
        const auto& right = all_values[j];  // right is larger
        if (IsTypeComparable(left, right)) {
          // Since all_values is sorted, if types match, right > left.
          // Add the reversed pair {right, left}.
          // This includes pairs like {1.0, 1} which compare as !greaterThan.
          // The calling test needs to handle the expected result.
          results.push_back({right, left});  // Add reversed pair
        }
      }
    }
    return results;
  }

  // Values of different types.
  static std::vector<ExprPair> MixedTypeValues() {
    std::vector<ExprPair> results;
    const auto& all_values = AllSupportedComparableValues();
    for (size_t i = 0; i < all_values.size(); ++i) {
      for (size_t j = 0; j < all_values.size(); ++j) {  // Note: j starts from 0
        const auto& left = all_values[i];
        const auto& right = all_values[j];
        if (!IsTypeComparable(left, right)) {
          results.push_back({left, right});
        }
      }
    }
    return results;
  }

  // Numeric values for NaN tests (subset of NUMERIC_VALUES)
  static const std::vector<std::shared_ptr<Expr>>& NumericValues() {
    return NUMERIC_VALUES;
  }
};

static remote::Serializer serializer(model::DatabaseId("test-project"));

// Creates a default evaluation context.
inline api::EvaluateContext NewContext() {
  return EvaluateContext{&serializer, core::ListenOptions()};
}

// Helper function to evaluate an expression and return the result.
// Creates a dummy context and input document.
inline EvaluateResult EvaluateExpr(const Expr& expr) {
  // Use a dummy input document (FoundDocument with empty data)
  model::PipelineInputOutput input = testutil::Doc("coll/doc", 1);

  std::unique_ptr<EvaluableExpr> evaluable = expr.ToEvaluable();
  HARD_ASSERT(evaluable != nullptr, "Failed to create evaluable expression");
  return evaluable->Evaluate(NewContext(), input);
}

// Helper function to evaluate an expression with a specific input.
inline EvaluateResult EvaluateExpr(const Expr& expr,
                                   const model::PipelineInputOutput& input) {
  std::unique_ptr<EvaluableExpr> evaluable = expr.ToEvaluable();
  HARD_ASSERT(evaluable != nullptr, "Failed to create evaluable expression");
  return evaluable->Evaluate(NewContext(), input);
}

// --- Custom Gmock Matchers ---

MATCHER(ReturnsError, std::string("evaluates to error ")) {
  // 'arg' is the value being tested
  if (arg.type() == EvaluateResult::ResultType::kError) {
    return true;
  } else {
    *result_listener << "the result type is "
                     << testing::PrintToString(arg.type());
    return false;
  }
}

MATCHER(ReturnsNull, std::string("evaluates to null ")) {
  // 'arg' is the value being tested
  if (arg.type() == EvaluateResult::ResultType::kNull) {
    return true;
  } else {
    *result_listener << "the result type is "
                     << testing::PrintToString(arg.type());
    return false;
  }
}

MATCHER(ReturnsUnset, std::string("evaluates to unset ")) {
  // 'arg' is the value being tested
  if (arg.type() == EvaluateResult::ResultType::kUnset) {
    return true;
  } else {
    *result_listener << "the result type is "
                     << testing::PrintToString(arg.type());
    return false;
  }
}

template <typename T>
class ReturnsMatcherImpl : public testing::MatcherInterface<T> {
 public:
  explicit ReturnsMatcherImpl(
      Message<google_firestore_v1_Value>&& expected_value)
      : expected_value_(std::move(expected_value)) {
  }

  bool MatchAndExplain(T arg,
                       testing::MatchResultListener* listener) const override {
    if (!arg.IsErrorOrUnset()) {
      // Value is valid, proceed with comparison
      if (model::IsNaNValue(*expected_value_)) {
        *listener << "expected NaN, but got "
                  << model::CanonicalId(*arg.value());
        // Special handling for NaN: Both must be NaN to match
        return model::IsNaNValue(*arg.value());
      } else {
        *listener << "expected value " << model::CanonicalId(*expected_value_)
                  << ", but got " << model::CanonicalId(*arg.value());
        // Standard equality comparison
        return model::Equals(*arg.value(), *expected_value_);
      }
    } else {
      // The actual result 'arg' is an error or unset, but we expected a value.
      // This is considered a mismatch.
      *listener << "expected value, but got result type"
                << testing::PrintToString(arg.type());
      return false;
    }
  }

  void DescribeTo(std::ostream* os) const override {
    *os << "evaluates to value " << testing::PrintToString(expected_value_);
  }

  void DescribeNegationTo(std::ostream* os) const override {
    *os << "does not evaluate to value "
        << testing::PrintToString(expected_value_);
  }

 private:
  Message<google_firestore_v1_Value> expected_value_;
};

template <typename T = const EvaluateResult&>
inline testing::Matcher<T> Returns(
    Message<google_firestore_v1_Value>&& expected_value) {
  return testing::MakeMatcher(
      new ReturnsMatcherImpl<T>(std::move(expected_value)));
}

// --- String Expression Helpers ---

inline std::shared_ptr<Expr> CharLengthExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "char_length", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> ByteLengthExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "byte_length", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> ToLowerExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "to_lower", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> ToUpperExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "to_upper", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> ReverseExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "reverse", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> TrimExpr(std::shared_ptr<Expr> operand) {
  return std::make_shared<FunctionExpr>(
      "trim", std::vector<std::shared_ptr<Expr>>{std::move(operand)});
}

inline std::shared_ptr<Expr> LikeExpr(std::shared_ptr<Expr> value,
                                      std::shared_ptr<Expr> pattern) {
  return std::make_shared<FunctionExpr>(
      "like",
      std::vector<std::shared_ptr<Expr>>{std::move(value), std::move(pattern)});
}

inline std::shared_ptr<Expr> RegexContainsExpr(std::shared_ptr<Expr> value,
                                               std::shared_ptr<Expr> regex) {
  return std::make_shared<FunctionExpr>(
      "regex_contains",
      std::vector<std::shared_ptr<Expr>>{std::move(value), std::move(regex)});
}

inline std::shared_ptr<Expr> RegexMatchExpr(std::shared_ptr<Expr> value,
                                            std::shared_ptr<Expr> regex) {
  return std::make_shared<FunctionExpr>(
      "regex_match",
      std::vector<std::shared_ptr<Expr>>{std::move(value), std::move(regex)});
}

inline std::shared_ptr<Expr> StrContainsExpr(std::shared_ptr<Expr> value,
                                             std::shared_ptr<Expr> search) {
  return std::make_shared<FunctionExpr>(
      "str_contains",
      std::vector<std::shared_ptr<Expr>>{std::move(value), std::move(search)});
}

inline std::shared_ptr<Expr> StartsWithExpr(std::shared_ptr<Expr> value,
                                            std::shared_ptr<Expr> prefix) {
  return std::make_shared<FunctionExpr>(
      "starts_with",
      std::vector<std::shared_ptr<Expr>>{std::move(value), std::move(prefix)});
}

inline std::shared_ptr<Expr> EndsWithExpr(std::shared_ptr<Expr> value,
                                          std::shared_ptr<Expr> suffix) {
  return std::make_shared<FunctionExpr>(
      "ends_with",
      std::vector<std::shared_ptr<Expr>>{std::move(value), std::move(suffix)});
}

inline std::shared_ptr<Expr> StrConcatExpr(
    std::vector<std::shared_ptr<Expr>> operands) {
  return std::make_shared<FunctionExpr>("str_concat", std::move(operands));
}

// --- Vector Expression Helpers ---
// TODO(b/351084804): Add vector helpers when supported.

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_EXPRESSION_TEST_UTIL_H_
