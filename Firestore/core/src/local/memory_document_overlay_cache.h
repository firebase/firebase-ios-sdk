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

#ifndef FIRESTORE_CORE_SRC_LOCAL_MEMORY_DOCUMENT_OVERLAY_H_
#define FIRESTORE_CORE_SRC_LOCAL_MEMORY_DOCUMENT_OVERLAY_H_

#include "Firestore/core/src/local/document_overlay_cache.h"

namespace firebase {
namespace firestore {
namespace local {

class MemoryDocumentOverlayCache final : public DocumentOverlayCache {
 public:
  absl::optional<model::mutation::Overlay&> GetOverlay(const model::DocumentKey& key) const override;

  void SaveOverlays(int largest_batch_id, const std::unordered_map<model::DocumentKey, model::Mutation>& overlays) override;

  void RemoveOverlaysForBatchId(int batch_id) override;

  std::unordered_map<model::DocumentKey, model::mutation::Overlay> GetOverlays(const model::ResourcePath& collection, int since_batch_id) const override;

  virtual std::unordered_map<model::DocumentKey, model::mutation::Overlay> GetOverlays(absl::string_view collection_group, int since_batch_id, int count) const override;

};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_MEMORY_DOCUMENT_OVERLAY_H_
