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

#include "Firestore/core/src/pipeline/util_evaluation.h"

#include <limits>
#include <utility>

#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace core {

// Helper to create a Value proto from double
nanopb::Message<google_firestore_v1_Value> DoubleValue(double val) {
  google_firestore_v1_Value proto;
  proto.which_value_type = google_firestore_v1_Value_double_value_tag;
  proto.double_value = val;
  return nanopb::MakeMessage(std::move(proto));
}

nanopb::Message<google_firestore_v1_Value> IntValue(int64_t val) {
  google_firestore_v1_Value proto;
  proto.which_value_type = google_firestore_v1_Value_integer_value_tag;
  proto.integer_value = val;
  return nanopb::MakeMessage(std::move(proto));
}

absl::optional<int64_t> SafeAdd(int64_t lhs, int64_t rhs) {
  int64_t result;
#if defined(__clang__) || defined(__GNUC__)
  if (__builtin_add_overflow(lhs, rhs, &result)) {
    return absl::nullopt;
  }
#else
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
    return absl::nullopt;
  }
  if (lhs == std::numeric_limits<int64_t>::min() && rhs == -1) {
    return absl::nullopt;
  }
  return lhs / rhs;
}

absl::optional<int64_t> SafeMod(int64_t lhs, int64_t rhs) {
  if (rhs == 0) {
    return absl::nullopt;
  }
  if (lhs == std::numeric_limits<int64_t>::min() && rhs == -1) {
    return absl::nullopt;
  }
  return lhs % rhs;
}

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

}  // namespace core
}  // namespace firestore
}  // namespace firebase
