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

#import "Firestore/Source/Local/FSTLocalStore.h"

#include <memory>
#include <set>
#include <unordered_map>
#include <utility>
#include <vector>

#import "FIRTimestamp.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"
#include "Firestore/core/src/firebase/firestore/immutable/sorted_set.h"
#include "Firestore/core/src/firebase/firestore/local/local_documents_view.h"
#include "Firestore/core/src/firebase/firestore/local/local_store.h"
#include "Firestore/core/src/firebase/firestore/local/local_view_changes.h"
#include "Firestore/core/src/firebase/firestore/local/local_write_result.h"
#include "Firestore/core/src/firebase/firestore/local/mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/local/query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch_result.h"
#include "Firestore/core/src/firebase/firestore/model/patch_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"
#include "absl/memory/memory.h"
#include "absl/types/optional.h"

namespace util = firebase::firestore::util;
using firebase::Timestamp;
using firebase::firestore::auth::User;
using firebase::firestore::core::Query;
using firebase::firestore::core::TargetIdGenerator;
using firebase::firestore::local::LocalDocumentsView;
using firebase::firestore::local::LocalStore;
using firebase::firestore::local::LocalViewChanges;
using firebase::firestore::local::LocalWriteResult;
using firebase::firestore::local::LruResults;
using firebase::firestore::local::MutationQueue;
using firebase::firestore::local::Persistence;
using firebase::firestore::local::QueryCache;
using firebase::firestore::local::QueryData;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::local::ReferenceSet;
using firebase::firestore::local::RemoteDocumentCache;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::DocumentVersionMap;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::MutationBatch;
using firebase::firestore::model::MutationBatchResult;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::OptionalMaybeDocumentMap;
using firebase::firestore::model::PatchMutation;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::TargetChange;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTLocalStore {
  std::unique_ptr<LocalStore> _localStore;
}

- (instancetype)initWithPersistence:(Persistence *)persistence
                        initialUser:(const User &)initialUser {
  if (self = [super init]) {
    _localStore = absl::make_unique<LocalStore>(persistence, initialUser);
  }
  return self;
}

- (void)start {
  _localStore->Start();
}

- (MaybeDocumentMap)userDidChange:(const User &)user {
  return _localStore->HandleUserChange(user);
}

- (LocalWriteResult)locallyWriteMutations:(std::vector<Mutation> &&)mutations {
  return _localStore->WriteLocally(std::move(mutations));
}

- (MaybeDocumentMap)acknowledgeBatchWithResult:(const MutationBatchResult &)batchResult {
  return _localStore->AcknowledgeBatch(batchResult);
}

- (MaybeDocumentMap)rejectBatchID:(BatchId)batchID {
  return _localStore->RejectBatch(batchID);
}

- (ByteString)lastStreamToken {
  return _localStore->GetLastStreamToken();
}

- (void)setLastStreamToken:(const ByteString &)streamToken {
  _localStore->SetLastStreamToken(streamToken);
}

- (const SnapshotVersion &)lastRemoteSnapshotVersion {
  return _localStore->GetLastRemoteSnapshotVersion();
}

- (MaybeDocumentMap)applyRemoteEvent:(const RemoteEvent &)remoteEvent {
  return _localStore->ApplyRemoteEvent(remoteEvent);
}

- (void)notifyLocalViewChanges:(const std::vector<LocalViewChanges> &)viewChanges {
  _localStore->NotifyLocalViewChanges(viewChanges);
}

- (absl::optional<MutationBatch>)nextMutationBatchAfterBatchID:(BatchId)batchID {
  return _localStore->GetNextMutationBatch(batchID);
}

- (absl::optional<MaybeDocument>)readDocument:(const DocumentKey &)key {
  return _localStore->ReadDocument(key);
}

- (model::BatchId)getHighestUnacknowledgedBatchId {
  return _localStore->GetHighestUnacknowledgedBatchId();
}

- (QueryData)allocateQuery:(Query)query {
  return _localStore->AllocateQuery(std::move(query));
}

- (void)releaseQuery:(const Query &)query {
  _localStore->ReleaseQuery(query);
}

- (DocumentMap)executeQuery:(const Query &)query {
  return _localStore->ExecuteQuery(query);
}

- (DocumentKeySet)remoteDocumentKeysForTarget:(TargetId)targetID {
  return _localStore->GetRemoteDocumentKeys(targetID);
}

- (LruResults)collectGarbage:(local::LruGarbageCollector *)garbageCollector {
  return _localStore->CollectGarbage(garbageCollector);
}

@end

NS_ASSUME_NONNULL_END
