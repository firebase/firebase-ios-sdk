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

#include "Firestore/core/src/core/pipeline_run.h"

#include <vector>

#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/pipeline_util.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/util/log.h"

namespace firebase {
namespace firestore {
namespace core {

model::PipelineInputOutputVector RunPipeline(
    api::RealtimePipeline& pipeline,
    const std::vector<model::MutableDocument>& inputs) {
  auto current = std::vector<model::MutableDocument>(inputs);
  for (const auto& stage : pipeline.rewritten_stages()) {
    current = stage->Evaluate(pipeline.evaluate_context(), current);
  }

  return current;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
