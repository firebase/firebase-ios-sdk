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

#include "Firestore/core/src/api/expressions.h"

#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace api {

google_firestore_v1_Value Field::to_proto() const {
  google_firestore_v1_Value result;

  result.which_value_type = google_firestore_v1_Value_field_reference_value_tag;
  result.field_reference_value = nanopb::MakeBytesArray(this->name_);

  return result;
}

google_firestore_v1_Value Constant::to_proto() const {
  google_firestore_v1_Value result;

  result.which_value_type = google_firestore_v1_Value_double_value_tag;
  result.double_value = this->value_;

  return result;
}

google_firestore_v1_Value Eq::to_proto() const {
  google_firestore_v1_Value result;

  result.which_value_type = google_firestore_v1_Value_function_value_tag;
  result.function_value = google_firestore_v1_Function{};
  result.function_value.name = nanopb::MakeBytesArray("eq");
  result.function_value.args_count = 2;
  result.function_value.args = nanopb::MakeArray<google_firestore_v1_Value>(2);
  result.function_value.args[0] = this->left_->to_proto();
  result.function_value.args[1] = this->right_->to_proto();

  return result;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
