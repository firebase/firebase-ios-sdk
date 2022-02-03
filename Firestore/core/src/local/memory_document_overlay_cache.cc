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

#include "Firestore/core/src/local/memory_document_overlay_cache.h"

#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace local {

using model::DocumentKey;
using model::Mutation;
using model::mutation::Overlay;

absl::optional<std::reference_wrapper<const Overlay>> MemoryDocumentOverlayCache::GetOverlay(const DocumentKey& key) const {
  const auto overlay_iter = overlays_.find(key);
  if (overlay_iter == overlays_.end()) {
    return absl::nullopt;
  } else {
    return std::cref(overlay_iter->second);
  }
}

void MemoryDocumentOverlayCache::SaveOverlay(int largest_batch_id, Mutation&& mutation) {
  const DocumentKey key = mutation.key();

  {
    const auto overlays_iter = overlays_.find(key);
    if (overlays_iter != overlays_.end()) {
      const Overlay& existing = overlays_iter->second;
      auto overlay_by_batch_id_iter = overlay_by_batch_id_.find(existing.largest_batch_id());
      HARD_ASSERT(overlay_by_batch_id_iter != overlay_by_batch_id_.end());
      DocumentKeySet& existing_keys = overlay_by_batch_id_iter->second;
      existing_keys.erase(key);
      overlays_.erase(overlays_iter);
    }
  }

  overlays_.insert({key, Overlay(largest_batch_id, std::move(mutation))});

  overlay_by_batch_id_[largest_batch_id].insert(key);
}

void MemoryDocumentOverlayCache::SaveOverlays(int largest_batch_id, MutationByDocumentKeyMap&& overlays) {
  for (auto& kv : overlays) {
    SaveOverlay(largest_batch_id, std::move(kv.second));
  }
}

void MemoryDocumentOverlayCache::RemoveOverlaysForBatchId(int batch_id) {
  const auto overlay_by_batch_id_iter = overlay_by_batch_id_.find(batch_id);
  if (overlay_by_batch_id_iter != overlay_by_batch_id_.end()) {
    const DocumentKeySet& keys = overlay_by_batch_id_iter->second;
    for (const auto& key : keys) {
      overlays_.erase(key);
    }
    overlay_by_batch_id_.erase(overlay_by_batch_id_iter);
  }
}

DocumentOverlayCache::OverlayByDocumentKeyMap MemoryDocumentOverlayCache::GetOverlays(const model::ResourcePath& collection, int since_batch_id) const {
  (void)collection;
  (void)since_batch_id;
  abort();
  return {};
}

DocumentOverlayCache::OverlayByDocumentKeyMap MemoryDocumentOverlayCache::GetOverlays(absl::string_view collection_group, int since_batch_id, int count) const {
  (void)collection_group;
  (void)since_batch_id;
  (void)count;
  abort();
  return {};
}


}  // namespace local
}  // namespace firestore
}  // namespace firebase
