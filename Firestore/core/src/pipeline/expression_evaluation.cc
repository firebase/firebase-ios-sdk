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

#include "Firestore/core/src/pipeline/expression_evaluation.h"

#include <memory>
#include <utility>  // For std::move

#include "Firestore/core/src/pipeline/aggregates_evaluation.h"
#include "Firestore/core/src/pipeline/arithmetic_evaluation.h"
#include "Firestore/core/src/pipeline/array_evaluation.h"
#include "Firestore/core/src/pipeline/comparison_evaluation.h"
#include "Firestore/core/src/pipeline/logical_evaluation.h"
#include "Firestore/core/src/pipeline/map_evaluation.h"
#include "Firestore/core/src/pipeline/string_evaluation.h"
#include "Firestore/core/src/pipeline/timestamp_evaluation.h"
#include "Firestore/core/src/pipeline/type_evaluation.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/hard_assert.h"

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
      nanopb::Message<google_firestore_v1_Value>(model::NullValue()));
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

namespace {

nanopb::Message<google_firestore_v1_Value> GetServerTimestampValue(
    const api::EvaluateContext& context,
    const google_firestore_v1_Value& timestamp_sentinel) {
  if (context.listen_options().server_timestamp_behavior() ==
      ListenOptions::ServerTimestampBehavior::kEstimate) {
    google_firestore_v1_Value result;
    result.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
    result.timestamp_value = model::GetLocalWriteTime(timestamp_sentinel);
    return nanopb::MakeMessage<google_firestore_v1_Value>(result);
  }

  if (context.listen_options().server_timestamp_behavior() ==
      ListenOptions::ServerTimestampBehavior::kPrevious) {
    auto result = model::GetPreviousValue(timestamp_sentinel);
    if (result.has_value()) {
      return model::DeepClone(result.value());
    }
  }

  return nanopb::MakeMessage<google_firestore_v1_Value>(model::NullValue());
}

}  // namespace

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
    if (model::IsServerTimestamp(result.value())) {
      return EvaluateResult::NewValue(
          GetServerTimestampValue(context, result.value()));
    }

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

std::unique_ptr<EvaluableExpr> FunctionToEvaluable(
    const api::FunctionExpr& function) {
  if (function.name() == "equal") {
    return std::make_unique<CoreEqual>(function);
  } else if (function.name() == "add") {
    return std::make_unique<CoreAdd>(function);
  } else if (function.name() == "subtract") {
    return std::make_unique<CoreSubtract>(function);
  } else if (function.name() == "multiply") {
    return std::make_unique<CoreMultiply>(function);
  } else if (function.name() == "divide") {
    return std::make_unique<CoreDivide>(function);
  } else if (function.name() == "mod") {
    return std::make_unique<CoreMod>(function);
  } else if (function.name() == "not_equal") {
    return std::make_unique<CoreNotEqual>(function);
  } else if (function.name() == "less_than") {
    return std::make_unique<CoreLessThan>(function);
  } else if (function.name() == "less_than_or_equal") {
    return std::make_unique<CoreLessThanOrEqual>(function);
  } else if (function.name() == "greater_than") {
    return std::make_unique<CoreGreaterThan>(function);
  } else if (function.name() == "greater_than_or_equal") {
    return std::make_unique<CoreGreaterThanOrEqual>(function);
  } else if (function.name() == "array_reverse") {
    return std::make_unique<CoreArrayReverse>(function);
  } else if (function.name() == "array_contains") {
    return std::make_unique<CoreArrayContains>(function);
  } else if (function.name() == "array_contains_all") {
    return std::make_unique<CoreArrayContainsAll>(function);
  } else if (function.name() == "array_contains_any") {
    return std::make_unique<CoreArrayContainsAny>(function);
  } else if (function.name() == "array_length") {
    return std::make_unique<CoreArrayLength>(function);
  } else if (function.name() == "exists") {
    return std::make_unique<CoreExists>(function);
  } else if (function.name() == "not") {
    return std::make_unique<CoreNot>(function);
  } else if (function.name() == "and") {
    return std::make_unique<CoreAnd>(function);
  } else if (function.name() == "or") {
    return std::make_unique<CoreOr>(function);
  } else if (function.name() == "xor") {
    return std::make_unique<CoreXor>(function);
  } else if (function.name() == "cond") {
    return std::make_unique<CoreCond>(function);
  } else if (function.name() == "equal_any") {
    return std::make_unique<CoreEqAny>(function);
  } else if (function.name() == "not_equal_any") {
    return std::make_unique<CoreNotEqAny>(function);
  } else if (function.name() == "is_nan") {
    return std::make_unique<CoreIsNan>(function);
  } else if (function.name() == "is_not_nan") {
    return std::make_unique<CoreIsNotNan>(function);
  } else if (function.name() == "is_null") {
    return std::make_unique<CoreIsNull>(function);
  } else if (function.name() == "is_not_null") {
    return std::make_unique<CoreIsNotNull>(function);
  } else if (function.name() == "is_error") {
    return std::make_unique<CoreIsError>(function);
  } else if (function.name() == "maximum") {
    return std::make_unique<CoreMaximum>(function);
  } else if (function.name() == "minimum") {
    return std::make_unique<CoreMinimum>(function);
  } else if (function.name() == "map_get") {
    return std::make_unique<CoreMapGet>(function);
  } else if (function.name() == "byte_length") {
    return std::make_unique<CoreByteLength>(function);
  } else if (function.name() == "char_length") {
    return std::make_unique<CoreCharLength>(function);
  } else if (function.name() == "string_concat") {
    return std::make_unique<CoreStringConcat>(function);
  } else if (function.name() == "ends_with") {
    return std::make_unique<CoreEndsWith>(function);
  } else if (function.name() == "starts_with") {
    return std::make_unique<CoreStartsWith>(function);
  } else if (function.name() == "string_contains") {
    return std::make_unique<CoreStringContains>(function);
  } else if (function.name() == "to_lower") {
    return std::make_unique<CoreToLower>(function);
  } else if (function.name() == "to_upper") {
    return std::make_unique<CoreToUpper>(function);
  } else if (function.name() == "trim") {
    return std::make_unique<CoreTrim>(function);
  } else if (function.name() == "string_reverse") {
    return std::make_unique<CoreStringReverse>(function);
  } else if (function.name() == "regex_contains") {
    return std::make_unique<CoreRegexContains>(function);
  } else if (function.name() == "regex_match") {
    return std::make_unique<CoreRegexMatch>(function);
  } else if (function.name() == "like") {
    return std::make_unique<CoreLike>(function);
  } else if (function.name() == "unix_micros_to_timestamp") {
    return std::make_unique<CoreUnixMicrosToTimestamp>(function);
  } else if (function.name() == "unix_millis_to_timestamp") {
    return std::make_unique<CoreUnixMillisToTimestamp>(function);
  } else if (function.name() == "unix_seconds_to_timestamp") {
    return std::make_unique<CoreUnixSecondsToTimestamp>(function);
  } else if (function.name() == "timestamp_to_unix_micros") {
    return std::make_unique<CoreTimestampToUnixMicros>(function);
  } else if (function.name() == "timestamp_to_unix_millis") {
    return std::make_unique<CoreTimestampToUnixMillis>(function);
  } else if (function.name() == "timestamp_to_unix_seconds") {
    return std::make_unique<CoreTimestampToUnixSeconds>(function);
  } else if (function.name() == "timestamp_add") {
    return std::make_unique<CoreTimestampAdd>(function);
  } else if (function.name() == "timestamp_sub") {
    return std::make_unique<CoreTimestampSub>(function);
  }

  HARD_FAIL("Unsupported function name: %s", function.name());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
