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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MAYBE_DOCUMENT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MAYBE_DOCUMENT_H_

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * The result of a lookup for a given path may be an existing document or a
 * tombstone that marks the path deleted.
 */
class MaybeDocument {
 public:
  enum class Type {
    Unknown,
    Document,
    NoDocument,
  };

  MaybeDocument(const DocumentKey& key, const SnapshotVersion& version);

  Type type() const {
    return type_;
  }

  const DocumentKey& key() const {
    return key_;
  }

  const SnapshotVersion& version() const {
    return version_;
  }

 protected:
  Type type_;
  DocumentKey key_;
  SnapshotVersion version_;
};

/** Compares against another MaybeDocument. */
inline bool operator<(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  return lhs.key() < rhs.key();
}

inline bool operator>(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  return lhs.key() > rhs.key();
}

inline bool operator>=(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  return lhs.key() >= rhs.key();
}

inline bool operator<=(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  return lhs.key() <= rhs.key();
}

inline bool operator!=(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  return lhs.key() != rhs.key() || lhs.type() != rhs.type();
}

inline bool operator==(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  return lhs.key() == rhs.key() && lhs.type() == rhs.type();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MAYBE_DOCUMENT_H_
