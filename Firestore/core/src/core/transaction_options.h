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

#ifndef FIRESTORE_CORE_SRC_CORE_TRANSACTION_OPTIONS_H_
#define FIRESTORE_CORE_SRC_CORE_TRANSACTION_OPTIONS_H_

#include <iosfwd>
#include <string>

namespace firebase {
namespace firestore {
namespace core {

class TransactionOptions {
 public:
  int32_t max_attempts() const {
    return max_attempts_;
  }

  void set_max_attempts(int32_t max_attempts);

  std::string ToString() const;

  friend bool operator==(const TransactionOptions&, const TransactionOptions&);

  size_t Hash() const;

 private:
  int32_t max_attempts_ = 5;
};

std::ostream& operator<<(std::ostream&, const TransactionOptions&);

inline bool operator!=(const TransactionOptions& lhs,
                       const TransactionOptions& rhs) {
  return !(lhs == rhs);
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CORE_TRANSACTION_OPTIONS_H_
