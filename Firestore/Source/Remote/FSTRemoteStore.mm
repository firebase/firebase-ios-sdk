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

#import "Firestore/Source/Remote/FSTRemoteStore.h"

#include <cinttypes>
#include <memory>
#include <unordered_map>
#include <utility>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTTransaction.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/remote/online_state_tracker.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_store.h"
#include "Firestore/core/src/firebase/firestore/remote/stream.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::User;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::kBatchIdUnknown;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::Datastore;
using firebase::firestore::remote::WatchStream;
using firebase::firestore::remote::WriteStream;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::OnlineStateTracker;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::RemoteStore;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::remote::WatchChangeAggregator;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using util::AsyncQueue;
using util::Status;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTRemoteStore

@implementation FSTRemoteStore {
  std::unique_ptr<RemoteStore> _remoteStore;
}

- (instancetype)initWithLocalStore:(FSTLocalStore *)localStore
                         datastore:(std::shared_ptr<Datastore>)datastore
                       workerQueue:(AsyncQueue *)queue
                onlineStateHandler:(std::function<void(OnlineState)>)onlineStateHandler {
  if (self = [super init]) {
    _remoteStore = absl::make_unique<RemoteStore>(localStore, std::move(datastore), queue,
                                                  std::move(onlineStateHandler));
  }
  return self;
}

- (void)setSyncEngine:(id<FSTRemoteSyncer>)syncEngine {
  _remoteStore->set_sync_engine(syncEngine);
}

- (void)start {
  _remoteStore->Start();
}

#pragma mark Online/Offline state

- (void)enableNetwork {
  _remoteStore->EnableNetwork();
}

- (void)disableNetwork {
  _remoteStore->DisableNetwork();
}

#pragma mark Shutdown

- (void)shutdown {
  _remoteStore->Shutdown();
}

- (void)credentialDidChange {
  _remoteStore->OnCredentialChange();
}

#pragma mark Watch Stream

- (void)listenToTargetWithQueryData:(FSTQueryData *)queryData {
  _remoteStore->Listen(queryData);
}

- (void)stopListeningToTargetID:(TargetId)targetID {
  _remoteStore->StopListening(targetID);
}

#pragma mark Write Stream

/**
 * Attempts to fill our write pipeline with writes from the LocalStore.
 *
 * Called internally to bootstrap or refill the write pipeline and by SyncEngine whenever there
 * are new mutations to process.
 *
 * Starts the write stream if necessary.
 */
- (void)fillWritePipeline {
  _remoteStore->FillWritePipeline();
}

- (void)addBatchToWritePipeline:(FSTMutationBatch *)batch {
  _remoteStore->AddToWritePipeline(batch);
}

- (FSTTransaction *)transaction {
  return _remoteStore->Transaction();
}

@end

NS_ASSUME_NONNULL_END
