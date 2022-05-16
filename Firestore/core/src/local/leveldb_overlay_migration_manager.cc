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

#include "Firestore/core/src/local/leveldb_overlay_migration_manager.h"

#include <string>
#include <unordered_set>
#include <utility>

#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_documents_view.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "absl/strings/match.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using credentials::User;

std::unordered_set<std::string> GetAllUserIds(LevelDbPersistence* db) {
  std::unordered_set<std::string> uids;
  auto prefix = LevelDbMutationKey::KeyPrefix();
  LevelDbMutationKey key;
  auto iter = db->current_transaction()->NewIterator();
  for (iter->Seek(prefix); iter->Valid(); iter->Next()) {
    if (!absl::StartsWith(iter->key(), prefix) || !key.Decode(iter->key())) {
      break;
    }

    uids.insert(key.user_id());
  }
  return uids;
}

void RemovePendingOverlayMigrations(LevelDbPersistence* db) {
  auto key = LevelDbDataMigrationKey::OverlayMigrationKey();
  db->current_transaction()->Delete(key);
}

}  // namespace

bool LevelDbOverlayMigrationManager::HasPendingOverlayMigration() {
  auto key = LevelDbDataMigrationKey::OverlayMigrationKey();
  std::string to_discard;
  return db_->current_transaction()->Get(key, &to_discard).ok();
}

void LevelDbOverlayMigrationManager::Run() {
  db_->Run("migrate overlays", [this] {
    if (!HasPendingOverlayMigration()) {
      return;
    }

    std::unordered_set<std::string> user_ids = GetAllUserIds(db_);
    auto* remote_document_cache = db_->remote_document_cache();
    for (const auto& uid : user_ids) {
      User user = User::Unauthenticated();
      if (!uid.empty()) {
        user = User(uid);
      }
      auto* index_manager = db_->GetIndexManager(user);
      auto* mutation_queue = db_->GetMutationQueue(user, index_manager);

      // Get all document keys that have local mutations
      model::DocumentKeySet all_document_keys;
      for (const auto& batch : mutation_queue->AllMutationBatches()) {
        all_document_keys = all_document_keys.union_with(batch.keys());
      }

      // Recalculate and save overlays
      auto* document_overlay_cache = db_->GetDocumentOverlayCache(user);
      LocalDocumentsView local_view(remote_document_cache, mutation_queue,
                                    document_overlay_cache, index_manager);
      local_view.RecalculateAndSaveOverlays(std::move(all_document_keys));
    }

    db_->ReleaseOtherUserSpecificComponents(uid_);
    RemovePendingOverlayMigrations(db_);
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
