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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_VIEW_SNAPSHOT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_VIEW_SNAPSHOT_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#include <string>
#include <vector>

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FSTDocument;

namespace firebase {
namespace firestore {
namespace core {

/** A change to a single document's state within a view. */
class DocumentViewChange {
 public:
  /**
   * The types of changes that can happen to a document with respect to a view.
   * NOTE: We sort document changes by their type, so the ordering of this enum
   * is significant.
   */
  enum class Type { kRemoved = 0, kAdded, kModified, kMetadata };

  DocumentViewChange() = default;

  DocumentViewChange(FSTDocument* document, Type type)
      : document_{document}, type_{type} {
  }

  FSTDocument* document() const {
    return document_;
  }
  DocumentViewChange::Type type() const {
    return type_;
  }

  std::string ToString() const;
  size_t Hash() const;

 private:
  FSTDocument* document_ = nullptr;
  Type type_{};
};

bool operator==(const DocumentViewChange& lhs, const DocumentViewChange& rhs);

/** The possible states a document can be in w.r.t syncing from local storage to
 * the backend. */
enum class SyncState { None = 0, Local, Synced };

/**
 * A set of changes to docs in a query, merging duplicate events for the same
 * doc.
 */
class DocumentViewChangeSet {
 public:
  /** Takes a new change and applies it to the set. */
  void AddChange(DocumentViewChange&& change);

  /** Returns the set of all changes tracked in this set. */
  std::vector<DocumentViewChange> GetChanges() const;

  std::string ToString() const;

 private:
  /** The set of all changes tracked so far, with redundant changes merged. */
  immutable::SortedMap<model::DocumentKey, DocumentViewChange> change_map_;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_VIEW_SNAPSHOT_H_
