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

#include <memory>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::DeepClone;

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
  return *DeepClone(value_.Get()).release();
}

google_firestore_v1_Value FunctionExpr::to_proto() const {
  google_firestore_v1_Value result;

  result.which_value_type = google_firestore_v1_Value_function_value_tag;
  result.function_value = google_firestore_v1_Function{};
  result.function_value.name = nanopb::MakeBytesArray(name_);
  nanopb::SetRepeatedField(
      &result.function_value.args, &result.function_value.args_count, args_,
      [](const std::shared_ptr<Expr>& arg) { return arg->to_proto(); });

  return result;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
