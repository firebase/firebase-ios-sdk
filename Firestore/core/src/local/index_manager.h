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

#ifndef FIRESTORE_CORE_SRC_LOCAL_INDEX_MANAGER_H_
#define FIRESTORE_CORE_SRC_LOCAL_INDEX_MANAGER_H_

#include <string>
#include <vector>

#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {

namespace core {
class Target;
class SortedMap;
}  // namespace core

namespace model {
class DocumentKey;
class FieldIndex;
class IndexOffset;
class ResourcePath;
}  // namespace model

namespace local {

/**
 * Represents a set of indexes that are used to execute queries efficiently.
 *
 * Currently the only index is a [collection id] => [parent path] index, used
 * to execute Collection Group queries.
 */
class IndexManager {
 public:
  /** Represents the index state as it relates to a particular target. */
  enum class IndexType {
    /** Indicates that no index could be found for serving the target. */
    NONE,
    /**
     * Indicates that only a "partial index" could be found for serving the
     * target. A partial index is one which does not have a segment for every
     * Filter/OrderBy in the target.
     */
    PARTIAL,
    /**
     * Indicates that a "full index" could be found for serving the target. A
     * full index is one which has a segment for every Filter/OrderBy in the
     * target.
     */
    FULL
  };

  virtual ~IndexManager() = default;

  /** Initializes the IndexManager. */
  virtual void Start() = 0;

  /**
   * Creates an index entry mapping the collection_id (last segment of the path)
   * to the parent path (either the containing document location or the empty
   * path for root-level collections). Index entries can be retrieved via
   * GetCollectionParents().
   *
   * NOTE: Currently we don't remove index entries. If this ends up being an
   * issue we can devise some sort of GC strategy.
   */
  virtual void AddToCollectionParentIndex(
      const model::ResourcePath& collection_path) = 0;

  /**
   * Retrieves all parent locations containing the given collection_id, as a set
   * of paths (each path being either a document location or the empty path for
   * a root-level collection).
   */
  virtual std::vector<model::ResourcePath> GetCollectionParents(
      const std::string& collection_id) = 0;

  /**
   * Adds a field path index.
   *
   * The actual entries for this index will be created and persisted in the
   * background by the SDK, and the index will be used for query execution once
   * values are persisted.
   */
  virtual void AddFieldIndex(const model::FieldIndex& index) = 0;

  /** Removes the given field index and deletes all index values. */
  virtual void DeleteFieldIndex(const model::FieldIndex& index) = 0;

  /**
   * Returns a list of field indexes that correspond to the specified collection
   * group.
   */
  virtual std::vector<model::FieldIndex> GetFieldIndexes(
      const std::string& collection_group) const = 0;

  /** Returns all configured field indexes. */
  virtual std::vector<model::FieldIndex> GetFieldIndexes() const = 0;

  /** Removes all field indexes and deletes all index values. */
  virtual void DeleteAllFieldIndexes() = 0;

  /** Creates a full matched field index which serves the given target. */
  virtual void CreateTargetIndexes(const core::Target& target) = 0;

  /**
   * Iterates over all field indexes that are used to serve the given target,
   * and returns the minimum offset of them all. Asserts that the target can be
   * served from index.
   */
  virtual model::IndexOffset GetMinOffset(const core::Target& target) = 0;

  /** Returns the minimum offset for the given collection group. */
  virtual model::IndexOffset GetMinOffset(
      const std::string& collection_group) const = 0;

  /** Returns the type of index (if any) that can be used to serve the given
   * target */
  virtual IndexType GetIndexType(const core::Target& target) = 0;

  /**
   * Returns the documents that match the given target based on the provided
   * index, or `nullopt` if the query cannot be served from an index.
   */
  virtual absl::optional<std::vector<model::DocumentKey>>
  GetDocumentsMatchingTarget(const core::Target& target) = 0;

  /**
   * Returns the next collection group to update. Returns `nullopt` if no
   * group exists.
   */
  virtual absl::optional<std::string> GetNextCollectionGroupToUpdate()
      const = 0;

  /**
   * Sets the collection group's latest read time.
   *
   * This method updates the index offset for all field indices for the
   * collection group and increments their sequence number.
   *
   * Subsequent calls to `GetNextCollectionGroupToUpdate()` will return a
   * different collection group (unless only one collection group is
   * configured).
   */
  virtual void UpdateCollectionGroup(const std::string& collection_group,
                                     model::IndexOffset offset) = 0;

  /** Updates the index entries for the provided documents. */
  virtual void UpdateIndexEntries(const model::DocumentMap& documents) = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_INDEX_MANAGER_H_
