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

#include "Firestore/core/src/firebase/firestore/api/document_reference.h"

#include <memory>

#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRListenerRegistration+Internal.h"
#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Util/FSTAsyncQueryListener.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace api {

namespace objc = util::objc;
using core::ViewSnapshot;
using core::ViewSnapshotHandler;
using model::DocumentKey;
using model::Precondition;
using model::ResourcePath;
using util::MakeNSError;
using util::Status;
using util::StatusOr;
using util::StatusOrCallback;

DocumentReference::DocumentReference(model::ResourcePath path,
                                     Firestore* firestore)
    : firestore_{firestore} {
  if (path.size() % 2 != 0) {
    HARD_FAIL(
        "Invalid document reference. Document references must have an even "
        "number of segments, but %s has %s",
        path.CanonicalString(), path.size());
  }
  key_ = DocumentKey{std::move(path)};
}

size_t DocumentReference::Hash() const {
  return util::Hash(firestore_, key_);
}

const std::string& DocumentReference::document_id() const {
  return key_.path().last_segment();
}

// TODO(varconst) uncomment when core API CollectionReference is implemented.
// CollectionReference DocumentReference::Parent() const {
//   return CollectionReference{firestore_, key_.path().PopLast()};
// }

std::string DocumentReference::Path() const {
  return key_.path().CanonicalString();
}

// TODO(varconst) uncomment when core API CollectionReference is implemented.
// CollectionReference DocumentReference::GetCollectionReference(
//     const std::string& collection_path) const {
//   ResourcePath sub_path = ResourcePath::FromString(collection_path);
//   ResourcePath path = key_.path().Append(sub_path);
//   return CollectionReference{firestore_, path};
// }

void DocumentReference::SetData(std::vector<FSTMutation*>&& mutations,
                                Completion completion) {
  [firestore_->client() writeMutations:std::move(mutations)
                            completion:completion];
}

void DocumentReference::UpdateData(std::vector<FSTMutation*>&& mutations,
                                   Completion completion) {
  return [firestore_->client() writeMutations:std::move(mutations)
                                   completion:completion];
}

void DocumentReference::DeleteDocument(Completion completion) {
  FSTDeleteMutation* mutation =
      [[FSTDeleteMutation alloc] initWithKey:key_
                                precondition:Precondition::None()];
  [firestore_->client() writeMutations:{mutation} completion:completion];
}

void DocumentReference::GetDocument(
    FIRFirestoreSource source,
    StatusOrCallback<DocumentSnapshot>&& completion) {
  if (source == FIRFirestoreSourceCache) {
    [firestore_->client() getDocumentFromLocalCache:*this
                                         completion:std::move(completion)];
    return;
  }

  FSTListenOptions* options =
      [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:true
                                     includeDocumentMetadataChanges:true
                                              waitForSyncWhenOnline:true];

  // TODO(varconst): replace with a synchronization primitive that doesn't
  // require libdispatch. See
  // https://github.com/firebase/firebase-ios-sdk/blob/3ccbdcdc65c93c4621c045c3c6d15de9dcefa23f/Firestore/Source/Core/FSTFirestoreClient.mm#L161
  // for an example.
  dispatch_semaphore_t registered = dispatch_semaphore_create(0);
  auto listener_registration = std::make_shared<id<FIRListenerRegistration>>();
  StatusOrCallback<DocumentSnapshot> listener =
      [listener_registration, registered, completion,
       source](StatusOr<DocumentSnapshot> maybe_snapshot) {
        if (!maybe_snapshot.ok()) {
          completion(std::move(maybe_snapshot));
          return;
        }

        DocumentSnapshot snapshot = std::move(maybe_snapshot).ValueOrDie();

        // Remove query first before passing event to user to avoid user actions
        // affecting the now stale query.
        dispatch_semaphore_wait(registered, DISPATCH_TIME_FOREVER);
        [*listener_registration remove];

        if (!snapshot.exists() && snapshot.metadata().from_cache()) {
          // TODO(dimond): Reconsider how to raise missing documents when
          // offline. If we're online and the document doesn't exist then we
          // call the completion with a document with document.exists set to
          // false. If we're offline however, we call the completion handler
          // with an error. Two options: 1) Cache the negative response from the
          // server so we can deliver that even when you're offline.
          // 2) Actually call the completion handler with an error if the
          // document doesn't exist when you are offline.
          completion(
              Status{FirestoreErrorCode::Unavailable,
                     "Failed to get document because the client is offline."});
        } else if (snapshot.exists() && snapshot.metadata().from_cache() &&
                   source == FIRFirestoreSourceServer) {
          completion(Status{FirestoreErrorCode::Unavailable,
                            "Failed to get document from server. (However, "
                            "this document does exist in the local cache. Run "
                            "again without setting source to "
                            "FIRFirestoreSourceServer to retrieve the cached "
                            "document.)"});
        } else {
          completion(std::move(snapshot));
        }
      };

  *listener_registration = AddSnapshotListener(std::move(listener), options);
  dispatch_semaphore_signal(registered);
}

id<FIRListenerRegistration> DocumentReference::AddSnapshotListener(
    StatusOrCallback<DocumentSnapshot>&& listener, FSTListenOptions* options) {
  Firestore* firestore = firestore_;
  FSTQuery* query = [FSTQuery queryWithPath:key_.path()];
  DocumentKey key = key_;

  ViewSnapshotHandler handler =
      [key, listener, firestore](const StatusOr<ViewSnapshot>& maybe_snapshot) {
        if (!maybe_snapshot.ok()) {
          listener(maybe_snapshot.status());
          return;
        }

        const ViewSnapshot& snapshot = maybe_snapshot.ValueOrDie();
        HARD_ASSERT(snapshot.documents().count <= 1,
                    "Too many documents returned on a document query");
        FSTDocument* document = [snapshot.documents() documentForKey:key];

        bool has_pending_writes =
            document
                ? snapshot.mutated_keys().contains(key)
                // We don't raise `has_pending_writes` for deleted documents.
                : false;

        DocumentSnapshot result{firestore, std::move(key), document,
                                snapshot.from_cache(), has_pending_writes};
        listener(std::move(result));
      };

  FSTAsyncQueryListener* async_listener = [[FSTAsyncQueryListener alloc]
      initWithExecutor:firestore_->client().userExecutor
       snapshotHandler:std::move(handler)];

  FSTQueryListener* internal_listener = [firestore_->client()
            listenToQuery:query
                  options:options
      viewSnapshotHandler:[async_listener asyncSnapshotHandler]];
  return [[FSTListenerRegistration alloc] initWithClient:firestore_->client()
                                           asyncListener:async_listener
                                        internalListener:internal_listener];
}

bool operator==(const DocumentReference& lhs, const DocumentReference& rhs) {
  return lhs.firestore() == rhs.firestore() && lhs.key() == rhs.key();
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
