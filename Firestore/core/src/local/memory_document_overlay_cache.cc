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

namespace firebase {
namespace firestore {
namespace local {

absl::optional<std::reference_wrapper<model::mutation::Overlay>> MemoryDocumentOverlayCache::GetOverlay(const model::DocumentKey& key) const {
  (void)key;
  return absl::nullopt;
}

void MemoryDocumentOverlayCache::SaveOverlays(int largest_batch_id, const MutationByDocumentKeyMap& overlays) {
  (void)largest_batch_id;
  (void)overlays;
  abort();
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
