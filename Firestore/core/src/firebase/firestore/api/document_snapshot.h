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

#include <memory>
#include <string>
#include <utility>

#import "Firestore/Source/Model/FSTFieldValue.h"

#include "Firestore/core/src/firebase/firestore/api/snapshot_metadata.h"
#include "Firestore/core/src/firebase/firestore/core/event_listener.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"

NS_ASSUME_NONNULL_BEGIN

@class FSTDocument;

namespace firebase {
namespace firestore {
namespace api {

class DocumentReference;
class Firestore;

class DocumentSnapshot {
 public:
  using Listener = std::unique_ptr<core::EventListener<DocumentSnapshot>>;

  DocumentSnapshot() = default;

  DocumentSnapshot(Firestore* firestore,
                   model::DocumentKey document_key,
                   FSTDocument* _Nullable document,
                   SnapshotMetadata metadata)
      : firestore_{firestore},
        internal_key_{std::move(document_key)},
        internal_document_{document},
        metadata_{std::move(metadata)} {
  }

  DocumentSnapshot(Firestore* firestore,
                   model::DocumentKey document_key,
                   FSTDocument* _Nullable document,
                   bool from_cache,
                   bool has_pending_writes)
      : firestore_{firestore},
        internal_key_{std::move(document_key)},
        internal_document_{document},
        metadata_{has_pending_writes, from_cache} {
  }

  size_t Hash() const;

  bool exists() const {
    return internal_document_ != nil;
  }
  FSTDocument* internal_document() const {
    return internal_document_;
  }
  std::string document_id() const;

  const SnapshotMetadata& metadata() const {
    return metadata_;
  }

  DocumentReference CreateReference() const;

  FSTObjectValue* _Nullable GetData() const;
  id _Nullable GetValue(const model::FieldPath& field_path) const;

  Firestore* firestore() const {
    return firestore_;
  }

  friend bool operator==(const DocumentSnapshot& lhs,
                         const DocumentSnapshot& rhs);

 private:
  Firestore* firestore_ = nullptr;
  model::DocumentKey internal_key_;
  FSTDocument* internal_document_ = nil;
  SnapshotMetadata metadata_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_DOCUMENT_SNAPSHOT_H_
