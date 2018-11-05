/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_SNAPSHOT_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_SNAPSHOT_H_

#include <cstddef>
#include <vector>

#include "firebase/firestore/document_change.h"
#include "firebase/firestore/document_snapshot.h"
#include "firebase/firestore/metadata_changes.h"
#include "firebase/firestore/query.h"
#include "firebase/firestore/snapshot_metadata.h"

namespace firebase {
namespace firestore {

class Query;
class QuerySnapshotInternal;

/**
 * A QuerySnapshot contains zero or more DocumentSnapshot objects. It can be
 * iterated using a range-based for loop and its size can be inspected with
 * empty() and count().
 */
class QuerySnapshot {
 public:
  /**
   * @brief Default constructor. This creates an invalid QuerySnapshot.
   * Attempting to perform any operations on this instance will fail (and cause
   * a crash) unless a valid QuerySnapshot has been assigned to it.
   */
  QuerySnapshot();

  /**
   * @brief Copy constructor. It's totally okay (and efficient) to copy
   * QuerySnapshot instances.
   *
   * @param[in] snapshot QuerySnapshot to copy from.
   */
  QuerySnapshot(const QuerySnapshot& snapshot);

  /**
   * @brief Move constructor. Moving is an efficient operation for
   * QuerySnapshot instances.
   *
   * @param[in] snapshot QuerySnapshot to move data from.
   */
  QuerySnapshot(QuerySnapshot&& snapshot);

  virtual ~QuerySnapshot();

  /**
   * @brief Copy assignment operator. It's totally okay (and efficient) to copy
   * QuerySnapshot instances.
   *
   * @param[in] snapshot QuerySnapshot to copy from.
   *
   * @returns Reference to the destination QuerySnapshot.
   */
  QuerySnapshot& operator=(const QuerySnapshot& snapshot);

  /**
   * @brief Move assignment operator. Moving is an efficient operation for
   * QuerySnapshot instances.
   *
   * @param[in] snapshot QuerySnapshot to move data from.
   *
   * @returns Reference to the destination QuerySnapshot.
   */
  QuerySnapshot& operator=(QuerySnapshot&& snapshot);

  /**
   * @brief The query from which you get this QuerySnapshot.
   */
  virtual Query query() const;

  /**
   * @brief Metadata about this snapshot, concerning its source and if it has
   * local modifications.
   *
   * @return The metadata for this document snapshot.
   */
  virtual SnapshotMetadata metadata() const;

  /**
   * @brief The list of documents that changed since the last snapshot. If it's
   * the first snapshot, all documents will be in the list as added changes.
   *
   * Documents with changes only to their metadata will not be included.
   *
   * @return The list of document changes since the last snapshot.
   */
  virtual std::vector<DocumentChange> DocumentChanges() const;

  /**
   * @brief The list of documents that changed since the last snapshot. If it's
   * the first snapshot, all documents will be in the list as added changes.
   *
   * Documents with changes only to their metadata will not be included.
   *
   * @param[in] metadata_changes Indicates whether metadata-only changes (i.e.
   * only Query.getMetadata() changed) should be included.
   *
   * @return The list of document changes since the last snapshot.
   */
  virtual std::vector<DocumentChange> DocumentChanges(
      MetadataChanges metadata_changes) const;

  /**
   * @brief The list of documents in this QuerySnapshot in order of the query.
   *
   * @return The list of documents.
   */
  virtual std::vector<DocumentSnapshot> documents() const;

  /**
   * @brief Check the emptiness of the QuerySnapshot.
   *
   * @return True if there are no documents in the QuerySnapshot.
   */
  bool empty() const {
    return size() == 0;
  }

  /**
   * @brief Check the size of the QuerySnapshot.
   *
   * @return The number of documents in the QuerySnapshot.
   */
  virtual std::size_t size() const;

 protected:
  explicit QuerySnapshot(QuerySnapshotInternal* internal);

 private:
  friend class EventListenerInternal;
  friend class FirestoreInternal;

  QuerySnapshotInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_SNAPSHOT_H_
