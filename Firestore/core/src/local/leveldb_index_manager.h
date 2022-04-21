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

#ifndef FIRESTORE_CORE_SRC_LOCAL_LEVELDB_INDEX_MANAGER_H_
#define FIRESTORE_CORE_SRC_LOCAL_LEVELDB_INDEX_MANAGER_H_

#include <queue>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/local/index_manager.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/memory_index_manager.h"
#include "Firestore/core/src/model/field_index.h"

namespace firebase {
namespace firestore {

namespace credentials {
class User;
}  // namespace credentials

namespace index {
class IndexEntry;
}  // namespace index

namespace local {

class LevelDbPersistence;
class LocalSerializer;

/** A persisted implementation of IndexManager. */
class LevelDbIndexManager : public IndexManager {
 public:
  explicit LevelDbIndexManager(const credentials::User& user,
                               LevelDbPersistence* db,
                               LocalSerializer* serializer);

  void Start() override;

  void AddToCollectionParentIndex(
      const model::ResourcePath& collection_path) override;

  std::vector<model::ResourcePath> GetCollectionParents(
      const std::string& collection_id) override;

  void AddFieldIndex(const model::FieldIndex& index) override;

  void DeleteFieldIndex(const model::FieldIndex& index) override;

  std::vector<model::FieldIndex> GetFieldIndexes(
      const std::string& collection_group) override;

  std::vector<model::FieldIndex> GetFieldIndexes() override;

  absl::optional<model::FieldIndex> GetFieldIndex(
      const core::Target& target) override;

  absl::optional<std::vector<model::DocumentKey>> GetDocumentsMatchingTarget(
      const core::Target& target) override;

  absl::optional<std::string> GetNextCollectionGroupToUpdate() override;

  void UpdateCollectionGroup(const std::string& collection_group,
                             model::IndexOffset offset) override;

  void UpdateIndexEntries(const model::DocumentMap& documents) override;

 private:
  using QueueForNextIndexToUpdate = std::priority_queue<
      model::FieldIndex*,
      std::vector<model::FieldIndex*>,
      std::function<bool(model::FieldIndex*, model::FieldIndex*)>>;

  // Convenient struct to hold two LevelDb keys as a range in LevelDb.
  struct IndexRange {
    std::string lower;
    std::string upper;
  };

  /**
   * Stores the index in the memoized indexes table and updates
   * `next_index_to_update_` `memoized_max_index_id_` and
   * `memoized_max_sequence_number_`.
   */
  void MemoizeIndex(model::FieldIndex index);

  void DeleteFromUpdateQueue(model::FieldIndex* index);

  std::set<index::IndexEntry> GetExistingIndexEntries(
      const model::DocumentKey& key, const model::FieldIndex& index);

  /** Creates the index entries for the given document. */
  std::set<index::IndexEntry> ComputeIndexEntries(
      const model::Document& document, const model::FieldIndex& index);

  /**
   * Updates the index entries for the provided document by deleting entries
   * that are no longer referenced in `new_entries` and adding all newly added
   * entries.
   */
  void UpdateEntries(const model::Document& document,
                     const model::FieldIndex& index,
                     const std::set<index::IndexEntry>& existing_entries,
                     const std::set<index::IndexEntry>& new_entries);

  void AddIndexEntry(const model::Document& document,
                     const model::FieldIndex& index,
                     const index::IndexEntry& entry);

  void DeleteIndexEntry(const model::Document& document,
                        const model::FieldIndex& index,
                        const index::IndexEntry& entry);

  /**
   * Returns the byte encoded form of the directional values in the field index.
   * Returns `nullopt` if the document does not have all fields specified in the
   * index.
   */
  absl::optional<std::string> EncodeDirectionalElements(
      const model::FieldIndex& index, const model::Document& document);

  /** Encodes a single value to the ascending index format. */
  std::string EncodeSingleElement(const _google_firestore_v1_Value& value);

  /**
   * Returns an encoded form of the document key that sorts based on the key
   * ordering of the field index.
   */
  std::string EncodedDirectionalKey(const model::FieldIndex& index,
                                    const model::DocumentKey& key);

  std::vector<core::Target> GetSubTargets(const core::Target& target);

  /**
   * Encodes the given bounds according to the specification in `target`. For IN
   * queries, a list of possible values is returned.
   */
  std::vector<std::string> EncodeBound(
      const model::FieldIndex& index,
      const core::Target& target,
      const core::IndexBoundValues& bound_values);

  /**
   * Encodes the given field values according to the specification in `target`.
   * For IN queries, a list of possible values is returned.
   */
  std::vector<std::string> EncodeValues(const model::FieldIndex& index,
                                        const core::Target& target,
                                        core::IndexedValues values);

  /**
   * Constructs a vector of LevelDb key ranges that unions all bounds.
   *
   * These ranges represent the sections in the index entry table that contain
   * the given bounds.
   */
  std::vector<IndexRange> GenerateIndexRanges(
      int32_t index_id,
      core::IndexedValues array_values,
      const std::vector<std::string>& lower_bounds,
      bool lower_bounds_inclusive,
      const std::vector<std::string>& upper_bounds,
      bool upper_bounds_inclusive,
      std::vector<std::string> not_in_values);

  /**
   * Returns a new set of LeveDb ranges that splits the existing range and
   * excludes any values that match the `not_in_values` from these ranges. As an
   * example,
   * '[foo > 2 && foo != 3]` becomes  `[foo > 2 && < 3, foo > 3]`.
   */
  std::vector<IndexRange> CreateRange(
      const index::IndexEntry& lower_bound,
      const index::IndexEntry& upper_bound,
      std::vector<index::IndexEntry> not_in_bounds) const;

  // The LevelDbIndexManager is owned by LevelDbPersistence.
  LevelDbPersistence* db_;

  /**
   * An in-memory copy of the index entries we've already written since the SDK
   * launched. Used to avoid re-writing the same entry repeatedly.
   *
   * This is *NOT* a complete cache of what's in persistence and so can never
   * be used to satisfy reads.
   */
  MemoryCollectionParentIndex collection_parents_cache_;

  /**
   * An in-memory map from collection group to a map of indexes associated with
   * the collection groups.
   *
   * The nested map is an index_id to FieldIndex map.
   */
  std::unordered_map<std::string,
                     std::unordered_map<int32_t, model::FieldIndex>>
      memoized_indexes_;

  QueueForNextIndexToUpdate next_index_to_update_;
  int32_t memoized_max_index_id_ = -1;
  int64_t memoized_max_sequence_number_ = -1;

  /* Owned by LevelDbPersistence. */
  LocalSerializer* serializer_ = nullptr;

  bool started_ = false;

  std::string uid_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_LEVELDB_INDEX_MANAGER_H_
