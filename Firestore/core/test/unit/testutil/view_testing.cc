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

#include "Firestore/core/test/unit/testutil/view_testing.h"

#include <utility>

#include "Firestore/core/src/core/view.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/remote/remote_event.h"

namespace firebase {
namespace firestore {
namespace testutil {

using core::View;
using core::ViewChange;
using core::ViewSnapshot;
using model::Document;
using model::DocumentKeySet;
using model::DocumentMap;
using nanopb::ByteString;
using remote::TargetChange;

model::DocumentMap DocUpdates(const std::vector<model::Document>& docs) {
  DocumentMap updates;
  for (const Document& doc : docs) {
    updates = updates.insert(doc->key(), doc);
  }
  return updates;
}

absl::optional<ViewSnapshot> ApplyChanges(
    View* view,
    const std::vector<Document>& docs,
    const absl::optional<TargetChange>& target_change) {
  ViewChange change = view->ApplyChanges(
      view->ComputeDocumentChanges(DocUpdates(docs)), target_change);
  return change.snapshot();
}

TargetChange AckTarget(DocumentKeySet docs) {
  return {ByteString(),
          /*current=*/true,
          /*added_documents*/ std::move(docs),
          /*modified_documents*/ DocumentKeySet{},
          /*removed_documents*/ DocumentKeySet{}};
}

TargetChange AckTarget(std::initializer_list<Document> docs) {
  DocumentKeySet keys;
  for (const auto& doc : docs) {
    keys = keys.insert(doc->key());
  }
  return AckTarget(keys);
}

TargetChange MarkCurrent() {
  return {ByteString(),
          /*current=*/true,
          /*added_documents=*/DocumentKeySet{},
          /*modified_documents=*/DocumentKeySet{},
          /*removed_documents=*/DocumentKeySet{}};
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
