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
#include <functional>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/index/firestore_index_value_writer.h"
#include "Firestore/core/src/index/index_byte_encoder.h"
#include "Firestore/core/src/index/index_entry.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/document_set.h"
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
using index::DirectionalIndexByteEncoder;
using index::IndexEncodingBuffer;
using index::IndexEntry;
using model::DocumentKey;
using model::DocumentMap;
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
LevelDbIndexManager::GetDocumentsMatchingTarget(const core::Target& target) {
  bool can_serve_target = true;
  std::unordered_map<core::Target, model::FieldIndex> indexes;
  for(const auto& sub_target: GetSubTargets(target)) {
    auto index_opt = GetFieldIndex(sub_target);
    can_serve_target = can_serve_target && index_opt.has_value();
    indexes.insert(sub_target, index_opt.value());
  }
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
  HARD_ASSERT(started_, "IndexManager not started");

  for (const auto& kv : documents) {
    const auto group = kv.first.GetCollectionGroup();
    std::vector<FieldIndex> indexes;
    if (group.has_value()) {
      indexes = GetFieldIndexes(group.value());
    }

    for (const auto& index : indexes) {
      auto existing_entries = GetExistingIndexEntries(kv.first, index);
      auto new_entries = ComputeIndexEntries(kv.second, index);
      if (existing_entries != new_entries) {
        UpdateEntries(kv.second, existing_entries, new_entries);
      }
    }
  }
}

std::set<IndexEntry> LevelDbIndexManager::GetExistingIndexEntries(
    const DocumentKey& key, const FieldIndex& index) {
  auto document_key_index_prefix =
      LevelDbIndexEntryDocumentKeyIndexKey::KeyPrefix(
          index.index_id(), uid_, key.path().CanonicalString());
  LevelDbIndexEntryDocumentKeyIndexKey document_key_index_key;
  auto iter = db_->current_transaction()->NewIterator();
  std::set<IndexEntry> index_entries;
  for (iter->Seek(document_key_index_prefix); iter->Valid(); iter->Next()) {
    if (!absl::StartsWith(iter->key(), document_key_index_prefix) ||
        !document_key_index_key.Decode(iter->key())) {
      break;
    }
    LevelDbIndexEntryKey entry_key;
    bool decoded = entry_key.Decode(iter->value());
    HARD_ASSERT(decoded,
                "LevelDbIndexEntryKey cannot be decoded from document key "
                "index table.");
    index_entries.insert({entry_key.index_id(),
                          DocumentKey::FromPathString(entry_key.document_key()),
                          entry_key.array_value(),
                          entry_key.directional_value()});
  }

  return index_entries;
}

std::set<IndexEntry> LevelDbIndexManager::ComputeIndexEntries(
    const model::Document& document, const FieldIndex& index) {
  std::set<IndexEntry> results;

  auto directional_value = EncodeDirectionalElements(index, document);
  if (directional_value == absl::nullopt) {
    return results;
  }

  auto array_segment = index.GetArraySegment();
  if (array_segment.has_value()) {
    auto field_value = document->field(array_segment->field_path());
    if (field_value.has_value() &&
        field_value.value().which_value_type ==
            google_firestore_v1_ArrayValue_values_tag) {
      for (pb_size_t i = 0; i < field_value.value().array_value.values_count;
           ++i) {
        results.insert(IndexEntry(
            index.index_id(), document->key(),
            EncodeSingleElement(field_value.value().array_value.values[i]),
            directional_value.value()));
      }
    }
  } else {
    results.insert(IndexEntry(index.index_id(), document->key(), "",
                              directional_value.value()));
  }

  return results;
}

absl::optional<std::string> LevelDbIndexManager::EncodeDirectionalElements(
    const FieldIndex& index, const model::Document& document) {
  IndexEncodingBuffer index_buffer;
  for (const auto& segment : index.GetDirectionalSegments()) {
    auto field = document->field(segment.field_path());
    if (!field.has_value()) {
      return absl::nullopt;
    }
    index::WriteIndexValue(field.value(), index_buffer.ForKind(segment.kind()));
  }
  return index_buffer.GetEncodedBytes();
}

std::string LevelDbIndexManager::EncodeSingleElement(
    const _google_firestore_v1_Value& value) {
  IndexEncodingBuffer index_buffer;
  index::WriteIndexValue(value, index_buffer.ForKind(model::Segment::kAscending));
  return index_buffer.GetEncodedBytes();
}

void DiffSets(std::set<IndexEntry> existing,
              std::set<IndexEntry> new_entries,
              std::function<void(const IndexEntry&)> on_add,
              std::function<void(const IndexEntry&)> on_remove) {
  auto existing_iter = existing.cbegin();
  auto new_iter = new_entries.cbegin();
  // Walk through the two sets at the same time, using the ordering defined by
  // `CompareTo`.
  while (existing_iter != existing.cend() || new_iter != new_entries.cend()) {
    bool added = false;
    bool removed = false;

    if (existing_iter != existing.cend() && new_iter != new_entries.cend()) {
      util::ComparisonResult cmp = existing_iter->CompareTo(*new_iter);
      if (cmp == util::ComparisonResult::Ascending) {
        // The element was removed if the next element in our ordered
        // walkthrough is only in `existing`.
        removed = true;
      } else if (cmp == util::ComparisonResult::Descending) {
        // The element was added if the next element in our ordered
        // walkthrough is only in `new_entries`.
        added = true;
      }
    } else if (existing_iter != existing.cend()) {
      removed = true;
    } else {
      added = true;
    }

    if (added) {
      on_add(*new_iter);
      new_iter++;
    } else if (removed) {
      on_remove(*existing_iter);
      existing_iter++;
    } else {
      if (existing_iter != existing.cend()) {
        existing_iter++;
      }
      if (new_iter != new_entries.cend()) {
        new_iter++;
      }
    }
  }
}

void LevelDbIndexManager::UpdateEntries(
    const model::Document& document,
    const std::set<IndexEntry>& existing_entries,
    const std::set<IndexEntry>& new_entries) {
  DiffSets(
      existing_entries, new_entries,
      [this, document](const IndexEntry& entry) {
        this->AddIndexEntry(document, entry);
      },
      [this, document](const IndexEntry& entry) {
        this->DeleteIndexEntry(document, entry);
      });
}

void LevelDbIndexManager::AddIndexEntry(const model::Document& document,
                                        const IndexEntry& entry) {
  absl::string_view document_key = document->key().path().CanonicalString();
  auto entry_key =
      LevelDbIndexEntryKey::Key(entry.index_id(), uid_, entry.array_value(),
                                entry.directional_value(), document_key);
  db_->current_transaction()->Put(entry_key, "");

  auto document_key_index_prefix =
      LevelDbIndexEntryDocumentKeyIndexKey::KeyPrefix(entry.index_id(), uid_,
                                                      document_key);
  std::string raw_key;
  auto iter = db_->current_transaction()->NewIterator();
  for (iter->Seek(document_key_index_prefix); iter->Valid(); iter->Next()) {
    if (absl::StartsWith(iter->key(), document_key_index_prefix)) {
      raw_key = iter->key();
    } else {
      break;
    }
  }

  LevelDbIndexEntryDocumentKeyIndexKey document_key_index_key(
      entry.index_id(), uid_, document_key, 0);
  if (!raw_key.empty()) {
    bool decoded = document_key_index_key.Decode(raw_key);
    HARD_ASSERT(decoded,
                "LevelDbIndexEntryDocumentKeyIndexKey cannot be decoded from "
                "document key index table.");
    document_key_index_key.IncreaseSeqNumber();
  }

  db_->current_transaction()->Put(document_key_index_key.Key(), entry_key);
}

void LevelDbIndexManager::DeleteIndexEntry(const model::Document& document,
                                           const IndexEntry& entry) {
  absl::string_view document_key = document->key().path().CanonicalString();
  auto entry_key =
      LevelDbIndexEntryKey::Key(entry.index_id(), uid_, entry.array_value(),
                                entry.directional_value(), document_key);
  db_->current_transaction()->Delete(entry_key);

  auto document_key_index_prefix =
      LevelDbIndexEntryDocumentKeyIndexKey::KeyPrefix(entry.index_id(), uid_,
                                                      document_key);
  LevelDbIndexEntryDocumentKeyIndexKey document_key_index_key;
  auto iter = db_->current_transaction()->NewIterator();
  for (iter->Seek(document_key_index_prefix); iter->Valid(); iter->Next()) {
    if (!absl::StartsWith(iter->key(), document_key_index_prefix) ||
        !document_key_index_key.Decode(iter->key())) {
      break;
    }
    db_->current_transaction()->Delete(iter->key());
  }
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
