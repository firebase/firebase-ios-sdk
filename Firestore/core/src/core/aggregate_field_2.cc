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

#include "Firestore/core/src/core/aggregate_field_2.h"

namespace firebase {
namespace firestore {
namespace core {

std::shared_ptr<CountAggregateField2> AggregateField2::count() {
  return std::make_shared<CountAggregateField2>();
}

std::shared_ptr<AverageAggregateField2> AggregateField2::average() {
  return std::make_shared<AverageAggregateField2>();
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
