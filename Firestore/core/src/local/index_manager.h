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
}  // namespace model

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
  virtual ~IndexManager() = default;

  /** Initializes the IndexManager. */
  virtual void Start();

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
   * Values for this index are persisted asynchronously. The index will only be
   * used for query execution once values are persisted.
   */
  virtual void AddFieldIndex(model::FieldIndex index);

  /** Removes the given field index and deletes all index values. */
  virtual void DeleteFieldIndex(model::FieldIndex index);

  /**
   * Returns a list of field indexes that correspond to the specified collection
   * group.
   */
  virtual std::vector<model::FieldIndex> GetFieldIndexes(const std::string& collection_group);

  /** Returns all configured field indexes. */
  virtual std::vector<model::FieldIndex> GetFieldIndexes();

  /**
   * Returns an index that can be used to serve the provided target. Returns
   * `nullopt` if no index is configured.
   */
  virtual absl::optional<model::FieldIndex> GetFieldIndex(core::Target target);

  /** Returns the documents that match the given target based on the provided index. */
  virtual std::vector<model::DocumentKey> GetDocumentsMatchingTarget(model::FieldIndex fieldIndex, core::Target target);

  /**
   * Returns the next collection group to update. Returns `nullopt` if no
   * group exists.
   */
  virtual absl::optional<std::string> GetNextCollectionGroupToUpdate();

  /**
   * Sets the collection group's latest read time.
   *
   * This method updates the index offset for all field indices for the
   * collection group and increments their sequence number.
   *
   * Subsequent calls to `getNextCollectionGroupToUpdate()` will return a
   * different collection group (unless only one collection group is
   * configured).
   */
  virtual void UpdateCollectionGroup(const std::string& collection_group, model::IndexOffset offset);

  /** Updates the index entries for the provided documents. */
  virtual void UpdateIndexEntries(model::DocumentMap documents);
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_INDEX_MANAGER_H_
