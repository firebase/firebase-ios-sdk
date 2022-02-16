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

#include "Firestore/core/src/local/leveldb_document_overlay_cache.h"

namespace firebase {
namespace firestore {
namespace local {

using model::DocumentKey;
using model::Mutation;
using model::ResourcePath;
using model::mutation::Overlay;

// TODO(dconeybe) Implement these methods.

LevelDbDocumentOverlayCache::LevelDbDocumentOverlayCache() {
}

absl::optional<Overlay> LevelDbDocumentOverlayCache::GetOverlay(
    const DocumentKey& key) const {
  (void)key;
  return absl::nullopt;
}

void LevelDbDocumentOverlayCache::SaveOverlays(
    int largest_batch_id, const MutationByDocumentKeyMap& overlays) {
  (void)largest_batch_id;
  (void)overlays;
}

void LevelDbDocumentOverlayCache::RemoveOverlaysForBatchId(int batch_id) {
  (void)batch_id;
}

DocumentOverlayCache::OverlayByDocumentKeyMap
LevelDbDocumentOverlayCache::GetOverlays(const ResourcePath& collection,
                                         int since_batch_id) const {
  (void)collection;
  (void)since_batch_id;
  return {};
}

DocumentOverlayCache::OverlayByDocumentKeyMap
LevelDbDocumentOverlayCache::GetOverlays(const std::string& collection_group,
                                         int since_batch_id,
                                         std::size_t count) const {
  (void)collection_group;
  (void)since_batch_id;
  (void)count;
  return {};
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
