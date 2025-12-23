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

#include "Firestore/core/src/api/aggregate_expressions.h"

#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace api {

google_firestore_v1_Value AggregateFunction::to_proto() const {
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_function_value_tag;
  result.function_value = google_firestore_v1_Function{};
  result.function_value.name = nanopb::MakeBytesArray(name_);
  result.function_value.args_count = static_cast<pb_size_t>(params_.size());
  result.function_value.args = nanopb::MakeArray<google_firestore_v1_Value>(
      result.function_value.args_count);

  for (size_t i = 0; i < params_.size(); ++i) {
    result.function_value.args[i] = params_[i]->to_proto();
  }

  return result;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
