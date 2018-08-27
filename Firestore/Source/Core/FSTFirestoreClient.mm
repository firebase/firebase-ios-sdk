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

#import "Firestore/Source/Core/FSTFirestoreClient.h"

#include <future>  // NOLINT(build/c++11)
#include <memory>
#include <utility>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSyncEngine.h"
#import "Firestore/Source/Core/FSTTransaction.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Remote/FSTDatastore.h"
#import "Firestore/Source/Remote/FSTRemoteStore.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::User;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::OnlineState;
using firebase::firestore::util::Path;
using firebase::firestore::util::Status;
using firebase::firestore::util::internal::Executor;

NS_ASSUME_NONNULL_BEGIN

@interface FSTFirestoreClient () {
  DatabaseInfo _databaseInfo;
}

- (instancetype)initWithDatabaseInfo:(const DatabaseInfo &)databaseInfo
                      usePersistence:(BOOL)usePersistence
                 credentialsProvider:
                     (CredentialsProvider *)credentialsProvider  // no passing ownership
                        userExecutor:(std::unique_ptr<Executor>)userExecutor
                 workerDispatchQueue:(FSTDispatchQueue *)queue NS_DESIGNATED_INITIALIZER;

@property(nonatomic, assign, readonly) const DatabaseInfo *databaseInfo;
@property(nonatomic, strong, readonly) FSTEventManager *eventManager;
@property(nonatomic, strong, readonly) id<FSTPersistence> persistence;
@property(nonatomic, strong, readonly) FSTSyncEngine *syncEngine;
@property(nonatomic, strong, readonly) FSTRemoteStore *remoteStore;
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;

/**
 * Dispatch queue responsible for all of our internal processing. When we get incoming work from
 * the user (via public API) or the network (incoming GRPC messages), we should always dispatch
 * onto this queue. This ensures our internal data structures are never accessed from multiple
 * threads simultaneously.
 */
@property(nonatomic, strong, readonly) FSTDispatchQueue *workerDispatchQueue;

// Does not own the CredentialsProvider instance.
@property(nonatomic, assign, readonly) CredentialsProvider *credentialsProvider;

@end

@implementation FSTFirestoreClient {
  std::unique_ptr<Executor> _userExecutor;
}

- (Executor *)userExecutor {
  return _userExecutor.get();
}

+ (instancetype)clientWithDatabaseInfo:(const DatabaseInfo &)databaseInfo
                        usePersistence:(BOOL)usePersistence
                   credentialsProvider:
                       (CredentialsProvider *)credentialsProvider  // no passing ownership
                          userExecutor:(std::unique_ptr<Executor>)userExecutor
                   workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue {
  return [[FSTFirestoreClient alloc] initWithDatabaseInfo:databaseInfo
                                           usePersistence:usePersistence
                                      credentialsProvider:credentialsProvider
                                             userExecutor:std::move(userExecutor)
                                      workerDispatchQueue:workerDispatchQueue];
}

- (instancetype)initWithDatabaseInfo:(const DatabaseInfo &)databaseInfo
                      usePersistence:(BOOL)usePersistence
                 credentialsProvider:
                     (CredentialsProvider *)credentialsProvider  // no passing ownership
                        userExecutor:(std::unique_ptr<Executor>)userExecutor
                 workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue {
  if (self = [super init]) {
    _databaseInfo = databaseInfo;
    _credentialsProvider = credentialsProvider;
    _userExecutor = std::move(userExecutor);
    _workerDispatchQueue = workerDispatchQueue;

    auto userPromise = std::make_shared<std::promise<User>>();

    __weak typeof(self) weakSelf = self;
    auto credentialChangeListener = [initialized = false, userPromise, weakSelf,
                                     workerDispatchQueue](User user) mutable {
      typeof(self) strongSelf = weakSelf;
      if (!strongSelf) return;

      if (!initialized) {
        initialized = true;
        userPromise->set_value(user);
      } else {
        [workerDispatchQueue dispatchAsync:^{
          [strongSelf credentialDidChangeWithUser:user];
        }];
      }
    };

    _credentialsProvider->SetCredentialChangeListener(credentialChangeListener);

    // Defer initialization until we get the current user from the credentialChangeListener. This is
    // guaranteed to be synchronously dispatched onto our worker queue, so we will be initialized
    // before any subsequently queued work runs.
    [_workerDispatchQueue dispatchAsync:^{
      User user = userPromise->get_future().get();
      [self initializeWithUser:user usePersistence:usePersistence];
    }];
  }
  return self;
}

- (void)initializeWithUser:(const User &)user usePersistence:(BOOL)usePersistence {
  // Do all of our initialization on our own dispatch queue.
  [self.workerDispatchQueue verifyIsCurrentQueue];
  LOG_DEBUG("Initializing. Current user: %s", user.uid());

  // Note: The initialization work must all be synchronous (we can't dispatch more work) since
  // external write/listen operations could get queued to run before that subsequent work
  // completes.
  if (usePersistence) {
    Path dir = [FSTLevelDB storageDirectoryForDatabaseInfo:*self.databaseInfo
                                        documentsDirectory:[FSTLevelDB documentsDirectory]];

    FSTSerializerBeta *remoteSerializer =
        [[FSTSerializerBeta alloc] initWithDatabaseID:&self.databaseInfo->database_id()];
    FSTLocalSerializer *serializer =
        [[FSTLocalSerializer alloc] initWithRemoteSerializer:remoteSerializer];

    _persistence = [[FSTLevelDB alloc] initWithDirectory:std::move(dir) serializer:serializer];
  } else {
    _persistence = [FSTMemoryPersistence persistenceWithEagerGC];
  }

  Status status = [_persistence start];
  if (!status.ok()) {
    // If local storage fails to start then just throw up our hands: the error is unrecoverable.
    // There's nothing an end-user can do and nearly all failures indicate the developer is doing
    // something grossly wrong so we should stop them cold in their tracks with a failure they
    // can't ignore.
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to open DB: %s", status.ToString().c_str()];
  }

  _localStore = [[FSTLocalStore alloc] initWithPersistence:_persistence initialUser:user];

  FSTDatastore *datastore = [FSTDatastore datastoreWithDatabase:self.databaseInfo
                                            workerDispatchQueue:self.workerDispatchQueue
                                                    credentials:_credentialsProvider];

  _remoteStore = [[FSTRemoteStore alloc] initWithLocalStore:_localStore
                                                  datastore:datastore
                                        workerDispatchQueue:self.workerDispatchQueue];

  _syncEngine = [[FSTSyncEngine alloc] initWithLocalStore:_localStore
                                              remoteStore:_remoteStore
                                              initialUser:user];

  _eventManager = [FSTEventManager eventManagerWithSyncEngine:_syncEngine];

  // Setup wiring for remote store.
  _remoteStore.syncEngine = _syncEngine;

  _remoteStore.onlineStateDelegate = self;

  // NOTE: RemoteStore depends on LocalStore (for persisting stream tokens, refilling mutation
  // queue, etc.) so must be started after LocalStore.
  [_localStore start];
  [_remoteStore start];
}

- (void)credentialDidChangeWithUser:(const User &)user {
  [self.workerDispatchQueue verifyIsCurrentQueue];

  LOG_DEBUG("Credential Changed. Current user: %s", user.uid());
  [self.syncEngine credentialDidChangeWithUser:user];
}

- (void)applyChangedOnlineState:(OnlineState)onlineState {
  [self.syncEngine applyChangedOnlineState:onlineState];
  [self.eventManager applyChangedOnlineState:onlineState];
}

- (void)disableNetworkWithCompletion:(nullable FSTVoidErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    [self.remoteStore disableNetwork];
    if (completion) {
      self->_userExecutor->Execute([=] { completion(nil); });
    }
  }];
}

- (void)enableNetworkWithCompletion:(nullable FSTVoidErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    [self.remoteStore enableNetwork];
    if (completion) {
      self->_userExecutor->Execute([=] { completion(nil); });
    }
  }];
}

- (void)shutdownWithCompletion:(nullable FSTVoidErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    self->_credentialsProvider->SetCredentialChangeListener(nullptr);

    [self.remoteStore shutdown];
    [self.persistence shutdown];
    if (completion) {
      self->_userExecutor->Execute([=] { completion(nil); });
    }
  }];
}

- (FSTQueryListener *)listenToQuery:(FSTQuery *)query
                            options:(FSTListenOptions *)options
                viewSnapshotHandler:(FSTViewSnapshotHandler)viewSnapshotHandler {
  FSTQueryListener *listener = [[FSTQueryListener alloc] initWithQuery:query
                                                               options:options
                                                   viewSnapshotHandler:viewSnapshotHandler];

  [self.workerDispatchQueue dispatchAsync:^{
    [self.eventManager addListener:listener];
  }];

  return listener;
}

- (void)removeListener:(FSTQueryListener *)listener {
  [self.workerDispatchQueue dispatchAsync:^{
    [self.eventManager removeListener:listener];
  }];
}

- (void)getDocumentFromLocalCache:(FIRDocumentReference *)doc
                       completion:(void (^)(FIRDocumentSnapshot *_Nullable document,
                                            NSError *_Nullable error))completion {
  [self.workerDispatchQueue dispatchAsync:^{
    FSTMaybeDocument *maybeDoc = [self.localStore readDocument:doc.key];
    FIRDocumentSnapshot *_Nullable result = nil;
    NSError *_Nullable error = nil;
    if (maybeDoc) {
      FSTDocument *_Nullable document =
          ([maybeDoc isKindOfClass:[FSTDocument class]]) ? (FSTDocument *)maybeDoc : nil;
      result = [FIRDocumentSnapshot snapshotWithFirestore:doc.firestore
                                              documentKey:doc.key
                                                 document:document
                                                fromCache:YES];
    } else {
      error = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                  code:FIRFirestoreErrorCodeUnavailable
                              userInfo:@{
                                NSLocalizedDescriptionKey :
                                    @"Failed to get document from cache. (However, this document "
                                    @"may exist on the server. Run again without setting source to "
                                    @"FIRFirestoreSourceCache to attempt to retrieve the document "
                                    @"from the server.)",
                              }];
    }

    if (completion) {
      self->_userExecutor->Execute([=] { completion(result, error); });
    }
  }];
}

- (void)getDocumentsFromLocalCache:(FIRQuery *)query
                        completion:(void (^)(FIRQuerySnapshot *_Nullable query,
                                             NSError *_Nullable error))completion {
  [self.workerDispatchQueue dispatchAsync:^{
    FSTDocumentDictionary *docs = [self.localStore executeQuery:query.query];

    FSTView *view = [[FSTView alloc] initWithQuery:query.query remoteDocuments:DocumentKeySet{}];
    FSTViewDocumentChanges *viewDocChanges = [view computeChangesWithDocuments:docs];
    FSTViewChange *viewChange = [view applyChangesToDocuments:viewDocChanges];
    HARD_ASSERT(viewChange.limboChanges.count == 0,
                "View returned limbo documents during local-only query execution.");

    FSTViewSnapshot *snapshot = viewChange.snapshot;
    FIRSnapshotMetadata *metadata =
        [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:snapshot.hasPendingWrites
                                                     fromCache:snapshot.fromCache];

    FIRQuerySnapshot *result = [FIRQuerySnapshot snapshotWithFirestore:query.firestore
                                                         originalQuery:query.query
                                                              snapshot:snapshot
                                                              metadata:metadata];

    if (completion) {
      self->_userExecutor->Execute([=] { completion(result, nil); });
    }
  }];
}

- (void)writeMutations:(NSArray<FSTMutation *> *)mutations
            completion:(nullable FSTVoidErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    if (mutations.count == 0) {
      if (completion) {
        self->_userExecutor->Execute([=] { completion(nil); });
      }
    } else {
      [self.syncEngine writeMutations:mutations
                           completion:^(NSError *error) {
                             // Dispatch the result back onto the user dispatch queue.
                             if (completion) {
                               self->_userExecutor->Execute([=] { completion(error); });
                             }
                           }];
    }
  }];
};

- (void)transactionWithRetries:(int)retries
                   updateBlock:(FSTTransactionBlock)updateBlock
                    completion:(FSTVoidIDErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    [self.syncEngine
        transactionWithRetries:retries
           workerDispatchQueue:self.workerDispatchQueue
                   updateBlock:updateBlock
                    completion:^(id _Nullable result, NSError *_Nullable error) {
                      // Dispatch the result back onto the user dispatch queue.
                      if (completion) {
                        self->_userExecutor->Execute([=] { completion(result, error); });
                      }
                    }];
  }];
}

- (const DatabaseInfo *)databaseInfo {
  return &_databaseInfo;
}

- (const DatabaseId *)databaseID {
  return &_databaseInfo.database_id();
}

@end

NS_ASSUME_NONNULL_END
