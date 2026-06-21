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

#include <algorithm>  // For std::reverse
#include <cctype>
#include <cmath>
#include <functional>  // Added for std::function
#include <limits>      // For std::numeric_limits
#include <locale>
#include <memory>
#include <string>
#include <utility>  // For std::move
#include <vector>   // For std::vector

// Ensure timestamp proto is included
#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/model/value_util.h"  // For value helpers like IsArray, DeepClone
#include "Firestore/core/src/nanopb/message.h"  // Added for MakeMessage
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "absl/strings/ascii.h"  // For AsciiStrToLower/ToUpper (if needed later)
#include "absl/strings/match.h"    // For StartsWith, EndsWith, StrContains
#include "absl/strings/str_cat.h"  // For StrAppend
#include "absl/strings/strip.h"    // For StripAsciiWhitespace
#include "absl/types/optional.h"
#include "re2/re2.h"

namespace firebase {
namespace firestore {
namespace core {

namespace {

// Helper functions for safe integer arithmetic with overflow detection.
// Return nullopt on overflow or error (like division by zero).

absl::optional<int64_t> SafeAdd(int64_t lhs, int64_t rhs) {
  int64_t result;
#if defined(__clang__) || defined(__GNUC__)
  if (__builtin_add_overflow(lhs, rhs, &result)) {
    return absl::nullopt;
  }
#else
  // Manual check (less efficient, might miss some edge cases on weird
  // platforms)
  if ((rhs > 0 && lhs > std::numeric_limits<int64_t>::max() - rhs) ||
      (rhs < 0 && lhs < std::numeric_limits<int64_t>::min() - rhs)) {
    return absl::nullopt;
  }
  result = lhs + rhs;
#endif
  return result;
}

absl::optional<int64_t> SafeSubtract(int64_t lhs, int64_t rhs) {
  int64_t result;
#if defined(__clang__) || defined(__GNUC__)
  if (__builtin_sub_overflow(lhs, rhs, &result)) {
    return absl::nullopt;
  }
#else
  // Manual check
  if ((rhs < 0 && lhs > std::numeric_limits<int64_t>::max() + rhs) ||
      (rhs > 0 && lhs < std::numeric_limits<int64_t>::min() + rhs)) {
    return absl::nullopt;
  }
  result = lhs - rhs;
#endif
  return result;
}

absl::optional<int64_t> SafeMultiply(int64_t lhs, int64_t rhs) {
  int64_t result;
#if defined(__clang__) || defined(__GNUC__)
  if (__builtin_mul_overflow(lhs, rhs, &result)) {
    return absl::nullopt;
  }
#else
  // Manual check (simplified, might not cover all edge cases perfectly)
  if (lhs != 0 && rhs != 0) {
    if (lhs > std::numeric_limits<int64_t>::max() / rhs ||
        lhs < std::numeric_limits<int64_t>::min() / rhs) {
      return absl::nullopt;
    }
  }
  result = lhs * rhs;
#endif
  return result;
}

absl::optional<int64_t> SafeDivide(int64_t lhs, int64_t rhs) {
  if (rhs == 0) {
    return absl::nullopt;  // Division by zero
  }
  // Check for overflow: INT64_MIN / -1
  if (lhs == std::numeric_limits<int64_t>::min() && rhs == -1) {
    return absl::nullopt;
  }
  return lhs / rhs;
}

absl::optional<int64_t> SafeMod(int64_t lhs, int64_t rhs) {
  if (rhs == 0) {
    return absl::nullopt;  // Modulo by zero
  }
  // Check for potential overflow/UB: INT64_MIN % -1
  if (lhs == std::numeric_limits<int64_t>::min() && rhs == -1) {
    // The result is 0 on most platforms, but standard allows signal.
    // Treat as error for consistency.
    return absl::nullopt;
  }
  return lhs % rhs;
}

// Helper to create a Value proto from int64_t
nanopb::Message<google_firestore_v1_Value> IntValue(int64_t val) {
  google_firestore_v1_Value proto;
  proto.which_value_type = google_firestore_v1_Value_integer_value_tag;
  proto.integer_value = val;
  return nanopb::MakeMessage(std::move(proto));
}

// Helper to create a Value proto from double
nanopb::Message<google_firestore_v1_Value> DoubleValue(double val) {
  google_firestore_v1_Value proto;
  proto.which_value_type = google_firestore_v1_Value_double_value_tag;
  proto.double_value = val;
  return nanopb::MakeMessage(std::move(proto));
}

}  // anonymous namespace

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
  if (function.name() == "equal") {
    return std::make_unique<CoreEq>(function);
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
    return std::make_unique<CoreNeq>(function);
  } else if (function.name() == "less_than") {
    return std::make_unique<CoreLt>(function);
  } else if (function.name() == "less_than_or_equal") {
    return std::make_unique<CoreLte>(function);
  } else if (function.name() == "greater_than") {
    return std::make_unique<CoreGt>(function);
  } else if (function.name() == "greater_than_or_equal") {
    return std::make_unique<CoreGte>(function);
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
    return std::make_unique<CoreLogicalMaximum>(function);
  } else if (function.name() == "minimum") {
    return std::make_unique<CoreLogicalMinimum>(function);
  } else if (function.name() == "map_get") {
    return std::make_unique<CoreMapGet>(function);
  } else if (function.name() == "byte_length") {
    return std::make_unique<CoreByteLength>(function);
  } else if (function.name() == "char_length") {
    return std::make_unique<CoreCharLength>(function);
  } else if (function.name() == "string_concat") {
    return std::make_unique<CoreStrConcat>(function);
  } else if (function.name() == "ends_with") {
    return std::make_unique<CoreEndsWith>(function);
  } else if (function.name() == "starts_with") {
    return std::make_unique<CoreStartsWith>(function);
  } else if (function.name() == "string_contains") {
    return std::make_unique<CoreStrContains>(function);
  } else if (function.name() == "to_lower") {
    return std::make_unique<CoreToLower>(function);
  } else if (function.name() == "to_upper") {
    return std::make_unique<CoreToUpper>(function);
  } else if (function.name() == "trim") {
    return std::make_unique<CoreTrim>(function);
  } else if (function.name() == "string_reverse") {
    return std::make_unique<CoreReverse>(function);
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

// --- Comparison Implementations ---

EvaluateResult ComparisonBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "%s() function requires exactly 2 params", expr_->name());

  std::unique_ptr<EvaluableExpr> left_evaluable =
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

  std::unique_ptr<EvaluableExpr> right_evaluable =
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

EvaluateResult CoreEq::CompareToResult(const EvaluateResult& left,
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

EvaluateResult CoreNeq::CompareToResult(const EvaluateResult& left,
                                        const EvaluateResult& right) const {
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

EvaluateResult CoreLt::CompareToResult(const EvaluateResult& left,
                                       const EvaluateResult& right) const {
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

EvaluateResult CoreLte::CompareToResult(const EvaluateResult& left,
                                        const EvaluateResult& right) const {
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

EvaluateResult CoreGt::CompareToResult(const EvaluateResult& left,
                                       const EvaluateResult& right) const {
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

EvaluateResult CoreGte::CompareToResult(const EvaluateResult& left,
                                        const EvaluateResult& right) const {
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

// --- String Expression Implementations ---

namespace {

/**
 * @brief Validates a string as UTF-8 and process the Unicode code points.
 *
 * Iterates through the byte sequence of the input string, performing
 * full UTF-8 validation checks:
 * - Correct number of continuation bytes.
 * - Correct format of continuation bytes (10xxxxxx).
 * - No overlong encodings (e.g., encoding '/' as 2 bytes).
 * - Decoded code points are within the valid Unicode range
 * (U+0000-U+D7FF and U+E000-U+10FFFF), excluding surrogates.
 *
 * @tparam T The type of the result accumulator.
 * @param s The input string (byte sequence) to validate.
 * @param result A pointer to the result accumulator, updated by `func`.
 * @param func A function `void(T* result, uint32_t code_point,
 * absl::string_view utf8_bytes)` called for each valid code point, providing
 * the code point and its UTF-8 byte representation.
 * @return `true` if the string is valid UTF-8, `false` otherwise.
 */
template <typename T>
bool ProcessUtf8(const std::string& s,
                 T* result,
                 std::function<void(T*, uint32_t, absl::string_view)> func) {
  size_t i = 0;
  const size_t len = s.size();
  const unsigned char* data = reinterpret_cast<const unsigned char*>(s.data());

  while (i < len) {
    uint32_t code_point = 0;  // To store the decoded code point
    int num_bytes = 0;
    const unsigned char start_byte = data[i];

    // 1. Determine expected sequence length and initial code point bits
    if ((start_byte & 0x80) == 0) {  // 1-byte sequence (ASCII 0xxxxxxx)
      num_bytes = 1;
      code_point = start_byte;
      // Overlong check: Not possible for 1-byte sequences
      // Range check: ASCII is always valid (0x00-0x7F)
    } else if ((start_byte & 0xE0) == 0xC0) {  // 2-byte sequence (110xxxxx)
      num_bytes = 2;
      code_point = start_byte & 0x1F;  // Mask out 110xxxxx
      // Overlong check: Must not represent code points < 0x80
      // Also, C0 and C1 are specifically invalid start bytes
      if (start_byte < 0xC2) {
        return false;  // C0, C1 are invalid starts
      }
    } else if ((start_byte & 0xF0) == 0xE0) {  // 3-byte sequence (1110xxxx)
      num_bytes = 3;
      code_point = start_byte & 0x0F;          // Mask out 1110xxxx
    } else if ((start_byte & 0xF8) == 0xF0) {  // 4-byte sequence (11110xxx)
      num_bytes = 4;
      code_point =
          start_byte & 0x07;  // Mask out 11110xxx
                              // Overlong check: Must not represent code points
                              // < 0x10000 Range check: Must not represent code
                              // points > 0x10FFFF F4 90.. BF.. is > 0x10FFFF
      if (start_byte > 0xF4) {
        return false;
      }
    } else {
      return false;  // Invalid start byte (e.g., 10xxxxxx or > F4)
    }

    // 2. Check for incomplete sequence
    if (i + num_bytes > len) {
      return false;  // Sequence extends beyond string end
    }

    // 3. Check and process continuation bytes (if any)
    for (int j = 1; j < num_bytes; ++j) {
      const unsigned char continuation_byte = data[i + j];
      if ((continuation_byte & 0xC0) != 0x80) {
        return false;  // Not a valid continuation byte (10xxxxxx)
      }
      // Combine bits into the code point
      code_point = (code_point << 6) | (continuation_byte & 0x3F);
    }

    // 4. Perform Overlong and Range Checks based on the fully decoded
    // code_point
    if (num_bytes == 2 && code_point < 0x80) {
      return false;  // Overlong encoding (should have been 1 byte)
    }
    if (num_bytes == 3 && code_point < 0x800) {
      // Specific check for 0xE0 0x80..0x9F .. sequences (overlong)
      if (start_byte == 0xE0 && (data[i + 1] & 0xFF) < 0xA0) {
        return false;
      }
      return false;  // Overlong encoding (should have been 1 or 2 bytes)
    }
    if (num_bytes == 4 && code_point < 0x10000) {
      // Specific check for 0xF0 0x80..0x8F .. sequences (overlong)
      if (start_byte == 0xF0 && (data[i + 1] & 0xFF) < 0x90) {
        return false;
      }
      return false;  // Overlong encoding (should have been 1, 2 or 3 bytes)
    }

    // Check for surrogates (U+D800 to U+DFFF)
    if (code_point >= 0xD800 && code_point <= 0xDFFF) {
      return false;
    }

    // Check for code points beyond the Unicode maximum (U+10FFFF)
    if (code_point > 0x10FFFF) {
      // Specific check for 0xF4 90..BF .. sequences (> U+10FFFF)
      if (start_byte == 0xF4 && (data[i + 1] & 0xFF) > 0x8F) {
        return false;
      }
      return false;
    }

    // 5. If all checks passed, call the function and advance index
    absl::string_view utf8_bytes(s.data() + i, num_bytes);
    func(result, code_point, utf8_bytes);
    i += num_bytes;
  }

  return true;  // String is valid UTF-8
}

// Helper function to convert SQL LIKE patterns to RE2 regex patterns.
// Handles % (matches any sequence of zero or more characters)
// and _ (matches any single character).
// Escapes other regex special characters.
std::string LikeToRegex(const std::string& like_pattern) {
  std::string regex_pattern = "^";  // Anchor at the start
  for (char c : like_pattern) {
    switch (c) {
      case '%':
        regex_pattern += ".*";
        break;
      case '_':
        regex_pattern += ".";
        break;
      // Escape RE2 special characters
      case '\\':
      case '.':
      case '*':
      case '+':
      case '?':
      case '(':
      case ')':
      case '|':
      case '{':
      case '}':
      case '[':
      case ']':
      case '^':
      case '$':
        regex_pattern += '\\';
        regex_pattern += c;
        break;
      default:
        regex_pattern += c;
        break;
    }
  }
  regex_pattern += '$';  // Anchor at the end
  return regex_pattern;
}

}  // anonymous namespace

EvaluateResult StringSearchBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 2,
              "%s() function requires exactly 2 params", expr_->name());

  bool has_null = false;
  EvaluateResult op1 =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (op1.type()) {
    case EvaluateResult::ResultType::kString: {
      break;
    }
    case EvaluateResult::ResultType::kNull: {
      has_null = true;
      break;
    }
    default: {
      return EvaluateResult::NewError();
    }
  }

  EvaluateResult op2 =
      expr_->params()[1]->ToEvaluable()->Evaluate(context, document);
  switch (op2.type()) {
    case EvaluateResult::ResultType::kString: {
      break;
    }
    case EvaluateResult::ResultType::kNull: {
      has_null = true;
      break;
    }
    default: {
      return EvaluateResult::NewError();
    }
  }

  // Null propagation
  if (has_null) {
    return EvaluateResult::NewNull();
  }

  // Both operands are valid strings, perform the specific search
  std::string value_str = nanopb::MakeString(op1.value()->string_value);
  std::string search_str = nanopb::MakeString(op2.value()->string_value);

  return PerformSearch(value_str, search_str);
}

EvaluateResult CoreRegexContains::PerformSearch(
    const std::string& value, const std::string& search) const {
  re2::RE2 re(search);
  if (!re.ok()) {
    // TODO(wuandy): Log warning about invalid regex?
    return EvaluateResult::NewError();
  }
  bool result = RE2::PartialMatch(value, re);
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreRegexMatch::PerformSearch(const std::string& value,
                                             const std::string& search) const {
  re2::RE2 re(search);
  if (!re.ok()) {
    // TODO(wuandy): Log warning about invalid regex?
    return EvaluateResult::NewError();
  }
  bool result = RE2::FullMatch(value, re);
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreLike::PerformSearch(const std::string& value,
                                       const std::string& search) const {
  std::string regex_pattern = LikeToRegex(search);
  re2::RE2 re(regex_pattern);
  // LikeToRegex should ideally produce valid regex, but check anyway.
  if (!re.ok()) {
    // TODO(wuandy): Log warning about failed LIKE conversion?
    return EvaluateResult::NewError();
  }
  // LIKE implies matching the entire string
  bool result = RE2::FullMatch(value, re);
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreByteLength::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "byte_length() requires exactly 1 param");
  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kString: {
      const auto str = nanopb::MakeString(evaluated.value()->string_value);
      // Validate UTF-8 using the generic function with a no-op lambda
      bool dummy_result = false;  // Result accumulator not needed here
      bool is_valid_utf8 = ProcessUtf8<bool>(
          str, &dummy_result,
          [](bool*, uint32_t, absl::string_view) { /* no-op */ });

      if (is_valid_utf8) {
        return EvaluateResult::NewValue(IntValue(str.size()));
      } else {
        return EvaluateResult::NewError();  // Invalid UTF-8
      }
    }
    case EvaluateResult::ResultType::kBytes: {
      const size_t len = evaluated.value()->bytes_value == nullptr
                             ? 0
                             : evaluated.value()->bytes_value->size;
      return EvaluateResult::NewValue(IntValue(len));
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      return EvaluateResult::NewError();  // Type mismatch or Error/Unset
  }
}

EvaluateResult CoreCharLength::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "char_length() requires exactly 1 param");
  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kString: {
      const auto str = nanopb::MakeString(evaluated.value()->string_value);
      // Count codepoints using the generic function
      int char_count = 0;
      bool is_valid_utf8 = ProcessUtf8<int>(
          str, &char_count,
          [](int* count, uint32_t, absl::string_view) { (*count)++; });

      if (is_valid_utf8) {
        return EvaluateResult::NewValue(IntValue(char_count));
      } else {
        return EvaluateResult::NewError();  // Invalid UTF-8
      }
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      return EvaluateResult::NewError();  // Type mismatch or Error/Unset
  }
}

EvaluateResult CoreStrConcat::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  std::string result_string;

  bool found_null = false;
  for (const auto& param : expr_->params()) {
    EvaluateResult evaluated =
        param->ToEvaluable()->Evaluate(context, document);
    switch (evaluated.type()) {
      case EvaluateResult::ResultType::kString: {
        absl::StrAppend(&result_string,
                        nanopb::MakeString(evaluated.value()->string_value));
        break;
      }
      case EvaluateResult::ResultType::kNull: {
        found_null = true;
        break;
      }
      default:
        return EvaluateResult::NewError();  // Type mismatch or Error/Unset
    }
  }

  if (found_null) {
    return EvaluateResult::NewNull();
  }

  return EvaluateResult::NewValue(model::StringValue(result_string));
}

EvaluateResult CoreEndsWith::PerformSearch(const std::string& value,
                                           const std::string& search) const {
  // Use absl::EndsWith
  bool result = absl::EndsWith(value, search);
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreStartsWith::PerformSearch(const std::string& value,
                                             const std::string& search) const {
  // Use absl::StartsWith
  bool result = absl::StartsWith(value, search);
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreStrContains::PerformSearch(const std::string& value,
                                              const std::string& search) const {
  // Use absl::StrContains
  bool result = absl::StrContains(value, search);
  return EvaluateResult::NewValue(
      nanopb::MakeMessage(result ? model::TrueValue() : model::FalseValue()));
}

EvaluateResult CoreToLower::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "to_lower() requires exactly 1 param");
  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kString: {
      // TODO(pipeline): Use https://unicode-org.github.io/icu/userguide/locale/
      // to be consistent with backend.
      std::locale locale;
      std::string str = nanopb::MakeString(evaluated.value()->string_value);
      std::transform(str.begin(), str.end(), str.begin(),
                     [&locale](char c) { return std::tolower(c, locale); });
      return EvaluateResult::NewValue(model::StringValue(str));
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      return EvaluateResult::NewError();  // Type mismatch or Error/Unset
  }
}
EvaluateResult CoreToUpper::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "to_upper() requires exactly 1 param");
  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kString: {
      // TODO(pipeline): Use https://unicode-org.github.io/icu/userguide/locale/
      // to be consistent with backend.
      std::locale locale;
      std::string str = nanopb::MakeString(evaluated.value()->string_value);
      std::transform(str.begin(), str.end(), str.begin(),
                     [&locale](char c) { return std::toupper(c, locale); });
      return EvaluateResult::NewValue(model::StringValue(str));
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      return EvaluateResult::NewError();  // Type mismatch or Error/Unset
  }
}

EvaluateResult CoreTrim::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1, "trim() requires exactly 1 param");
  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kString: {
      std::string str = nanopb::MakeString(evaluated.value()->string_value);
      absl::string_view trimmed_view = absl::StripAsciiWhitespace(str);
      return EvaluateResult::NewValue(model::StringValue(trimmed_view));
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      return EvaluateResult::NewError();  // Type mismatch or Error/Unset
  }
}

EvaluateResult CoreReverse::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "reverse() requires exactly 1 param");
  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kString: {
      std::string reversed;
      bool is_valid_utf8 = ProcessUtf8<std::string>(
          nanopb::MakeString(evaluated.value()->string_value), &reversed,
          [](std::string* reversed_str, uint32_t /*code_point*/,
             absl::string_view utf8_bytes) {
            reversed_str->insert(0, utf8_bytes.data(), utf8_bytes.size());
          });

      if (is_valid_utf8) {
        return EvaluateResult::NewValue(model::StringValue(reversed));
      }

      return EvaluateResult::NewError();
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      return EvaluateResult::NewError();  // Type mismatch or Error/Unset
  }
}

// --- Map Expression Implementations ---

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

// --- Array Expression Implementations ---

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
  auto const eq_any =
      CoreEqAny(api::FunctionExpr("equal_any", std::move(reversed_params)));
  return eq_any.Evaluate(context, document);
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
      return EvaluateResult::NewValue(IntValue(array_size));
    }
    default: {
      return EvaluateResult::NewError();
    }
  }
}

// --- Logical Expression Implementations ---

// Constructor definitions removed as they are now inline in the header

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
  HARD_ASSERT(expr_->params().size() == 2,
              "eq_any() function requires exactly 2 params (search value and "
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

EvaluateResult CoreLogicalMaximum::Evaluate(
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

EvaluateResult CoreLogicalMinimum::Evaluate(
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

// --- Debugging Expression Implementations ---

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

EvaluateResult CoreNot::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "not() function requires exactly 1 param");

  std::unique_ptr<EvaluableExpr> operand_evaluable =
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

namespace {
// timestamp utilities

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
constexpr int64_t kNanosecondsPerMillisecond = 1000000LL;
constexpr int64_t kNanosecondsPerSecond = 1000000000LL;

// 0001-01-01T00:00:00.000Z
constexpr int64_t kTimestampMinMilliseconds =
    kTimestampMinSeconds * kMillisecondsPerSecond;
// 9999-12-31T23:59:59.999Z
constexpr int64_t kTimestampMaxMilliseconds =
    kTimestampMaxSeconds * kMillisecondsPerSecond + 999LL;

// 0001-01-01T00:00:00.000000Z
constexpr int64_t kTimestampMinMicroseconds =
    kTimestampMinSeconds * kMicrosecondsPerSecond;
// 9999-12-31T23:59:59.999999Z
constexpr int64_t kTimestampMaxMicroseconds =
    kTimestampMaxSeconds * kMicrosecondsPerSecond + 999999LL;

// --- Timestamp Helper Functions ---

bool IsMicrosInBounds(int64_t micros) {
  return micros >= kTimestampMinMicroseconds &&
         micros <= kTimestampMaxMicroseconds;
}

bool IsMillisInBounds(int64_t millis) {
  return millis >= kTimestampMinMilliseconds &&
         millis <= kTimestampMaxMilliseconds;
}

bool IsSecondsInBounds(int64_t seconds) {
  return seconds >= kTimestampMinSeconds && seconds <= kTimestampMaxSeconds;
}

// Checks if a google_protobuf_Timestamp is within the valid Firestore range.
bool IsTimestampInBounds(const google_protobuf_Timestamp& ts) {
  if (ts.seconds < kTimestampMinSeconds || ts.seconds > kTimestampMaxSeconds) {
    return false;
  }
  // Nanos must be non-negative and less than 1 second.
  if (ts.nanos < 0 || ts.nanos >= kNanosecondsPerSecond) {
    return false;
  }
  // Additional checks for min/max boundaries.
  if (ts.seconds == kTimestampMinSeconds && ts.nanos != 0) {
    return false;  // Min timestamp must have 0 nanos.
  }
  if (ts.seconds == kTimestampMaxSeconds && ts.nanos > kTimestampMaxNanos) {
    return false;  // Max timestamp allows up to 999,999,999 nanos.
  }
  return true;
}

// Converts a google_protobuf_Timestamp to total microseconds since epoch.
// Returns nullopt if the timestamp is out of bounds or calculation overflows.
absl::optional<int64_t> TimestampToMicros(const google_protobuf_Timestamp& ts) {
  if (!IsTimestampInBounds(ts)) {
    return absl::nullopt;
  }

  absl::optional<int64_t> seconds_part_micros =
      SafeMultiply(ts.seconds, kMicrosecondsPerSecond);
  if (!seconds_part_micros.has_value()) {
    return absl::nullopt;  // Overflow multiplying seconds
  }

  // Integer division truncates towards zero.
  int64_t nanos_part_micros = ts.nanos / kNanosecondsPerMicrosecond;

  absl::optional<int64_t> total_micros =
      SafeAdd(seconds_part_micros.value(), nanos_part_micros);

  // Final check to ensure the result is within the representable microsecond
  // range.
  if (!total_micros.has_value() || !IsMicrosInBounds(total_micros.value())) {
    return absl::nullopt;
  }

  return total_micros;
}

// Enum for time units used in timestamp arithmetic.
enum class TimeUnit {
  kMicrosecond,
  kMillisecond,
  kSecond,
  kMinute,
  kHour,
  kDay
};

// Parses a string representation of a time unit into the TimeUnit enum.
absl::optional<TimeUnit> ParseTimeUnit(const std::string& unit_str) {
  if (unit_str == "microsecond") return TimeUnit::kMicrosecond;
  if (unit_str == "millisecond") return TimeUnit::kMillisecond;
  if (unit_str == "second") return TimeUnit::kSecond;
  if (unit_str == "minute") return TimeUnit::kMinute;
  if (unit_str == "hour") return TimeUnit::kHour;
  if (unit_str == "day") return TimeUnit::kDay;
  return absl::nullopt;  // Invalid unit string
}

// Calculates the total microseconds for a given unit and amount.
// Returns nullopt on overflow.
absl::optional<int64_t> MicrosFromUnitAndAmount(TimeUnit unit, int64_t amount) {
  switch (unit) {
    case TimeUnit::kMicrosecond:
      return amount;  // No multiplication needed, no overflow possible here.
    case TimeUnit::kMillisecond:
      return SafeMultiply(
          amount, kNanosecondsPerMillisecond / kNanosecondsPerMicrosecond);
    case TimeUnit::kSecond:
      return SafeMultiply(amount, kMicrosecondsPerSecond);
    case TimeUnit::kMinute:
      return SafeMultiply(amount, 60LL * kMicrosecondsPerSecond);
    case TimeUnit::kHour:
      return SafeMultiply(amount, 3600LL * kMicrosecondsPerSecond);
    case TimeUnit::kDay:
      return SafeMultiply(amount, 86400LL * kMicrosecondsPerSecond);
    default:
      // Should not happen if ParseTimeUnit is used correctly.
      HARD_FAIL("Invalid TimeUnit enum value");
      return absl::nullopt;
  }
}

// Helper to create a google_protobuf_Timestamp from seconds and nanos.
// Assumes inputs are already validated to be within bounds.
google_protobuf_Timestamp CreateTimestampProto(int64_t seconds, int32_t nanos) {
  google_protobuf_Timestamp ts;
  // Use direct member assignment for protobuf fields
  ts.seconds = seconds;
  ts.nanos = nanos;
  return ts;
}

// Helper function to adjust timestamp for negative nanoseconds.
// Returns the adjusted {seconds, nanos} pair. Returns nullopt if adjusting
// seconds underflows.
absl::optional<std::pair<int64_t, int32_t>> AdjustTimestamp(int64_t seconds,
                                                            int32_t nanos) {
  if (nanos < 0) {
    absl::optional<int64_t> adjusted_seconds = SafeSubtract(seconds, 1);
    if (!adjusted_seconds.has_value()) {
      return absl::nullopt;  // Underflow during adjustment
    }
    // Ensure nanos is within [-1e9 + 1, -1] before adding 1e9.
    // The modulo operation should guarantee this range for negative results.
    return std::make_pair(adjusted_seconds.value(),
                          nanos + kNanosecondsPerSecond);
  }
  // No adjustment needed, return original values.
  return std::make_pair(seconds, nanos);
}

}  // anonymous namespace

// --- Timestamp Expression Implementations ---

EvaluateResult UnixToTimestampBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "%s() function requires exactly 1 param", expr_->name());

  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kInt: {
      absl::optional<int64_t> value = model::GetInteger(*evaluated.value());
      HARD_ASSERT(value.has_value(), "Integer value extraction failed");
      return ToTimestamp(value.value());
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      // Type error (not integer or null)
      return EvaluateResult::NewError();
  }
}

EvaluateResult TimestampToUnixBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(expr_->params().size() == 1,
              "%s() function requires exactly 1 param", expr_->name());

  EvaluateResult evaluated =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);

  switch (evaluated.type()) {
    case EvaluateResult::ResultType::kTimestamp: {
      // Check if the input timestamp is within valid bounds before conversion.
      if (!IsTimestampInBounds(evaluated.value()->timestamp_value)) {
        return EvaluateResult::NewError();
      }
      return ToUnix(evaluated.value()->timestamp_value);
    }
    case EvaluateResult::ResultType::kNull:
      return EvaluateResult::NewNull();
    default:
      // Type error (not timestamp or null)
      return EvaluateResult::NewError();
  }
}

EvaluateResult TimestampArithmeticBase::Evaluate(
    const api::EvaluateContext& context,
    const model::PipelineInputOutput& document) const {
  HARD_ASSERT(
      expr_->params().size() == 3,
      "%s() function requires exactly 3 params (timestamp, unit, amount)",
      expr_->name());

  bool has_null = false;

  // 1. Evaluate Timestamp operand
  EvaluateResult timestamp_result =
      expr_->params()[0]->ToEvaluable()->Evaluate(context, document);
  switch (timestamp_result.type()) {
    case EvaluateResult::ResultType::kTimestamp:
      // Check initial timestamp bounds
      if (!IsTimestampInBounds(timestamp_result.value()->timestamp_value)) {
        return EvaluateResult::NewError();
      }
      break;
    case EvaluateResult::ResultType::kNull:
      has_null = true;
      break;
    default:
      return EvaluateResult::NewError();  // Type error
  }

  // 2. Evaluate Unit operand (must be string)
  EvaluateResult unit_result =
      expr_->params()[1]->ToEvaluable()->Evaluate(context, document);
  absl::optional<TimeUnit> time_unit;
  switch (unit_result.type()) {
    case EvaluateResult::ResultType::kString: {
      std::string unit_str =
          nanopb::MakeString(unit_result.value()->string_value);
      time_unit = ParseTimeUnit(unit_str);
      if (!time_unit.has_value()) {
        return EvaluateResult::NewError();  // Invalid unit string
      }
      break;
    }
    case EvaluateResult::ResultType::kNull:
      has_null = true;
      break;
    default:
      return EvaluateResult::NewError();  // Type error
  }

  // 3. Evaluate Amount operand (must be integer)
  EvaluateResult amount_result =
      expr_->params()[2]->ToEvaluable()->Evaluate(context, document);
  absl::optional<int64_t> amount;
  switch (amount_result.type()) {
    case EvaluateResult::ResultType::kInt:
      amount = model::GetInteger(*amount_result.value());
      HARD_ASSERT(amount.has_value(), "Integer value extraction failed");
      break;
    case EvaluateResult::ResultType::kNull:
      has_null = true;
      break;
    default:
      return EvaluateResult::NewError();  // Type error
  }

  // Null propagation
  if (has_null) {
    return EvaluateResult::NewNull();
  }

  // Calculate initial micros and micros to operate
  absl::optional<int64_t> initial_micros =
      TimestampToMicros(timestamp_result.value()->timestamp_value);
  if (!initial_micros.has_value()) {
    // Should have been caught by IsTimestampInBounds earlier, but double-check.
    return EvaluateResult::NewError();
  }

  absl::optional<int64_t> micros_to_operate =
      MicrosFromUnitAndAmount(time_unit.value(), amount.value());
  if (!micros_to_operate.has_value()) {
    return EvaluateResult::NewError();  // Overflow calculating micros delta
  }

  // Perform the specific arithmetic (add or subtract)
  absl::optional<int64_t> new_micros_opt =
      PerformArithmetic(initial_micros.value(), micros_to_operate.value());
  if (!new_micros_opt.has_value()) {
    return EvaluateResult::NewError();  // Arithmetic overflow/error
  }
  int64_t new_micros = new_micros_opt.value();

  // Check final microsecond bounds
  if (!IsMicrosInBounds(new_micros)) {
    return EvaluateResult::NewError();
  }

  // Convert back to seconds and nanos
  // Use SafeDivide to handle potential INT64_MIN / -1 edge case, though
  // unlikely here.
  absl::optional<int64_t> new_seconds_opt =
      SafeDivide(new_micros, kMicrosecondsPerSecond);
  if (!new_seconds_opt.has_value()) {
    return EvaluateResult::NewError();  // Should not happen if IsMicrosInBounds
                                        // passed
  }
  int64_t new_seconds = new_seconds_opt.value();
  int64_t nanos_remainder_micros = new_micros % kMicrosecondsPerSecond;

  // Adjust seconds and calculate nanos based on remainder sign
  int32_t new_nanos;
  if (nanos_remainder_micros < 0) {
    // If remainder is negative, adjust seconds down and make nanos positive.
    absl::optional<int64_t> adjusted_seconds_opt = SafeSubtract(new_seconds, 1);
    if (!adjusted_seconds_opt.has_value())
      return EvaluateResult::NewError();  // Overflow
    new_seconds = adjusted_seconds_opt.value();
    new_nanos =
        static_cast<int32_t>((nanos_remainder_micros + kMicrosecondsPerSecond) *
                             kNanosecondsPerMicrosecond);
  } else {
    new_nanos = static_cast<int32_t>(nanos_remainder_micros *
                                     kNanosecondsPerMicrosecond);
  }

  // Create the final timestamp proto
  google_protobuf_Timestamp result_ts =
      CreateTimestampProto(new_seconds, new_nanos);

  // Final check on calculated timestamp bounds
  if (!IsTimestampInBounds(result_ts)) {
    return EvaluateResult::NewError();
  }

  // Wrap in Value proto and return
  google_firestore_v1_Value result_value;
  result_value.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result_value.timestamp_value = result_ts;  // Copy the timestamp proto
  return EvaluateResult::NewValue(nanopb::MakeMessage(std::move(result_value)));
}

// --- Specific Timestamp Function Implementations ---

// Define constructors declared in the header
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

// Define member function implementations
EvaluateResult CoreUnixMicrosToTimestamp::ToTimestamp(int64_t micros) const {
  if (!IsMicrosInBounds(micros)) {
    return EvaluateResult::NewError();
  }

  // Use SafeDivide to handle potential INT64_MIN / -1 edge case, though
  // unlikely here.
  absl::optional<int64_t> seconds_opt =
      SafeDivide(micros, kMicrosecondsPerSecond);
  if (!seconds_opt.has_value()) return EvaluateResult::NewError();
  int64_t initial_seconds = seconds_opt.value();
  // Calculate initial nanos directly from the remainder.
  int32_t initial_nanos = static_cast<int32_t>(
      (micros % kMicrosecondsPerSecond) * kNanosecondsPerMicrosecond);

  // Adjust for negative nanoseconds using the helper function.
  absl::optional<std::pair<int64_t, int32_t>> adjusted_ts =
      AdjustTimestamp(initial_seconds, initial_nanos);

  if (!adjusted_ts.has_value()) {
    return EvaluateResult::NewError();  // Overflow during adjustment
  }

  int64_t final_seconds = adjusted_ts.value().first;
  int32_t final_nanos = adjusted_ts.value().second;

  google_firestore_v1_Value result_value;
  result_value.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result_value.timestamp_value =
      CreateTimestampProto(final_seconds, final_nanos);

  // Final bounds check after adjustment.
  if (!IsTimestampInBounds(result_value.timestamp_value)) {
    return EvaluateResult::NewError();
  }

  return EvaluateResult::NewValue(nanopb::MakeMessage(std::move(result_value)));
}

EvaluateResult CoreUnixMillisToTimestamp::ToTimestamp(int64_t millis) const {
  if (!IsMillisInBounds(millis)) {
    return EvaluateResult::NewError();
  }

  absl::optional<int64_t> seconds_opt =
      SafeDivide(millis, kMillisecondsPerSecond);
  if (!seconds_opt.has_value()) return EvaluateResult::NewError();
  int64_t initial_seconds = seconds_opt.value();
  // Calculate initial nanos directly from the remainder.
  int32_t initial_nanos = static_cast<int32_t>(
      (millis % kMillisecondsPerSecond) * kNanosecondsPerMillisecond);

  // Adjust for negative nanoseconds using the helper function.
  absl::optional<std::pair<int64_t, int32_t>> adjusted_ts =
      AdjustTimestamp(initial_seconds, initial_nanos);

  if (!adjusted_ts.has_value()) {
    return EvaluateResult::NewError();  // Overflow during adjustment
  }

  int64_t final_seconds = adjusted_ts.value().first;
  int32_t final_nanos = adjusted_ts.value().second;

  google_firestore_v1_Value result_value;
  result_value.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result_value.timestamp_value =
      CreateTimestampProto(final_seconds, final_nanos);

  // Final bounds check after adjustment.
  if (!IsTimestampInBounds(result_value.timestamp_value)) {
    return EvaluateResult::NewError();
  }

  return EvaluateResult::NewValue(nanopb::MakeMessage(std::move(result_value)));
}

EvaluateResult CoreUnixSecondsToTimestamp::ToTimestamp(int64_t seconds) const {
  if (!IsSecondsInBounds(seconds)) {
    return EvaluateResult::NewError();
  }

  google_firestore_v1_Value result_value;
  result_value.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result_value.timestamp_value =
      CreateTimestampProto(seconds, 0);  // Nanos are always 0

  // Bounds check is implicitly handled by IsSecondsInBounds
  return EvaluateResult::NewValue(nanopb::MakeMessage(std::move(result_value)));
}

EvaluateResult CoreTimestampToUnixMicros::ToUnix(
    const google_protobuf_Timestamp& ts) const {
  absl::optional<int64_t> micros = TimestampToMicros(ts);
  // Check if the resulting micros are within representable bounds (already done
  // in TimestampToMicros)
  if (!micros.has_value()) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(IntValue(micros.value()));
}

EvaluateResult CoreTimestampToUnixMillis::ToUnix(
    const google_protobuf_Timestamp& ts) const {
  absl::optional<int64_t> micros_opt = TimestampToMicros(ts);
  if (!micros_opt.has_value()) {
    return EvaluateResult::NewError();
  }
  int64_t micros = micros_opt.value();

  // Perform division, truncating towards zero.
  absl::optional<int64_t> millis_opt = SafeDivide(micros, 1000LL);
  if (!millis_opt.has_value()) {
    // This should ideally not happen if micros were in bounds, but check
    // anyway.
    return EvaluateResult::NewError();
  }
  int64_t millis = millis_opt.value();

  // Adjust for negative timestamps where truncation differs from floor
  // division. If micros is negative and not perfectly divisible by 1000,
  // subtract 1 from millis.
  if (micros < 0 && (micros % 1000LL != 0)) {
    absl::optional<int64_t> adjusted_millis_opt = SafeSubtract(millis, 1);
    if (!adjusted_millis_opt.has_value())
      return EvaluateResult::NewError();  // Overflow check
    millis = adjusted_millis_opt.value();
  }

  // Check if the resulting millis are within representable bounds
  if (!IsMillisInBounds(millis)) {
    return EvaluateResult::NewError();
  }

  return EvaluateResult::NewValue(IntValue(millis));
}

EvaluateResult CoreTimestampToUnixSeconds::ToUnix(
    const google_protobuf_Timestamp& ts) const {
  // Seconds are directly available and already checked by IsTimestampInBounds
  // in base class.
  int64_t seconds = ts.seconds;
  // Check if the resulting seconds are within representable bounds (redundant
  // but safe)
  if (!IsSecondsInBounds(seconds)) {
    return EvaluateResult::NewError();
  }
  return EvaluateResult::NewValue(IntValue(seconds));
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
