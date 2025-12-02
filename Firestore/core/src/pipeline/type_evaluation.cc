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

#include "Firestore/core/src/pipeline/type_evaluation.h"
#include "Firestore/core/src/pipeline/logical_evaluation.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace core {

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

}  // namespace core
}  // namespace firestore
}  // namespace firebase
