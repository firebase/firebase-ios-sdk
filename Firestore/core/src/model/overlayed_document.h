/*
 * Copyright 2022 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_MODEL_OVERLAYED_DOCUMENT_H_
#define FIRESTORE_CORE_SRC_MODEL_OVERLAYED_DOCUMENT_H_

#include <utility>

#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {
namespace model {

/** Represents a local view (overlay) of a document, and the fields that are
 * locally mutated. */
class OverlayedDocument {
 public:
  OverlayedDocument(model::Document document,
                    absl::optional<model::FieldMask> mutated_fields)
      : document_(std::move(document)),
        mutated_fields_(std::move(mutated_fields)) {
  }

  const model::Document& document() const& {
    return document_;
  }

  model::Document&& document() && {
    return std::move(document_);
  }

  const absl::optional<model::FieldMask>& mutated_fields() const {
    return mutated_fields_;
  }

 private:
  model::Document document_;
  absl::optional<model::FieldMask> mutated_fields_;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_OVERLAYED_DOCUMENT_H_
