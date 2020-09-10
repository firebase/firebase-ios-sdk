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

#ifndef FIRESTORE_CORE_SRC_CORE_KEY_FIELD_NOT_IN_FILTER_H_
#define FIRESTORE_CORE_SRC_CORE_KEY_FIELD_NOT_IN_FILTER_H_

#include <string>

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {
namespace core {

/**
 * A Filter that matches on key fields not present within an array.
 */
class KeyFieldNotInFilter : public FieldFilter {
 public:
  KeyFieldNotInFilter(model::FieldPath field, model::FieldValue value);

 private:
  class Rep;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CORE_KEY_FIELD_NOT_IN_FILTER_H_
