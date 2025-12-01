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

#include "Firestore/core/src/core/pipeline/aggregates.h"

#include <utility>

#include "Firestore/core/src/model/value_util.h"

namespace firebase {
namespace firestore {
namespace core {

EvaluateResult CoreMaximum::Evaluate(
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

EvaluateResult CoreMinimum::Evaluate(
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

}  // namespace core
}  // namespace firestore
}  // namespace firebase
