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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_VIEW_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_VIEW_H_

#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"

namespace firebase {
namespace firestore {
namespace core {

/** A change to a particular document wrt to whether it is in "limbo". */
class LimboDocumentChange {
 public:
  enum class Type {
    Added,
    Removed,
  };

  static LimboDocumentChange Added(model::DocumentKey key) {
    return {Type::Added, std::move(key)};
  }

  static LimboDocumentChange Removed(model::DocumentKey key) {
    return {Type::Removed, std::move(key)};
  }

  LimboDocumentChange(Type type, model::DocumentKey key);

  Type type() const {
    return type_;
  }

  const model::DocumentKey& key() const {
    return key_;
  }

  friend bool operator==(const LimboDocumentChange& lhs,
                         const LimboDocumentChange& rhs);

 private:
  Type type_;
  model::DocumentKey key_;
};

/** The result of applying a set of doc changes to a view. */
class ViewDocumentChanges {
 public:
  ViewDocumentChanges(model::DocumentSet new_documents,
                      DocumentViewChangeSet changes,
                      model::DocumentKeySet mutated_keys,
                      bool needs_refill);

  /** The new set of docs that should be in the view. */
  const model::DocumentSet& document_set() const {
    return document_set_;
  }

  /** The diff of this these docs with the previous set of docs. */
  const core::DocumentViewChangeSet& change_set() const {
    return change_set_;
  }

  const model::DocumentKeySet& mutated_keys() const {
    return mutated_keys_;
  }

  /**
   * Whether the set of documents passed in was not sufficient to calculate the
   * new state of the view and there needs to be another pass based on the local
   * cache.
   */
  bool needs_refill() const {
    return needs_refill_;
  }

 private:
  model::DocumentSet document_set_;
  core::DocumentViewChangeSet change_set_;
  model::DocumentKeySet mutated_keys_;
  bool needs_refill_ = false;
};

/** A set of changes to a view. */
class ViewChange {
 public:
  ViewChange(absl::optional<ViewSnapshot> snapshot,
             std::vector<LimboDocumentChange> limbo_changes)
      : snapshot_(std::move(snapshot)),
        limbo_changes_(std::move(limbo_changes)) {
  }

  const absl::optional<ViewSnapshot> snapshot() const {
    return snapshot_;
  }

  const std::vector<LimboDocumentChange> limbo_changes() const {
    return limbo_changes_;
  }

 private:
  absl::optional<ViewSnapshot> snapshot_;
  std::vector<LimboDocumentChange> limbo_changes_;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_VIEW_H_
