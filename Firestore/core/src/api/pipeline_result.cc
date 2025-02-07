/*
 * Copyright 2025 Google
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

#include "Firestore/core/src/api/pipeline_result.h"

#include <utility>

#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/model/resource_path.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace api {

using model::Document;
using model::DocumentKey;
using model::FieldPath;
using model::ObjectValue;

const absl::optional<model::ObjectValue>& PipelineResult::internal_value()
    const {
  if (value_ == nullptr) {
    return absl::nullopt;
  }

  return *value_;
}

const absl::optional<std::string_view> PipelineResult::document_id() const {
  if (!internal_key_.has_value()) {
    return absl::nullopt;
  }
  return internal_key_.value().path().last_segment();
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
