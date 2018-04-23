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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_H_

#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * Represents a document in Firestore with a key, version, data and whether the
 * data has local mutations applied to it.
 */
class Document : public MaybeDocument {
 public:
  /**
   * Construct a document. FieldValue must be passed by rvalue.
   */
  Document(FieldValue&& data,
           DocumentKey key,
           SnapshotVersion version,
           bool has_local_mutations);

  const FieldValue& data() const {
    return data_;
  }

  absl::optional<FieldValue> field(const FieldPath& path) const {
    return data_.Get(path);
  }

  bool has_local_mutations() const {
    return has_local_mutations_;
  }

 protected:
  bool Equals(const MaybeDocument& other) const override;

 private:
  FieldValue data_;  // This is of type Object.
  bool has_local_mutations_;
};

/** Compares against another Document. */
inline bool operator==(const Document& lhs, const Document& rhs) {
  return lhs.version() == rhs.version() && lhs.key() == rhs.key() &&
         lhs.has_local_mutations() == rhs.has_local_mutations() &&
         lhs.data() == rhs.data();
}

inline bool operator!=(const Document& lhs, const Document& rhs) {
  return !(lhs == rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DOCUMENT_H_
