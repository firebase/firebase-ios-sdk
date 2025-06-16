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

#include "Firestore/core/src/core/pipeline_util.h"
#include "Firestore/core/src/remote/serializer.h"

namespace firebase {
namespace firestore {
namespace api {

RealtimePipeline::RealtimePipeline(
    std::vector<std::shared_ptr<EvaluableStage>> stages,
    std::unique_ptr<remote::Serializer> serializer)
    : stages_(std::move(stages)), serializer_(std::move(serializer)) {
  this->rewritten_stages_ = core::RewriteStages(this->stages());
}

RealtimePipeline::RealtimePipeline(const RealtimePipeline& other)
    : stages_(other.stages_),
      rewritten_stages_(other.rewritten_stages_),
      serializer_(std::make_unique<remote::Serializer>(
          other.serializer_->database_id())),
      listen_options_(other.listen_options()) {
}

RealtimePipeline& RealtimePipeline::operator=(const RealtimePipeline& other) {
  if (this != &other) {
    stages_ = other.stages_;
    rewritten_stages_ = other.rewritten_stages_;
    serializer_ =
        std::make_unique<remote::Serializer>(other.serializer_->database_id());
    listen_options_ = other.listen_options();
  }
  return *this;
}

RealtimePipeline RealtimePipeline::AddingStage(
    std::shared_ptr<EvaluableStage> stage) {
  auto copy = std::vector<std::shared_ptr<EvaluableStage>>(this->stages_);
  copy.push_back(stage);

  return {copy,
          std::make_unique<remote::Serializer>(serializer_->database_id())};
}

const std::vector<std::shared_ptr<EvaluableStage>>& RealtimePipeline::stages()
    const {
  return this->stages_;
}

const std::vector<std::shared_ptr<EvaluableStage>>&
RealtimePipeline::rewritten_stages() const {
  return this->rewritten_stages_;
}

EvaluateContext RealtimePipeline::evaluate_context() const {
  return EvaluateContext(serializer_.get(), listen_options_);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
