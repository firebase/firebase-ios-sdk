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

#include "Firestore/core/src/firebase/firestore/api/query_snapshot.h"

#include <utility>

#import "Firestore/Source/API/FIRDocumentChange+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace api {

namespace objc = util::objc;
using api::Firestore;
using core::ViewSnapshot;
using model::DocumentSet;

bool operator==(const QuerySnapshot& lhs, const QuerySnapshot& rhs) {
  return lhs.firestore_ == rhs.firestore_ &&
         objc::Equals(lhs.internal_query_, rhs.internal_query_) &&
         lhs.snapshot_ == rhs.snapshot_ && lhs.metadata_ == rhs.metadata_;
}

size_t QuerySnapshot::Hash() const {
  return util::Hash(firestore_, internal_query_, snapshot_, metadata_);
}

void QuerySnapshot::ForEachDocument(
    const std::function<void(DocumentSnapshot)>& callback) const {
  DocumentSet documentSet = snapshot_.documents();
  bool from_cache = metadata_.from_cache();

  for (FSTDocument* document : documentSet) {
    bool has_pending_writes = snapshot_.mutated_keys().contains(document.key);
    DocumentSnapshot snap(firestore_, document.key, document, from_cache,
                          has_pending_writes);
    callback(std::move(snap));
  }
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
