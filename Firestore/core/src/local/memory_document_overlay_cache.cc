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

#include <cstdlib>
#include <map>

#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace local {

using model::DocumentKey;
using model::DocumentKeyHash;
using model::Mutation;
using model::Overlay;
using model::ResourcePath;

absl::optional<Overlay> MemoryDocumentOverlayCache::GetOverlay(
    const DocumentKey& key) const {
  const auto overlays_iter = overlays_.find(key);
  if (overlays_iter == overlays_.end()) {
    return absl::nullopt;
  } else {
    return overlays_iter->second;
  }
}

void MemoryDocumentOverlayCache::SaveOverlays(
    int largest_batch_id, const MutationByDocumentKeyMap& overlays) {
  for (const auto& kv : overlays) {
    SaveOverlay(largest_batch_id, kv.second);
  }
}

void MemoryDocumentOverlayCache::RemoveOverlaysForBatchId(int batch_id) {
  const auto overlay_by_batch_id_iter = overlay_by_batch_id_.find(batch_id);
  if (overlay_by_batch_id_iter != overlay_by_batch_id_.end()) {
    const DocumentKeySet& keys = overlay_by_batch_id_iter->second;
    for (const auto& key : keys) {
      overlays_ = overlays_.erase(key);
    }
    overlay_by_batch_id_.erase(overlay_by_batch_id_iter);
  }
}

DocumentOverlayCache::OverlayByDocumentKeyMap
MemoryDocumentOverlayCache::GetOverlays(const ResourcePath& collection,
                                        int since_batch_id) const {
  OverlayByDocumentKeyMap result;

  std::size_t immediate_children_path_length{collection.size() + 1};
  DocumentKey prefix(collection.Append(""));
  auto overlays_iter = overlays_.lower_bound(prefix);

  while (overlays_iter != overlays_.end()) {
    const Overlay& overlay = overlays_iter->second;
    ++overlays_iter;

    const DocumentKey& key = overlay.key();
    if (!collection.IsPrefixOf(key.path())) {
      break;
    }
    // Documents from sub-collections
    if (key.path().size() != immediate_children_path_length) {
      continue;
    }

    if (overlay.largest_batch_id() > since_batch_id) {
      result[key] = overlay;
    }
  }

  return result;
}

DocumentOverlayCache::OverlayByDocumentKeyMap
MemoryDocumentOverlayCache::GetOverlays(absl::string_view collection_group,
                                        int since_batch_id,
                                        std::size_t count) const {
  // NOTE: This method is only used by the backfiller, which will not run for
  // memory persistence; therefore, this method is being implemented only so
  // that the test suite for `LevelDbDocumentOverlayCache` can be re-used by
  // the test suite for this class.
  using OverlaysByDocumentKeyMap =
      std::unordered_map<DocumentKey, Overlay, DocumentKeyHash>;
  std::map<int, OverlaysByDocumentKeyMap> batch_id_to_overlays;

  for (const auto& overlays_entry : overlays_) {
    const Overlay& overlay = overlays_entry.second;
    const DocumentKey& key = overlay.key();
    if (!key.HasCollectionGroup(collection_group)) {
      continue;
    }
    if (overlay.largest_batch_id() > since_batch_id) {
      batch_id_to_overlays[overlay.largest_batch_id()][key] = overlay;
    }
  }

  OverlayByDocumentKeyMap result;
  for (const auto& overlays_entry : batch_id_to_overlays) {
    const auto& overlays = overlays_entry.second;
    result.insert(overlays.cbegin(), overlays.cend());
    if (result.size() >= count) {
      break;
    }
  }

  return result;
}

int MemoryDocumentOverlayCache::GetOverlayCount() const {
  return overlays_.size();
}

void MemoryDocumentOverlayCache::SaveOverlay(int largest_batch_id,
                                             const Mutation& mutation) {
  {
    const auto overlays_iter = overlays_.find(mutation.key());
    if (overlays_iter != overlays_.end()) {
      const Overlay& existing = overlays_iter->second;
      auto overlay_by_batch_id_iter =
          overlay_by_batch_id_.find(existing.largest_batch_id());
      HARD_ASSERT(overlay_by_batch_id_iter != overlay_by_batch_id_.end());
      DocumentKeySet& existing_keys = overlay_by_batch_id_iter->second;
      existing_keys.erase(mutation.key());
    }
  }

  overlays_ =
      overlays_.insert(mutation.key(), Overlay(largest_batch_id, mutation));

  overlay_by_batch_id_[largest_batch_id].insert(mutation.key());
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
