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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_QUERY_SNAPSHOT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_QUERY_SNAPSHOT_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <functional>
#include <utility>

#include "Firestore/core/src/firebase/firestore/api/document_change.h"
#include "Firestore/core/src/firebase/firestore/api/document_snapshot.h"
#include "Firestore/core/src/firebase/firestore/api/snapshot_metadata.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"

NS_ASSUME_NONNULL_BEGIN

@class FSTQuery;

namespace firebase {
namespace firestore {
namespace api {

/**
 * A `QuerySnapshot` contains zero or more `DocumentSnapshot` objects.
 */
class QuerySnapshot {
 public:
  QuerySnapshot(Firestore* firestore,
                FSTQuery* query,
                core::ViewSnapshot&& snapshot,
                SnapshotMetadata metadata)
      : firestore_(firestore),
        internal_query_(query),
        snapshot_(std::move(snapshot)),
        metadata_(std::move(metadata)) {
  }

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

  Firestore* firestore() const {
    return firestore_;
  }

  FSTQuery* internal_query() const {
    return internal_query_;
  }

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
  Firestore* firestore_ = nullptr;
  FSTQuery* internal_query_ = nil;
  core::ViewSnapshot snapshot_;
  SnapshotMetadata metadata_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_QUERY_SNAPSHOT_H_
