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

#include "Firestore/core/src/firebase/firestore/model/document.h"

#include <ostream>
#include <sstream>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace model {

std::ostream& operator<<(std::ostream& os, DocumentState state) {
  switch (state) {
    case DocumentState::kCommittedMutations:
      return os << "kCommittedMutations";
    case DocumentState::kLocalMutations:
      return os << "kLocalMutations";
    case DocumentState::kSynced:
      return os << "kLocalMutations";
  }

  UNREACHABLE();
}

Document::Document(ObjectValue&& data,
                   DocumentKey key,
                   SnapshotVersion version,
                   DocumentState document_state)
    : MaybeDocument(std::move(key), std::move(version)),
      data_(std::move(data)),
      document_state_(document_state) {
  set_type(Type::Document);
}

std::string Document::ToString() const {
  std::ostringstream out;
  out << *this;
  return out.str();
}

std::ostream& operator<<(std::ostream& os, const Document& doc) {
  return os << "Document(key=" << doc.key()
            << ", version=" << doc.version().timestamp()
            << ", document_state=" << doc.document_state_
            << ", data=" << doc.data() << ")";
}

bool Document::Equals(const MaybeDocument& other) const {
  if (other.type() != Type::Document) {
    return false;
  }
  auto& other_doc = static_cast<const Document&>(other);
  return MaybeDocument::Equals(other) &&
         document_state_ == other_doc.document_state_ &&
         data_ == other_doc.data_;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
