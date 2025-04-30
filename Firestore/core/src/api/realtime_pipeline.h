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

#ifndef FIRESTORE_CORE_SRC_API_REALTIME_PIPELINE_H_
#define FIRESTORE_CORE_SRC_API_REALTIME_PIPELINE_H_

#include <memory>
#include <vector>

#include "Firestore/core/src/api/stages.h"

namespace firebase {
namespace firestore {
namespace remote {
class Serializer;
}  // namespace remote

namespace api {

class RealtimePipeline {
 public:
  RealtimePipeline(std::vector<std::shared_ptr<EvaluableStage>> stages,
                   std::unique_ptr<remote::Serializer> serializer);

  RealtimePipeline(const RealtimePipeline& other);
  RealtimePipeline& operator=(const RealtimePipeline& other);

  RealtimePipeline AddingStage(std::shared_ptr<EvaluableStage> stage);

  const std::vector<std::shared_ptr<EvaluableStage>>& stages() const;
  const std::vector<std::shared_ptr<EvaluableStage>>& rewritten_stages() const;

  EvaluateContext evaluate_context() const;

 private:
  std::vector<std::shared_ptr<EvaluableStage>> stages_;
  std::vector<std::shared_ptr<EvaluableStage>> rewritten_stages_;
  std::unique_ptr<remote::Serializer> serializer_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_REALTIME_PIPELINE_H_
