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

#include "Firestore/core/src/api/realtime_pipeline_snapshot.h"

#include <utility>

#include "Firestore/core/src/api/pipeline_result.h"
#include "Firestore/core/src/api/pipeline_result_change.h"
#include "Firestore/core/src/api/query_snapshot.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace api {

using api::Firestore;
using core::DocumentViewChange;
using core::ViewSnapshot;
using model::Document;
using model::DocumentComparator;
using model::DocumentSet;
using util::ThrowInvalidArgument;

std::vector<PipelineResultChange>
RealtimePipelineSnapshot::CalculateResultChanges(
    bool include_metadata_changes) const {
  auto factory = [](const Document& doc,
                    SnapshotMetadata meta) -> PipelineResult {
    return PipelineResult(doc, std::move(meta));
  };

  return GenerateChangesFromSnapshot<PipelineResultChange, PipelineResult>(
      this->snapshot_, include_metadata_changes, factory);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
