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

#include "Firestore/core/src/pipeline/arithmetic_evaluation.h"

#include <cmath>
#include <limits>
#include <utility>

#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/pipeline/util_evaluation.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace core {

namespace {

// Helper to create a Value proto from double
nanopb::Message<google_firestore_v1_Value> DoubleValue(double val) {
  google_firestore_v1_Value proto;
  proto.which_value_type = google_firestore_v1_Value_double_value_tag;
  proto.double_value = val;
  return nanopb::MakeMessage(std::move(proto));
}

}  // anonymous namespace

// --- Unary Arithmetic Implementation ---
EvaluateResult UnaryArithmetic::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "%s() function requires exactly 1 param", expr_->name());

  EvaluateResult result =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  if (result.IsErrorOrUnset()) {
    return EvaluateResult::NewError();
  }
  if (result.IsNull()) {
    return EvaluateResult::NewNull();
  }

  const google_firestore_v1_Value* val = result.value();
  if (!model::IsNumber(*val)) {
    return EvaluateResult::NewError();  // Type error
  }

  double double_val = model::IsDouble(*val)
                          ? val->double_value
                          : static_cast<double>(val->integer_value);

  return PerformOperation(double_val);
}

// --- Arithmetic Implementations ---
EvaluateResult BinaryArithmetic::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() >= 2,
              "%s() function requires at least 2 params", expr_->name());

  EvaluateResult current_result =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  for (size_t i = 1; i < expr_->params().size(); ++i) {
    // Check current accumulated result before evaluating next operand
    if (current_result.IsErrorOrUnset()) {
      // Propagate error immediately if accumulated result is error/unset
      // Note: Unset is treated as Error in arithmetic according to TS logic
      return EvaluateResult::NewError();
    }
    // Null check happens inside ApplyOperation

    EvaluateResult next_operand =
        expr_->params()[i]->ToEvaluable()->Evaluate(context, document);

    // Apply the operation
    current_result = ApplyOperation(current_result, next_operand);

    // If ApplyOperation resulted in error or unset, propagate immediately as
    // error
    if (current_result.IsErrorOrUnset()) {
      // Treat Unset from ApplyOperation as Error for propagation
      return EvaluateResult::NewError();
    }
    // Null is handled within the loop by ApplyOperation in the next iteration
  }

  return current_result;
}

inline EvaluateResult BinaryArithmetic::ApplyOperation(
    const EvaluateResult& left, const EvaluateResult& right) const {
  // Mirroring TypeScript logic:
  // 1. Check for Error/Unset first
  if (left.IsErrorOrUnset() || right.IsErrorOrUnset()) {
    return EvaluateResult::NewError();
  }
  // 2. Check for Null
  if (left.IsNull() || right.IsNull()) {
    return EvaluateResult::NewNull();
  }

  // 3. Type check: Both must be numbers
  const google_firestore_v1_Value* left_val = left.value();
  const google_firestore_v1_Value* right_val = right.value();
  if (!model::IsNumber(*left_val) || !model::IsNumber(*right_val)) {
    return EvaluateResult::NewError();  // Type error
  }

  // 4. Determine operation type (Integer or Double)
  if (model::IsDouble(*left_val) || model::IsDouble(*right_val)) {
    // Promote to double
    double left_double_val = model::IsDouble(*left_val)
                                 ? left_val->double_value
                                 : static_cast<double>(left_val->integer_value);
    double right_double_val =
        model::IsDouble(*right_val)
            ? right_val->double_value
            : static_cast<double>(right_val->integer_value);

    // NaN propagation and specific error handling (like div/mod by zero)
    // are handled within PerformDoubleOperation.
    return PerformDoubleOperation(left_double_val, right_double_val);

  } else {
    // Both are integers
    absl::optional<int64_t> left_int_opt = model::GetInteger(*left_val);
    absl::optional<int64_t> right_int_opt = model::GetInteger(*right_val);
    // These should always succeed because we already checked IsNumber and
    // excluded IsDouble.
    HARD_ASSERT(left_int_opt.has_value() && right_int_opt.has_value(),
                "Failed to extract integer values after IsNumber check");

    return PerformIntegerOperation(left_int_opt.value(), right_int_opt.value());
  }
}

EvaluateResult EvaluateAdd::PerformIntegerOperation(int64_t l,
                                                    int64_t r) const {
  auto const result = SafeAdd(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateAdd::PerformDoubleOperation(double l, double r) const {
  return EvaluateResult::NewValue(DoubleValue(l + r));
}

EvaluateResult EvaluateSubtract::PerformIntegerOperation(int64_t l,
                                                         int64_t r) const {
  auto const result = SafeSubtract(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateSubtract::PerformDoubleOperation(double l,
                                                        double r) const {
  return EvaluateResult::NewValue(DoubleValue(l - r));
}

EvaluateResult EvaluateMultiply::PerformIntegerOperation(int64_t l,
                                                         int64_t r) const {
  auto const result = SafeMultiply(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateMultiply::PerformDoubleOperation(double l,
                                                        double r) const {
  return EvaluateResult::NewValue(DoubleValue(l * r));
}

EvaluateResult EvaluateDivide::PerformIntegerOperation(int64_t l,
                                                       int64_t r) const {
  auto const result = SafeDivide(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateDivide::PerformDoubleOperation(double l,
                                                      double r) const {
  // C++ double division handles signed zero correctly according to IEEE
  // 754. +x / +0 -> +Inf -x / +0 -> -Inf +x / -0 -> -Inf -x / -0 -> +Inf
  //  0 /  0 -> NaN
  return EvaluateResult::NewValue(DoubleValue(l / r));
}

EvaluateResult EvaluateMod::PerformIntegerOperation(int64_t l,
                                                    int64_t r) const {
  auto const result = SafeMod(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult EvaluateMod::PerformDoubleOperation(double l, double r) const {
  if (r == 0.0) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  // Use std::fmod for double modulo, matches C++ and Firestore semantics
  return EvaluateResult::NewValue(DoubleValue(std::fmod(l, r)));
}

EvaluateResult EvaluatePow::PerformIntegerOperation(int64_t l,
                                                    int64_t r) const {
  // Promote to double, as std::pow for integers is complex and can overflow.
  return PerformDoubleOperation(static_cast<double>(l), static_cast<double>(r));
}

EvaluateResult EvaluatePow::PerformDoubleOperation(double l, double r) const {
  if (r == 0.0 || l == 1.0) {
    return EvaluateResult::NewValue(DoubleValue(1.0));
  }
  if (l == -1.0 && std::isinf(r)) {
    return EvaluateResult::NewValue(DoubleValue(1.0));
  }
  if (std::isnan(l) || std::isnan(r)) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  // Check for non-integer exponent on a negative base
  if (l < 0 && std::isfinite(l) && (r != std::floor(r))) {
    return EvaluateResult::NewError();
  }
  if ((l == 0.0 || l == -0.0) && r < 0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::pow(l, r)));
}

EvaluateResult EvaluateRoundToPrecision::PerformIntegerOperation(
    int64_t l, int64_t r) const {
  if (r >= 0) {
    return EvaluateResult::NewValue(IntValue(l));
  }
  double num_digits =
      std::floor(std::log10(std::abs(static_cast<double>(l)))) + 1;
  if (-r >= num_digits) {
    return EvaluateResult::NewValue(IntValue(0));
  }
  double rounding_factor_double = std::pow(10.0, -static_cast<double>(r));
  int64_t rounding_factor = static_cast<int64_t>(rounding_factor_double);

  int64_t truncated = l - (l % rounding_factor);

  if (std::abs(l % rounding_factor) < (rounding_factor / 2)) {
    return EvaluateResult::NewValue(IntValue(truncated));
  }

  if (l < 0) {
    if (l < std::numeric_limits<int64_t>::min() + rounding_factor)
      return EvaluateResult::NewError();
    return EvaluateResult::NewValue(IntValue(truncated - rounding_factor));
  } else {
    if (l > std::numeric_limits<int64_t>::max() - rounding_factor)
      return EvaluateResult::NewError();
    return EvaluateResult::NewValue(IntValue(truncated + rounding_factor));
  }
}

EvaluateResult EvaluateRoundToPrecision::PerformDoubleOperation(
    double l, double r) const {
  int64_t places = static_cast<int64_t>(r);
  if (places >= 16 || !std::isfinite(l)) {
    return EvaluateResult::NewValue(DoubleValue(l));
  }
  double num_digits = std::floor(std::log10(std::abs(l))) + 1;
  if (-places >= num_digits) {
    return EvaluateResult::NewValue(DoubleValue(0.0));
  }
  double factor = std::pow(10.0, places);
  double result = std::round(l * factor) / factor;

  if (std::isfinite(result)) {
    return EvaluateResult::NewValue(DoubleValue(result));
  }
  return EvaluateResult::NewError();  // overflow
}

EvaluateResult EvaluateLog::PerformIntegerOperation(int64_t l,
                                                    int64_t r) const {
  return PerformDoubleOperation(static_cast<double>(l), static_cast<double>(r));
}

EvaluateResult EvaluateLog::PerformDoubleOperation(double l, double r) const {
  if (std::isinf(l) && l < 0) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  if (std::isinf(r)) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  if (l <= 0 || r <= 0 || r == 1.0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::log(l) / std::log(r)));
}

EvaluateResult EvaluateCeil::PerformOperation(double val) const {
  return EvaluateResult::NewValue(DoubleValue(std::ceil(val)));
}

EvaluateResult EvaluateFloor::PerformOperation(double val) const {
  return EvaluateResult::NewValue(DoubleValue(std::floor(val)));
}

EvaluateResult EvaluateRound::PerformOperation(double val) const {
  return EvaluateResult::NewValue(DoubleValue(std::round(val)));
}

EvaluateResult EvaluateAbs::PerformOperation(double val) const {
  return EvaluateResult::NewValue(DoubleValue(std::abs(val)));
}

EvaluateResult EvaluateExp::PerformOperation(double val) const {
  double result = std::exp(val);
  if (std::isinf(result) && !std::isinf(val)) {
    return EvaluateResult::NewError();  // Overflow
  }
  return EvaluateResult::NewValue(DoubleValue(result));
}

EvaluateResult EvaluateLn::PerformOperation(double val) const {
  if (val <= 0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::log(val)));
}

EvaluateResult EvaluateLog10::PerformOperation(double val) const {
  if (val <= 0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::log10(val)));
}

EvaluateResult EvaluateSqrt::PerformOperation(double val) const {
  if (val < 0) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(DoubleValue(std::sqrt(val)));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
