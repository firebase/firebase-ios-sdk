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

#include "Firestore/core/src/firebase/firestore/api/document_snapshot.h"

#import "Firestore/Source/API/FIRFirestore+Internal.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace api {

namespace objc = util::objc;
using model::DocumentKey;
using model::FieldPath;

size_t DocumentSnapshot::Hash() const {
  return util::Hash(firestore_, internal_key_, internal_document_, from_cache_,
                    has_pending_writes_);
}

FIRDocumentReference* DocumentSnapshot::CreateReference() const {
  return [FIRDocumentReference referenceWithKey:internal_key_
                                      firestore:firestore_];
}

std::string DocumentSnapshot::document_id() const {
  return internal_key_.path().last_segment();
}

FIRSnapshotMetadata* DocumentSnapshot::GetMetadata() const {
  if (!cached_metadata_) {
    cached_metadata_ = [FIRSnapshotMetadata
        snapshotMetadataWithPendingWrites:has_pending_writes_
                                fromCache:from_cache_];
  }
  return cached_metadata_;
}

FSTObjectValue* _Nullable DocumentSnapshot::GetData() const {
  return internal_document_ == nil ? nil : [internal_document_ data];
}

id _Nullable DocumentSnapshot::GetValue(const FieldPath& field_path) const {
  return [[internal_document_ data] valueForPath:field_path];
}

bool operator==(const DocumentSnapshot& lhs, const DocumentSnapshot& rhs) {
  return objc::Equals(lhs.firestore_, rhs.firestore_) &&
         lhs.internal_key_ == rhs.internal_key_ &&
         objc::Equals(lhs.internal_document_, rhs.internal_document_) &&
         lhs.from_cache_ == rhs.from_cache_ &&
         lhs.has_pending_writes_ == rhs.has_pending_writes_;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
