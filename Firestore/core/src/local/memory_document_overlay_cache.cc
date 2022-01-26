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
  auto overlay_iter = overlay_by_document_key_.find(key);
  if (overlay_iter == overlay_by_document_key_.end()) {
    return absl::nullopt;
  } else {
    return std::cref(overlay_iter->second);
  }
}

void MemoryDocumentOverlayCache::SaveOverlay(int largest_batch_id, const Mutation& mutation) {
  {
    auto existing_overlay_iter = overlay_by_document_key_.find(mutation.key());
    if (existing_overlay_iter != overlay_by_document_key_.end()) {
      int existing_overlay_largest_batch_id = existing_overlay_iter->second.largest_batch_id();
      auto document_keys_iter = document_keys_by_batch_id_.find(existing_overlay_largest_batch_id);
      HARD_ASSERT(document_keys_iter != document_keys_by_batch_id_.end());
      auto& document_keys_for_existing_overlay_largest_batch_id = document_keys_iter->second;
      document_keys_for_existing_overlay_largest_batch_id.erase(mutation.key());
    }
  }

  overlay_by_document_key_.insert({mutation.key(), Overlay(largest_batch_id, mutation)});

  document_keys_by_batch_id_[largest_batch_id].emplace(mutation.key());
}

void MemoryDocumentOverlayCache::SaveOverlays(int largest_batch_id, const MutationByDocumentKeyMap& overlays) {
  for (const auto& kv : overlays) {
    SaveOverlay(largest_batch_id, kv.second);
  }
}

void MemoryDocumentOverlayCache::RemoveOverlaysForBatchId(int batch_id) {
  (void)batch_id;
  abort();
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
