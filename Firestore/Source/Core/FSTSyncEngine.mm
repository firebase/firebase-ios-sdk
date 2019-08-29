/*
 * Copyright 2017 Google
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

#import "Firestore/Source/Core/FSTSyncEngine.h"

#include <map>
#include <memory>
#include <set>
#include <unordered_map>
#include <utility>
#include <vector>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/Local/FSTLocalStore.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/sync_engine.h"
#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"
#include "Firestore/core/src/firebase/firestore/core/transaction.h"
#include "Firestore/core/src/firebase/firestore/core/transaction_runner.h"
#include "Firestore/core/src/firebase/firestore/core/view.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/local/local_view_changes.h"
#include "Firestore/core/src/firebase/firestore/local/local_write_result.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/util/delayed_constructor.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/types/optional.h"

using firebase::firestore::Error;
using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;
using firebase::firestore::core::LimboDocumentChange;
using firebase::firestore::core::Query;
using firebase::firestore::core::SyncEngine;
using firebase::firestore::core::SyncEngineCallback;
using firebase::firestore::core::TargetIdGenerator;
using firebase::firestore::core::Transaction;
using firebase::firestore::core::TransactionRunner;
using firebase::firestore::core::View;
using firebase::firestore::core::ViewChange;
using firebase::firestore::core::ViewDocumentChanges;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::local::LocalViewChanges;
using firebase::firestore::local::LocalWriteResult;
using firebase::firestore::local::QueryData;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::local::ReferenceSet;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::kBatchIdUnknown;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::MutationBatchResult;
using firebase::firestore::model::NoDocument;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::remote::Datastore;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::RemoteStore;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::MakeNSError;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusCallback;

NS_ASSUME_NONNULL_BEGIN

@interface FSTSyncEngine ()

/** The local store, used to persist mutations and cached documents. */
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;

@end

@implementation FSTSyncEngine {
  std::unique_ptr<SyncEngine> _syncEngine;
}

- (instancetype)initWithLocalStore:(FSTLocalStore *)localStore
                       remoteStore:(RemoteStore *)remoteStore
                       initialUser:(const User &)initialUser {
  if (self = [super init]) {
    _syncEngine = absl::make_unique<SyncEngine>(localStore, remoteStore, initialUser);
  }
  return self;
}

- (void)setCallback:(SyncEngineCallback *)callback {
  _syncEngine->SetCallback(callback);
}

- (TargetId)listenToQuery:(Query)query {
  return _syncEngine->Listen(query);
}

- (void)stopListeningToQuery:(const Query &)query {
  _syncEngine->StopListening(query);
}

- (void)writeMutations:(std::vector<Mutation> &&)mutations
            completion:(FSTVoidErrorBlock)completion {
  _syncEngine->WriteMutations(std::move(mutations), [completion](Status status) {
    if (completion) {
      completion(status.ToNSError());
    }
  });
}

- (void)registerPendingWritesCallback:(StatusCallback)callback {
  _syncEngine->RegisterPendingWritesCallback(std::move(callback));
}

/**
 * Takes an updateCallback in which a set of reads and writes can be performed atomically. In the
 * updateCallback, user code can read and write values using a transaction object. After the
 * updateCallback, all changes will be committed. If a retryable error occurs (for example, some
 * other client has changed any of the data referenced), then the updateCallback will be called
 * again after a backoff. If the updateCallback still fails after all retries, then the transaction
 * will be rejected.
 *
 * The transaction object passed to the updateCallback contains methods for accessing documents
 * and collections. Unlike other firestore access, data accessed with the transaction will not
 * reflect local changes that have not been committed. For this reason, it is required that all
 * reads are performed before any writes. Transactions must be performed while online.
 */
- (void)transactionWithRetries:(int)retries
                   workerQueue:(const std::shared_ptr<AsyncQueue> &)workerQueue
                updateCallback:(core::TransactionUpdateCallback)updateCallback
                resultCallback:(core::TransactionResultCallback)resultCallback {
  _syncEngine->Transaction(retries, workerQueue, updateCallback, resultCallback);
}

- (void)applyRemoteEvent:(const RemoteEvent &)remoteEvent {
  _syncEngine->HandleRemoteEvent(remoteEvent);
}

- (void)applyChangedOnlineState:(OnlineState)onlineState {
  _syncEngine->HandleOnlineStateChange(onlineState);
}

- (void)rejectListenWithTargetID:(const TargetId)targetID error:(NSError *)error {
  _syncEngine->HandleRejectedListen(targetID, Status::FromNSError(error));
}

- (void)applySuccessfulWriteWithResult:(const MutationBatchResult &)batchResult {
  _syncEngine->HandleSuccessfulWrite(batchResult);
}

- (void)rejectFailedWriteWithBatchID:(BatchId)batchID error:(NSError *)error {
  _syncEngine->HandleRejectedWrite(batchID, Status::FromNSError(error));
}

// Used for testing
- (std::map<DocumentKey, TargetId>)currentLimboDocuments {
  return _syncEngine->GetCurrentLimboDocuments();
}

- (void)credentialDidChangeWithUser:(const firebase::firestore::auth::User &)user {
  _syncEngine->HandleCredentialChange(user);
}
- (DocumentKeySet)remoteKeysForTarget:(TargetId)targetId {
  return _syncEngine->GetRemoteKeys(targetId);
}

@end

NS_ASSUME_NONNULL_END
