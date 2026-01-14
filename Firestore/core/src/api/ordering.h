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

#ifndef FIRESTORE_CORE_SRC_API_ORDERING_H_
#define FIRESTORE_CORE_SRC_API_ORDERING_H_

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/util/exception.h"

namespace firebase {
namespace firestore {
namespace api {

class Ordering {
 public:
  enum Direction {
    ASCENDING,
    DESCENDING,
  };

  static Direction DirectionFromString(const std::string& str) {
    if (str == "ascending") return ASCENDING;
    if (str == "descending") return DESCENDING;
    util::ThrowInvalidArgument("Unknown direction: '%s' ", str);
  }

  Ordering(std::shared_ptr<api::Expr> expr, Direction direction)
      : expr_(expr), direction_(direction) {
  }

  const Expr* expr() const {
    return expr_.get();
  }

  const std::shared_ptr<Expr> expr_shared() const {
    return expr_;
  }

  Direction direction() const {
    return direction_;
  }

  Ordering WithReversedDirection() const {
    return Ordering(expr_, direction_ == ASCENDING ? DESCENDING : ASCENDING);
  }

  google_firestore_v1_Value to_proto() const;

 private:
  std::shared_ptr<api::Expr> expr_;
  Direction direction_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_ORDERING_H_
