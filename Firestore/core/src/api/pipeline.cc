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

#include "Firestore/core/src/api/pipeline.h"

#include <memory>
#include <utility>

#include "Firestore/core/src/core/firestore_client.h"

namespace firebase {
namespace firestore {
namespace api {

using nanopb::CheckedSize;

Pipeline Pipeline::AddingStage(std::shared_ptr<Stage> stage) {
  auto copy = std::vector<std::shared_ptr<Stage>>(this->stages_);
  copy.push_back(stage);

  return {copy, this->firestore_};
}

const std::vector<std::shared_ptr<Stage>>& Pipeline::stages() const {
  return this->stages_;
}

void Pipeline::execute(util::StatusOrCallback<PipelineSnapshot> callback) {
  this->firestore_->RunPipeline(*this, std::move(callback));
}

google_firestore_v1_Value Pipeline::to_proto() const {
  google_firestore_v1_Value result;

  result.which_value_type = google_firestore_v1_Value_pipeline_value_tag;
  result.pipeline_value = google_firestore_v1_Pipeline{};
  result.pipeline_value.stages_count = CheckedSize(this->stages_.size());
  nanopb::SetRepeatedField(
      &result.pipeline_value.stages, &result.pipeline_value.stages_count,
      stages_,
      [](const std::shared_ptr<Stage>& arg) { return arg->to_proto(); });

  return result;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
