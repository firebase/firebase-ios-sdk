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

#include "Firestore/core/src/api/stages.h"

#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace api {

google_firestore_v1_Pipeline_Stage CollectionSource::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray("collection");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);
  result.args[0].which_value_type =
      google_firestore_v1_Value_reference_value_tag;
  result.args[0].reference_value = nanopb::MakeBytesArray(this->path_);

  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Pipeline_Stage Where::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray("where");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);
  result.args[0] = this->expr_->to_proto();

  result.options_count = 0;
  result.options = nullptr;

  return result;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
