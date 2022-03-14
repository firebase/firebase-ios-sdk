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

#include <algorithm>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/third_party/nlohmann_json/json.hpp"
#include "absl/strings/match.h"

namespace firebase {
namespace firestore {
namespace local {

using credentials::User;
using model::DocumentKey;
using model::FieldIndex;
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
  model::BatchId largest_batch_id;
};

void from_json(const json& j, DbIndexState& s) {
  j.at("seconds").get_to(s.seconds);
  j.at("nanos").get_to(s.nanos);
  j.at("key").get_to(s.key);
  j.at("seq_num").get_to(s.sequence_number);
  j.at("largest_batch").get_to(s.largest_batch_id);
}

IndexState DecodeIndexState(const std::string& encoded) {
  auto j = json::parse(encoded.begin(), encoded.end(), /*callback=*/nullptr,
                       /*allow_exceptions=*/false);
  auto db_state = j.get<DbIndexState>();
  return {db_state.sequence_number,
          SnapshotVersion(Timestamp(db_state.seconds, db_state.nanos)),
          DocumentKey::FromPathString(db_state.key), db_state.largest_batch_id};
}

std::string EncodeIndexState(const IndexState& state) {
  return json{
      {"seconds", state.index_offset().read_time().timestamp().seconds()},
      {"nanos", state.index_offset().read_time().timestamp().nanoseconds()},
      {"key", state.index_offset().document_key().ToString()},
      {"seq_num", state.sequence_number()},
      {"largest_batch", state.index_offset().largest_batch_id()}}
      .dump();
}

}  // namespace

LevelDbIndexManager::LevelDbIndexManager(const User& user,
                                         LevelDbPersistence* db,
                                         LocalSerializer* serializer)
    : db_(db), serializer_(serializer), uid_(user.uid()) {
  // The contract for this comparison expected by priority queue is
  // `std::less`, but std::priority_queue's default order is descending.
  // We change the order to be ascending by doing left >= right instead.
  auto cmp = [](FieldIndex* left, FieldIndex* right) {
    if (left->index_state().sequence_number() ==
        right->index_state().sequence_number()) {
      return left->collection_group() >= right->collection_group();
    }
    return left->index_state().sequence_number() >
           right->index_state().sequence_number();
  };
  next_index_to_update_ = std::priority_queue<
      FieldIndex*, std::vector<FieldIndex*>,
      std::function<bool(model::FieldIndex*, model::FieldIndex*)>>(cmp);
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

  // Fetch all index states that are persisted for the user. These states
  // contain per user information on how up to date the index is.
  {
    auto state_iter = db_->current_transaction()->NewIterator();
    auto state_key_prefix = LevelDbIndexStateKey::KeyPrefix(uid_);
    LevelDbIndexStateKey state_key;
    for (state_iter->Seek(state_key_prefix); state_iter->Valid();
         state_iter->Next()) {
      if (!absl::StartsWith(state_iter->key(), state_key_prefix) ||
          !state_key.Decode(state_iter->key())) {
        break;
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

      nanopb::StringReader reader{config_iter->value()};
      auto message =
          nanopb::Message<google_firestore_admin_v1_Index>::TryParse(&reader);
      if (!reader.ok()) {
        HARD_FAIL("Index proto failed to parse: %s",
                  reader.status().ToString());
      }

      auto segments = serializer_->DecodeFieldIndexSegments(&reader, *message);
      if (!reader.ok()) {
        HARD_FAIL("Index proto failed to decode: %s",
                  reader.status().ToString());
      }

      // If we fetched an index state for the user above, combine it with this
      // index. We use the default state if we don't have an index state (e.g.
      // the index was created while a different user was logged in).
      auto iter = index_states.find(config_key.index_id());
      IndexState state = iter != index_states.end()
                             ? iter->second
                             : FieldIndex::InitialState();

      // Store the index and update `memoized_max_index_id_` and
      // `memoized_max_sequence_number_`.
      MemoizeIndex(FieldIndex(config_key.index_id(),
                              config_key.collection_group(),
                              std::move(segments), state));
    }
  }

  started_ = true;
}

void LevelDbIndexManager::DeleteFromUpdateQueue(FieldIndex* index_ptr) {
  // Pop and save `FieldIndex*` until index_ptr is found, then pushed what are
  // popped out back to `next_index_to_update_` except for `index_ptr`.
  std::vector<FieldIndex*> popped_out;
  while (!next_index_to_update_.empty()) {
    auto* top = next_index_to_update_.top();
    next_index_to_update_.pop();
    if (top == index_ptr) {
      break;
    } else {
      popped_out.push_back(top);
    }
  }

  for (auto* index : popped_out) {
    next_index_to_update_.push(index);
  }
}

void LevelDbIndexManager::MemoizeIndex(FieldIndex index) {
  auto& existing_indexes = memoized_indexes_[index.collection_group()];

  // Copy some value out because `index` will be moved to `existing_index_`
  // later.
  auto index_id = index.index_id();
  auto sequence_number = index.index_state().sequence_number();

  auto existing_index_iter = existing_indexes.find(index_id);

  if (existing_index_iter != existing_indexes.end()) {
    DeleteFromUpdateQueue(&existing_index_iter->second);
  }

  // Moves `index` into `existing_indexes`.
  existing_indexes[index_id] = std::move(index);

  // next_index_to_update_ holds a pointer to the index owned by
  // `existing_indexes`.
  next_index_to_update_.push(&existing_indexes.find(index_id)->second);
  memoized_max_index_id_ = std::max(memoized_max_index_id_, index_id);
  memoized_max_sequence_number_ =
      std::max(memoized_max_sequence_number_, sequence_number);
}

void LevelDbIndexManager::AddFieldIndex(const FieldIndex& index) {
  HARD_ASSERT(started_, "IndexManager not started");

  int next_index_id = memoized_max_index_id_ + 1;
  FieldIndex new_index(next_index_id, index.collection_group(),
                       index.segments(), index.index_state());

  auto config_key = LevelDbIndexConfigurationKey::Key(
      new_index.index_id(), new_index.collection_group());
  db_->current_transaction()->Put(
      config_key, serializer_->EncodeFieldIndexSegments(new_index.segments()));

  MemoizeIndex(std::move(new_index));
}

void LevelDbIndexManager::DeleteFieldIndex(const FieldIndex& index) {
  HARD_ASSERT(started_, "IndexManager not started");

  db_->current_transaction()->Delete(LevelDbIndexConfigurationKey::Key(
      index.index_id(), index.collection_group()));

  // Delete states from all users for this index id.
  {
    auto state_prefix = LevelDbIndexStateKey::KeyPrefix();
    auto iter = db_->current_transaction()->NewIterator();
    LevelDbIndexStateKey state_key;
    for (iter->Seek(state_prefix); iter->Valid(); iter->Next()) {
      if (!absl::StartsWith(iter->key(), state_prefix) ||
          !state_key.Decode(iter->key())) {
        break;
      }

      if (state_key.index_id() == index.index_id()) {
        db_->current_transaction()->Delete(iter->key());
      }
    }
  }

  // Delete entries from all users for this index id.
  {
    auto entry_prefix = LevelDbIndexEntryKey::KeyPrefix(index.index_id());
    auto iter = db_->current_transaction()->NewIterator();
    for (iter->Seek(entry_prefix); iter->Valid(); iter->Next()) {
      if (!absl::StartsWith(iter->key(), entry_prefix)) {
        break;
      }
      db_->current_transaction()->Delete(iter->key());
    }
  }

  auto group_index_iter = memoized_indexes_.find(index.collection_group());
  if (group_index_iter != memoized_indexes_.end()) {
    auto& index_map = group_index_iter->second;
    auto index_iter = index_map.find(index.index_id());
    if (index_iter != index_map.end()) {
      DeleteFromUpdateQueue(&index_iter->second);
      index_map.erase(index_iter);
    }
  }
}

std::vector<FieldIndex> LevelDbIndexManager::GetFieldIndexes(
    const std::string& collection_group) {
  HARD_ASSERT(started_, "IndexManager not started");

  std::vector<FieldIndex> result;
  const auto iter = memoized_indexes_.find(collection_group);
  if (iter != memoized_indexes_.end()) {
    for (const auto& entry : iter->second) {
      result.push_back(entry.second);
    }
  }

  return result;
}

std::vector<model::FieldIndex> LevelDbIndexManager::GetFieldIndexes() {
  std::vector<FieldIndex> result;
  for (const auto& entry : memoized_indexes_) {
    for (const auto& id_index_entry : entry.second) {
      result.push_back(id_index_entry.second);
    }
  }

  return result;
}

absl::optional<model::FieldIndex> LevelDbIndexManager::GetFieldIndex(
    core::Target target) {
  (void)target;
  return {};
}

absl::optional<std::vector<model::DocumentKey>>
LevelDbIndexManager::GetDocumentsMatchingTarget(model::FieldIndex field_index,
                                                core::Target target) {
  (void)field_index;
  (void)target;
  return {};
}

absl::optional<std::string>
LevelDbIndexManager::GetNextCollectionGroupToUpdate() {
  if (next_index_to_update_.empty()) {
    return absl::nullopt;
  }

  return next_index_to_update_.top()->collection_group();
}

void LevelDbIndexManager::UpdateCollectionGroup(
    const std::string& collection_group, model::IndexOffset offset) {
  HARD_ASSERT(started_, "IndexManager not started");

  ++memoized_max_sequence_number_;
  for (const auto& field_index : GetFieldIndexes(collection_group)) {
    IndexState updated_state{memoized_max_sequence_number_, offset};

    auto state_key = LevelDbIndexStateKey::Key(uid_, field_index.index_id());
    auto val = EncodeIndexState(updated_state);
    db_->current_transaction()->Put(std::move(state_key),
                                    EncodeIndexState(updated_state));

    MemoizeIndex(FieldIndex{field_index.index_id(),
                            field_index.collection_group(),
                            field_index.segments(), std::move(updated_state)});
  }
}

void LevelDbIndexManager::UpdateIndexEntries(
    const model::DocumentMap& documents) {
  (void)documents;
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
