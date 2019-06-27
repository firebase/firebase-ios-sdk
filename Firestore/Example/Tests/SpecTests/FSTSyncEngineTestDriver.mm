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

#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSyncEngine.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Model/FSTMutation.h"

#import "Firestore/Example/Tests/Core/FSTSyncEngine+Testing.h"
#import "Firestore/Example/Tests/SpecTests/FSTMockDatastore.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/objc/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_store.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"
#include "absl/memory/memory.h"

namespace objc = firebase::firestore::objc;
using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::MockDatastore;
using firebase::firestore::remote::RemoteStore;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::TimerId;
using firebase::firestore::util::ExecutorLibdispatch;
using firebase::firestore::util::MakeNSError;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;
using firebase::firestore::util::StringFormat;
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
  return util::MakeNSString(str);
}

@end

@implementation FSTOutstandingWrite
@end

@interface FSTSyncEngineTestDriver ()

#pragma mark - Parts of the Firestore system that the spec tests need to control.

@property(nonatomic, strong, readonly) FSTEventManager *eventManager;
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;
@property(nonatomic, strong, readonly) FSTSyncEngine *syncEngine;
@property(nonatomic, strong, readonly) id<FSTPersistence> persistence;

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
  std::shared_ptr<AsyncQueue> _workerQueue;

  std::unique_ptr<RemoteStore> _remoteStore;

  std::unordered_map<TargetId, FSTQueryData *> _expectedActiveTargets;

  // ivar is declared as mutable.
  std::unordered_map<User, NSMutableArray<FSTOutstandingWrite *> *, HashUser> _outstandingWrites;
  DocumentKeySet _expectedLimboDocuments;

  /** A dictionary for tracking the listens on queries. */
  objc::unordered_map<FSTQuery *, std::shared_ptr<QueryListener>> _queryListeners;

  DatabaseInfo _databaseInfo;
  User _currentUser;
  EmptyCredentialsProvider _credentialProvider;

  std::shared_ptr<MockDatastore> _datastore;
}

- (instancetype)initWithPersistence:(id<FSTPersistence>)persistence {
  return [self initWithPersistence:persistence
                       initialUser:User::Unauthenticated()
                 outstandingWrites:{}];
}

- (instancetype)initWithPersistence:(id<FSTPersistence>)persistence
                        initialUser:(const User &)initialUser
                  outstandingWrites:(const FSTOutstandingWriteQueues &)outstandingWrites {
  if (self = [super init]) {
    // Do a deep copy.
    for (const auto &pair : outstandingWrites) {
      _outstandingWrites[pair.first] = [pair.second mutableCopy];
    }

    _events = [NSMutableArray array];

    _databaseInfo = {DatabaseId{"project", "database"}, "persistence", "host", false};

    // Set up the sync engine and various stores.
    dispatch_queue_t queue =
        dispatch_queue_create("sync_engine_test_driver", DISPATCH_QUEUE_SERIAL);
    _workerQueue = std::make_shared<AsyncQueue>(absl::make_unique<ExecutorLibdispatch>(queue));
    _persistence = persistence;
    _localStore = [[FSTLocalStore alloc] initWithPersistence:persistence initialUser:initialUser];

    _datastore = std::make_shared<MockDatastore>(_databaseInfo, _workerQueue, &_credentialProvider);
    _remoteStore = absl::make_unique<RemoteStore>(
        _localStore, _datastore, _workerQueue, [self](OnlineState onlineState) {
          [self.syncEngine applyChangedOnlineState:onlineState];
          [self.eventManager applyChangedOnlineState:onlineState];
        });
    ;

    _syncEngine = [[FSTSyncEngine alloc] initWithLocalStore:_localStore
                                                remoteStore:_remoteStore.get()
                                                initialUser:initialUser];
    _remoteStore->set_sync_engine(_syncEngine);
    _eventManager = [FSTEventManager eventManagerWithSyncEngine:_syncEngine];

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

- (const DocumentKeySet &)expectedLimboDocuments {
  return _expectedLimboDocuments;
}

- (void)setExpectedLimboDocuments:(DocumentKeySet)docs {
  _expectedLimboDocuments = std::move(docs);
}

- (void)drainQueue {
  _workerQueue->EnqueueBlocking([] {});
}

- (const User &)currentUser {
  return _currentUser;
}

- (void)start {
  _workerQueue->EnqueueBlocking([&] {
    [self.localStore start];
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
    [self.persistence shutdown];
  });
}

- (void)validateNextWriteSent:(FSTMutation *)expectedWrite {
  std::vector<FSTMutation *> request = _datastore->NextSentWrite();
  // Make sure the write went through the pipe like we expected it to.
  HARD_ASSERT(request.size() == 1, "Only single mutation requests are supported at the moment");
  FSTMutation *actualWrite = request[0];
  HARD_ASSERT([actualWrite isEqual:expectedWrite],
              "Mock datastore received write %s but first outstanding mutation was %s", actualWrite,
              expectedWrite);
  LOG_DEBUG("A write was sent: %s", actualWrite);
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

- (void)changeUser:(const User &)user {
  _currentUser = user;
  _workerQueue->EnqueueBlocking([&] { [self.syncEngine credentialDidChangeWithUser:user]; });
}

- (FSTOutstandingWrite *)receiveWriteAckWithVersion:(const SnapshotVersion &)commitVersion
                                    mutationResults:
                                        (std::vector<FSTMutationResult *>)mutationResults {
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
  Status error{static_cast<FirestoreErrorCode>(errorCode), MakeString([userInfo description])};

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

- (TargetId)addUserListenerWithQuery:(FSTQuery *)query {
  // TODO(dimond): Allow customizing listen options in spec tests
  // TODO(dimond): Change spec tests to verify isFromCache on snapshots
  ListenOptions options = ListenOptions::FromIncludeMetadataChanges(true);
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
  _workerQueue->EnqueueBlocking([&] { targetID = [self.eventManager addListener:listener]; });
  return targetID;
}

- (void)removeUserListenerWithQuery:(FSTQuery *)query {
  auto found_iter = _queryListeners.find(query);
  if (found_iter != _queryListeners.end()) {
    std::shared_ptr<QueryListener> listener = found_iter->second;
    _queryListeners.erase(found_iter);

    _workerQueue->EnqueueBlocking([&] { [self.eventManager removeListener:listener]; });
  }
}

- (void)writeUserMutation:(FSTMutation *)mutation {
  FSTOutstandingWrite *write = [[FSTOutstandingWrite alloc] init];
  write.write = mutation;
  [[self currentOutstandingWrites] addObject:write];
  LOG_DEBUG("sending a user write.");
  _workerQueue->EnqueueBlocking([=] {
    [self.syncEngine writeMutations:{mutation}
                         completion:^(NSError *_Nullable error) {
                           LOG_DEBUG("A callback was called with error: %s", error);
                           write.done = YES;
                           write.error = error;

                           NSString *mutationKey =
                               [NSString stringWithCString:mutation.key.ToString().c_str()
                                                  encoding:[NSString defaultCStringEncoding]];
                           if (error) {
                             [self.rejectedDocs addObject:mutationKey];
                           } else {
                             [self.acknowledgedDocs addObject:mutationKey];
                           }
                         }];
  });
}

- (void)receiveWatchChange:(const WatchChange &)change
           snapshotVersion:(const SnapshotVersion &)snapshot {
  _workerQueue->EnqueueBlocking([&] { _datastore->WriteWatchChange(change, snapshot); });
}

- (void)receiveWatchStreamError:(int)errorCode userInfo:(NSDictionary<NSString *, id> *)userInfo {
  Status error{static_cast<FirestoreErrorCode>(errorCode), MakeString([userInfo description])};

  _workerQueue->EnqueueBlocking([&] {
    _datastore->FailWatchStream(error);
    // Unlike web, stream should re-open synchronously (if we have any listeners)
    if (!_queryListeners.empty()) {
      HARD_ASSERT(_datastore->IsWatchStreamOpen(), "Watch stream is open");
    }
  });
}

- (std::map<DocumentKey, TargetId>)currentLimboDocuments {
  return [self.syncEngine currentLimboDocuments];
}

- (const std::unordered_map<TargetId, FSTQueryData *> &)activeTargets {
  return _datastore->ActiveTargets();
}

- (const std::unordered_map<TargetId, FSTQueryData *> &)expectedActiveTargets {
  return _expectedActiveTargets;
}

- (void)setExpectedActiveTargets:(const std::unordered_map<TargetId, FSTQueryData *> &)targets {
  _expectedActiveTargets = targets;
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
