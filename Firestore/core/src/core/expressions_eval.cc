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

#include "Firestore/core/src/core/expressions_eval.h"

#include <algorithm>  // For std::reverse
#include <cmath>
#include <limits>
#include <memory>
#include <utility>  // For std::move
#include <vector>   // For std::vector

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/value_util.h"  // For value helpers like IsArray, DeepClone
#include "Firestore/core/src/nanopb/message.h"  // Added for MakeMessage
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace core {

namespace {

// Helper functions for safe integer arithmetic with overflow detection.
// Return nullopt on overflow or error (like division by zero).

absl::optional<int64_t> SafeAdd(int64_t lhs, int64_t rhs) {
  int64_t result;
#if defined(__clang__) || defined(__GNUC__)
  if (__builtin_add_overflow(lhs, rhs, &result)) {
    return absl::nullopt;
  }
#else
  // Manual check (less efficient, might miss some edge cases on weird
  // platforms)
  if ((rhs > 0 && lhs > std::numeric_limits<int64_t>::max() - rhs) ||
      (rhs < 0 && lhs < std::numeric_limits<int64_t>::min() - rhs)) {
    return absl::nullopt;
  }
  result = lhs + rhs;
#endif
  return result;
}

absl::optional<int64_t> SafeSubtract(int64_t lhs, int64_t rhs) {
  int64_t result;
#if defined(__clang__) || defined(__GNUC__)
  if (__builtin_sub_overflow(lhs, rhs, &result)) {
    return absl::nullopt;
  }
#else
  // Manual check
  if ((rhs < 0 && lhs > std::numeric_limits<int64_t>::max() + rhs) ||
      (rhs > 0 && lhs < std::numeric_limits<int64_t>::min() + rhs)) {
    return absl::nullopt;
  }
  result = lhs - rhs;
#endif
  return result;
}

absl::optional<int64_t> SafeMultiply(int64_t lhs, int64_t rhs) {
  int64_t result;
#if defined(__clang__) || defined(__GNUC__)
  if (__builtin_mul_overflow(lhs, rhs, &result)) {
    return absl::nullopt;
  }
#else
  // Manual check (simplified, might not cover all edge cases perfectly)
  if (lhs != 0 && rhs != 0) {
    if (lhs > std::numeric_limits<int64_t>::max() / rhs ||
        lhs < std::numeric_limits<int64_t>::min() / rhs) {
      return absl::nullopt;
    }
  }
  result = lhs * rhs;
#endif
  return result;
}

absl::optional<int64_t> SafeDivide(int64_t lhs, int64_t rhs) {
  if (rhs == 0) {
    return absl::nullopt;  // Division by zero
  }
  // Check for overflow: INT64_MIN / -1
  if (lhs == std::numeric_limits<int64_t>::min() && rhs == -1) {
    return absl::nullopt;
  }
  return lhs / rhs;
}

absl::optional<int64_t> SafeMod(int64_t lhs, int64_t rhs) {
  if (rhs == 0) {
    return absl::nullopt;  // Modulo by zero
  }
  // Check for potential overflow/UB: INT64_MIN % -1
  if (lhs == std::numeric_limits<int64_t>::min() && rhs == -1) {
    // The result is 0 on most platforms, but standard allows signal.
    // Treat as error for consistency.
    return absl::nullopt;
  }
  return lhs % rhs;
}

// Helper to get double value, converting integer if necessary.
absl::optional<double> GetDoubleValue(const google_firestore_v1_Value& value) {
  if (model::IsDouble(value)) {
    return value.double_value;
  } else if (model::IsInteger(value)) {
    return static_cast<double>(value.integer_value);
  }
  return absl::nullopt;
}

// Helper to create a Value proto from int64_t
nanopb::Message<google_firestore_v1_Value> IntValue(int64_t val) {
  google_firestore_v1_Value proto;
  proto.which_value_type = google_firestore_v1_Value_integer_value_tag;
  proto.integer_value = val;
  return nanopb::MakeMessage(std::move(proto));
}

// Helper to create a Value proto from double
nanopb::Message<google_firestore_v1_Value> DoubleValue(double val) {
  google_firestore_v1_Value proto;
  proto.which_value_type = google_firestore_v1_Value_double_value_tag;
  proto.double_value = val;
  return nanopb::MakeMessage(std::move(proto));
}

// Common evaluation logic for binary arithmetic operations
template <typename IntOp, typename DoubleOp>
EvaluateResult EvaluateArithmetic(const api::FunctionExpr* expr,
                                  const api::EvaluateContext& context,
                                  const model::PipelineInputOutput& document,
                                  IntOp int_op,
                                  DoubleOp double_op) {
  HARD_ASSERT(expr->params().size() >= 2,
              "%s() function requires at least 2 params", expr->name());

  EvaluateResult current_result =
      expr->params()[0]->ToEvaluable()->Evaluate(context, document);

  for (size_t i = 1; i < expr->params().size(); ++i) {
    if (current_result.IsErrorOrUnset()) {
      return EvaluateResult::NewError();
    }
    if (current_result.IsNull()) {
      // Null propagates
      return EvaluateResult::NewNull();
    }

    EvaluateResult next_operand =
        expr->params()[i]->ToEvaluable()->Evaluate(context, document);

    if (next_operand.IsErrorOrUnset()) {
      return EvaluateResult::NewError();
    }
    if (next_operand.IsNull()) {
      // Null propagates
      return EvaluateResult::NewNull();
    }

    const google_firestore_v1_Value* left_val = current_result.value();
    const google_firestore_v1_Value* right_val = next_operand.value();

    // Type checking
    bool left_is_num = model::IsNumber(*left_val);
    bool right_is_num = model::IsNumber(*right_val);

    if (!left_is_num || !right_is_num) {
      return EvaluateResult::NewError();  // Type error
    }

    // NaN propagation
    if (model::IsNaNValue(*left_val) || model::IsNaNValue(*right_val)) {
      current_result =
          EvaluateResult::NewValue(nanopb::MakeMessage(model::NaNValue()));
      continue;
    }

    // Perform arithmetic
    if (model::IsDouble(*left_val) || model::IsDouble(*right_val)) {
      // Promote to double
      absl::optional<double> left_double = GetDoubleValue(*left_val);
      absl::optional<double> right_double = GetDoubleValue(*right_val);
      // Should always succeed due to IsNumber check above
      HARD_ASSERT(left_double.has_value() && right_double.has_value(),
                  "Failed to extract double values");

      double result_double =
          double_op(left_double.value(), right_double.value());
      current_result = EvaluateResult::NewValue(DoubleValue(result_double));

    } else {
      // Both are integers
      absl::optional<int64_t> left_int = model::GetInteger(*left_val);
      absl::optional<int64_t> right_int = model::GetInteger(*right_val);
      // Should always succeed due to IsNumber check above
      HARD_ASSERT(left_int.has_value() && right_int.has_value(),
                  "Failed to extract integer values");

      absl::optional<int64_t> result_int =
          int_op(left_int.value(), right_int.value());

      if (!result_int.has_value()) {
        // Overflow or division/mod by zero
        return EvaluateResult::NewError();
      }
      current_result = EvaluateResult::NewValue(IntValue(result_int.value()));
    }
  }

  return current_result;
}

}  // anonymous namespace

EvaluateResult::EvaluateResult(
    EvaluateResult::ResultType type,
    nanopb::Message<google_firestore_v1_Value> message)
    : value_(std::move(message)), type_(type) {
}

EvaluateResult EvaluateResult::NewNull() {
  return EvaluateResult(
      ResultType::kNull,
      nanopb::Message<google_firestore_v1_Value>(model::MinValue()));
}

EvaluateResult EvaluateResult::NewValue(
    nanopb::Message<google_firestore_v1_Value> value) {
  if (model::IsNullValue(*value)) {
    return EvaluateResult::NewNull();
  } else if (value->which_value_type ==
             google_firestore_v1_Value_boolean_value_tag) {
    return EvaluateResult(ResultType::kBoolean, std::move(value));
  } else if (model::IsInteger(*value)) {
    return EvaluateResult(ResultType::kInt, std::move(value));
  } else if (model::IsDouble(*value)) {
    return EvaluateResult(ResultType::kDouble, std::move(value));
  } else if (value->which_value_type ==
             google_firestore_v1_Value_timestamp_value_tag) {
    return EvaluateResult(ResultType::kTimestamp, std::move(value));
  } else if (value->which_value_type ==
             google_firestore_v1_Value_string_value_tag) {
    return EvaluateResult(ResultType::kString, std::move(value));
  } else if (value->which_value_type ==
             google_firestore_v1_Value_bytes_value_tag) {
    return EvaluateResult(ResultType::kBytes, std::move(value));
  } else if (value->which_value_type ==
             google_firestore_v1_Value_reference_value_tag) {
    return EvaluateResult(ResultType::kReference, std::move(value));
  } else if (value->which_value_type ==
             google_firestore_v1_Value_geo_point_value_tag) {
    return EvaluateResult(ResultType::kGeoPoint, std::move(value));
  } else if (model::IsArray(*value)) {
    return EvaluateResult(ResultType::kArray, std::move(value));
  } else if (model::IsVectorValue(*value)) {
    // vector value must be before map value
    return EvaluateResult(ResultType::kVector, std::move(value));
  } else if (model::IsMap(*value)) {
    return EvaluateResult(ResultType::kMap, std::move(value));
  } else {
    return EvaluateResult(ResultType::kError, {});
  }
}

std::unique_ptr<EvaluableExpr> FunctionToEvaluable(
    const api::FunctionExpr& function) {
  if (function.name() == "eq") {
    return std::make_unique<CoreEq>(function);
  } else if (function.name() == "add") {
    return std::make_unique<CoreAdd>(function);
  } else if (function.name() == "subtract") {
    return std::make_unique<CoreSubtract>(function);
  } else if (function.name() == "multiply") {
    return std::make_unique<CoreMultiply>(function);
  } else if (function.name() == "divide") {
    return std::make_unique<CoreDivide>(function);
  } else if (function.name() == "mod") {
    return std::make_unique<CoreMod>(function);
  } else if (function.name() == "neq") {
    return std::make_unique<CoreNeq>(function);
  } else if (function.name() == "lt") {
    return std::make_unique<CoreLt>(function);
  } else if (function.name() == "lte") {
    return std::make_unique<CoreLte>(function);
  } else if (function.name() == "gt") {
    return std::make_unique<CoreGt>(function);
  } else if (function.name() == "gte") {
    return std::make_unique<CoreGte>(function);
  } else if (function.name() == "array_reverse") {  // Removed array_concat
    return std::make_unique<CoreArrayReverse>(function);
  } else if (function.name() == "array_contains") {
    return std::make_unique<CoreArrayContains>(function);
  } else if (function.name() == "array_contains_all") {
    return std::make_unique<CoreArrayContainsAll>(function);
  } else if (function.name() == "array_contains_any") {
    return std::make_unique<CoreArrayContainsAny>(function);
  } else if (function.name() == "array_length") {
    return std::make_unique<CoreArrayLength>(function);
  } else if (function.name() == "exists") {
    return std::make_unique<CoreExists>(function);
  } else if (function.name() == "not") {
    return std::make_unique<CoreNot>(function);
  } else if (function.name() == "and") {
    return std::make_unique<CoreAnd>(function);
  } else if (function.name() == "or") {
    return std::make_unique<CoreOr>(function);
  } else if (function.name() == "xor") {
    return std::make_unique<CoreXor>(function);
  } else if (function.name() == "cond") {
    return std::make_unique<CoreCond>(function);
  } else if (function.name() == "eq_any") {
    return std::make_unique<CoreEqAny>(function);
  } else if (function.name() == "not_eq_any") {
    return std::make_unique<CoreNotEqAny>(function);
  } else if (function.name() == "is_nan") {
    return std::make_unique<CoreIsNan>(function);
  } else if (function.name() == "is_not_nan") {
    return std::make_unique<CoreIsNotNan>(function);
  } else if (function.name() == "is_null") {
    return std::make_unique<CoreIsNull>(function);
  } else if (function.name() == "is_not_null") {
    return std::make_unique<CoreIsNotNull>(function);
  } else if (function.name() == "is_error") {
    return std::make_unique<CoreIsError>(function);
  } else if (function.name() == "logical_maximum") {
    return std::make_unique<CoreLogicalMaximum>(function);
  } else if (function.name() == "logical_minimum") {
    return std::make_unique<CoreLogicalMinimum>(function);
  }
  // TODO(wuandy): Add other non-array/logical functions

  HARD_FAIL("Unsupported function name: %s", function.name());
}

EvaluateResult CoreField::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& input) const {
  auto* field = dynamic_cast<api::Field*>(expr_.get());
  if (field->alias() == model::FieldPath::kDocumentKeyPath) {
    google_firestore_v1_Value result;

    result.which_value_type = google_firestore_v1_Value_reference_value_tag;
    result.reference_value = context.serializer().EncodeKey(input.key());

    return EvaluateResult::NewValue(nanopb::MakeMessage(std::move(result)));
  }

  if (field->alias() == model::FieldPath::kUpdateTimePath) {
    google_firestore_v1_Value result;

    result.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
    result.timestamp_value =
        context.serializer().EncodeVersion(input.version());

    return EvaluateResult::NewValue(nanopb::MakeMessage(std::move(result)));
  }

  // TODO(pipeline): Add create time support.

  // Return 'UNSET' if the field doesn't exist, otherwise the Value.
  const auto& result = input.field(field->field_path());
  if (result.has_value()) {
    // DeepClone the field value to avoid modifying the original.
    return EvaluateResult::NewValue(model::DeepClone(result.value()));
  } else {
    return EvaluateResult::NewUnset();
  }
}

EvaluateResult CoreConstant::Evaluate(const api::EvaluateContext&,
                                      const model::PipelineInputOutput&) const {
  auto* constant = dynamic_cast<api::Constant*>(expr_.get());
  return EvaluateResult::NewValue(nanopb::MakeMessage(constant->to_proto()));
}

// --- Comparison Implementations ---

EvaluateResult ComparisonBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "%s() function requires exactly 2 params", expr_->name());

  std::unique_ptr<EvaluableExpr> left_evaluable =
      expr_->params()[0]->ToEvaluable();
  std::unique_ptr<EvaluableExpr> right_evaluable =
      expr_->params()[1]->ToEvaluable();

  EvaluateResult left = left_evaluable->Evaluate(context, document);
  if (left.IsErrorOrUnset()) {
    return left;  // Propagate Error or Unset
  }

  EvaluateResult right = right_evaluable->Evaluate(context, document);
  if (right.IsErrorOrUnset()) {
    return right;  // Propagate Error or Unset
  }

  // Comparisons involving Null propagate Null
  if (left.IsNull() || right.IsNull()) {
    return EvaluateResult::NewNull();
  }

  // Operands are valid Values, proceed with specific comparison
  return CompareToResult(left, right);
}

EvaluateResult CoreEq::CompareToResult(const EvaluateResult& left,
                                       const EvaluateResult& right) const {
  // Type mismatch always results in false for Eq
  if (model::GetTypeOrder(*left.value()) !=
      model::GetTypeOrder(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
  // NaN == anything (including NaN) is false
  if (model::IsNaNValue(*left.value()) || model::IsNaNValue(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }

  switch (model::StrictEquals(*left.value(), *right.value())) {
    case model::StrictEqualsResult::kEq:
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
    case model::StrictEqualsResult::kNotEq:
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
    case model::StrictEqualsResult::kNull:
      return EvaluateResult::NewNull();
  }
}

EvaluateResult CoreNeq::CompareToResult(const EvaluateResult& left,
                                        const EvaluateResult& right) const {
  // NaN != anything (including NaN) is true
  if (model::IsNaNValue(*left.value()) || model::IsNaNValue(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
  }
  // Type mismatch always results in true for Neq
  if (model::GetTypeOrder(*left.value()) !=
      model::GetTypeOrder(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
  }

  switch (model::StrictEquals(*left.value(), *right.value())) {
    case model::StrictEqualsResult::kEq:
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
    case model::StrictEqualsResult::kNotEq:
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
    case model::StrictEqualsResult::kNull:
      return EvaluateResult::NewNull();
  }
}

EvaluateResult CoreLt::CompareToResult(const EvaluateResult& left,
                                       const EvaluateResult& right) const {
  // Type mismatch always results in false
  if (model::GetTypeOrder(*left.value()) !=
      model::GetTypeOrder(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
  // NaN compared to anything is false
  if (model::IsNaNValue(*left.value()) || model::IsNaNValue(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }

  bool result = model::Compare(*left.value(), *right.value()) ==
                util::ComparisonResult::Ascending;
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreLte::CompareToResult(const EvaluateResult& left,
                                        const EvaluateResult& right) const {
  // Type mismatch always results in false
  if (model::GetTypeOrder(*left.value()) !=
      model::GetTypeOrder(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
  // NaN compared to anything is false
  if (model::IsNaNValue(*left.value()) || model::IsNaNValue(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }

  // Check for equality first using StrictEquals
  if (model::StrictEquals(*left.value(), *right.value()) ==
      model::StrictEqualsResult::kEq) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
  }

  // If not equal, perform standard comparison
  bool result = model::Compare(*left.value(), *right.value()) ==
                util::ComparisonResult::Ascending;
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreGt::CompareToResult(const EvaluateResult& left,
                                       const EvaluateResult& right) const {
  // Type mismatch always results in false
  if (model::GetTypeOrder(*left.value()) !=
      model::GetTypeOrder(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
  // NaN compared to anything is false
  if (model::IsNaNValue(*left.value()) || model::IsNaNValue(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }

  bool result = model::Compare(*left.value(), *right.value()) ==
                util::ComparisonResult::Descending;
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreGte::CompareToResult(const EvaluateResult& left,
                                        const EvaluateResult& right) const {
  // Type mismatch always results in false
  if (model::GetTypeOrder(*left.value()) !=
      model::GetTypeOrder(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
  // NaN compared to anything is false
  if (model::IsNaNValue(*left.value()) || model::IsNaNValue(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }

  // Check for equality first using StrictEquals
  if (model::StrictEquals(*left.value(), *right.value()) ==
      model::StrictEqualsResult::kEq) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
  }

  // If not equal, perform standard comparison
  bool result = model::Compare(*left.value(), *right.value()) ==
                util::ComparisonResult::Descending;
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

// --- Arithmetic Implementations ---

EvaluateResult CoreAdd::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  return EvaluateArithmetic(
      expr_.get(), context, document,
      [](int64_t l, int64_t r) { return SafeAdd(l, r); },
      [](double l, double r) { return l + r; });
}

EvaluateResult CoreSubtract::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  return EvaluateArithmetic(
      expr_.get(), context, document,
      [](int64_t l, int64_t r) { return SafeSubtract(l, r); },
      [](double l, double r) { return l - r; });
}

EvaluateResult CoreMultiply::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  return EvaluateArithmetic(
      expr_.get(), context, document,
      [](int64_t l, int64_t r) { return SafeMultiply(l, r); },
      [](double l, double r) { return l * r; });
}

EvaluateResult CoreDivide::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  return EvaluateArithmetic(
      expr_.get(), context, document,
      // Integer division
      [](int64_t l, int64_t r) { return SafeDivide(l, r); },
      // Double division
      [](double l, double r) {
        // C++ double division handles signed zero correctly according to IEEE
        // 754. +x / +0 -> +Inf -x / +0 -> -Inf +x / -0 -> -Inf -x / -0 -> +Inf
        //  0 /  0 -> NaN
        return l / r;
      });
}

EvaluateResult CoreMod::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  return EvaluateArithmetic(
      expr_.get(), context, document,
      // Integer modulo
      [](int64_t l, int64_t r) { return SafeMod(l, r); },
      // Double modulo
      [](double l, double r) {
        if (r == 0.0) {
          return std::numeric_limits<double>::quiet_NaN();
        }
        // Use std::fmod for double modulo, matches C++ and Firestore semantics
        return std::fmod(l, r);
      });
}

// --- Array Expression Implementations ---

EvaluateResult CoreArrayReverse::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "array_reverse() function requires exactly 1 param");

  std::unique_ptr<EvaluableExpr> operand_evaluable =
      expr_->params()[0]->ToEvaluable();
  EvaluateResult evaluated = operand_evaluable->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kNull: {
      return EvaluateResult::NewNull();
    }
    case EvaluateResult::ResultType::kArray: {
      std::vector<nanopb::Message<google_firestore_v1_Value>> reversed_values;
      if (evaluated.value()->array_value.values != nullptr) {
        for (pb_size_t i = 0; i < evaluated.value()->array_value.values_count;
             ++i) {
          // Deep clone each element to get a new FieldValue wrapper
          reversed_values.push_back(
              model::DeepClone(evaluated.value()->array_value.values[i]));
        }
      }

      std::reverse(reversed_values.begin(), reversed_values.end());
      return EvaluateResult::NewValue(
          model::ArrayValue(std::move(reversed_values)));
    }
    default:
      return EvaluateResult::NewError();
  }
}

EvaluateResult CoreArrayContains::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "array_contains() function requires exactly 2 params");

  std::vector<std::shared_ptr<api::Expr>> reversed_params(
      expr_->params().rbegin(), expr_->params().rend());
  auto const eq_any =
      CoreEqAny(api::FunctionExpr("eq_any", std::move(reversed_params)));
  return eq_any.Evaluate(context, document);
}

EvaluateResult CoreArrayContainsAll::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "array_contains_all() function requires exactly 2 params");

  bool found_null = false;

  // Evaluate the array to search (param 0)
  std::unique_ptr<EvaluableExpr> array_to_search_evaluable =
      expr_->params()[0]->ToEvaluable();
  EvaluateResult array_to_search =
      array_to_search_evaluable->Evaluate(context, document);

  switch (array_to_search.type()) {
    case EvaluateResult::ResultType::kArray: {
      break;  // Expected type
    }
    case EvaluateResult::ResultType::kNull: {
      found_null = true;
      break;
    }
    default: {
      return EvaluateResult::NewError();  // Error or Unset or wrong type
    }
  }

  // Evaluate the elements to find (param 1)
  std::unique_ptr<EvaluableExpr> elements_to_find_evaluable =
      expr_->params()[1]->ToEvaluable();
  EvaluateResult elements_to_find =
      elements_to_find_evaluable->Evaluate(context, document);

  switch (elements_to_find.type()) {
    case EvaluateResult::ResultType::kArray: {
      break;  // Expected type
    }
    case EvaluateResult::ResultType::kNull: {
      found_null = true;
      break;
    }
    default: {
      // Handle all other types (kError, kUnset, kBoolean, kInt, kDouble, etc.)
      // as errors for the 'elements_to_find' parameter.
      return EvaluateResult::NewError();
    }
  }

  // If either input was null, the result is null
  if (found_null) {
    return EvaluateResult::NewNull();
  }

  const google_firestore_v1_Value* search_values_proto =
      elements_to_find.value();
  const google_firestore_v1_Value* array_values_proto = array_to_search.value();
  bool found_null_at_least_once = false;

  // Iterate through elements we need to find (search_values)
  if (search_values_proto->array_value.values != nullptr) {
    for (pb_size_t i = 0; i < search_values_proto->array_value.values_count;
         ++i) {
      const google_firestore_v1_Value& search =
          search_values_proto->array_value.values[i];
      bool found = false;

      // Iterate through the array we are searching within (array_values)
      if (array_values_proto->array_value.values != nullptr) {
        for (pb_size_t j = 0; j < array_values_proto->array_value.values_count;
             ++j) {
          const google_firestore_v1_Value& value =
              array_values_proto->array_value.values[j];

          switch (model::StrictEquals(search, value)) {
            case model::StrictEqualsResult::kEq: {
              found = true;
              break;  // Found it, break inner loop
            }
            case model::StrictEqualsResult::kNotEq: {
              // Keep searching
              break;
            }
            case model::StrictEqualsResult::kNull: {
              found_null = true;
              found_null_at_least_once = true;  // Track null globally
              break;
            }
          }
          if (found) {
            break;  // Exit inner loop once found
          }
        }  // End inner loop (searching array_values)
      }

      // Check result for the current 'search' element
      if (found) {
        // true case - do nothing, we found a match, make sure all other values
        // are also found
      } else {
        // false case - we didn't find a match, short circuit
        if (!found_null) {
          return EvaluateResult::NewValue(
              nanopb::MakeMessage(model::FalseValue()));
        }
        // null case - do nothing, we found at least one null value for this
        // search element, keep going
      }
    }  // End outer loop (iterating search_values)
  }

  // If we finished the outer loop
  if (found_null_at_least_once) {
    // If we encountered any null comparison and didn't return false earlier,
    // the result is null.
    return EvaluateResult::NewNull();
  } else {
    // If we finished and found no nulls, and never returned false,
    // it means all elements were found.
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
  }
}

EvaluateResult CoreArrayContainsAny::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "array_contains_any() function requires exactly 2 params");

  bool found_null = false;

  // Evaluate the array to search (param 0)
  std::unique_ptr<EvaluableExpr> array_to_search_evaluable =
      expr_->params()[0]->ToEvaluable();
  EvaluateResult array_to_search =
      array_to_search_evaluable->Evaluate(context, document);

  switch (array_to_search.type()) {
    case EvaluateResult::ResultType::kArray: {
      break;  // Expected type
    }
    case EvaluateResult::ResultType::kNull: {
      found_null = true;
      break;
    }
    default: {
      return EvaluateResult::NewError();  // Error or Unset or wrong type
    }
  }

  // Evaluate the elements to find (param 1)
  std::unique_ptr<EvaluableExpr> elements_to_find_evaluable =
      expr_->params()[1]->ToEvaluable();
  EvaluateResult elements_to_find =
      elements_to_find_evaluable->Evaluate(context, document);

  switch (elements_to_find.type()) {
    case EvaluateResult::ResultType::kArray: {
      break;  // Expected type
    }
    case EvaluateResult::ResultType::kNull: {
      found_null = true;
      break;
    }
    default: {
      // Handle all other types (kError, kUnset, kBoolean, kInt, kDouble, etc.)
      // as errors for the 'elements_to_find' parameter.
      return EvaluateResult::NewError();
    }
  }

  // If either input was null, the result is null
  if (found_null) {
    return EvaluateResult::NewNull();
  }

  const google_firestore_v1_Value* search_values_proto =
      elements_to_find.value();
  const google_firestore_v1_Value* array_values_proto = array_to_search.value();

  // Outer loop: Iterate through the array being searched
  if (search_values_proto->array_value.values != nullptr) {
    for (pb_size_t i = 0; i < search_values_proto->array_value.values_count;
         ++i) {
      const google_firestore_v1_Value& candidate =
          search_values_proto->array_value.values[i];

      // Inner loop: Iterate through the elements to find
      if (array_values_proto->array_value.values != nullptr) {
        for (pb_size_t j = 0; j < array_values_proto->array_value.values_count;
             ++j) {
          const google_firestore_v1_Value& search_element =
              array_values_proto->array_value.values[j];

          switch (model::StrictEquals(candidate, search_element)) {
            case model::StrictEqualsResult::kEq: {
              // Found one match, return true immediately
              return EvaluateResult::NewValue(
                  nanopb::MakeMessage(model::TrueValue()));
            }
            case model::StrictEqualsResult::kNotEq:
              // Continue inner loop
              break;
            case model::StrictEqualsResult::kNull:
              // Track null, continue inner loop
              found_null = true;
              break;
          }
        }  // End inner loop
      }
    }  // End outer loop
  }

  // If we finished both loops without returning true
  if (found_null) {
    // If we encountered any null comparison, the result is null
    return EvaluateResult::NewNull();
  } else {
    // If no match was found and no nulls were encountered
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
}

EvaluateResult CoreArrayLength::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "array_length() function requires exactly 1 param");

  std::unique_ptr<EvaluableExpr> operand_evaluable =
      expr_->params()[0]->ToEvaluable();
  EvaluateResult operand_result =
      operand_evaluable->Evaluate(context, document);

  switch (operand_result.type()) {
    case EvaluateResult::ResultType::kNull: {
      return EvaluateResult::NewNull();
    }
    case EvaluateResult::ResultType::kArray: {
      size_t array_size = operand_result.value()->array_value.values_count;
      return EvaluateResult::NewValue(IntValue(array_size));
    }
    default: {
      return EvaluateResult::NewError();
    }
  }
}

// --- Logical Expression Implementations ---

// Constructor definitions removed as they are now inline in the header

EvaluateResult CoreAnd::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  bool has_null = false;
  bool has_error = false;
  for (const auto& param : expr_->params()) {
    EvaluateResult const result =
        param->ToEvaluable()->Evaluate(context, document);
    switch (result.type()) {
      case EvaluateResult::ResultType::kBoolean:
        if (!result.value()->boolean_value) {
          // Short-circuit on false
          return EvaluateResult::NewValue(
              nanopb::MakeMessage(model::FalseValue()));
        }
        break;  // Break if true
      case EvaluateResult::ResultType::kNull:
        has_null = true;  // Track null, continue evaluation
        break;
      default:
        has_error = true;
        break;
    }
  }

  if (has_error) {
    return EvaluateResult::NewError();  // If any operand results in error
  }

  if (has_null) {
    return EvaluateResult::NewNull();  // If null was encountered, result is
                                       // null
  }

  return EvaluateResult::NewValue(
      nanopb::MakeMessage(model::TrueValue()));  // Otherwise, result is true
}

EvaluateResult CoreOr::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  bool has_null = false;
  bool has_error = false;
  for (const auto& param : expr_->params()) {
    EvaluateResult const result =
        param->ToEvaluable()->Evaluate(context, document);
    switch (result.type()) {
      case EvaluateResult::ResultType::kBoolean:
        if (result.value()->boolean_value) {
          // Short-circuit on true
          return EvaluateResult::NewValue(
              nanopb::MakeMessage(model::TrueValue()));
        }
        break;  // Continue if false
      case EvaluateResult::ResultType::kNull:
        has_null = true;  // Track null, continue evaluation
        break;
      default:
        has_error = true;
        break;
    }
  }

  // If loop completes without returning true:
  if (has_error) {
    return EvaluateResult::NewError();
  }

  if (has_null) {
    return EvaluateResult::NewNull();
  }

  return EvaluateResult::NewValue(
      nanopb::MakeMessage(model::FalseValue()));  // Otherwise, result is false
}

EvaluateResult CoreXor::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  bool current_xor_result = false;
  bool has_null = false;
  for (const auto& param : expr_->params()) {
    EvaluateResult const evaluated =
        param->ToEvaluable()->Evaluate(context, document);
    switch (evaluated.type()) {
      case EvaluateResult::ResultType::kBoolean: {
        bool operand_value = evaluated.value()->boolean_value;
        // XOR logic: result = result ^ operand
        current_xor_result = current_xor_result != operand_value;
        break;
      }
      case EvaluateResult::ResultType::kNull: {
        has_null = true;
        break;
      }
      default: {
        // Any non-boolean, non-null operand results in error
        return EvaluateResult::NewError();
      }
    }
  }

  if (has_null) {
    return EvaluateResult::NewNull();
  }
  return EvaluateResult::NewValue(nanopb::MakeMessage(
      current_xor_result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreCond::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 3,
              "cond() function requires exactly 3 params");

  EvaluateResult condition =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (condition.type()) {
    case EvaluateResult::ResultType::kBoolean: {
      if (condition.value()->boolean_value) {
        // Condition is true, evaluate the second parameter
        return expr_->params()[1]->ToEvaluable()->Evaluate(context, document);
      } else {
        // Condition is false, evaluate the third parameter
        return expr_->params()[2]->ToEvaluable()->Evaluate(context, document);
      }
    }
    case EvaluateResult::ResultType::kNull: {
      // Condition is null, evaluate the third parameter (false case)
      return expr_->params()[2]->ToEvaluable()->Evaluate(context, document);
    }
    default:
      // Condition is error, unset, or non-boolean/non-null type
      return EvaluateResult::NewError();
  }
}

EvaluateResult CoreEqAny::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "eq_any() function requires exactly 2 params (search value and "
              "array value)");

  bool found_null = false;

  // Evaluate the search value (param 0)
  EvaluateResult const search_result =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (search_result.type()) {
    case EvaluateResult::ResultType::kNull: {
      found_null = true;
      break;
    }
    case EvaluateResult::ResultType::kError:
    case EvaluateResult::ResultType::kUnset:
      return EvaluateResult::NewError();  // Error/Unset search value is error
    default:
      break;  // Valid value
  }

  EvaluateResult const array_result =
      expr_->params()[1]->ToEvaluable()->Evaluate(context, document);
  switch (array_result.type()) {
    case EvaluateResult::ResultType::kNull: {
      found_null = true;
      break;
    }
    case EvaluateResult::ResultType::kArray: {
      break;
    }
    default:
      return EvaluateResult::NewError();
  }

  if (found_null) {
    return EvaluateResult::NewNull();
  }

  for (size_t i = 0; i < array_result.value()->array_value.values_count; ++i) {
    const google_firestore_v1_Value& candidate =
        array_result.value()->array_value.values[i];
    switch (model::StrictEquals(*search_result.value(), candidate)) {
      case model::StrictEqualsResult::kEq: {
        return EvaluateResult::NewValue(
            nanopb::MakeMessage(model::TrueValue()));
      }
      case model::StrictEqualsResult::kNotEq: {
        break;
      }
      case model::StrictEqualsResult::kNull: {
        found_null = true;
        break;
      }
    }
  }

  if (found_null) {
    return EvaluateResult::NewNull();
  }

  return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
}

EvaluateResult CoreNotEqAny::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(
      expr_->params().size() == 2,
      "not_eq_any() function requires exactly 2 params (search value and "
      "array value)");

  CoreNot equivalent(api::FunctionExpr(
      "not", {std::make_shared<api::FunctionExpr>("eq_any", expr_->params())}));
  return equivalent.Evaluate(context, document);
}

EvaluateResult CoreIsNan::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "is_nan() function requires exactly 1 param");

  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kInt:
      // Integers are never NaN
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
    case EvaluateResult::ResultType::kDouble:
      // Check if the double value is NaN
      return EvaluateResult::NewValue(nanopb::MakeMessage(
          model::IsNaNValue(*evaluated.value()) ? model::TrueValue()
                                                : model::FalseValue()));
    case EvaluateResult::ResultType::kNull:
      // is_nan(null) -> null
      return EvaluateResult::NewNull();
    default:
      // is_nan applied to non-numeric, non-null is an error
      return EvaluateResult::NewError();
  }
}

EvaluateResult CoreIsNotNan::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "is_not_nan() function requires exactly 1 param");

  CoreNot equivalent(api::FunctionExpr(
      "not", {std::make_shared<api::FunctionExpr>("is_nan", expr_->params())}));
  return equivalent.Evaluate(context, document);
}

EvaluateResult CoreIsNull::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "is_null() function requires exactly 1 param");

  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
    case EvaluateResult::ResultType::kUnset:
    case EvaluateResult::ResultType::kError:
      // is_null on error/unset is an error
      return EvaluateResult::NewError();
    default:
      // is_null on any other value is false
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
}

EvaluateResult CoreIsNotNull::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "is_not_null() function requires exactly 1 param");

  CoreNot equivalent(api::FunctionExpr(
      "not",
      {std::make_shared<api::FunctionExpr>("is_null", expr_->params())}));
  return equivalent.Evaluate(context, document);
}

EvaluateResult CoreIsError::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "is_error() function requires exactly 1 param");

  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kError:
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
    default:
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
}

EvaluateResult CoreLogicalMaximum::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  // Store the underlying Value proto in the optional, not EvaluateResult
  absl::optional<nanopb::Message<google_firestore_v1_Value>> max_value_proto;

  for (const auto& param : expr_->params()) {
    EvaluateResult result = param->ToEvaluable()->Evaluate(context, document);

    switch (result.type()) {
      case EvaluateResult::ResultType::kError:
      case EvaluateResult::ResultType::kUnset:
      case EvaluateResult::ResultType::kNull:
        // Skip null, error, unset
        continue;
      default: {
        if (!max_value_proto.has_value() ||
            model::Compare(*result.value(), *max_value_proto.value()) ==
                util::ComparisonResult::Descending) {
          // Store a deep copy of the value proto
          max_value_proto = model::DeepClone(*result.value());
        }
      }
    }
  }

  if (max_value_proto.has_value()) {
    // Reconstruct EvaluateResult from the stored proto
    return EvaluateResult::NewValue(std::move(max_value_proto.value()));
  }
  // If only null/error/unset were encountered, return Null
  return EvaluateResult::NewNull();
}

EvaluateResult CoreLogicalMinimum::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  // Store the underlying Value proto in the optional, not EvaluateResult
  absl::optional<nanopb::Message<google_firestore_v1_Value>> min_value_proto;

  for (const auto& param : expr_->params()) {
    EvaluateResult result = param->ToEvaluable()->Evaluate(context, document);

    switch (result.type()) {
      case EvaluateResult::ResultType::kError:
      case EvaluateResult::ResultType::kUnset:
      case EvaluateResult::ResultType::kNull:
        // Skip null, error, unset
        continue;
      default: {
        if (!min_value_proto.has_value() ||
            model::Compare(*result.value(), *min_value_proto.value()) ==
                util::ComparisonResult::Ascending) {
          min_value_proto = model::DeepClone(*result.value());
        }
      }
    }
  }

  if (min_value_proto.has_value()) {
    // Reconstruct EvaluateResult from the stored proto
    return EvaluateResult::NewValue(std::move(min_value_proto.value()));
  }
  // If only null/error/unset were encountered, return Null
  return EvaluateResult::NewNull();
}

// --- Debugging Expression Implementations ---

EvaluateResult CoreExists::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "exists() function requires exactly 1 param");

  std::unique_ptr<EvaluableExpr> operand_evaluable =
      expr_->params()[0]->ToEvaluable();
  EvaluateResult evaluated = operand_evaluable->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kError:
      return EvaluateResult::NewError();  // Propagate error
    case EvaluateResult::ResultType::kUnset:
      // Unset field means it doesn't exist
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
    default:
      // Null or any other value means it exists
      return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
  }
}

EvaluateResult CoreNot::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "not() function requires exactly 1 param");

  std::unique_ptr<EvaluableExpr> operand_evaluable =
      expr_->params()[0]->ToEvaluable();
  EvaluateResult evaluated = operand_evaluable->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kBoolean: {
      // Negate the boolean value
      bool original_value = evaluated.value()->boolean_value;
      return EvaluateResult::NewValue(nanopb::MakeMessage(
          original_value ? model::FalseValue() : model::TrueValue()));
    }
    case EvaluateResult::ResultType::kNull: {
      // NOT(NULL) -> NULL
      return EvaluateResult::NewNull();
    }
    default: {
      // NOT applied to non-boolean, non-null is an error
      return EvaluateResult::NewError();
    }
  }
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
