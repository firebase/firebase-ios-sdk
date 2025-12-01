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

#include "Firestore/core/src/core/pipeline/evaluation/array.h"
#include "Firestore/core/src/core/pipeline/evaluation/util.h"

#include <algorithm>
#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/core/pipeline/evaluation/logical.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace core {

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
  auto const equal_any =
      CoreEqAny(api::FunctionExpr("equal_any", std::move(reversed_params)));
  return equal_any.Evaluate(context, document);
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
      google_firestore_v1_Value val;
      val.which_value_type = google_firestore_v1_Value_integer_value_tag;
      val.integer_value = array_size;
      return EvaluateResult::NewValue(nanopb::MakeMessage(val));
    }
    default: {
      return EvaluateResult::NewError();
    }
  }
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
