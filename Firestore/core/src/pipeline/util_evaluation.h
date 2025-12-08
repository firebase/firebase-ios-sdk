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

#ifndef FIRESTORE_CORE_SRC_PIPELINE_UTIL_EVALUATION_H_
#define FIRESTORE_CORE_SRC_PIPELINE_UTIL_EVALUATION_H_

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/nanopb/message.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace core {

nanopb::Message<google_firestore_v1_Value> IntValue(int64_t val);

absl::optional<int64_t> SafeAdd(int64_t lhs, int64_t rhs);
absl::optional<int64_t> SafeSubtract(int64_t lhs, int64_t rhs);
absl::optional<int64_t> SafeMultiply(int64_t lhs, int64_t rhs);
absl::optional<int64_t> SafeDivide(int64_t lhs, int64_t rhs);
absl::optional<int64_t> SafeMod(int64_t lhs, int64_t rhs);

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_PIPELINE_UTIL_EVALUATION_H_
