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
                                     /*has_local_mutations=*/true);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
