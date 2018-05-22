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
#import <GRPCClient/GRPCCall.h>

#include <map>
#include <unordered_map>

#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSyncEngine.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTDatastore.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"
#import "Firestore/Source/Util/FSTAssert.h"

#import "Firestore/Example/Tests/Core/FSTSyncEngine+Testing.h"
#import "Firestore/Example/Tests/SpecTests/FSTMockDatastore.h"

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryEvent

- (NSString *)description {
  // The Query is also included in the view, so we skip it.
  return [NSString stringWithFormat:@"<FSTQueryEvent: viewSnapshot=%@, error=%@>",
                                    self.viewSnapshot, self.error];
}

@end

@implementation FSTOutstandingWrite
@end

@interface FSTSyncEngineTestDriver ()

#pragma mark - Parts of the Firestore system that the spec tests need to control.

@property(nonatomic, strong, readonly) FSTMockDatastore *datastore;
@property(nonatomic, strong, readonly) FSTEventManager *eventManager;
@property(nonatomic, strong, readonly) FSTRemoteStore *remoteStore;
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;
@property(nonatomic, strong, readonly) FSTSyncEngine *syncEngine;
@property(nonatomic, strong, readonly) FSTDispatchQueue *dispatchQueue;

#pragma mark - Data structures for holding events sent by the watch stream.

/** A block for the FSTEventAggregator to use to report events to the test. */
@property(nonatomic, strong, readonly) void (^eventHandler)(FSTQueryEvent *);
/** The events received by our eventHandler and not yet retrieved via capturedEventsSinceLastCall */
@property(nonatomic, strong, readonly) NSMutableArray<FSTQueryEvent *> *events;
/** A dictionary for tracking the listens on queries. */
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTQuery *, FSTQueryListener *> *queryListeners;

@end

@implementation FSTSyncEngineTestDriver {
  // ivar is declared as mutable.
  std::unordered_map<User, NSMutableArray<FSTOutstandingWrite *> *, HashUser> _outstandingWrites;

  DatabaseInfo _databaseInfo;
  User _currentUser;
  EmptyCredentialsProvider _credentialProvider;
}

- (instancetype)initWithPersistence:(id<FSTPersistence>)persistence
                   garbageCollector:(id<FSTGarbageCollector>)garbageCollector {
  return [self initWithPersistence:persistence
                  garbageCollector:garbageCollector
                       initialUser:User::Unauthenticated()
                 outstandingWrites:{}];
}

- (instancetype)initWithPersistence:(id<FSTPersistence>)persistence
                   garbageCollector:(id<FSTGarbageCollector>)garbageCollector
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
    _dispatchQueue = [FSTDispatchQueue queueWith:queue];
    _localStore = [[FSTLocalStore alloc] initWithPersistence:persistence
                                            garbageCollector:garbageCollector
                                                 initialUser:initialUser];
    _datastore = [[FSTMockDatastore alloc] initWithDatabaseInfo:&_databaseInfo
                                            workerDispatchQueue:_dispatchQueue
                                                    credentials:&_credentialProvider];

    _remoteStore = [[FSTRemoteStore alloc] initWithLocalStore:_localStore
                                                    datastore:_datastore
                                          workerDispatchQueue:_dispatchQueue];

    _syncEngine = [[FSTSyncEngine alloc] initWithLocalStore:_localStore
                                                remoteStore:_remoteStore
                                                initialUser:initialUser];
    _remoteStore.syncEngine = _syncEngine;
    _eventManager = [FSTEventManager eventManagerWithSyncEngine:_syncEngine];

    _remoteStore.onlineStateDelegate = self;

    // Set up internal event tracking for the spec tests.
    NSMutableArray<FSTQueryEvent *> *events = [NSMutableArray array];
    _eventHandler = ^(FSTQueryEvent *e) {
      [events addObject:e];
    };
    _events = events;

    _queryListeners = [NSMutableDictionary dictionary];

    _expectedLimboDocuments = [NSSet set];

    _expectedActiveTargets = [NSDictionary dictionary];

    _currentUser = initialUser;
  }
  return self;
}

- (const FSTOutstandingWriteQueues &)outstandingWrites {
  return _outstandingWrites;
}

- (const User &)currentUser {
  return _currentUser;
}

- (void)applyChangedOnlineState:(FSTOnlineState)onlineState {
  [self.syncEngine applyChangedOnlineState:onlineState];
  [self.eventManager applyChangedOnlineState:onlineState];
}

- (void)start {
  [self.dispatchQueue dispatchSync:^{
    [self.localStore start];
    [self.remoteStore start];
  }];
}

- (void)validateUsage {
  // We could relax this if we found a reason to.
  FSTAssert(self.events.count == 0,
            @"You must clear all pending events by calling"
             " capturedEventsSinceLastCall before calling shutdown.");
}

- (void)shutdown {
  [self.dispatchQueue dispatchSync:^{
    [self.remoteStore shutdown];
  }];
}

- (void)validateNextWriteSent:(FSTMutation *)expectedWrite {
  NSArray<FSTMutation *> *request = [self.datastore nextSentWrite];
  // Make sure the write went through the pipe like we expected it to.
  FSTAssert(request.count == 1, @"Only single mutation requests are supported at the moment");
  FSTMutation *actualWrite = request[0];
  FSTAssert([actualWrite isEqual:expectedWrite],
            @"Mock datastore received write %@ but first outstanding mutation was %@", actualWrite,
            expectedWrite);
  LOG_DEBUG("A write was sent: %s", actualWrite);
}

- (int)sentWritesCount {
  return [self.datastore writesSent];
}

- (int)writeStreamRequestCount {
  return [self.datastore writeStreamRequestCount];
}

- (int)watchStreamRequestCount {
  return [self.datastore watchStreamRequestCount];
}

- (void)disableNetwork {
  [self.dispatchQueue dispatchSync:^{
    // Make sure to execute all writes that are currently queued. This allows us
    // to assert on the total number of requests sent before shutdown.
    [self.remoteStore fillWritePipeline];
    [self.remoteStore disableNetwork];
  }];
}

- (void)enableNetwork {
  [self.dispatchQueue dispatchSync:^{
    [self.remoteStore enableNetwork];
  }];
}

- (void)runTimer:(FSTTimerID)timerID {
  [self.dispatchQueue runDelayedCallbacksUntil:timerID];
}

- (void)changeUser:(const User &)user {
  _currentUser = user;
  [self.dispatchQueue dispatchSync:^{
    [self.syncEngine userDidChange:user];
  }];
}

- (FSTOutstandingWrite *)receiveWriteAckWithVersion:(const SnapshotVersion &)commitVersion
                                    mutationResults:
                                        (NSArray<FSTMutationResult *> *)mutationResults {
  FSTOutstandingWrite *write = [self currentOutstandingWrites].firstObject;
  [[self currentOutstandingWrites] removeObjectAtIndex:0];
  [self validateNextWriteSent:write.write];

  [self.dispatchQueue dispatchSync:^{
    [self.datastore ackWriteWithVersion:commitVersion mutationResults:mutationResults];
  }];

  return write;
}

- (FSTOutstandingWrite *)receiveWriteError:(int)errorCode
                                  userInfo:(NSDictionary<NSString *, id> *)userInfo {
  NSError *error =
      [NSError errorWithDomain:FIRFirestoreErrorDomain code:errorCode userInfo:userInfo];

  FSTOutstandingWrite *write = [self currentOutstandingWrites].firstObject;
  [self validateNextWriteSent:write.write];

  // If this is a permanent error, the mutation is not expected to be sent again so we remove it
  // from currentOutstandingWrites.
  if ([FSTDatastore isPermanentWriteError:error]) {
    [[self currentOutstandingWrites] removeObjectAtIndex:0];
  }

  LOG_DEBUG("Failing a write.");
  [self.dispatchQueue dispatchSync:^{
    [self.datastore failWriteWithError:error];
  }];

  return write;
}

- (NSArray<FSTQueryEvent *> *)capturedEventsSinceLastCall {
  NSArray<FSTQueryEvent *> *result = [self.events copy];
  [self.events removeAllObjects];
  return result;
}

- (FSTTargetID)addUserListenerWithQuery:(FSTQuery *)query {
  // TODO(dimond): Allow customizing listen options in spec tests
  // TODO(dimond): Change spec tests to verify isFromCache on snapshots
  FSTListenOptions *options = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
                                                             includeDocumentMetadataChanges:YES
                                                                      waitForSyncWhenOnline:NO];
  FSTQueryListener *listener = [[FSTQueryListener alloc]
            initWithQuery:query
                  options:options
      viewSnapshotHandler:^(FSTViewSnapshot *_Nullable snapshot, NSError *_Nullable error) {
        FSTQueryEvent *event = [[FSTQueryEvent alloc] init];
        event.query = query;
        event.viewSnapshot = snapshot;
        event.error = error;
        [self.events addObject:event];
      }];
  self.queryListeners[query] = listener;
  __block FSTTargetID targetID;
  [self.dispatchQueue dispatchSync:^{
    targetID = [self.eventManager addListener:listener];
  }];
  return targetID;
}

- (void)removeUserListenerWithQuery:(FSTQuery *)query {
  FSTQueryListener *listener = self.queryListeners[query];
  [self.queryListeners removeObjectForKey:query];
  [self.dispatchQueue dispatchSync:^{
    [self.eventManager removeListener:listener];
  }];
}

- (void)writeUserMutation:(FSTMutation *)mutation {
  FSTOutstandingWrite *write = [[FSTOutstandingWrite alloc] init];
  write.write = mutation;
  [[self currentOutstandingWrites] addObject:write];
  LOG_DEBUG("sending a user write.");
  [self.dispatchQueue dispatchSync:^{
    [self.syncEngine writeMutations:@[ mutation ]
                         completion:^(NSError *_Nullable error) {
                           LOG_DEBUG("A callback was called with error: %s", error);
                           write.done = YES;
                           write.error = error;
                         }];
  }];
}

- (void)receiveWatchChange:(FSTWatchChange *)change
           snapshotVersion:(const SnapshotVersion &)snapshot {
  [self.dispatchQueue dispatchSync:^{
    [self.datastore writeWatchChange:change snapshotVersion:snapshot];
  }];
}

- (void)receiveWatchStreamError:(int)errorCode userInfo:(NSDictionary<NSString *, id> *)userInfo {
  NSError *error =
      [NSError errorWithDomain:FIRFirestoreErrorDomain code:errorCode userInfo:userInfo];

  [self.dispatchQueue dispatchSync:^{
    [self.datastore failWatchStreamWithError:error];
    // Unlike web, stream should re-open synchronously (if we have any listeners)
    if (self.queryListeners.count > 0) {
      FSTAssert(self.datastore.isWatchStreamOpen, @"Watch stream is open");
    }
  }];
}

- (std::map<DocumentKey, TargetId>)currentLimboDocuments {
  return [self.syncEngine currentLimboDocuments];
}

- (NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)activeTargets {
  return [[self.datastore activeTargets] copy];
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
