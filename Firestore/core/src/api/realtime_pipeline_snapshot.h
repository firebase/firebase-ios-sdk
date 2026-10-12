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

#ifndef FIRESTORE_CORE_SRC_API_REALTIME_PIPELINE_SNAPSHOT_H_
#define FIRESTORE_CORE_SRC_API_REALTIME_PIPELINE_SNAPSHOT_H_

#include <functional>
#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/api_fwd.h"
#include "Firestore/core/src/api/pipeline_result.h"
#include "Firestore/core/src/api/pipeline_result_change.h"
#include "Firestore/core/src/api/snapshot_metadata.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/model/snapshot_version.h"

namespace firebase {
namespace firestore {
namespace api {

class RealtimePipelineSnapshot {
 public:
  explicit RealtimePipelineSnapshot(std::shared_ptr<Firestore> firestore,
                                    core::ViewSnapshot&& snapshot,
                                    SnapshotMetadata metadata)
      : firestore_(std::move(firestore)),
        snapshot_(std::move(snapshot)),
        metadata_(metadata) {
  }

  const std::shared_ptr<api::Firestore>& firestore() const {
    return firestore_;
  }

  const core::ViewSnapshot& view_snapshot() const {
    return snapshot_;
  }

  SnapshotMetadata snapshot_metadata() const {
    return metadata_;
  }

  std::vector<PipelineResultChange> CalculateResultChanges(
      bool include_metadata_changes) const;

 private:
  std::shared_ptr<Firestore> firestore_;
  core::ViewSnapshot snapshot_;
  SnapshotMetadata metadata_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_REALTIME_PIPELINE_SNAPSHOT_H_
