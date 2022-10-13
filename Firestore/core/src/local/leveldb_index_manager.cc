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
#include <memory>
#include <set>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

#include "Firestore/core/src/core/composite_filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/index/firestore_index_value_writer.h"
#include "Firestore/core/src/index/index_byte_encoder.h"
#include "Firestore/core/src/index/index_entry.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/leveldb_util.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/target_index_matcher.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/logic_utils.h"
#include "Firestore/core/src/util/set_util.h"
#include "Firestore/core/src/util/string_util.h"
#include "Firestore/third_party/nlohmann_json/json.hpp"
#include "absl/strings/match.h"
#include "leveldb/iterator.h"

namespace firebase {
namespace firestore {
namespace local {

using core::CompositeFilter;
using core::Filter;
using core::Target;
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
using model::TargetIndexMatcher;
using nlohmann::json;
using util::LogicUtils;

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

bool IsInFilter(const Target& target, const model::FieldPath& field_path) {
  for (const auto& filter : target.filters()) {
    if (filter.IsAFieldFilter()) {
      const core::FieldFilter field_filter(filter);
      if (field_filter.field() != field_path) {
        continue;
      }
      if (field_filter.op() == core::FieldFilter::Operator::In ||
          field_filter.op() == core::FieldFilter::Operator::NotIn) {
        return true;
      }
    }
  }

  return false;
}

/**
 * Creates a separate encoder buffer for each element of an array.
 *
 * The method appends each value to all existing encoders (e.g. filter("a",
 * "==", "a1").filter("b", "in", ["b1", "b2"]) becomes ["a1,b1", "a1,b2"]). A
 * list of new encoders is returned.
 */
std::vector<IndexEncodingBuffer> ExpandIndexValues(
    const std::vector<IndexEncodingBuffer>& buffers,
    const model::Segment& segment,
    const google_firestore_v1_Value& value) {
  std::vector<IndexEncodingBuffer> results;
  for (size_t idx = 0; idx < value.array_value.values_count; ++idx) {
    for (const IndexEncodingBuffer& buf : buffers) {
      IndexEncodingBuffer cloned_buf;
      cloned_buf.Seed(buf.GetEncodedBytes());
      WriteIndexValue(value.array_value.values[idx],
                      cloned_buf.ForKind(segment.kind()));
      results.push_back(std::move(cloned_buf));
    }
  }
  return results;
}

/** Returns the byte representation for all encoders. */
std::vector<std::string> GetEncodedBytes(
    const std::vector<IndexEncodingBuffer>& buffers) {
  std::vector<std::string> result;
  for (const auto& buf : buffers) {
    result.push_back(buf.GetEncodedBytes());
  }
  return result;
}

/** Generates the lower bound for `arrayValue` and `directionalValue`. */
IndexEntry GenerateLowerBound(int32_t index_id,
                              const std::string& array_value,
                              const std::string& directional_value,
                              bool inclusive) {
  IndexEntry entry{index_id, DocumentKey::Empty(), array_value,
                   directional_value};
  return inclusive ? entry : entry.Successor();
}

/** Generates the upper bound for `arrayValue` and `directionalValue`. */
IndexEntry GenerateUpperBound(int32_t index_id,
                              const std::string& array_value,
                              const std::string& directional_value,
                              bool inclusive) {
  IndexEntry entry{index_id, DocumentKey::Empty(), array_value,
                   directional_value};
  return inclusive ? entry.Successor() : entry;
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
    const std::string& collection_group) const {
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

std::vector<model::FieldIndex> LevelDbIndexManager::GetFieldIndexes() const {
  std::vector<FieldIndex> result;
  for (const auto& entry : memoized_indexes_) {
    for (const auto& id_index_entry : entry.second) {
      result.push_back(id_index_entry.second);
    }
  }

  return result;
}

absl::optional<model::FieldIndex> LevelDbIndexManager::GetFieldIndex(
    const core::Target& target) const {
  HARD_ASSERT(started_, "IndexManager not started");

  TargetIndexMatcher target_index_matcher(target);
  std::string collection_group = target.collection_group() != nullptr
                                     ? (*target.collection_group())
                                     : target.path().last_segment();

  std::vector<FieldIndex> collection_indexes =
      GetFieldIndexes(collection_group);
  if (collection_indexes.empty()) {
    return absl::nullopt;
  }

  absl::optional<FieldIndex> result;
  for (FieldIndex index : collection_indexes) {
    if (target_index_matcher.ServedByIndex(index)) {
      if (!result.has_value() ||
          result.value().segments().size() < index.segments().size()) {
        // `index` serves the target, and it has more segments than the current
        // `result`.
        result = std::move(index);
      }
    }
  }

  return result;
}

model::IndexOffset LevelDbIndexManager::GetMinOffset(
    const core::Target& target) {
  std::vector<FieldIndex> indexes;
  for (const auto& sub_target : GetSubTargets(target)) {
    auto index_opt = GetFieldIndex(sub_target);
    if (index_opt.has_value()) {
      indexes.push_back(index_opt.value());
    }
  }
  return GetMinOffset(indexes);
}

model::IndexOffset LevelDbIndexManager::GetMinOffset(
    const std::string& collection_group) const {
  const std::vector<model::FieldIndex> field_indexes =
      GetFieldIndexes(collection_group);
  return GetMinOffset(field_indexes);
}

model::IndexOffset LevelDbIndexManager::GetMinOffset(
    const std::vector<model::FieldIndex>& indexes) const {
  HARD_ASSERT(
      !indexes.empty(),
      "Found empty index group when looking for least recent index offset.");

  auto it = indexes.cbegin();
  const model::IndexOffset* min_offset =
      &((it++)->index_state().index_offset());
  int max_batch_id = min_offset->largest_batch_id();
  for (; it != indexes.cend(); it++) {
    const model::IndexOffset* new_offset = &(it->index_state().index_offset());
    if (new_offset->CompareTo(*min_offset) ==
        util::ComparisonResult::Ascending) {
      min_offset = new_offset;
    }
    max_batch_id = std::max(max_batch_id, new_offset->largest_batch_id());
  }

  return {min_offset->read_time(), min_offset->document_key(), max_batch_id};
}

IndexManager::IndexType LevelDbIndexManager::GetIndexType(
    const core::Target& target) {
  IndexManager::IndexType result = IndexManager::IndexType::FULL;
  const auto sub_targets = GetSubTargets(target);

  for (const Target& sub_target : sub_targets) {
    absl::optional<model::FieldIndex> index = GetFieldIndex(sub_target);
    if (!index) {
      result = IndexManager::IndexType::NONE;
      break;
    }

    if (index.value().segments().size() < sub_target.GetSegmentCount()) {
      result = IndexManager::IndexType::PARTIAL;
    }
  }

  // OR queries have more than one sub-target (one sub-target per DNF term).
  // We currently consider OR queries that have a `limit` to have a partial
  // index. For such queries we perform sorting and apply the limit in memory as
  // a post-processing step.
  if (target.HasLimit() && sub_targets.size() > 1U &&
      result == IndexManager::IndexType::FULL) {
    result = IndexManager::IndexType::PARTIAL;
  }

  return result;
}

absl::optional<std::vector<model::DocumentKey>>
LevelDbIndexManager::GetDocumentsMatchingTarget(const core::Target& target) {
  std::unordered_map<core::Target, model::FieldIndex> indexes;
  for (const auto& sub_target : GetSubTargets(target)) {
    auto index_opt = GetFieldIndex(sub_target);
    if (!index_opt.has_value()) {
      return absl::nullopt;
    }

    indexes.insert({sub_target, index_opt.value()});
  }

  std::vector<DocumentKey> result;
  std::unordered_set<std::string> existing_keys;
  for (const auto& entry : indexes) {
    const Target& sub_target = entry.first;
    const FieldIndex& index = entry.second;

    LOG_DEBUG("Using index %s to execute target %s", index.collection_group(),
              sub_target.CanonicalId());

    auto array_values = sub_target.GetArrayValues(index);
    auto not_in_values = sub_target.GetNotInValues(index);
    auto lower_bound = sub_target.GetLowerBound(index);
    auto upper_bound = sub_target.GetUpperBound(index);

    auto encoded_lower = EncodeBound(index, sub_target, lower_bound);
    auto encoded_upper = EncodeBound(index, sub_target, upper_bound);
    auto encoded_not_in = EncodeValues(index, sub_target, not_in_values);

    auto index_ranges = GenerateIndexRanges(
        index.index_id(), array_values, encoded_lower, lower_bound.inclusive,
        encoded_upper, upper_bound.inclusive, encoded_not_in);

    auto iter = db_->current_transaction()->NewIterator();
    for (const auto& range : index_ranges) {
      int32_t count = 0;
      for (iter->Seek(range.lower); iter->Valid() && count < target.limit() &&
                                    iter->key() <= range.upper;
           iter->Next()) {
        LevelDbIndexEntryKey entry_key;
        if (!entry_key.Decode(iter->key())) {
          break;
        }

        ++count;
        if (existing_keys.find(entry_key.document_key()) ==
            existing_keys.end()) {
          result.push_back(
              DocumentKey::FromPathString(entry_key.document_key()));
          existing_keys.insert(entry_key.document_key());
        }
      }
    }
  }

  return result;
}

std::vector<std::string> LevelDbIndexManager::EncodeBound(
    const FieldIndex& index,
    const Target& target,
    const core::IndexBoundValues& bound) {
  return EncodeValues(index, target, bound.values);
}

std::vector<std::string> LevelDbIndexManager::EncodeValues(
    const FieldIndex& index,
    const Target& target,
    core::IndexedValues bound_values) {
  if (!bound_values.has_value()) {
    return {};
  }

  std::vector<IndexEncodingBuffer> buffers = {};
  buffers.emplace_back();

  size_t bound_idx = 0;
  for (const auto& segment : index.GetDirectionalSegments()) {
    const google_firestore_v1_Value& value = bound_values.value()[bound_idx++];
    if (IsInFilter(target, segment.field_path()) && model::IsArray(value)) {
      buffers = ExpandIndexValues(buffers, segment, value);
    } else {
      for (auto& buffer : buffers) {
        auto* encoder = buffer.ForKind(segment.kind());
        WriteIndexValue(value, encoder);
      }
    }
  }
  return GetEncodedBytes(buffers);
}

std::vector<LevelDbIndexManager::IndexRange>
LevelDbIndexManager::GenerateIndexRanges(
    int32_t index_id,
    core::IndexedValues array_values,
    const std::vector<std::string>& lower_bounds,
    bool lower_bounds_inclusive,
    const std::vector<std::string>& upper_bounds,
    bool upper_bounds_inclusive,
    std::vector<std::string> not_in_values) {
  // The number of total index scans we union together. This is similar to a
  // disjunctive normal form, but adapted for array values. We create a single
  // index range per value in an ARRAY_CONTAINS or ARRAY_CONTAINS_ANY filter
  // combined with the values from the query bounds.
  size_t total_scans = (array_values.has_value() ? array_values->size() : 1) *
                       std::max(lower_bounds.size(), upper_bounds.size());
  size_t scans_per_array_element =
      total_scans / (array_values.has_value() ? array_values->size() : 1);

  std::vector<IndexRange> index_ranges;
  for (size_t i = 0; i < total_scans; ++i) {
    std::string array_value =
        array_values.has_value()
            ? EncodeSingleElement(
                  array_values.value()[i / scans_per_array_element])
            : "";

    IndexEntry lower_bound = GenerateLowerBound(
        index_id, array_value, lower_bounds[i % scans_per_array_element],
        lower_bounds_inclusive);
    IndexEntry upper_bound = GenerateUpperBound(
        index_id, array_value, upper_bounds[i % scans_per_array_element],
        upper_bounds_inclusive);

    std::vector<IndexEntry> not_in_bounds;
    for (const auto& not_in : not_in_values) {
      not_in_bounds.push_back(GenerateLowerBound(index_id, array_value, not_in,
                                                 /* inclusive= */ true));
    }

    auto new_range =
        CreateRange(lower_bound, upper_bound, std::move(not_in_bounds));
    index_ranges.insert(index_ranges.end(), new_range.begin(), new_range.end());
  }

  return index_ranges;
}

std::vector<LevelDbIndexManager::IndexRange> LevelDbIndexManager::CreateRange(
    const index::IndexEntry& lower_bound,
    const index::IndexEntry& upper_bound,
    std::vector<index::IndexEntry> not_in_values) const {
  // The `not_in_values` need to be sorted and unique so that we can return a
  // sorted set of non-overlapping ranges.
  std::sort(not_in_values.begin(), not_in_values.end(),
            [](const IndexEntry& left, const IndexEntry& right) {
              return left.CompareTo(right) == util::ComparisonResult::Ascending;
            });
  std::vector<index::IndexEntry> sorted_unique_not_in;
  for (size_t idx = 0; idx < not_in_values.size(); ++idx) {
    if (idx == 0 || not_in_values[idx].CompareTo(not_in_values[idx - 1]) !=
                        util::ComparisonResult::Same) {
      sorted_unique_not_in.push_back(not_in_values[idx]);
    }
  }

  std::vector<IndexEntry> bounds;
  bounds.push_back(lower_bound);
  for (const auto& not_in_value : sorted_unique_not_in) {
    auto cmp_to_lower = not_in_value.CompareTo(lower_bound);
    auto cmp_to_upper = not_in_value.CompareTo(upper_bound);

    if (cmp_to_lower == util::ComparisonResult::Same) {
      // `notInValue` is the lower bound. We therefore need to raise the bound
      // to the next value.
      bounds[0] = lower_bound.Successor();
    } else if (cmp_to_lower == util::ComparisonResult::Descending &&
               cmp_to_upper == util::ComparisonResult::Ascending) {
      // `notInValue` is in the middle of the range
      bounds.push_back(not_in_value);
      bounds.push_back(not_in_value.Successor());
    } else if (cmp_to_upper == util::ComparisonResult::Descending) {
      // `notInValue` (and all following values) are out of the range
      break;
    }
  }
  bounds.push_back(upper_bound);

  std::vector<LevelDbIndexManager::IndexRange> ranges;
  for (size_t i = 0; i < bounds.size(); i += 2) {
    ranges.push_back(LevelDbIndexManager::IndexRange{
        LevelDbIndexEntryKey::KeyPrefix(bounds[i].index_id(), uid_,
                                        bounds[i].array_value(),
                                        bounds[i].directional_value()),
        LevelDbIndexEntryKey::KeyPrefix(bounds[i + 1].index_id(), uid_,
                                        bounds[i + 1].array_value(),
                                        bounds[i + 1].directional_value())});
  }
  return ranges;
}

absl::optional<std::string>
LevelDbIndexManager::GetNextCollectionGroupToUpdate() const {
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
    HARD_ASSERT(group.has_value(),
                "Document key is expected to have a collection group");
    std::vector<FieldIndex> indexes;
    indexes = GetFieldIndexes(group.value());

    for (const auto& index : indexes) {
      auto existing_entries = GetExistingIndexEntries(kv.first, index);
      auto new_entries = ComputeIndexEntries(kv.second, index);
      if (existing_entries != new_entries) {
        UpdateEntries(kv.second, index, existing_entries, new_entries);
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
    index_entries.insert({entry_key.index_id(), key, entry_key.array_value(),
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
            google_firestore_v1_Value_array_value_tag) {
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
  index::WriteIndexValue(value,
                         index_buffer.ForKind(model::Segment::kAscending));
  return index_buffer.GetEncodedBytes();
}

void LevelDbIndexManager::UpdateEntries(
    const model::Document& document,
    const FieldIndex& index,
    const std::set<IndexEntry>& existing_entries,
    const std::set<IndexEntry>& new_entries) {
  util::DiffSets<IndexEntry>(
      existing_entries, new_entries,
      [](const IndexEntry& left, const IndexEntry& right) {
        return left.CompareTo(right);
      },
      [this, document, index](const IndexEntry& entry) {
        this->AddIndexEntry(document, index, entry);
      },
      [this, document, index](const IndexEntry& entry) {
        this->DeleteIndexEntry(document, index, entry);
      });
}

void LevelDbIndexManager::AddIndexEntry(const model::Document& document,
                                        const FieldIndex& index,
                                        const IndexEntry& entry) {
  std::string document_key = document->key().path().CanonicalString();
  auto entry_key = LevelDbIndexEntryKey::Key(
      entry.index_id(), uid_, entry.array_value(), entry.directional_value(),
      EncodedDirectionalKey(index, document->key()), document_key);
  db_->current_transaction()->Put(entry_key, "");

  auto document_key_index_prefix =
      LevelDbIndexEntryDocumentKeyIndexKey::KeyPrefix(entry.index_id(), uid_,
                                                      document_key);
  std::unique_ptr<leveldb::Iterator> iter(
      db_->ptr()->NewIterator(LevelDbTransaction::DefaultReadOptions()));
  iter->Seek(util::PrefixSuccessor(document_key_index_prefix));
  iter->Prev();
  absl::string_view raw_key;
  if (iter->Valid() && absl::StartsWith(local::MakeStringView(iter->key()),
                                        document_key_index_prefix)) {
    raw_key = local::MakeStringView(iter->key());
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

std::string LevelDbIndexManager::EncodedDirectionalKey(
    const FieldIndex& index, const model::DocumentKey& key) {
  auto kind = index.GetDirectionalSegments().empty()
                  ? model::Segment::kAscending
                  : index.GetDirectionalSegments().rbegin()->kind();
  IndexEncodingBuffer buffer;
  index::WriteIndexValue(*model::RefValue(serializer_->database_id(), key),
                         buffer.ForKind(kind));
  return buffer.GetEncodedBytes();
}

void LevelDbIndexManager::DeleteIndexEntry(const model::Document& document,
                                           const FieldIndex& index,
                                           const IndexEntry& entry) {
  std::string document_key = document->key().path().CanonicalString();
  auto entry_key = LevelDbIndexEntryKey::Key(
      entry.index_id(), uid_, entry.array_value(), entry.directional_value(),
      EncodedDirectionalKey(index, document->key()), document_key);
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

std::vector<Target> LevelDbIndexManager::GetSubTargets(const Target& target) {
  auto it = target_to_dnf_subtargets_.find(target);
  if (it != target_to_dnf_subtargets_.end()) {
    return it->second;
  }

  std::vector<Target> subtargets;
  if (target.filters().empty()) {
    subtargets.push_back(target);
  } else {
    // There is an implicit AND operation between all the filters stored in the
    // target.
    std::vector<Filter> filters;
    for (const auto& filter : target.filters()) {
      filters.push_back(filter);
    }
    std::vector<Filter> dnf = LogicUtils::GetDnfTerms(CompositeFilter::Create(
        std::move(filters), CompositeFilter::Operator::And));

    for (const Filter& term : dnf) {
      core::FilterList filter_list;
      if (term.IsAFieldFilter()) {
        filter_list = filter_list.push_back(term);
      } else if (term.IsACompositeFilter()) {
        for (const auto& filter : (CompositeFilter(term)).filters()) {
          filter_list = filter_list.push_back(filter);
        }
      }
      subtargets.push_back({target.path(), target.collection_group(),
                            std::move(filter_list), target.order_bys(),
                            target.limit(), target.start_at(),
                            target.end_at()});
    }
  }
  return target_to_dnf_subtargets_[target] = subtargets;
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
