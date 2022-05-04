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

#include <string>
#include <utility>

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
using model::MutationByDocumentKeyMap;
using model::Overlay;
using model::OverlayByDocumentKeyMap;
using model::OverlayHash;
using model::ResourcePath;
using nanopb::Message;
using nanopb::StringReader;

LevelDbDocumentOverlayCache::LevelDbDocumentOverlayCache(
    const User& user, LevelDbPersistence* db, LocalSerializer* serializer)
    : db_(NOT_NULL(db)),
      serializer_(NOT_NULL(serializer)),
      user_id_(user.is_authenticated() ? user.uid() : "") {
}

absl::optional<Overlay> LevelDbDocumentOverlayCache::GetOverlay(
    const DocumentKey& document_key) const {
  const std::string key_prefix =
      LevelDbDocumentOverlayKey::KeyPrefix(user_id_, document_key);

  auto it = db_->current_transaction()->NewIterator();
  it->Seek(key_prefix);

  if (!it->Valid() || !absl::StartsWith(it->key(), key_prefix)) {
    return absl::nullopt;
  }

  LevelDbDocumentOverlayKey key;
  HARD_ASSERT(key.Decode(it->key()));
  if (key.document_key() != document_key) {
    return absl::nullopt;
  }

  return ParseOverlay(key, it->value());
}

void LevelDbDocumentOverlayCache::SaveOverlays(
    int largest_batch_id, const MutationByDocumentKeyMap& overlays) {
  for (const auto& overlays_entry : overlays) {
    SaveOverlay(largest_batch_id, overlays_entry.first, overlays_entry.second);
  }
}

void LevelDbDocumentOverlayCache::RemoveOverlaysForBatchId(int batch_id) {
  ForEachKeyWithLargestBatchId(
      batch_id, [&](LevelDbDocumentOverlayKey&& key) { DeleteOverlay(key); });
}

OverlayByDocumentKeyMap LevelDbDocumentOverlayCache::GetOverlays(
    const ResourcePath& collection, int since_batch_id) const {
  OverlayByDocumentKeyMap result;
  ForEachKeyInCollection(
      collection, since_batch_id, [&](LevelDbDocumentOverlayKey&& key) {
        absl::optional<Overlay> overlay = GetOverlay(key);
        HARD_ASSERT(overlay.has_value());
        result[std::move(key).document_key()] = std::move(overlay).value();
      });
  return result;
}

OverlayByDocumentKeyMap LevelDbDocumentOverlayCache::GetOverlays(
    absl::string_view collection_group,
    int since_batch_id,
    std::size_t count) const {
  absl::optional<int> current_batch_id;
  OverlayByDocumentKeyMap result;
  ForEachKeyInCollectionGroup(
      collection_group, since_batch_id,
      [&](LevelDbDocumentOverlayKey&& key) -> ForEachKeyAction {
        if (!current_batch_id.has_value()) {
          current_batch_id = key.largest_batch_id();
        } else if (current_batch_id.value() != key.largest_batch_id()) {
          if (result.size() >= count) {
            return ForEachKeyAction::kStop;
          }
          current_batch_id = key.largest_batch_id();
        }

        absl::optional<Overlay> overlay = GetOverlay(key);
        HARD_ASSERT(overlay.has_value());
        result[std::move(key).document_key()] = std::move(overlay).value();
        return ForEachKeyAction::kKeepGoing;
      });
  return result;
}

int LevelDbDocumentOverlayCache::GetOverlayCount() const {
  return CountEntriesWithKeyPrefix(
      LevelDbDocumentOverlayKey::KeyPrefix(user_id_));
}

int LevelDbDocumentOverlayCache::GetLargestBatchIdIndexEntryCount() const {
  return CountEntriesWithKeyPrefix(
      LevelDbDocumentOverlayLargestBatchIdIndexKey::KeyPrefix(user_id_));
}

int LevelDbDocumentOverlayCache::GetCollectionIndexEntryCount() const {
  return CountEntriesWithKeyPrefix(
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(user_id_));
}

int LevelDbDocumentOverlayCache::GetCollectionGroupIndexEntryCount() const {
  return CountEntriesWithKeyPrefix(
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix(user_id_));
}

int LevelDbDocumentOverlayCache::CountEntriesWithKeyPrefix(
    const std::string& key_prefix) const {
  int count = 0;
  auto it = db_->current_transaction()->NewIterator();
  for (it->Seek(key_prefix);
       it->Valid() && absl::StartsWith(it->key(), key_prefix); it->Next()) {
    ++count;
  }
  return count;
}

Overlay LevelDbDocumentOverlayCache::ParseOverlay(
    const LevelDbDocumentOverlayKey& key,
    absl::string_view encoded_mutation) const {
  StringReader reader{encoded_mutation};
  auto maybe_message = Message<google_firestore_v1_Write>::TryParse(&reader);
  Mutation mutation = serializer_->DecodeMutation(&reader, *maybe_message);
  if (!reader.ok()) {
    HARD_FAIL("Mutation proto failed to parse: %s", reader.status().ToString());
  }
  return Overlay(key.largest_batch_id(), std::move(mutation));
}

void LevelDbDocumentOverlayCache::SaveOverlay(int largest_batch_id,
                                              const DocumentKey& document_key,
                                              const Mutation& mutation) {
  // Remove the existing overlay and any index entries pointing to it.
  DeleteOverlay(document_key);

  const LevelDbDocumentOverlayKey key(user_id_, document_key, largest_batch_id);

  // Add the overlay to the database and index entries pointing to it.
  auto* transaction = db_->current_transaction();
  transaction->Put(key.Encode(), serializer_->EncodeMutation(mutation));
  transaction->Put(LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(key), "");
  transaction->Put(LevelDbDocumentOverlayCollectionIndexKey::Key(key), "");

  absl::optional<std::string> collection_group_index_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(key);
  if (collection_group_index_key.has_value()) {
    transaction->Put(std::move(collection_group_index_key).value(), "");
  }
}

void LevelDbDocumentOverlayCache::DeleteOverlay(
    const model::DocumentKey& document_key) {
  const std::string key_prefix =
      LevelDbDocumentOverlayKey::KeyPrefix(user_id_, document_key);
  auto it = db_->current_transaction()->NewIterator();
  it->Seek(key_prefix);

  if (!it->Valid() || !absl::StartsWith(it->key(), key_prefix)) {
    return;
  }

  LevelDbDocumentOverlayKey key;
  HARD_ASSERT(key.Decode(it->key()));
  if (key.document_key() == document_key) {
    DeleteOverlay(key);
  }
}

void LevelDbDocumentOverlayCache::DeleteOverlay(
    const LevelDbDocumentOverlayKey& key) {
  auto* transaction = db_->current_transaction();
  transaction->Delete(key.Encode());
  transaction->Delete(LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(key));
  transaction->Delete(LevelDbDocumentOverlayCollectionIndexKey::Key(key));

  absl::optional<std::string> collection_group_index_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(key);
  if (collection_group_index_key.has_value()) {
    transaction->Delete(std::move(collection_group_index_key).value());
  }
}

void LevelDbDocumentOverlayCache::ForEachKeyWithLargestBatchId(
    int largest_batch_id,
    std::function<void(LevelDbDocumentOverlayKey&& key)> callback) const {
  const std::string key_prefix =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::KeyPrefix(user_id_,
                                                              largest_batch_id);
  auto it = db_->current_transaction()->NewIterator();
  for (it->Seek(key_prefix);
       it->Valid() && absl::StartsWith(it->key(), key_prefix); it->Next()) {
    LevelDbDocumentOverlayLargestBatchIdIndexKey key;
    HARD_ASSERT(key.Decode(it->key()));
    callback(std::move(key).ToLevelDbDocumentOverlayKey());
  }
}

void LevelDbDocumentOverlayCache::ForEachKeyInCollection(
    const ResourcePath& collection,
    int since_batch_id,
    std::function<void(LevelDbDocumentOverlayKey&&)> callback) const {
  const std::string index_start_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(user_id_, collection,
                                                          since_batch_id + 1);
  const std::string index_key_prefix =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(user_id_, collection);

  auto it = db_->current_transaction()->NewIterator();
  for (it->Seek(index_start_key);
       it->Valid() && absl::StartsWith(it->key(), index_key_prefix);
       it->Next()) {
    LevelDbDocumentOverlayCollectionIndexKey key;
    HARD_ASSERT(key.Decode(it->key()));
    if (key.collection() != collection) {
      break;
    }
    callback(std::move(key).ToLevelDbDocumentOverlayKey());
  }
}

void LevelDbDocumentOverlayCache::ForEachKeyInCollectionGroup(
    absl::string_view collection_group,
    int since_batch_id,
    std::function<ForEachKeyAction(LevelDbDocumentOverlayKey&&)> callback)
    const {
  const std::string index_start_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix(
          user_id_, collection_group, since_batch_id + 1);
  const std::string index_key_prefix =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix(
          user_id_, collection_group);

  auto it = db_->current_transaction()->NewIterator();
  for (it->Seek(index_start_key);
       it->Valid() && absl::StartsWith(it->key(), index_key_prefix);
       it->Next()) {
    LevelDbDocumentOverlayCollectionGroupIndexKey key;
    HARD_ASSERT(key.Decode(it->key()));
    if (key.collection_group() != collection_group) {
      break;
    }
    const ForEachKeyAction action =
        callback(std::move(key).ToLevelDbDocumentOverlayKey());
    if (action == ForEachKeyAction::kStop) {
      break;
    }
    HARD_ASSERT(action == ForEachKeyAction::kKeepGoing);
  }
}

absl::optional<Overlay> LevelDbDocumentOverlayCache::GetOverlay(
    const LevelDbDocumentOverlayKey& key) const {
  auto it = db_->current_transaction()->NewIterator();
  const std::string encoded_key = key.Encode();
  it->Seek(encoded_key);
  if (!it->Valid() || it->key() != encoded_key) {
    return absl::nullopt;
  }
  return ParseOverlay(key, it->value());
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
