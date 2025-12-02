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

#include "Firestore/core/src/pipeline/string_evaluation.h"

#include <algorithm>
#include <cctype>
#include <functional>
#include <locale>
#include <string>
#include <vector>

#include "Firestore/core/src/pipeline/util_evaluation.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/match.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/strip.h"
#include "re2/re2.h"

namespace firebase {
namespace firestore {
namespace core {

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
        google_firestore_v1_Value val;
        val.which_value_type = google_firestore_v1_Value_integer_value_tag;
        val.integer_value = str.size();
        return EvaluateResult::NewValue(nanopb::MakeMessage(val));
      } else {
        return EvaluateResult::NewError();  // Invalid UTF-8
      }
    }
    case EvaluateResult::ResultType::kBytes: {
      const size_t len = evaluated.value()->bytes_value == nullptr
                             ? 0
                             : evaluated.value()->bytes_value->size;
      google_firestore_v1_Value val;
      val.which_value_type = google_firestore_v1_Value_integer_value_tag;
      val.integer_value = len;
      return EvaluateResult::NewValue(nanopb::MakeMessage(val));
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
        google_firestore_v1_Value val;
        val.which_value_type = google_firestore_v1_Value_integer_value_tag;
        val.integer_value = char_count;
        return EvaluateResult::NewValue(nanopb::MakeMessage(val));
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

EvaluateResult CoreStringConcat::Evaluate(
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

EvaluateResult CoreStringContains::PerformSearch(
    const std::string& value, const std::string& search) const {
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
      std::locale locale{"en_US.UTF-8"};
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
      std::locale locale{"en_US.UTF-8"};
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

EvaluateResult CoreStringReverse::Evaluate(
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

}  // namespace core
}  // namespace firestore
}  // namespace firebase
