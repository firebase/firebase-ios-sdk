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

#include <functional>
#include <memory>

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
  /**
   * All the different kinds of documents, including MaybeDocument and its
   * subclasses. This is used to provide RTTI for documents. See the docstrings
   * of the subclasses for details.
   */
  enum class Type {
    // An unknown subclass of MaybeDocument. This should never happen.
    //
    // TODO(rsgowman): Since it's no longer possible to directly create
    // MaybeDocument's, we can likely remove this value entirely. But
    // investigate impact on the serializers first.
    Unknown,

    Document,
    NoDocument,
    UnknownDocument,
  };

  MaybeDocument(DocumentKey key, SnapshotVersion version);

  virtual ~MaybeDocument() {
  }

  /** The runtime type of this document. */
  Type type() const {
    return type_;
  }

  /** The key for this document. */
  const DocumentKey& key() const {
    return key_;
  }

  /**
   * Returns the version of this document if it exists or a version at which
   * this document was guaranteed to not exist.
   */
  const SnapshotVersion& version() const {
    return version_;
  }

  /**
   * Whether this document has a local mutation applied that has not yet been
   * acknowledged by Watch.
   */
  virtual bool HasPendingWrites() const = 0;

 protected:
  // Only allow subclass to set their types.
  void set_type(Type type) {
    type_ = type;
  }

  virtual bool Equals(const MaybeDocument& other) const;

  friend bool operator==(const MaybeDocument& lhs, const MaybeDocument& rhs);

 private:
  Type type_ = Type::Unknown;
  DocumentKey key_;
  SnapshotVersion version_;
};

inline bool operator==(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  return lhs.Equals(rhs);
}

inline bool operator!=(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  return !(lhs == rhs);
}

/** Compares against another MaybeDocument by keys only. */
struct DocumentKeyComparator : public std::less<MaybeDocument> {
  bool operator()(const MaybeDocument& lhs, const MaybeDocument& rhs) const {
    return lhs.key() < rhs.key();
  }
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MAYBE_DOCUMENT_H_
