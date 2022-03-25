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
#include <string>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/local/index_manager.h"
#include "Firestore/core/src/local/memory_index_manager.h"
#include "Firestore/core/src/model/field_index.h"

namespace firebase {
namespace firestore {

namespace credentials {
class User;
}  // namespace credentials

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

  absl::optional<model::FieldIndex> GetFieldIndex(core::Target target) override;

  absl::optional<std::vector<model::DocumentKey>> GetDocumentsMatchingTarget(
      model::FieldIndex field_index, core::Target target) override;

  absl::optional<std::string> GetNextCollectionGroupToUpdate() override;

  void UpdateCollectionGroup(const std::string& collection_group,
                             model::IndexOffset offset) override;

  void UpdateIndexEntries(const model::DocumentMap& documents) override;

 private:
  using QueueForNextIndexToUpdate = std::priority_queue<
      model::FieldIndex*,
      std::vector<model::FieldIndex*>,
      std::function<bool(model::FieldIndex*, model::FieldIndex*)>>;

  /**
   * Stores the index in the memoized indexes table and updates
   * `next_index_to_update_` `memoized_max_index_id_` and
   * `memoized_max_sequence_number_`.
   */
  void MemoizeIndex(model::FieldIndex index);

  void DeleteFromUpdateQueue(model::FieldIndex* index);

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
