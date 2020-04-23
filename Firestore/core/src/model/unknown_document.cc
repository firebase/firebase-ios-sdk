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

#include "Firestore/core/src/model/unknown_document.h"

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace model {

static_assert(
    sizeof(MaybeDocument) == sizeof(UnknownDocument),
    "UnknownDocument may not have additional members (everything goes in Rep)");

class UnknownDocument::Rep : public MaybeDocument::Rep {
 public:
  Rep(DocumentKey key, SnapshotVersion version)
      : MaybeDocument::Rep(Type::UnknownDocument, std::move(key), version) {
  }

  bool has_pending_writes() const override {
    // Unknown documents can only exist because of a logical inconsistency
    // between the server successfully committing a mutation and our local
    // cache believing it should not apply. We record UnknownDocuments to
    // prevent flicker after the committed mutation is removed from the queue.
    // If we ever read an UnknownDocument back, this means the cache entry for
    // that document must be dirty.
    return true;
  }

  std::string ToString() const override {
    return absl::StrCat("UnknownDocument(key=", key().ToString(),
                        ", version=", version().ToString(), ")");
  }
};

UnknownDocument::UnknownDocument(DocumentKey key, SnapshotVersion version)
    : MaybeDocument(std::make_shared<Rep>(std::move(key), version)) {
}

UnknownDocument::UnknownDocument(const MaybeDocument& document)
    : MaybeDocument(document) {
  HARD_ASSERT(type() == Type::UnknownDocument);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
