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

#include "Firestore/core/src/pipeline/map_evaluation.h"

#include <memory>
#include <string>

#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace core {

EvaluateResult CoreMapGet::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "map_get() function requires exactly 2 params (map and key)");

  // Evaluate the map operand (param 0)
  std::unique_ptr<EvaluableExpr> map_evaluable =
      expr_->params()[0]->ToEvaluable();
  EvaluateResult map_result = map_evaluable->Evaluate(context, document);

  switch (map_result.type()) {
    case EvaluateResult::ResultType::kUnset: {
      // If the map itself is unset, the result is unset
      return EvaluateResult::NewUnset();
    }
    case EvaluateResult::ResultType::kMap: {
      // Expected type, continue
      break;
    }
    default: {
      // Any other type (including Null, Error) is an error
      return EvaluateResult::NewError();
    }
  }

  // Evaluate the key operand (param 1)
  std::unique_ptr<EvaluableExpr> key_evaluable =
      expr_->params()[1]->ToEvaluable();
  EvaluateResult key_result = key_evaluable->Evaluate(context, document);

  absl::optional<std::string> key_string;
  switch (key_result.type()) {
    case EvaluateResult::ResultType::kString: {
      key_string = nanopb::MakeString(key_result.value()->string_value);
      HARD_ASSERT(key_string.has_value(), "Failed to extract string key");
      break;
    }
    default: {
      // Key must be a string, otherwise it's an error
      return EvaluateResult::NewError();
    }
  }

  // Look up the field in the map value
  const auto* entry = model::FindEntry(*map_result.value(), key_string.value());

  if (entry != nullptr) {
    // Key found, return a deep clone of the value
    return EvaluateResult::NewValue(model::DeepClone(entry->value));
  } else {
    // Key not found, return Unset
    return EvaluateResult::NewUnset();
  }
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
