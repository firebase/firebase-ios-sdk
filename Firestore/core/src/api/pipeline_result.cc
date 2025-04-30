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

#include "Firestore/core/src/api/pipeline_result.h"

#include <memory>

#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/model/resource_path.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace api {

using model::Document;
using model::DocumentKey;
using model::FieldPath;
using model::ObjectValue;

std::shared_ptr<model::ObjectValue> PipelineResult::internal_value() const {
  return value_;
}

size_t PipelineResult::Hash() const {
  return util::Hash(internal_key_, *value_, metadata_);
}

bool operator==(const PipelineResult& lhs, const PipelineResult& rhs) {
  return lhs.internal_key() == rhs.internal_key() &&
         lhs.internal_value() == rhs.internal_value() &&
         lhs.metadata() == rhs.metadata();
}

absl::optional<absl::string_view> PipelineResult::document_id() const {
  if (!internal_key_.has_value()) {
    return absl::nullopt;
  }
  return internal_key_.value().path().last_segment();
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
