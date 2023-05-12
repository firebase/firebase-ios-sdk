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

#include <vector>

#include "Firestore/core/src/model/aggregate_field.h"

namespace firebase {
namespace firestore {
namespace model {

size_t AggregateField::Hash() const {
  return util::Hash(op, alias, fieldPath.CanonicalString());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
