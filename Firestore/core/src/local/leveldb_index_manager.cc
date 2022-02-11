/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/local/leveldb_index_manager.h"

#include <string>
#include <vector>

#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/memory_index_manager.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/third_party/nlohmann_json/json.hpp"
#include "absl/strings/match.h"

namespace firebase {
namespace firestore {
namespace local {

using model::DocumentKey;
using model::IndexState;
using model::ResourcePath;
using model::SnapshotVersion;
using nlohmann::json;

namespace {

struct DbIndexState {
  int64_t seconds;
  int32_t nanos;
  std::string key;
  model::ListenSequenceNumber sequence_number;
};

void to_json(json& j, const DbIndexState& s) {
  j = json{{"seconds", s.seconds}, {"nanos", s.nanos},
           {"key", s.key}, {"seq_num", s.sequence_number}};
}

void from_json(const json& j, DbIndexState& s) {
   j.at("seconds").get_to(s.seconds);
  j.at("nanos").get_to(s.nanos);
  j.at("key").get_to(s.key);
  j.at("seq_num").get_to(s.sequence_number);
}

IndexState DecodeIndexState(const std::string& encoded) {
  auto j = json::parse(encoded.begin(), encoded.end(), /*callback=*/nullptr,
                     /*allow_exceptions=*/false);
  auto db_state = j.get<DbIndexState>();
  return {db_state.sequence_number,
                    SnapshotVersion(Timestamp(db_state.seconds,
                                              db_state.nanos)),
                    DocumentKey::FromPathString(db_state.key)};
}

} // namespace

LevelDbIndexManager::LevelDbIndexManager(LevelDbPersistence* db) : db_(db) {
}

void LevelDbIndexManager::AddToCollectionParentIndex(
    const ResourcePath& collection_path) {
  HARD_ASSERT(collection_path.size() % 2 == 1, "Expected a collection path.");

  if (collection_parents_cache_.Add(collection_path)) {
    std::string collection_id = collection_path.last_segment();
    ResourcePath parent_path = collection_path.PopLast();

    std::string key =
        LevelDbCollectionParentKey::Key(collection_id, parent_path);
    std::string empty_buffer;
    db_->current_transaction()->Put(key, empty_buffer);
  }
}

std::vector<ResourcePath> LevelDbIndexManager::GetCollectionParents(
    const std::string& collection_id) {
  std::vector<ResourcePath> results;

  auto index_iterator = db_->current_transaction()->NewIterator();
  std::string index_prefix =
      LevelDbCollectionParentKey::KeyPrefix(collection_id);
  LevelDbCollectionParentKey row_key;
  for (index_iterator->Seek(index_prefix); index_iterator->Valid();
       index_iterator->Next()) {
    if (!absl::StartsWith(index_iterator->key(), index_prefix) ||
        !row_key.Decode(index_iterator->key()) ||
        row_key.collection_id() != collection_id) {
      break;
    }

    results.push_back(row_key.parent());
  }
  return results;
}

void LevelDbIndexManager::Start() {
  std::unordered_map<int32_t, IndexState> index_states;

  // Fetch all index states if persisted for the user. These states contain per user information
  // on how up to date the index is.
  {
    auto state_iter = db_->current_transaction()->NewIterator();
    auto state_key_prefix = LevelDbIndexStateKey::KeyPrefix();
    LevelDbIndexStateKey state_key;
    for (state_iter->Seek(state_key_prefix); state_iter->Valid();
         state_iter->Next()) {
      if (!absl::StartsWith(state_iter->key(), state_key_prefix) ||
          !state_key.Decode(state_iter->key())) {
        break;
      }

      if (state_key.user_id() != uid_) {
        continue;
      }

      index_states.insert(
          {state_key.index_id(), DecodeIndexState(state_iter->value())});
    }
  }

  // Fetch all indices and combine with user's index state if available.
  {
    auto config_iter = db_->current_transaction()->NewIterator();
    auto config_key_prefix = LevelDbIndexConfigurationKey::KeyPrefix();
    LevelDbIndexConfigurationKey config_key;
    for (config_iter->Seek(config_key_prefix); config_iter->Valid();
         config_iter->Next()) {
      if (!absl::StartsWith(config_iter->key(), config_key_prefix) ||
          !config_key.Decode(config_iter->key())) {
        break;
      }

      static_cast<>(config_key)
    }
  }

  db.query("SELECT index_id, collection_group, index_proto FROM index_configuration")
        .forEach(
            row -> {
              try {
                int indexId = row.getInt(0);
                String collectionGroup = row.getString(1);
                List<FieldIndex.Segment> segments =
                    serializer.decodeFieldIndexSegments(Index.parseFrom(row.getBlob(2)));

                // If we fetched an index state for the user above, combine it with this index.
                // We use the default state if we don't have an index state (e.g. the index was
                // created while a different user as logged in).
                FieldIndex.IndexState indexState =
                    indexStates.containsKey(indexId)
                        ? indexStates.get(indexId)
                        : FieldIndex.INITIAL_STATE;
                FieldIndex fieldIndex =
                    FieldIndex.create(indexId, collectionGroup, segments, indexState);

                // Store the index and update `memoizedMaxIndexId` and `memoizedMaxSequenceNumber`.
                memoizeIndex(fieldIndex);
              } catch (InvalidProtocolBufferException e) {
                throw fail("Failed to decode index: " + e);
              }
            });

    started_ = true;
}

void LevelDbIndexManager::AddFieldIndex(model::FieldIndex index) {
  IndexManager::AddFieldIndex(index);
}
void LevelDbIndexManager::DeleteFieldIndex(model::FieldIndex index) {
  IndexManager::DeleteFieldIndex(index);
}
std::vector<model::FieldIndex> LevelDbIndexManager::GetFieldIndexes(
    const std::string& collection_group) {
  return IndexManager::GetFieldIndexes(collection_group);
}
std::vector<model::FieldIndex> LevelDbIndexManager::GetFieldIndexes() {
  return IndexManager::GetFieldIndexes();
}
absl::optional<model::FieldIndex> LevelDbIndexManager::GetFieldIndex(
    core::Target target) {
  return IndexManager::GetFieldIndex(target);
}
std::vector<model::DocumentKey> LevelDbIndexManager::GetDocumentsMatchingTarget(
    model::FieldIndex fieldIndex, core::Target target) {
  return IndexManager::GetDocumentsMatchingTarget(fieldIndex, target);
}
absl::optional<std::string>
LevelDbIndexManager::GetNextCollectionGroupToUpdate() {
  return IndexManager::GetNextCollectionGroupToUpdate();
}
void LevelDbIndexManager::UpdateCollectionGroup(
    const std::string& collection_group, model::IndexOffset offset) {
  IndexManager::UpdateCollectionGroup(collection_group, offset);
}
void LevelDbIndexManager::UpdateIndexEntries(model::DocumentMap documents) {
  IndexManager::UpdateIndexEntries(documents);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
