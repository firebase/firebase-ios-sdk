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

#include "Firestore/core/src/pipeline/util_evaluation.h"

#include <limits>
#include <utility>

namespace firebase {
namespace firestore {
namespace core {

nanopb::Message<google_firestore_v1_Value> IntValue(int64_t val) {
  google_firestore_v1_Value proto;
  proto.which_value_type = google_firestore_v1_Value_integer_value_tag;
  proto.integer_value = val;
  return nanopb::MakeMessage(std::move(proto));
}

absl::optional<int64_t> SafeAdd(int64_t lhs, int64_t rhs) {
  int64_t result;
#if defined(__clang__) || defined(__GNUC__)
  if (__builtin_add_overflow(lhs, rhs, &result)) {
    return absl::nullopt;
  }
#else
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
    return absl::nullopt;
  }
  if (lhs == std::numeric_limits<int64_t>::min() && rhs == -1) {
    return absl::nullopt;
  }
  return lhs / rhs;
}

absl::optional<int64_t> SafeMod(int64_t lhs, int64_t rhs) {
  if (rhs == 0) {
    return absl::nullopt;
  }
  if (lhs == std::numeric_limits<int64_t>::min() && rhs == -1) {
    return absl::nullopt;
  }
  return lhs % rhs;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
