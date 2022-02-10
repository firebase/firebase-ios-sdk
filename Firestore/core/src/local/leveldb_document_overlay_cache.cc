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

#include <map>
#include <string>
#include <unordered_set>
#include <utility>

#include "Firestore/Protos/nanopb/firestore/local/document_overlay.nanopb.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/match.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace local {

using credentials::User;
using model::DocumentKey;
using model::Mutation;
using model::ResourcePath;
using model::mutation::Overlay;
using model::mutation::OverlayHash;
using nanopb::Message;
using nanopb::StringReader;

LevelDbDocumentOverlayCache::LevelDbDocumentOverlayCache(
    const User& user, LevelDbPersistence* db, LocalSerializer* serializer)
    : db_(NOT_NULL(db)),
      serializer_(NOT_NULL(serializer)),
      user_id_(user.is_authenticated() ? user.uid() : "") {
}

absl::optional<Overlay> LevelDbDocumentOverlayCache::GetOverlay(
    const DocumentKey& key) const {
  const std::string leveldb_key = LevelDbDocumentOverlayKey::Key(user_id_, key);

  auto it = db_->current_transaction()->NewIterator();
  it->Seek(leveldb_key);

  if (!(it->Valid() && it->key() == leveldb_key)) {
    return absl::nullopt;
  }

  return ParseOverlay(it->value());
}

void LevelDbDocumentOverlayCache::SaveOverlays(
    int largest_batch_id, const MutationByDocumentKeyMap& overlays) {
  for (const auto& overlays_entry : overlays) {
    SaveOverlay(largest_batch_id, overlays_entry.first, overlays_entry.second);
  }
}

void LevelDbDocumentOverlayCache::RemoveOverlaysForBatchId(int batch_id) {
  ForEachOverlay([&](absl::string_view leveldb_key, Overlay&& overlay) {
    if (overlay.largest_batch_id() == batch_id) {
      db_->current_transaction()->Delete(leveldb_key);
    }
  });
}

DocumentOverlayCache::OverlayByDocumentKeyMap
LevelDbDocumentOverlayCache::GetOverlays(const ResourcePath& collection,
                                         int since_batch_id) const {
  // TODO(dconeybe) Implement an index so that this query can be performed
  // without requiring a full table scan.

  OverlayByDocumentKeyMap result;

  const size_t immediate_children_path_length{collection.size() + 1};

  ForEachOverlay([&](absl::string_view, Overlay&& overlay) {
    const DocumentKey key = overlay.key();
    if (!collection.IsPrefixOf(key.path())) {
      return;
    }
    // Documents from sub-collections
    if (key.path().size() != immediate_children_path_length) {
      return;
    }

    if (overlay.largest_batch_id() > since_batch_id) {
      result[key] = std::move(overlay);
    }
  });

  return result;
}

DocumentOverlayCache::OverlayByDocumentKeyMap
LevelDbDocumentOverlayCache::GetOverlays(const std::string& collection_group,
                                         int since_batch_id,
                                         std::size_t count) const {
  // TODO(dconeybe) Implement an index so that this query can be performed
  // without requiring a full table scan.

  std::map<int, std::unordered_set<Overlay, OverlayHash>> overlays_by_batch_id;
  ForEachOverlay([&](absl::string_view, Overlay&& overlay) {
    if (overlay.largest_batch_id() <= since_batch_id) {
      return;
    }
    if (overlay.key().HasCollectionId(collection_group)) {
      overlays_by_batch_id[overlay.largest_batch_id()].emplace(
          std::move(overlay));
    }
  });

  OverlayByDocumentKeyMap result;
  for (auto& overlays_by_batch_id_entry : overlays_by_batch_id) {
    for (auto& overlay : overlays_by_batch_id_entry.second) {
      DocumentKey key = overlay.key();
      result[key] = std::move(overlay);
    }
    if (result.size() >= count) {
      break;
    }
  }

  return result;
}

Overlay LevelDbDocumentOverlayCache::ParseOverlay(
    absl::string_view encoded) const {
  StringReader reader{encoded};
  auto maybe_message =
      Message<firestore_client_DocumentOverlay>::TryParse(&reader);
  auto result = serializer_->DecodeDocumentOverlay(&reader, *maybe_message);
  if (!reader.ok()) {
    HARD_FAIL("DocumentOverlay proto failed to parse: %s",
              reader.status().ToString());
  }

  return result;
}

void LevelDbDocumentOverlayCache::SaveOverlay(int largest_batch_id,
                                              const DocumentKey& key,
                                              const Mutation& mutation) {
  const std::string leveldb_key = LevelDbDocumentOverlayKey::Key(user_id_, key);
  Overlay overlay(largest_batch_id, mutation);
  auto serialized_overlay = serializer_->EncodeDocumentOverlay(overlay);
  db_->current_transaction()->Put(leveldb_key, serialized_overlay);
}

void LevelDbDocumentOverlayCache::ForEachOverlay(
    std::function<void(absl::string_view, model::mutation::Overlay&&)> callback)
    const {
  auto it = db_->current_transaction()->NewIterator();
  const std::string user_key = LevelDbDocumentOverlayKey::KeyPrefix(user_id_);
  it->Seek(user_key);
  for (; it->Valid() && absl::StartsWith(it->key(), user_key); it->Next()) {
    callback(it->key(), ParseOverlay(it->value()));
  }
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
