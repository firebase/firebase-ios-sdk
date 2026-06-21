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

#include "Firestore/core/src/api/ordering.h"

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace api {

google_firestore_v1_Value Ordering::to_proto() const {
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_map_value_tag;

  result.map_value.fields_count = 2;
  result.map_value.fields =
      nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(2);

  result.map_value.fields[0].key = nanopb::MakeBytesArray("direction");
  google_firestore_v1_Value direction;
  direction.which_value_type = google_firestore_v1_Value_string_value_tag;
  direction.string_value = nanopb::MakeBytesArray(
      this->direction_ == ASCENDING ? "ascending" : "descending");
  result.map_value.fields[0].value = direction;

  result.map_value.fields[1].key = nanopb::MakeBytesArray("expression");
  result.map_value.fields[1].value = expr_->to_proto();

  return result;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
