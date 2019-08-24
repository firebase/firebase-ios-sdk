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

#include "Firestore/core/src/firebase/firestore/core/view.h"

#include <utility>

namespace firebase {
namespace firestore {
namespace core {

// MARK: - LimboDocumentChange

LimboDocumentChange::LimboDocumentChange(
    firebase::firestore::core::LimboDocumentChange::Type type,
    firebase::firestore::model::DocumentKey key)
    : type_(type), key_(std::move(key)) {
}

bool operator==(const LimboDocumentChange& lhs,
                const LimboDocumentChange& rhs) {
  return lhs.type() == rhs.type() && lhs.key() == rhs.key();
}

// MARK: - ViewDocumentChanges

ViewDocumentChanges::ViewDocumentChanges(model::DocumentSet new_documents,
                                         DocumentViewChangeSet changes,
                                         model::DocumentKeySet mutated_keys,
                                         bool needs_refill)
    : document_set_(std::move(new_documents)),
      change_set_(std::move(changes)),
      mutated_keys_(std::move(mutated_keys)),
      needs_refill_(needs_refill) {
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
