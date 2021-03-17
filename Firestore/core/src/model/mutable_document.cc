/*
 * Copyright 2021 Google LLC
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

#include "Firestore/core/src/model/mutable_document.h"

#include <sstream>
#include <string>

namespace firebase {
namespace firestore {
namespace model {

/* static */
MutableDocument MutableDocument::InvalidDocument(
    const DocumentKey& document_key) {
  return {document_key, DocumentType::kInvalid, SnapshotVersion::None(),
          ObjectValue{}, DocumentState::kSynced};
}

/* static */
MutableDocument MutableDocument::FoundDocument(const DocumentKey& document_key,
                                               const SnapshotVersion& version,
                                               ObjectValue value) {
  return std::move(InvalidDocument(document_key)
                       .ConvertToFoundDocument(version, std::move(value)));
}

/* static */
MutableDocument MutableDocument::NoDocument(const DocumentKey& document_key,
                                            const SnapshotVersion& version) {
  return std::move(InvalidDocument(document_key).ConvertToNoDocument(version));
}

/* static */
MutableDocument MutableDocument::UnknownDocument(
    const DocumentKey& document_key, const SnapshotVersion& version) {
  return std::move(
      InvalidDocument(document_key).ConvertToUnknownDocument(version));
}

MutableDocument& MutableDocument::ConvertToFoundDocument(
    const SnapshotVersion& version, ObjectValue value) {
  version_ = version;
  document_type_ = DocumentType::kFoundDocument;
  value_ = std::move(value);
  document_state_ = DocumentState::kSynced;
  return *this;
}

MutableDocument& MutableDocument::ConvertToNoDocument(
    const SnapshotVersion& version) {
  version_ = version;
  document_type_ = DocumentType::kNoDocument;
  value_ = {};
  document_state_ = DocumentState::kSynced;
  return *this;
}

MutableDocument& MutableDocument::ConvertToUnknownDocument(
    const SnapshotVersion& version) {
  version_ = version;
  document_type_ = DocumentType::kUnknownDocument;
  value_ = {};
  document_state_ = DocumentState::kHasCommittedMutations;
  return *this;
}

MutableDocument& MutableDocument::SetHasCommittedMutations() {
  document_state_ = DocumentState::kHasCommittedMutations;
  return *this;
}

MutableDocument& MutableDocument::SetHasLocalMutations() {
  document_state_ = DocumentState::kHasLocalMutations;
  return *this;
}

std::string MutableDocument::ToString() const {
  std::stringstream stream;
  stream << "MutableDocument(key=" << key_ << ", type=" << document_type_
         << ", version=" << version_ << ", value=" << value_
         << ", state=" << document_state_;
  return stream.str();
}

bool operator==(const MutableDocument& lhs, const MutableDocument& rhs) {
  return lhs.key_ == rhs.key_ && lhs.document_type_ == rhs.document_type_ &&
         lhs.version_ == rhs.version_ &&
         lhs.document_state_ == rhs.document_state_ && lhs.value_ == rhs.value_;
}

std::ostream& operator<<(std::ostream& os,
                         MutableDocument::DocumentState state) {
  switch (state) {
    case MutableDocument::DocumentState::kHasCommittedMutations:
      return os << "kHasCommittedMutations";
    case MutableDocument::DocumentState::kHasLocalMutations:
      return os << "kHasLocalMutations";
    case MutableDocument::DocumentState::kSynced:
      return os << "kSynced";
  }

  UNREACHABLE();
}

std::ostream& operator<<(std::ostream& os,
                         MutableDocument::DocumentType state) {
  switch (state) {
    case MutableDocument::DocumentType::kInvalid:
      return os << "kInvalid";
    case MutableDocument::DocumentType::kFoundDocument:
      return os << "kFoundDocument";
    case MutableDocument::DocumentType::kNoDocument:
      return os << "kNoDocument";
    case MutableDocument::DocumentType::kUnknownDocument:
      return os << "kUnknownDocument";
  }

  UNREACHABLE();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
