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

#import "Firestore/Example/Tests/SpecTests/FSTSyncEngineTestDriver.h"

#import <FirebaseFirestore/FIRFirestoreErrors.h>

#include <cstddef>
#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#import "Firestore/Example/Tests/SpecTests/FSTMockDatastore.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/api/load_bundle_task.h"
#include "Firestore/core/src/bundle/bundle_reader.h"
#include "Firestore/core/src/core/database_info.h"
#include "Firestore/core/src/core/event_manager.h"
#include "Firestore/core/src/core/listen_options.h"
#include "Firestore/core/src/core/query_listener.h"
#include "Firestore/core/src/core/sync_engine.h"
#include "Firestore/core/src/credentials/empty_credentials_provider.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/local_store.h"
#include "Firestore/core/src/local/lru_garbage_collector.h"
#include "Firestore/core/src/local/memory_lru_reference_delegate.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/query_engine.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/remote/firebase_metadata_provider_noop.h"
#include "Firestore/core/src/remote/remote_store.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/delayed_constructor.h"
#include "Firestore/core/src/util/error_apple.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_format.h"
#include "Firestore/core/src/util/to_string.h"
#include "Firestore/core/test/unit/remote/create_noop_connectivity_monitor.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/memory/memory.h"

using firebase::firestore::Error;
using firebase::firestore::api::LoadBundleTask;
using firebase::firestore::bundle::BundleReader;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::core::EventListener;
using firebase::firestore::core::EventManager;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::Query;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::SyncEngine;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::credentials::EmptyAppCheckCredentialsProvider;
using firebase::firestore::credentials::EmptyAuthCredentialsProvider;
using firebase::firestore::credentials::HashUser;
using firebase::firestore::credentials::User;
using firebase::firestore::local::LocalStore;
using firebase::firestore::local::LruDelegate;
using firebase::firestore::local::LruParams;
using firebase::firestore::local::Persistence;
using firebase::firestore::local::QueryEngine;
using firebase::firestore::local::TargetData;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::MutationResult;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::ConnectivityMonitor;
using firebase::firestore::remote::CreateFirebaseMetadataProviderNoOp;
using firebase::firestore::remote::CreateNoOpConnectivityMonitor;
using firebase::firestore::remote::FirebaseMetadataProvider;
using firebase::firestore::remote::MockDatastore;
using firebase::firestore::remote::RemoteStore;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::testutil::AsyncQueueForTesting;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::DelayedConstructor;
using firebase::firestore::util::Empty;
using firebase::firestore::util::Executor;
using firebase::firestore::util::MakeNSError;
using firebase::firestore::util::MakeNSString;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;
using firebase::firestore::util::StringFormat;
using firebase::firestore::util::TimerId;
using firebase::firestore::util::ToString;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryEvent {
  absl::optional<ViewSnapshot> _maybeViewSnapshot;
}

- (const absl::optional<ViewSnapshot> &)viewSnapshot {
  return _maybeViewSnapshot;
}

- (void)setViewSnapshot:(absl::optional<ViewSnapshot>)snapshot {
  _maybeViewSnapshot = std::move(snapshot);
}

- (NSString *)description {
  // The Query is also included in the view, so we skip it.
  std::string str = StringFormat("<FSTQueryEvent: viewSnapshot=%s, error=%s>",
                                 ToString(_maybeViewSnapshot), self.error);
  return MakeNSString(str);
}

@end

@implementation FSTOutstandingWrite {
  Mutation _write;
}

- (const model::Mutation &)write {
  return _write;
}

- (void)setWrite:(model::Mutation)write {
  _write = std::move(write);
}

@end

@interface FSTSyncEngineTestDriver ()

#pragma mark - Parts of the Firestore system that the spec tests need to control.

#pragma mark - Data structures for holding events sent by the watch stream.

/** A block for the FSTEventAggregator to use to report events to the test. */
@property(nonatomic, strong, readonly) void (^eventHandler)(FSTQueryEvent *);
/** The events received by our eventHandler and not yet retrieved via capturedEventsSinceLastCall */
@property(nonatomic, strong, readonly) NSMutableArray<FSTQueryEvent *> *events;

#pragma mark - Data structures for holding events sent by the write stream.

/** The names of the documents that the client acknowledged during the current spec test step */
@property(nonatomic, strong, readonly) NSMutableArray<NSString *> *acknowledgedDocs;
/** The names of the documents that the client rejected during the current spec test step */
@property(nonatomic, strong, readonly) NSMutableArray<NSString *> *rejectedDocs;

@end

@implementation FSTSyncEngineTestDriver {
  size_t _maxConcurrentLimboResolutions;

  std::unique_ptr<Persistence> _persistence;

  LruDelegate *_lru_delegate;

  std::unique_ptr<LocalStore> _localStore;

  std::unique_ptr<SyncEngine> _syncEngine;

  std::shared_ptr<AsyncQueue> _workerQueue;

  std::unique_ptr<RemoteStore> _remoteStore;

  std::unique_ptr<ConnectivityMonitor> _connectivityMonitor;

  std::unique_ptr<FirebaseMetadataProvider> _firebaseMetadataProvider;

  DelayedConstructor<EventManager> _eventManager;

  // Set of active targets, keyed by target Id, mapped to corresponding resume token,
  // and list of `TargetData`.
  ActiveTargetMap _expectedActiveTargets;

  // ivar is declared as mutable.
  std::unordered_map<User, NSMutableArray<FSTOutstandingWrite *> *, HashUser> _outstandingWrites;
  DocumentKeySet _expectedActiveLimboDocuments;
  DocumentKeySet _expectedEnqueuedLimboDocuments;

  /** A dictionary for tracking the listens on queries. */
  std::unordered_map<Query, std::shared_ptr<QueryListener>> _queryListeners;

  DatabaseInfo _databaseInfo;
  User _currentUser;

  std::vector<std::shared_ptr<EventListener<Empty>>> _snapshotsInSyncListeners;
  std::shared_ptr<MockDatastore> _datastore;

  QueryEngine _queryEngine;

  int _snapshotsInSyncEvents;
  int _waitForPendingWritesEvents;
}

- (instancetype)initWithPersistence:(std::unique_ptr<Persistence>)persistence
                            eagerGC:(BOOL)eagerGC
                        initialUser:(const User &)initialUser
                  outstandingWrites:(const FSTOutstandingWriteQueues &)outstandingWrites
      maxConcurrentLimboResolutions:(size_t)maxConcurrentLimboResolutions {
  if (self = [super init]) {
    _maxConcurrentLimboResolutions = maxConcurrentLimboResolutions;

    // Do a deep copy.
    for (const auto &pair : outstandingWrites) {
      _outstandingWrites[pair.first] = [pair.second mutableCopy];
    }

    _events = [NSMutableArray array];

    _databaseInfo = {DatabaseId{"test-project", "(default)"}, "persistence", "host", false};

    // Set up the sync engine and various stores.
    _workerQueue = AsyncQueueForTesting();
    _persistence = std::move(persistence);
    _localStore = absl::make_unique<LocalStore>(_persistence.get(), &_queryEngine, initialUser);
    if (!eagerGC) {
      _lru_delegate = static_cast<local::LruDelegate *>(_persistence->reference_delegate());
    }
    _connectivityMonitor = CreateNoOpConnectivityMonitor();
    _firebaseMetadataProvider = CreateFirebaseMetadataProviderNoOp();

    _datastore = std::make_shared<MockDatastore>(
        _databaseInfo, _workerQueue, std::make_shared<EmptyAuthCredentialsProvider>(),
        std::make_shared<EmptyAppCheckCredentialsProvider>(), _connectivityMonitor.get(),
        _firebaseMetadataProvider.get());
    _remoteStore = absl::make_unique<RemoteStore>(
        _localStore.get(), _datastore, _workerQueue, _connectivityMonitor.get(),
        [self](OnlineState onlineState) { _syncEngine->HandleOnlineStateChange(onlineState); });
    ;

    _syncEngine = absl::make_unique<SyncEngine>(_localStore.get(), _remoteStore.get(), initialUser,
                                                _maxConcurrentLimboResolutions);
    _remoteStore->set_sync_engine(_syncEngine.get());
    _eventManager.Init(_syncEngine.get());

    // Set up internal event tracking for the spec tests.
    NSMutableArray<FSTQueryEvent *> *events = [NSMutableArray array];
    _eventHandler = ^(FSTQueryEvent *e) {
      [events addObject:e];
    };
    _events = events;

    _currentUser = initialUser;

    _acknowledgedDocs = [NSMutableArray array];

    _rejectedDocs = [NSMutableArray array];
  }
  return self;
}

- (const FSTOutstandingWriteQueues &)outstandingWrites {
  return _outstandingWrites;
}

- (const DocumentKeySet &)expectedActiveLimboDocuments {
  return _expectedActiveLimboDocuments;
}

- (void)setExpectedActiveLimboDocuments:(DocumentKeySet)docs {
  _expectedActiveLimboDocuments = std::move(docs);
}

- (const DocumentKeySet &)expectedEnqueuedLimboDocuments {
  return _expectedEnqueuedLimboDocuments;
}

- (void)setExpectedEnqueuedLimboDocuments:(DocumentKeySet)docs {
  _expectedEnqueuedLimboDocuments = std::move(docs);
}

- (void)drainQueue {
  _workerQueue->EnqueueBlocking([] {});
}

- (const User &)currentUser {
  return _currentUser;
}

- (const DatabaseInfo &)databaseInfo {
  return _databaseInfo;
}

- (void)incrementSnapshotsInSyncEvents {
  _snapshotsInSyncEvents += 1;
}

- (void)resetSnapshotsInSyncEvents {
  _snapshotsInSyncEvents = 0;
}

- (void)incrementWaitForPendingWritesEvents {
  _waitForPendingWritesEvents += 1;
}

- (void)resetWaitForPendingWritesEvents {
  _waitForPendingWritesEvents = 0;
}

- (void)waitForPendingWrites {
  _syncEngine->RegisterPendingWritesCallback(
      [self](const Status &) { [self incrementWaitForPendingWritesEvents]; });
}

- (void)addSnapshotsInSyncListener {
  std::shared_ptr<EventListener<Empty>> eventListener = EventListener<Empty>::Create(
      [self](const StatusOr<Empty> &) { [self incrementSnapshotsInSyncEvents]; });
  _snapshotsInSyncListeners.push_back(eventListener);
  _eventManager->AddSnapshotsInSyncListener(eventListener);
}

- (void)removeSnapshotsInSyncListener {
  if (_snapshotsInSyncListeners.empty()) {
    HARD_FAIL("There must be a listener to unlisten to");
  } else {
    _eventManager->RemoveSnapshotsInSyncListener(_snapshotsInSyncListeners.back());
    _snapshotsInSyncListeners.pop_back();
  }
}

- (int)waitForPendingWritesEvents {
  return _waitForPendingWritesEvents;
}

- (int)snapshotsInSyncEvents {
  return _snapshotsInSyncEvents;
}

- (void)start {
  _workerQueue->EnqueueBlocking([&] {
    _localStore->Start();
    _remoteStore->Start();
  });
}

- (void)validateUsage {
  // We could relax this if we found a reason to.
  HARD_ASSERT(self.events.count == 0, "You must clear all pending events by calling"
                                      " capturedEventsSinceLastCall before calling shutdown.");
}

- (void)shutdown {
  _workerQueue->EnqueueBlocking([&] {
    _remoteStore->Shutdown();
    _persistence->Shutdown();
  });
}

- (void)validateNextWriteSent:(const Mutation &)expectedWrite {
  std::vector<Mutation> request = _datastore->NextSentWrite();
  // Make sure the write went through the pipe like we expected it to.
  HARD_ASSERT(request.size() == 1, "Only single mutation requests are supported at the moment");
  const Mutation &actualWrite = request[0];
  HARD_ASSERT(actualWrite == expectedWrite,
              "Mock datastore received write %s but first outstanding mutation was %s",
              actualWrite.ToString(), expectedWrite.ToString());
  LOG_DEBUG("A write was sent: %s", actualWrite.ToString());
}

- (int)sentWritesCount {
  return _datastore->WritesSent();
}

- (int)writeStreamRequestCount {
  return _datastore->write_stream_request_count();
}

- (int)watchStreamRequestCount {
  return _datastore->watch_stream_request_count();
}

- (void)disableNetwork {
  _workerQueue->EnqueueBlocking([&] {
    // Make sure to execute all writes that are currently queued. This allows us
    // to assert on the total number of requests sent before shutdown.
    _remoteStore->FillWritePipeline();
    _remoteStore->DisableNetwork();
  });
}

- (void)enableNetwork {
  _workerQueue->EnqueueBlocking([&] { _remoteStore->EnableNetwork(); });
}

- (void)runTimer:(TimerId)timerID {
  _workerQueue->RunScheduledOperationsUntil(timerID);
}

- (void)triggerLruGC:(NSNumber *)threshold {
  if (_lru_delegate != nullptr) {
    _workerQueue->EnqueueBlocking([&] {
      auto *gc = _lru_delegate->garbage_collector();
      // Change params to collect all possible garbages
      gc->set_lru_params(LruParams{/*min_bytes_threshold*/ threshold.longValue,
                                   /*percentile_to_collect*/ 100,
                                   /*maximum_sequence_numbers_to_collect*/ 1000});
      _localStore->CollectGarbage(gc);
    });
  }
}

- (void)changeUser:(const User &)user {
  _currentUser = user;
  _workerQueue->EnqueueBlocking([&] { _syncEngine->HandleCredentialChange(user); });
}

- (FSTOutstandingWrite *)receiveWriteAckWithVersion:(const SnapshotVersion &)commitVersion
                                    mutationResults:(std::vector<MutationResult>)mutationResults {
  FSTOutstandingWrite *write = [self currentOutstandingWrites].firstObject;
  [[self currentOutstandingWrites] removeObjectAtIndex:0];
  [self validateNextWriteSent:write.write];

  _workerQueue->EnqueueBlocking(
      [&] { _datastore->AckWrite(commitVersion, std::move(mutationResults)); });

  return write;
}

- (FSTOutstandingWrite *)receiveWriteError:(int)errorCode
                                  userInfo:(NSDictionary<NSString *, id> *)userInfo
                               keepInQueue:(BOOL)keepInQueue {
  Status error{static_cast<Error>(errorCode), MakeString([userInfo description])};

  FSTOutstandingWrite *write = [self currentOutstandingWrites].firstObject;
  [self validateNextWriteSent:write.write];

  // If this is a permanent error, the mutation is not expected to be sent again so we remove it
  // from currentOutstandingWrites.
  if (!keepInQueue) {
    [[self currentOutstandingWrites] removeObjectAtIndex:0];
  }

  LOG_DEBUG("Failing a write.");
  _workerQueue->EnqueueBlocking([&] { _datastore->FailWrite(error); });

  return write;
}

- (NSArray<FSTQueryEvent *> *)capturedEventsSinceLastCall {
  NSArray<FSTQueryEvent *> *result = [self.events copy];
  [self.events removeAllObjects];
  return result;
}

- (NSArray<NSString *> *)capturedAcknowledgedWritesSinceLastCall {
  NSArray<NSString *> *result = [self.acknowledgedDocs copy];
  [self.acknowledgedDocs removeAllObjects];
  return result;
}

- (NSArray<NSString *> *)capturedRejectedWritesSinceLastCall {
  NSArray<NSString *> *result = [self.rejectedDocs copy];
  [self.rejectedDocs removeAllObjects];
  return result;
}

- (TargetId)addUserListenerWithQuery:(Query)query options:(ListenOptions)options {
  // TODO(dimond): Change spec tests to verify isFromCache on snapshots
  auto listener = QueryListener::Create(
      query, options, [self, query](const StatusOr<ViewSnapshot> &maybe_snapshot) {
        FSTQueryEvent *event = [[FSTQueryEvent alloc] init];
        event.query = query;
        if (maybe_snapshot.ok()) {
          [event setViewSnapshot:maybe_snapshot.ValueOrDie()];
        } else {
          event.error = MakeNSError(maybe_snapshot.status());
        }

        [self.events addObject:event];
      });
  _queryListeners[query] = listener;
  TargetId targetID;
  _workerQueue->EnqueueBlocking([&] { targetID = _eventManager->AddQueryListener(listener); });
  return targetID;
}

- (void)removeUserListenerWithQuery:(const Query &)query {
  auto found_iter = _queryListeners.find(query);
  if (found_iter != _queryListeners.end()) {
    std::shared_ptr<QueryListener> listener = found_iter->second;
    _queryListeners.erase(found_iter);

    _workerQueue->EnqueueBlocking([&] { _eventManager->RemoveQueryListener(listener); });
  }
}

- (void)loadBundleWithReader:(std::shared_ptr<BundleReader>)reader
                        task:(std::shared_ptr<LoadBundleTask>)task {
  _workerQueue->EnqueueBlocking(
      [=] { _syncEngine->LoadBundle(std::move(reader), std::move(task)); });
}

- (void)writeUserMutation:(Mutation)mutation {
  FSTOutstandingWrite *write = [[FSTOutstandingWrite alloc] init];
  write.write = mutation;
  [[self currentOutstandingWrites] addObject:write];
  LOG_DEBUG("sending a user write.");
  _workerQueue->EnqueueBlocking([=] {
    _syncEngine->WriteMutations({mutation}, [self, write, mutation](Status error) {
      LOG_DEBUG("A callback was called with error: %s", error.error_message());
      write.done = YES;
      write.error = error.ToNSError();

      NSString *mutationKey = MakeNSString(mutation.key().ToString());
      if (!error.ok()) {
        [self.rejectedDocs addObject:mutationKey];
      } else {
        [self.acknowledgedDocs addObject:mutationKey];
      }
    });
  });
}

- (void)receiveWatchChange:(const WatchChange &)change
           snapshotVersion:(const SnapshotVersion &)snapshot {
  _workerQueue->EnqueueBlocking([&] { _datastore->WriteWatchChange(change, snapshot); });
}

- (void)receiveWatchStreamError:(int)errorCode userInfo:(NSDictionary<NSString *, id> *)userInfo {
  Status error{static_cast<Error>(errorCode), MakeString([userInfo description])};

  _workerQueue->EnqueueBlocking([&] {
    _datastore->FailWatchStream(error);
    // Unlike web, stream should re-open synchronously (if we have any listeners)
    if (!_queryListeners.empty()) {
      HARD_ASSERT(_datastore->IsWatchStreamOpen(), "Watch stream is open");
    }
  });
}

- (std::map<DocumentKey, TargetId>)activeLimboDocumentResolutions {
  return _syncEngine->GetActiveLimboDocumentResolutions();
}

- (std::vector<DocumentKey>)enqueuedLimboDocumentResolutions {
  return _syncEngine->GetEnqueuedLimboDocumentResolutions();
}

- (const std::unordered_map<TargetId, TargetData> &)activeTargets {
  return _datastore->ActiveTargets();
}

- (const ActiveTargetMap &)expectedActiveTargets {
  return _expectedActiveTargets;
}

- (void)setExpectedActiveTargets:(ActiveTargetMap)targets {
  _expectedActiveTargets = std::move(targets);
}

#pragma mark - Helper Methods

- (NSMutableArray<FSTOutstandingWrite *> *)currentOutstandingWrites {
  NSMutableArray<FSTOutstandingWrite *> *writes = _outstandingWrites[_currentUser];
  if (!writes) {
    writes = [NSMutableArray array];
    _outstandingWrites[_currentUser] = writes;
  }
  return writes;
}

@end

NS_ASSUME_NONNULL_END
