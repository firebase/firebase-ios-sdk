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
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace api {

Field::Field(std::string name) {
  field_path_ = model::FieldPath::FromDotSeparatedString(name);
  alias_ = field_path_.CanonicalString();
}

google_firestore_v1_Value Field::to_proto() const {
  google_firestore_v1_Value result;

  result.which_value_type = google_firestore_v1_Value_field_reference_value_tag;
  result.field_reference_value = nanopb::MakeBytesArray(this->alias());

  return result;
}

std::unique_ptr<core::EvaluableExpr> Field::ToEvaluable() const {
  return std::make_unique<core::CoreField>(std::make_unique<Field>(*this));
}

google_firestore_v1_Value Constant::to_proto() const {
  // Return a copy of the value proto to avoid double delete.
  return *model::DeepClone(*value_).release();
}

const google_firestore_v1_Value& Constant::value() const {
  return *value_;
}

std::unique_ptr<core::EvaluableExpr> Constant::ToEvaluable() const {
  return std::make_unique<core::CoreConstant>(
      std::make_unique<Constant>(*this));
}

google_firestore_v1_Value FunctionExpr::to_proto() const {
  google_firestore_v1_Value result;

  result.which_value_type = google_firestore_v1_Value_function_value_tag;
  result.function_value = google_firestore_v1_Function{};
  result.function_value.name = nanopb::MakeBytesArray(name_);
  nanopb::SetRepeatedField(
      &result.function_value.args, &result.function_value.args_count, params_,
      [](const std::shared_ptr<Expr>& arg) { return arg->to_proto(); });

  return result;
}

std::unique_ptr<core::EvaluableExpr> FunctionExpr::ToEvaluable() const {
  return core::FunctionToEvaluable(*this);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
