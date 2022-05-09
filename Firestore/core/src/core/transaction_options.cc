/*
 * Copyright 2020 Google LLC
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

#include "Firestore/core/src/core/transaction_options.h"

#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/hashing.h"
#include "Firestore/core/src/util/string_format.h"
#include "Firestore/core/src/util/to_string.h"

namespace firebase {
namespace firestore {
namespace core {

void TransactionOptions::set_max_attempts(int32_t max_attempts) {
  HARD_ASSERT(max_attempts > 0, "invalid max_attempts: %s",
              util::ToString(max_attempts));
  max_attempts_ = max_attempts;
}

std::string TransactionOptions::ToString() const {
  return util::StringFormat("TransactionOptions(max_attempts=%s)",
                            util::ToString(max_attempts_));
}

size_t TransactionOptions::Hash() const {
  return util::Hash(max_attempts_);
}

std::ostream& operator<<(std::ostream& os, const TransactionOptions& options) {
  return os << options.ToString();
}

bool operator==(const TransactionOptions& lhs, const TransactionOptions& rhs) {
  return lhs.max_attempts_ == rhs.max_attempts_;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
