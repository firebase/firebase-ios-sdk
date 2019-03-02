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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_DOCUMENT_SNAPSHOT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_DOCUMENT_SNAPSHOT_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <string>
#include <utility>

#import "Firestore/Source/Model/FSTFieldValue.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRFirestore;
@class FIRSnapshotMetadata;
@class FIRDocumentReference;
@class FSTDocument;

namespace firebase {
namespace firestore {
namespace api {

class DocumentSnapshot {
 public:
  DocumentSnapshot() = default;

  DocumentSnapshot(FIRFirestore* firestore,
                   model::DocumentKey document_key,
                   FSTDocument* _Nullable document,
                   bool from_cache,
                   bool has_pending_writes)
      : firestore_{firestore},
        internal_key_{std::move(document_key)},
        internal_document_{document},
        from_cache_{from_cache},
        has_pending_writes_{has_pending_writes} {
  }

  size_t Hash() const;

  bool exists() const {
    return internal_document_ != nil;
  }
  FSTDocument* internal_document() const {
    return internal_document_;
  }
  std::string document_id() const;

  FIRDocumentReference* CreateReference() const;
  FIRSnapshotMetadata* GetMetadata() const;

  FSTObjectValue* _Nullable GetData() const;
  id _Nullable GetValue(const model::FieldPath& field_path) const;

  FIRFirestore* firestore() const {
    return firestore_;
  }

  friend bool operator==(const DocumentSnapshot& lhs,
                         const DocumentSnapshot& rhs);

 private:
  FIRFirestore* firestore_ = nil;
  model::DocumentKey internal_key_;
  FSTDocument* internal_document_ = nil;
  bool from_cache_ = false;
  bool has_pending_writes_ = false;

  mutable FIRSnapshotMetadata* cached_metadata_ = nil;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_DOCUMENT_SNAPSHOT_H_
