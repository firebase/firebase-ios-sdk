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

namespace firebase {
namespace firestore {
namespace model {

/* static */
MutableDocument MutableDocument::InvalidDocument(
    const firebase::firestore::model::DocumentKey& document_key) {
  return MutableDocument{document_key, DocumentType::kInvalid,
                         SnapshotVersion::None(), ObjectValue{},
                         DocumentState::kSynced};
}

/* static */
MutableDocument MutableDocument::FoundDocument(
    const firebase::firestore::model::DocumentKey& document_key,
    const firebase::firestore::model::SnapshotVersion& version,
    firebase::firestore::model::ObjectValue value) {
  return std::move(InvalidDocument(document_key)
                       .ConvertToFoundDocument(version, std::move(value)));
}

/* static */
MutableDocument MutableDocument::NoDocument(
    const firebase::firestore::model::DocumentKey& document_key,
    const firebase::firestore::model::SnapshotVersion& version) {
  return std::move(InvalidDocument(document_key).ConvertToNoDocument(version));
}

/* static */
MutableDocument MutableDocument::UnknownDocument(
    const firebase::firestore::model::DocumentKey& document_key,
    const firebase::firestore::model::SnapshotVersion& version) {
  return std::move(
      InvalidDocument(document_key).ConvertToUnknownDocument(version));
}

MutableDocument& MutableDocument::ConvertToFoundDocument(
    const firebase::firestore::model::SnapshotVersion& version,
    firebase::firestore::model::ObjectValue value) {
  version_ = version;
  document_type_ = DocumentType::kFoundDocument;
  value_ = std::move(value);
  document_state_ = DocumentState::kSynced;
  return *this;
}

MutableDocument& MutableDocument::ConvertToNoDocument(
    const firebase::firestore::model::SnapshotVersion& version) {
  version_ = version;
  document_type_ = DocumentType::kNoDocument;
  value_ = {};
  document_state_ = DocumentState::kSynced;
  return *this;
}

MutableDocument& MutableDocument::ConvertToUnknownDocument(
    const firebase::firestore::model::SnapshotVersion& version) {
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

bool operator==(const MutableDocument& lhs, const MutableDocument& rhs) {
  return lhs.key_ == rhs.key_ && lhs.document_type_ == rhs.document_type_ &&
         lhs.version_ == rhs.version_ && lhs.value_ == rhs.value_ &&
         lhs.document_state_ == rhs.document_state_;
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

std::ostream& operator<<(std::ostream& os, const MutableDocument& doc) {
  return os << "MutableDocument(key=" << doc.key_
            << ", type=" << doc.document_type_ << ", version=" << doc.version_
            << ", value=" << doc.value_ << ", state=" << doc.document_state_;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
