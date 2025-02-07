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

#ifndef FIRESTORE_CORE_SRC_API_PIPELINE_RESULT_H_
#define FIRESTORE_CORE_SRC_API_PIPELINE_RESULT_H_

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace api {

class DocumentReference;
class Firestore;

class PipelineResult {
 public:
  PipelineResult(absl::optional<model::DocumentKey> document_key,
                 std::shared_ptr<model::ObjectValue> value,
                 absl::optional<model::SnapshotVersion> create_time,
                 absl::optional<model::SnapshotVersion> update_time,
                 absl::optional<model::SnapshotVersion> execution_time)
      : internal_key_{std::move(document_key)},
        value_{std::move(value)},
        create_time_{create_time},
        update_time_{update_time},
        execution_time_{execution_time} {
  }

  PipelineResult() = default;

  const absl::optional<model::ObjectValue>& internal_value() const;
  const absl::optional<std::string_view> document_id() const;

 private:
  absl::optional<model::DocumentKey> internal_key_;
  // Using a shared pointer to ObjectValue makes PipelineResult copy-assignable
  // without having to manually create a deep clone of its Protobuf contents.
  std::shared_ptr<model::ObjectValue> value_ = std::make_shared<ObjectValue>();
  absl::optional<model::SnapshotVersion> create_time_;
  absl::optional<model::SnapshotVersion> update_time_;
  absl::optional<model::SnapshotVersion> execution_time_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_PIPELINE_RESULT_H_
