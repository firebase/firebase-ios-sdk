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

#include <memory>
#include <utility>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/remote/serializer.h"

namespace firebase {
namespace firestore {
namespace core {

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
  }

  return nullptr;
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

EvaluateResult CoreEq::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  auto* api_eq = expr_.get();
  HARD_ASSERT(api_eq->params().size() == 2,
              "%s() function should have exactly 2 params", api_eq->name());

  const auto left =
      api_eq->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (left.type()) {
    case EvaluateResult::ResultType::kError:
      return EvaluateResult::NewError();
    case EvaluateResult::ResultType::kUnset:
      return EvaluateResult::NewUnset();
    default: {
    }
  }

  const auto right =
      api_eq->params()[1]->ToEvaluable()->Evaluate(context, document);
  switch (right.type()) {
    case EvaluateResult::ResultType::kError:
      return EvaluateResult::NewError();
    case EvaluateResult::ResultType::kUnset:
      return EvaluateResult::NewUnset();
    default: {
    }
  }

  if (left.IsNull() || right.IsNull()) {
    return EvaluateResult::NewNull();
  }

  if (model::GetTypeOrder(*left.value()) !=
      model::GetTypeOrder(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
  if (model::IsNaNValue(*left.value()) || model::IsNaNValue(*right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }

  // TODO(pipeline): Port strictEquals from web
  if (model::Equals(*left.value(), *right.value())) {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::TrueValue()));
  } else {
    return EvaluateResult::NewValue(nanopb::MakeMessage(model::FalseValue()));
  }
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
