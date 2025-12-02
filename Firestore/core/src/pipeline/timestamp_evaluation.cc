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

#include "Firestore/core/src/pipeline/timestamp_evaluation.h"

#include <memory>

#include "Firestore/core/src/pipeline/util_evaluation.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace core {

namespace {

// --- Timestamp Constants ---
// 0001-01-01T00:00:00Z
constexpr int64_t kTimestampMinSeconds = -62135596800LL;
// 9999-12-31T23:59:59Z (max seconds part)
constexpr int64_t kTimestampMaxSeconds = 253402300799LL;
// Max nanoseconds part
constexpr int32_t kTimestampMaxNanos = 999999999;

constexpr int64_t kMillisecondsPerSecond = 1000LL;
constexpr int64_t kMicrosecondsPerSecond = 1000000LL;
constexpr int64_t kNanosecondsPerMicrosecond = 1000LL;
constexpr int64_t kNanosecondsPerSecond = 1000000000LL;

// 0001-01-01T00:00:00.000000Z
constexpr int64_t kTimestampMinMicroseconds =
    kTimestampMinSeconds * kMicrosecondsPerSecond;
// 9999-12-31T23:59:59.999999Z
constexpr int64_t kTimestampMaxMicroseconds =
    kTimestampMaxSeconds * kMicrosecondsPerSecond + 999999LL;

EvaluateResult MicrosToTimestampResult(int64_t value) {
  if (value < kTimestampMinMicroseconds || value > kTimestampMaxMicroseconds) {
    return EvaluateResult::NewError();
  }
  int64_t seconds = value / kMicrosecondsPerSecond;
  int32_t nanos = (value % kMicrosecondsPerSecond) * kNanosecondsPerMicrosecond;
  if (nanos < 0) {
    seconds--;
    nanos += kNanosecondsPerSecond;
  }
  if (nanos > kTimestampMaxNanos) {  // Explicitly use kTimestampMaxNanos
    return EvaluateResult::NewError();
  }
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result.timestamp_value.seconds = seconds;
  result.timestamp_value.nanos = nanos;
  return EvaluateResult::NewValue(nanopb::MakeMessage(result));
}

}  // namespace

CoreUnixMicrosToTimestamp::CoreUnixMicrosToTimestamp(
    const api::FunctionExpr& expr)
    : UnixToTimestampBase(expr) {
}

CoreUnixMillisToTimestamp::CoreUnixMillisToTimestamp(
    const api::FunctionExpr& expr)
    : UnixToTimestampBase(expr) {
}

CoreUnixSecondsToTimestamp::CoreUnixSecondsToTimestamp(
    const api::FunctionExpr& expr)
    : UnixToTimestampBase(expr) {
}

CoreTimestampToUnixMicros::CoreTimestampToUnixMicros(
    const api::FunctionExpr& expr)
    : TimestampToUnixBase(expr) {
}

CoreTimestampToUnixMillis::CoreTimestampToUnixMillis(
    const api::FunctionExpr& expr)
    : TimestampToUnixBase(expr) {
}

CoreTimestampToUnixSeconds::CoreTimestampToUnixSeconds(
    const api::FunctionExpr& expr)
    : TimestampToUnixBase(expr) {
}

CoreTimestampAdd::CoreTimestampAdd(const api::FunctionExpr& expr)
    : TimestampArithmeticBase(expr) {
}

CoreTimestampSub::CoreTimestampSub(const api::FunctionExpr& expr)
    : TimestampArithmeticBase(expr) {
}

EvaluateResult UnixToTimestampBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "Unix to Timestamp conversion requires exactly 1 param");
  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kInt: {
      return ToTimestamp(evaluated.value()->integer_value);
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      return EvaluateResult::NewError();
  }
}

EvaluateResult CoreUnixMicrosToTimestamp::ToTimestamp(int64_t value) const {
  return MicrosToTimestampResult(value);
}

EvaluateResult CoreUnixMillisToTimestamp::ToTimestamp(int64_t value) const {
  constexpr int64_t kTimestampMinMilliseconds =
      kTimestampMinSeconds * kMillisecondsPerSecond;
  constexpr int64_t kTimestampMaxMilliseconds =
      kTimestampMaxSeconds * kMillisecondsPerSecond + 999LL;
  if (value < kTimestampMinMilliseconds || value > kTimestampMaxMilliseconds) {
    return EvaluateResult::NewError();
  }
  int64_t seconds = value / kMillisecondsPerSecond;
  int32_t nanos = (value % kMillisecondsPerSecond) * 1000000LL;
  if (nanos < 0) {
    seconds--;
    nanos += kNanosecondsPerSecond;
  }
  if (nanos > kTimestampMaxNanos) {
    return EvaluateResult::NewError();
  }
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result.timestamp_value.seconds = seconds;
  result.timestamp_value.nanos = nanos;
  return EvaluateResult::NewValue(nanopb::MakeMessage(result));
}

EvaluateResult CoreUnixSecondsToTimestamp::ToTimestamp(int64_t value) const {
  if (value < kTimestampMinSeconds || value > kTimestampMaxSeconds) {
    return EvaluateResult::NewError();
  }
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result.timestamp_value.seconds = value;
  result.timestamp_value.nanos = 0;
  return EvaluateResult::NewValue(nanopb::MakeMessage(result));
}

EvaluateResult TimestampToUnixBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "Timestamp to Unix conversion requires exactly 1 param");
  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kTimestamp: {
      return ToUnix(evaluated.value()->timestamp_value);
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      return EvaluateResult::NewError();
  }
}

EvaluateResult CoreTimestampToUnixMicros::ToUnix(
    const google_protobuf_Timestamp& ts) const {
  absl::optional<int64_t> seconds_part =
      SafeMultiply(ts.seconds, kMicrosecondsPerSecond);
  if (!seconds_part.has_value()) {
    return EvaluateResult::NewError();
  }
  int64_t micros = seconds_part.value() + ts.nanos / kNanosecondsPerMicrosecond;
  return EvaluateResult::NewValue(IntValue(micros));
}

EvaluateResult CoreTimestampToUnixMillis::ToUnix(
    const google_protobuf_Timestamp& ts) const {
  absl::optional<int64_t> seconds_part =
      SafeMultiply(ts.seconds, kMillisecondsPerSecond);
  if (!seconds_part.has_value()) {
    return EvaluateResult::NewError();
  }
  int64_t millis = seconds_part.value() + ts.nanos / 1000000LL;
  return EvaluateResult::NewValue(IntValue(millis));
}

EvaluateResult CoreTimestampToUnixSeconds::ToUnix(
    const google_protobuf_Timestamp& ts) const {
  if (ts.seconds < kTimestampMinSeconds || ts.seconds > kTimestampMaxSeconds) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(IntValue(ts.seconds));
}

EvaluateResult TimestampArithmeticBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 3,
              "Timestamp arithmetic requires exactly 3 params");

  EvaluateResult ts_result =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  EvaluateResult unit_result =
      expr_->params()[1]->ToEvaluable()->Evaluate(context, document);
  EvaluateResult amount_result =
      expr_->params()[2]->ToEvaluable()->Evaluate(context, document);

  if (ts_result.IsErrorOrUnset() || unit_result.IsErrorOrUnset() ||
      amount_result.IsErrorOrUnset()) {
    return EvaluateResult::NewError();
  }
  if (ts_result.IsNull() || unit_result.IsNull() || amount_result.IsNull()) {
    return EvaluateResult::NewNull();
  }
  if (ts_result.type() != EvaluateResult::ResultType::kTimestamp ||
      unit_result.type() != EvaluateResult::ResultType::kString ||
      amount_result.type() != EvaluateResult::ResultType::kInt) {
    return EvaluateResult::NewError();
  }

  const google_protobuf_Timestamp& ts = ts_result.value()->timestamp_value;
  absl::string_view unit =
      nanopb::MakeStringView(unit_result.value()->string_value);
  int64_t amount = amount_result.value()->integer_value;

  absl::optional<int64_t> micros_to_operate;
  if (unit == "microsecond") {
    micros_to_operate = amount;
  } else if (unit == "millisecond") {
    micros_to_operate = SafeMultiply(amount, 1000);
  } else if (unit == "second") {
    micros_to_operate = SafeMultiply(amount, kMicrosecondsPerSecond);
  } else if (unit == "minute") {
    micros_to_operate = SafeMultiply(amount, 60 * kMicrosecondsPerSecond);
  } else if (unit == "hour") {
    micros_to_operate = SafeMultiply(amount, 3600 * kMicrosecondsPerSecond);
  } else if (unit == "day") {
    micros_to_operate = SafeMultiply(amount, 86400 * kMicrosecondsPerSecond);
  } else {
    return EvaluateResult::NewError();
  }

  if (!micros_to_operate.has_value()) {
    return EvaluateResult::NewError();
  }

  absl::optional<int64_t> seconds_part =
      SafeMultiply(ts.seconds, kMicrosecondsPerSecond);
  absl::optional<int64_t> initial_micros;
  if (seconds_part.has_value()) {
    initial_micros =
        SafeAdd(seconds_part.value(), ts.nanos / kNanosecondsPerMicrosecond);
  }

  if (!initial_micros.has_value()) {
    return EvaluateResult::NewError();
  }

  absl::optional<int64_t> final_micros =
      PerformArithmetic(initial_micros.value(), micros_to_operate.value());
  if (!final_micros.has_value()) {
    return EvaluateResult::NewError();
  }

  return MicrosToTimestampResult(final_micros.value());
}

absl::optional<int64_t> CoreTimestampAdd::PerformArithmetic(
    int64_t initial_micros, int64_t micros_to_operate) const {
  return SafeAdd(initial_micros, micros_to_operate);
}

absl::optional<int64_t> CoreTimestampSub::PerformArithmetic(
    int64_t initial_micros, int64_t micros_to_operate) const {
  return SafeSubtract(initial_micros, micros_to_operate);
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
