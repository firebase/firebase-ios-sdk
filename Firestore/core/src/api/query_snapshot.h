/*
 * Copyright 2019 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_API_QUERY_SNAPSHOT_H_
#define FIRESTORE_CORE_SRC_API_QUERY_SNAPSHOT_H_

#include <functional>
#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/api_fwd.h"
#include "Firestore/core/src/api/document_change.h"
#include "Firestore/core/src/api/document_snapshot.h"
#include "Firestore/core/src/api/snapshot_metadata.h"
#include "Firestore/core/src/core/event_listener.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/util/exception.h"

namespace firebase {
namespace firestore {
namespace api {

static inline DocumentChange::Type DocumentChangeTypeForChange(
    const core::DocumentViewChange& change) {
  switch (change.type()) {
    case core::DocumentViewChange::Type::Added:
      return DocumentChange::Type::Added;
    case core::DocumentViewChange::Type::Modified:
    case core::DocumentViewChange::Type::Metadata:
      return DocumentChange::Type::Modified;
    case core::DocumentViewChange::Type::Removed:
      return DocumentChange::Type::Removed;
  }

  HARD_FAIL("Unknown DocumentViewChange::Type: %s", change.type());
}

/**
 * Calculates the changes in a ViewSnapshot, and returns the changes (either
 * DocumentChange or PipelineResultChange).
 */
template <typename TChange, typename TDocWrapper>
std::vector<TChange> GenerateChangesFromSnapshot(
    const core::ViewSnapshot& snapshot,
    bool include_metadata_changes,
    const std::function<TDocWrapper(const model::Document&, SnapshotMetadata)>&
        doc_factory) {
  if (include_metadata_changes && snapshot.excludes_metadata_changes()) {
    util::ThrowInvalidArgument(
        "To include metadata changes with your document "
        "changes, you must call "
        "addSnapshotListener(includeMetadataChanges:true).");
  }

  std::vector<TChange> changes;
  constexpr size_t npos = TChange::npos;  // Assumes TChange exposes npos

  if (snapshot.old_documents().empty()) {
    // Special case the first snapshot because index calculation is simple.
    model::DocumentComparator doc_comparator =
        snapshot.query_or_pipeline().Comparator();
    size_t index = 0;
    for (const core::DocumentViewChange& change : snapshot.document_changes()) {
      const model::Document& doc = change.document();
      SnapshotMetadata metadata(
          /*pending_writes=*/snapshot.mutated_keys().contains(doc->key()),
          /*from_cache=*/snapshot.from_cache());

      TDocWrapper document = doc_factory(doc, metadata);

      changes.emplace_back(TChange::Type::Added, std::move(document), npos,
                           index++);
    }

  } else {
    // Handle subsequent snapshots with incremental index tracking.
    model::DocumentSet index_tracker = snapshot.old_documents();
    for (const core::DocumentViewChange& change : snapshot.document_changes()) {
      if (!include_metadata_changes &&
          change.type() == core::DocumentViewChange::Type::Metadata) {
        continue;
      }

      const model::Document& doc = change.document();
      SnapshotMetadata metadata(
          /*pending_writes=*/snapshot.mutated_keys().contains(doc->key()),
          /*from_cache=*/snapshot.from_cache());

      TDocWrapper document = doc_factory(doc, metadata);

      size_t old_index = npos;
      size_t new_index = npos;

      if (change.type() != core::DocumentViewChange::Type::Added) {
        old_index = index_tracker.IndexOf(change.document()->key());
        index_tracker = index_tracker.erase(change.document()->key());
      }
      if (change.type() != core::DocumentViewChange::Type::Removed) {
        index_tracker = index_tracker.insert(change.document());
        new_index = index_tracker.IndexOf(change.document()->key());
      }

      auto type = static_cast<typename TChange::Type>(
          DocumentChangeTypeForChange(change));

      // A TChange object is constructed from the TDocWrapper.
      changes.emplace_back(type, std::move(document), old_index, new_index);
    }
  }
  return changes;
}

/**
 * A `QuerySnapshot` contains zero or more `DocumentSnapshot` objects.
 */
class QuerySnapshot {
 public:
  QuerySnapshot(std::shared_ptr<Firestore> firestore,
                core::Query query,
                core::ViewSnapshot&& snapshot,
                SnapshotMetadata metadata);

  size_t Hash() const;

  /**
   * Indicates whether this `QuerySnapshot` is empty (contains no documents).
   */
  bool empty() const {
    return snapshot_.documents().empty();
  }

  /** The count of documents in this `QuerySnapshot`. */
  size_t size() const {
    return snapshot_.documents().size();
  }

  const std::shared_ptr<Firestore>& firestore() const {
    return firestore_;
  }

  Query query() const;

  const core::Query& internal_query() const;

  /**
   * Metadata about this snapshot, concerning its source and if it has local
   * modifications.
   */
  const SnapshotMetadata& metadata() const {
    return metadata_;
  }

  /** Iterates over the `DocumentSnapshots` that make up this query snapshot. */
  void ForEachDocument(
      const std::function<void(DocumentSnapshot)>& callback) const;

  /**
   * Iterates over the `DocumentChanges` representing the changes between
   * the prior snapshot and this one.
   */
  void ForEachChange(bool include_metadata_changes,
                     const std::function<void(DocumentChange)>& callback) const;

  friend bool operator==(const QuerySnapshot& lhs, const QuerySnapshot& rhs);

 private:
  std::shared_ptr<Firestore> firestore_;
  core::Query internal_query_;
  core::ViewSnapshot snapshot_;
  SnapshotMetadata metadata_;
};

using QuerySnapshotListener =
    std::unique_ptr<core::EventListener<QuerySnapshot>>;

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_QUERY_SNAPSHOT_H_
