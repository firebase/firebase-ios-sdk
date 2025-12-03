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

#include "Firestore/core/src/pipeline/comparison_evaluation.h"

#include <memory>
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace core {

// --- Comparison Implementations ---

EvaluateResult ComparisonBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "%s() function requires exactly 2 params", expr_->name());

  std::unique_ptr<EvaluableExpression> left_evaluable =
      expr_->params()[0]->ToEvaluable();
  EvaluateResult left = left_evaluable->Evaluate(context, document);

  switch (left.type()) {
    case EvaluateResult::ResultType::kError:
    case EvaluateResult::ResultType::kUnset: {
      return EvaluateResult::NewError();
    }
    default:
      break;
  }

  std::unique_ptr<EvaluableExpression> right_evaluable =
      expr_->params()[1]->ToEvaluable();
  EvaluateResult right = right_evaluable->Evaluate(context, document);
  switch (right.type()) {
    case EvaluateResult::ResultType::kError:
    case EvaluateResult::ResultType::kUnset: {
      return EvaluateResult::NewError();
    }
    default:
      break;
  }

  // Comparisons involving Null propagate Null
  if (left.IsNull() || right.IsNull()) {
    return EvaluateResult::NewNull();
  }

  // Operands are valid Values, proceed with specific comparison
  return CompareToResult(left, right);
}

EvaluateResult CoreEqual::CompareToResult(const EvaluateResult& left,
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
  HARD_FAIL("Unhandled case in switch statement");
}

EvaluateResult CoreNotEqual::CompareToResult(
    const EvaluateResult& left, const EvaluateResult& right) const {
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
  HARD_FAIL("Unhandled case in switch statement");
}

EvaluateResult CoreLessThan::CompareToResult(
    const EvaluateResult& left, const EvaluateResult& right) const {
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

EvaluateResult CoreLessThanOrEqual::CompareToResult(
    const EvaluateResult& left, const EvaluateResult& right) const {
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

EvaluateResult CoreGreaterThan::CompareToResult(
    const EvaluateResult& left, const EvaluateResult& right) const {
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

EvaluateResult CoreGreaterThanOrEqual::CompareToResult(
    const EvaluateResult& left, const EvaluateResult& right) const {
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

}  // namespace core
}  // namespace firestore
}  // namespace firebase
