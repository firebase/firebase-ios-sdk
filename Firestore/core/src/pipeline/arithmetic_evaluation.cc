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

#include "Firestore/core/src/pipeline/util_evaluation.h"
#include "Firestore/core/src/model/value_util.h"
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

// --- Arithmetic Implementations ---
EvaluateResult ArithmeticBase::Evaluate(
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

inline EvaluateResult ArithmeticBase::ApplyOperation(
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

EvaluateResult CoreAdd::PerformIntegerOperation(int64_t l, int64_t r) const {
  auto const result = SafeAdd(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult CoreAdd::PerformDoubleOperation(double l, double r) const {
  return EvaluateResult::NewValue(DoubleValue(l + r));
}

EvaluateResult CoreSubtract::PerformIntegerOperation(int64_t l,
                                                     int64_t r) const {
  auto const result = SafeSubtract(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult CoreSubtract::PerformDoubleOperation(double l, double r) const {
  return EvaluateResult::NewValue(DoubleValue(l - r));
}

EvaluateResult CoreMultiply::PerformIntegerOperation(int64_t l,
                                                     int64_t r) const {
  auto const result = SafeMultiply(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult CoreMultiply::PerformDoubleOperation(double l, double r) const {
  return EvaluateResult::NewValue(DoubleValue(l * r));
}

EvaluateResult CoreDivide::PerformIntegerOperation(int64_t l, int64_t r) const {
  auto const result = SafeDivide(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult CoreDivide::PerformDoubleOperation(double l, double r) const {
  // C++ double division handles signed zero correctly according to IEEE
  // 754. +x / +0 -> +Inf -x / +0 -> -Inf +x / -0 -> -Inf -x / -0 -> +Inf
  //  0 /  0 -> NaN
  return EvaluateResult::NewValue(DoubleValue(l / r));
}

EvaluateResult CoreMod::PerformIntegerOperation(int64_t l, int64_t r) const {
  auto const result = SafeMod(l, r);
  if (result.has_value()) {
    return EvaluateResult::NewValue(IntValue(result.value()));
  }

  return EvaluateResult::NewError();
}

EvaluateResult CoreMod::PerformDoubleOperation(double l, double r) const {
  if (r == 0.0) {
    return EvaluateResult::NewValue(
        DoubleValue(std::numeric_limits<double>::quiet_NaN()));
  }
  // Use std::fmod for double modulo, matches C++ and Firestore semantics
  return EvaluateResult::NewValue(DoubleValue(std::fmod(l, r)));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
