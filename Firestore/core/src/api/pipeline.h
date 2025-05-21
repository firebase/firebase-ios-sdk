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

#ifndef FIRESTORE_CORE_SRC_API_PIPELINE_H_
#define FIRESTORE_CORE_SRC_API_PIPELINE_H_

#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/pipeline_snapshot.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/util/status_fwd.h"

namespace firebase {
namespace firestore {
namespace api {

class Pipeline {
 public:
  Pipeline(std::vector<std::shared_ptr<Stage>> stages,
           std::shared_ptr<Firestore> firestore)
      : stages_(std::move(stages)), firestore_(firestore) {
  }

  const std::shared_ptr<Firestore>& firestore() const {
    return firestore_;
  }

  Pipeline AddingStage(std::shared_ptr<Stage> stage);

  const std::vector<std::shared_ptr<Stage>>& stages() const;

  void execute(util::StatusOrCallback<PipelineSnapshot> callback);

  google_firestore_v1_Value to_proto() const;

 private:
  std::vector<std::shared_ptr<Stage>> stages_;
  std::shared_ptr<Firestore> firestore_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_PIPELINE_H_
