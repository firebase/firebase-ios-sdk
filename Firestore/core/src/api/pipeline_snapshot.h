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

#ifndef FIRESTORE_CORE_SRC_API_PIPELINE_SNAPSHOT_H_
#define FIRESTORE_CORE_SRC_API_PIPELINE_SNAPSHOT_H_

#include <functional>
#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/api_fwd.h"
#include "Firestore/core/src/api/pipeline_result.h"
#include "Firestore/core/src/model/snapshot_version.h"

namespace firebase {
namespace firestore {
namespace api {

class PipelineSnapshot {
 public:
  explicit PipelineSnapshot(std::vector<PipelineResult>&& results,
                            model::SnapshotVersion execution_time)
      : results_(std::move(results)), execution_time_(execution_time) {
  }

  const std::vector<PipelineResult>& results() const {
    return results_;
  }

  model::SnapshotVersion execution_time() const {
    return execution_time_;
  }

  const std::shared_ptr<Firestore> firestore() const {
    return firestore_;
  }

  void SetFirestore(std::shared_ptr<Firestore> db) {
    firestore_ = std::move(db);
  }

 private:
  std::vector<PipelineResult> results_;
  model::SnapshotVersion execution_time_;
  std::shared_ptr<Firestore> firestore_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_PIPELINE_SNAPSHOT_H_
