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

#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"

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

}  // namespace model
}  // namespace firestore
}  // namespace firebase
