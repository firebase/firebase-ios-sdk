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

#include "Firestore/core/src/firebase/firestore/model/mutation.h"

#include <cstdlib>
#include <utility>

#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace model {

Mutation::Mutation(DocumentKey&& key, Precondition&& precondition)
    : key_(std::move(key)), precondition_(std::move(precondition)) {
}

void Mutation::VerifyKeyMatches(
    const absl::optional<MaybeDocument>& maybe_doc) const {
  if (maybe_doc) {
    HARD_ASSERT(maybe_doc->key() == key(),
                "Can only apply a mutation to a document with the same key");
  }
}

SnapshotVersion Mutation::GetPostMutationVersion(
    const absl::optional<MaybeDocument>& maybe_doc) {
  if (maybe_doc && maybe_doc->type() == MaybeDocument::Type::Document) {
    return maybe_doc->version();
  } else {
    return SnapshotVersion::None();
  }
}

bool Mutation::equal_to(const Mutation& other) const {
  return key_ == other.key_ && precondition_ == other.precondition_ &&
         type() == other.type();
}

SetMutation::SetMutation(DocumentKey&& key,
                         ObjectValue&& value,
                         Precondition&& precondition)
    : Mutation(std::move(key), std::move(precondition)),
      value_(std::move(value)) {
}

MaybeDocument SetMutation::ApplyToRemoteDocument(
    const absl::optional<MaybeDocument>& maybe_doc,
    const MutationResult& mutation_result) const {
  VerifyKeyMatches(maybe_doc);

  HARD_ASSERT(mutation_result.transform_results() == nullptr,
              "Transform results received by SetMutation.");

  // Unlike applyToLocalView, if we're applying a mutation to a remote document
  // the server has accepted the mutation so the precondition must have held.

  const SnapshotVersion& version = mutation_result.version();
  return Document(value_, key(), version, DocumentState::kCommittedMutations);
}

absl::optional<MaybeDocument> SetMutation::ApplyToLocalView(
    const absl::optional<MaybeDocument>& maybe_doc,
    const absl::optional<MaybeDocument>&,
    const Timestamp&) const {
  VerifyKeyMatches(maybe_doc);

  if (!precondition().IsValidFor(maybe_doc)) {
    return maybe_doc;
  }

  SnapshotVersion version = GetPostMutationVersion(maybe_doc);
  return Document(value_, key(), version, DocumentState::kLocalMutations);
}

bool SetMutation::equal_to(const Mutation& other) const {
  if (!Mutation::equal_to(other)) return false;
  return value_ == static_cast<const SetMutation&>(other).value_;
}

PatchMutation::PatchMutation(DocumentKey&& key,
                             ObjectValue&& value,
                             FieldMask&& mask,
                             Precondition&& precondition)
    : Mutation(std::move(key), std::move(precondition)),
      value_(std::move(value)),
      mask_(std::move(mask)) {
}

MaybeDocument PatchMutation::ApplyToRemoteDocument(
    const absl::optional<MaybeDocument>& maybe_doc,
    const MutationResult& mutation_result) const {
  VerifyKeyMatches(maybe_doc);
  HARD_ASSERT(mutation_result.transform_results() == nullptr,
              "Transform results received by PatchMutation.");

  if (!precondition().IsValidFor(maybe_doc)) {
    // Since the mutation was not rejected, we know that the precondition
    // matched on the backend. We therefore must not have the expected version
    // of the document in our cache and return an UnknownDocument with the known
    // updateTime.

    // TODO(rsgowman): heldwriteacks: Implement. Like this (once UnknownDocument
    // is ported):
    // return absl::make_unique<UnknownDocument>(key(),
    // mutation_result.version());

    abort();
  }

  const SnapshotVersion& version = mutation_result.version();
  ObjectValue new_data = PatchDocument(maybe_doc);
  return Document(std::move(new_data), key(), version,
                  DocumentState::kCommittedMutations);
}

absl::optional<MaybeDocument> PatchMutation::ApplyToLocalView(
    const absl::optional<MaybeDocument>& maybe_doc,
    const absl::optional<MaybeDocument>&,
    const Timestamp&) const {
  VerifyKeyMatches(maybe_doc);

  if (!precondition().IsValidFor(maybe_doc)) {
    return maybe_doc;
  }

  SnapshotVersion version = GetPostMutationVersion(maybe_doc);
  ObjectValue new_data = PatchDocument(maybe_doc);
  return Document(std::move(new_data), key(), version,
                  DocumentState::kLocalMutations);
}

ObjectValue PatchMutation::PatchDocument(
    const absl::optional<MaybeDocument>& maybe_doc) const {
  if (maybe_doc && maybe_doc->type() == MaybeDocument::Type::Document) {
    return PatchObject(Document(*maybe_doc).data());
  } else {
    return PatchObject(ObjectValue::Empty());
  }
}

ObjectValue PatchMutation::PatchObject(ObjectValue obj) const {
  for (const FieldPath& path : mask_) {
    if (!path.empty()) {
      absl::optional<FieldValue> new_value = value_.Get(path);
      if (!new_value) {
        obj = obj.Delete(path);
      } else {
        obj = obj.Set(path, *new_value);
      }
    }
  }
  return obj;
}

bool PatchMutation::equal_to(const Mutation& other) const {
  if (!Mutation::equal_to(other)) return false;
  const PatchMutation& patch_other = static_cast<const PatchMutation&>(other);
  return value_ == patch_other.value_ && mask_ == patch_other.mask_;
}

DeleteMutation::DeleteMutation(DocumentKey&& key, Precondition&& precondition)
    : Mutation(std::move(key), std::move(precondition)) {
}

MaybeDocument DeleteMutation::ApplyToRemoteDocument(
    const absl::optional<MaybeDocument>& /*maybe_doc*/,
    const MutationResult& /*mutation_result*/) const {
  // TODO(rsgowman): Implement.
  abort();
}

absl::optional<MaybeDocument> DeleteMutation::ApplyToLocalView(
    const absl::optional<MaybeDocument>& maybe_doc,
    const absl::optional<MaybeDocument>&,
    const Timestamp&) const {
  VerifyKeyMatches(maybe_doc);

  if (!precondition().IsValidFor(maybe_doc)) {
    return maybe_doc;
  }

  return NoDocument(key(), SnapshotVersion::None(),
                    /* has_committed_mutations= */ false);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
