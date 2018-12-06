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

#include <utility>

#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace model {

Mutation::Mutation(DocumentKey&& key, Precondition&& precondition)
    : key_(std::move(key)), precondition_(std::move(precondition)) {
}

void Mutation::VerifyKeyMatches(const MaybeDocument* maybe_doc) const {
  if (maybe_doc) {
    HARD_ASSERT(maybe_doc->key() == key(),
                "Can only apply a mutation to a document with the same key");
  }
}

SnapshotVersion Mutation::GetPostMutationVersion(
    const MaybeDocument* maybe_doc) {
  if (maybe_doc && maybe_doc->type() == MaybeDocument::Type::Document) {
    return maybe_doc->version();
  } else {
    return SnapshotVersion::None();
  }
}

SetMutation::SetMutation(DocumentKey&& key,
                         FieldValue&& value,
                         Precondition&& precondition)
    : Mutation(std::move(key), std::move(precondition)),
      value_(std::move(value)) {
}

std::shared_ptr<const MaybeDocument> SetMutation::ApplyToRemoteDocument(
    const std::shared_ptr<const MaybeDocument>& maybe_doc,
    const MutationResult& mutation_result) const {
  VerifyKeyMatches(maybe_doc.get());

  HARD_ASSERT(mutation_result.transform_results() == nullptr,
              "Transform results received by SetMutation.");

  // Unlike applyToLocalView, if we're applying a mutation to a remote document
  // the server has accepted the mutation so the precondition must have held.

  const SnapshotVersion& version = mutation_result.version();
  return absl::make_unique<Document>(FieldValue(value_), key(), version,
                                     DocumentState::kCommittedMutations);
}

std::shared_ptr<const MaybeDocument> SetMutation::ApplyToLocalView(
    const std::shared_ptr<const MaybeDocument>& maybe_doc,
    const MaybeDocument*,
    const Timestamp&) const {
  VerifyKeyMatches(maybe_doc.get());

  if (!precondition().IsValidFor(maybe_doc.get())) {
    return maybe_doc;
  }

  SnapshotVersion version = GetPostMutationVersion(maybe_doc.get());
  return absl::make_unique<Document>(FieldValue(value_), key(), version,
                                     DocumentState::kLocalMutations);
}

PatchMutation::PatchMutation(DocumentKey&& key,
                             FieldValue&& value,
                             FieldMask&& mask,
                             Precondition&& precondition)
    : Mutation(std::move(key), std::move(precondition)),
      value_(std::move(value)),
      mask_(std::move(mask)) {
}

std::shared_ptr<const MaybeDocument> PatchMutation::ApplyToRemoteDocument(
    const std::shared_ptr<const MaybeDocument>& /*maybe_doc*/,
    const MutationResult& /*mutation_result*/) const {
  // TODO(rsgowman): implement
  abort();
}

std::shared_ptr<const MaybeDocument> PatchMutation::ApplyToLocalView(
    const std::shared_ptr<const MaybeDocument>& maybe_doc,
    const MaybeDocument*,
    const Timestamp&) const {
  VerifyKeyMatches(maybe_doc.get());

  if (!precondition().IsValidFor(maybe_doc.get())) {
    return maybe_doc;
  }

  SnapshotVersion version = GetPostMutationVersion(maybe_doc.get());
  FieldValue new_data = PatchDocument(maybe_doc.get());
  return absl::make_unique<Document>(std::move(new_data), key(), version,
                                     DocumentState::kLocalMutations);
}

FieldValue PatchMutation::PatchDocument(const MaybeDocument* maybe_doc) const {
  if (maybe_doc && maybe_doc->type() == MaybeDocument::Type::Document) {
    return PatchObject(static_cast<const Document*>(maybe_doc)->data());
  } else {
    return PatchObject(FieldValue::FromMap({}));
  }
}

FieldValue PatchMutation::PatchObject(FieldValue obj) const {
  HARD_ASSERT(obj.type() == FieldValue::Type::Object);
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

}  // namespace model
}  // namespace firestore
}  // namespace firebase
