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

#include "Firestore/core/src/api/realtime_pipeline.h"

#include <memory>
#include <utility>

#include "Firestore/core/src/remote/serializer.h"

namespace firebase {
namespace firestore {
namespace api {

RealtimePipeline::RealtimePipeline(
    std::vector<std::shared_ptr<EvaluableStage>> stages,
    remote::Serializer serializer)
    : stages_(std::move(stages)), serializer_(serializer) {
}

RealtimePipeline RealtimePipeline::AddingStage(
    std::shared_ptr<EvaluableStage> stage) {
  auto copy = std::vector<std::shared_ptr<EvaluableStage>>(this->stages_);
  copy.push_back(stage);

  return {copy, serializer_};
}

const std::vector<std::shared_ptr<EvaluableStage>>& RealtimePipeline::stages()
    const {
  return this->stages_;
}

EvaluateContext RealtimePipeline::evaluate_context() {
  return EvaluateContext(&serializer_);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
