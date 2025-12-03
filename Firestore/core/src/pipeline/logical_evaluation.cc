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

#include "Firestore/core/src/pipeline/logical_evaluation.h"

#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace core {

// --- Logical Expression Implementations ---

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
  HARD_ASSERT(
      expr_->params().size() == 2,
      "equal_any() function requires exactly 2 params (search value and "
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
      "not",
      {std::make_shared<api::FunctionExpr>("equal_any", expr_->params())}));
  return equivalent.Evaluate(context, document);
}

EvaluateResult CoreNot::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "not() function requires exactly 1 param");

  std::unique_ptr<EvaluableExpression> operand_evaluable =
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
