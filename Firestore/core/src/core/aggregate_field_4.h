/*
 * Copyright 2023 Google LLC
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

#ifndef FIREBASE_AGGREGATE_FIELD_4_H
#define FIREBASE_AGGREGATE_FIELD_4_H

#include <iosfwd>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {

namespace core {

class AggregateField4 {
 public:
  enum class Type {
    kAggregateField,
    kSumAggregateField,
    kCountAggregateField,
    kAverageAggregateField,
  };

  Type type() const {
    return _class_type;
  }

  static AggregateField4 count() {
    return AggregateField4(Type::kCountAggregateField);
  }

  static AggregateField4 average() {
    return AggregateField4(Type::kAverageAggregateField);
  }

 private:
  explicit AggregateField4(Type t) : _class_type(t) {
  }

  Type _class_type;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_AGGREGATE_FIELD_4_H
