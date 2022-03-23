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

#ifndef FIRESTORE_CORE_SRC_LOCAL_MEMORY_DOCUMENT_OVERLAY_CACHE_H_
#define FIRESTORE_CORE_SRC_LOCAL_MEMORY_DOCUMENT_OVERLAY_CACHE_H_

#include <unordered_map>
#include <unordered_set>

#include "Firestore/core/src/immutable/sorted_map.h"
#include "Firestore/core/src/local/document_overlay_cache.h"

namespace firebase {
namespace firestore {
namespace local {

class MemoryDocumentOverlayCache final : public DocumentOverlayCache {
 public:
  MemoryDocumentOverlayCache() = default;

  MemoryDocumentOverlayCache(const MemoryDocumentOverlayCache&) = delete;
  MemoryDocumentOverlayCache& operator=(const MemoryDocumentOverlayCache&) =
      delete;

  MemoryDocumentOverlayCache(MemoryDocumentOverlayCache&&) = delete;
  MemoryDocumentOverlayCache& operator=(MemoryDocumentOverlayCache&&) = delete;

  absl::optional<model::Overlay> GetOverlay(
      const model::DocumentKey& key) const override;

  void SaveOverlays(int largest_batch_id,
                    const MutationByDocumentKeyMap& overlays) override;

  void RemoveOverlaysForBatchId(int batch_id) override;

  OverlayByDocumentKeyMap GetOverlays(const model::ResourcePath& collection,
                                      int since_batch_id) const override;

  OverlayByDocumentKeyMap GetOverlays(absl::string_view collection_group,
                                      int since_batch_id,
                                      std::size_t count) const override;

 private:
  using OverlayByDocumentKeySortedMap =
      immutable::SortedMap<model::DocumentKey, model::Overlay>;
  using DocumentKeySet =
      std::unordered_set<model::DocumentKey, model::DocumentKeyHash>;
  using DocumentKeysByBatchIdMap = std::unordered_map<int, DocumentKeySet>;

  int GetOverlayCount() const override;

  void SaveOverlay(int largest_batch_id, const model::Mutation& mutation);

  OverlayByDocumentKeySortedMap overlays_;
  DocumentKeysByBatchIdMap overlay_by_batch_id_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_MEMORY_DOCUMENT_OVERLAY_CACHE_H_
