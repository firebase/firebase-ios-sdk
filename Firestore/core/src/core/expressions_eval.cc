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

#include <cmath>
#include <limits>
#include <memory>
#include <utility>  // For std::move

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/value_util.h"  // Added for value helpers
#include "Firestore/core/src/nanopb/message.h"    // Added for MakeMessage
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/hard_assert.h"  // Added for HARD_ASSERT
#include "absl/types/optional.h"                  // Added for absl::optional

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
  }
  // TODO(wuandy): Add other functions

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

}  // namespace core
}  // namespace firestore
}  // namespace firebase
