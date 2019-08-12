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

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)
#include <memory>
#include <utility>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/Core/FSTSyncEngine.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/src/firebase/firestore/api/settings.h"
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/core/event_manager.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_store.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/delayed_constructor.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"

namespace util = firebase::firestore::util;
using firebase::firestore::Error;
using firebase::firestore::api::DocumentReference;
using firebase::firestore::api::DocumentSnapshot;
using firebase::firestore::api::Settings;
using firebase::firestore::api::SnapshotMetadata;
using firebase::firestore::api::ThrowIllegalState;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::User;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::EventManager;
using firebase::firestore::core::Query;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::local::LruParams;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::OnlineState;
using firebase::firestore::remote::Datastore;
using firebase::firestore::remote::RemoteStore;
using firebase::firestore::util::Path;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::DelayedConstructor;
using firebase::firestore::util::DelayedOperation;
using firebase::firestore::util::Executor;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;
using firebase::firestore::util::StatusOrCallback;
using firebase::firestore::util::TimerId;

NS_ASSUME_NONNULL_BEGIN

/** How long we wait to try running LRU GC after SDK initialization. */
static const std::chrono::milliseconds FSTLruGcInitialDelay = std::chrono::minutes(1);
/** Minimum amount of time between GC checks, after the first one. */
static const std::chrono::milliseconds FSTLruGcRegularDelay = std::chrono::minutes(5);

@interface FSTFirestoreClient () {
  DatabaseInfo _databaseInfo;
}

- (instancetype)initWithDatabaseInfo:(const DatabaseInfo &)databaseInfo
                            settings:(const Settings &)settings
                 credentialsProvider:(std::shared_ptr<CredentialsProvider>)credentialsProvider
                        userExecutor:(std::shared_ptr<Executor>)userExecutor
                         workerQueue:(std::shared_ptr<AsyncQueue>)queue NS_DESIGNATED_INITIALIZER;

@property(nonatomic, assign, readonly) const DatabaseInfo *databaseInfo;
@property(nonatomic, strong, readonly) id<FSTPersistence> persistence;
@property(nonatomic, strong, readonly) FSTSyncEngine *syncEngine;
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;

@end

@implementation FSTFirestoreClient {
  /**
   * Async queue responsible for all of our internal processing. When we get incoming work from
   * the user (via public API) or the network (incoming gRPC messages), we should always dispatch
   * onto this queue. This ensures our internal data structures are never accessed from multiple
   * threads simultaneously.
   */
  std::shared_ptr<AsyncQueue> _workerQueue;

  std::unique_ptr<RemoteStore> _remoteStore;
  DelayedConstructor<EventManager> _eventManager;

  std::shared_ptr<Executor> _userExecutor;
  std::shared_ptr<CredentialsProvider> _credentialsProvider;
  std::chrono::milliseconds _initialGcDelay;
  std::chrono::milliseconds _regularGcDelay;
  bool _gcHasRun;
  _Nullable id<FSTLRUDelegate> _lruDelegate;
  DelayedOperation _lruCallback;
}

- (const std::shared_ptr<util::Executor> &)userExecutor {
  return _userExecutor;
}

- (const std::shared_ptr<util::AsyncQueue> &)workerQueue {
  return _workerQueue;
}

- (bool)isShutdown {
  // Technically, the asyncQueue is still running, but only accepting tasks related to shutdown
  // or supposed to be run after shutdown. It is effectively shut down to the eyes of users.
  return _workerQueue->is_shutting_down();
}

+ (instancetype)clientWithDatabaseInfo:(const DatabaseInfo &)databaseInfo
                              settings:(const Settings &)settings
                   credentialsProvider:(std::shared_ptr<CredentialsProvider>)credentialsProvider
                          userExecutor:(std::shared_ptr<Executor>)userExecutor
                           workerQueue:(std::shared_ptr<AsyncQueue>)workerQueue {
  return [[FSTFirestoreClient alloc] initWithDatabaseInfo:databaseInfo
                                                 settings:settings
                                      credentialsProvider:std::move(credentialsProvider)
                                             userExecutor:std::move(userExecutor)
                                              workerQueue:std::move(workerQueue)];
}

- (instancetype)initWithDatabaseInfo:(const DatabaseInfo &)databaseInfo
                            settings:(const Settings &)settings
                 credentialsProvider:(std::shared_ptr<CredentialsProvider>)credentialsProvider
                        userExecutor:(std::shared_ptr<Executor>)userExecutor
                         workerQueue:(std::shared_ptr<AsyncQueue>)workerQueue {
  if (self = [super init]) {
    _databaseInfo = databaseInfo;
    _credentialsProvider = std::move(credentialsProvider);
    _userExecutor = std::move(userExecutor);
    _workerQueue = std::move(workerQueue);
    _gcHasRun = false;
    _initialGcDelay = FSTLruGcInitialDelay;
    _regularGcDelay = FSTLruGcRegularDelay;

    auto userPromise = std::make_shared<std::promise<User>>();
    bool initialized = false;

    __weak __typeof__(self) weakSelf = self;
    auto credentialChangeListener = [initialized, userPromise, weakSelf](User user) mutable {
      __typeof__(self) strongSelf = weakSelf;
      if (!strongSelf) return;

      if (!initialized) {
        initialized = true;
        userPromise->set_value(user);
      } else {
        strongSelf->_workerQueue->Enqueue(
            [strongSelf, user] { [strongSelf credentialDidChangeWithUser:user]; });
      }
    };

    _credentialsProvider->SetCredentialChangeListener(credentialChangeListener);

    // Defer initialization until we get the current user from the credentialChangeListener. This is
    // guaranteed to be synchronously dispatched onto our worker queue, so we will be initialized
    // before any subsequently queued work runs.
    _workerQueue->Enqueue([self, userPromise, settings] {
      User user = userPromise->get_future().get();
      [self initializeWithUser:user settings:settings];
    });
  }
  return self;
}

- (void)initializeWithUser:(const User &)user settings:(const Settings &)settings {
  // Do all of our initialization on our own dispatch queue.
  _workerQueue->VerifyIsCurrentQueue();
  LOG_DEBUG("Initializing. Current user: %s", user.uid());

  // Note: The initialization work must all be synchronous (we can't dispatch more work) since
  // external write/listen operations could get queued to run before that subsequent work
  // completes.
  if (settings.persistence_enabled()) {
    Path dir = [FSTLevelDB storageDirectoryForDatabaseInfo:*self.databaseInfo
                                        documentsDirectory:[FSTLevelDB documentsDirectory]];

    FSTSerializerBeta *remoteSerializer =
        [[FSTSerializerBeta alloc] initWithDatabaseID:self.databaseInfo->database_id()];
    FSTLocalSerializer *serializer =
        [[FSTLocalSerializer alloc] initWithRemoteSerializer:remoteSerializer];
    FSTLevelDB *ldb;
    Status levelDbStatus =
        [FSTLevelDB dbWithDirectory:std::move(dir)
                         serializer:serializer
                          lruParams:LruParams::WithCacheSize(settings.cache_size_bytes())
                                ptr:&ldb];
    if (!levelDbStatus.ok()) {
      // If leveldb fails to start then just throw up our hands: the error is unrecoverable.
      // There's nothing an end-user can do and nearly all failures indicate the developer is doing
      // something grossly wrong so we should stop them cold in their tracks with a failure they
      // can't ignore.
      [NSException raise:NSInternalInconsistencyException
                  format:@"Failed to open DB: %s", levelDbStatus.ToString().c_str()];
    }
    _lruDelegate = ldb.referenceDelegate;
    _persistence = ldb;
    if (settings.gc_enabled()) {
      [self scheduleLruGarbageCollection];
    }
  } else {
    _persistence = [FSTMemoryPersistence persistenceWithEagerGC];
  }

  _localStore = [[FSTLocalStore alloc] initWithPersistence:_persistence initialUser:user];

  auto datastore =
      std::make_shared<Datastore>(*self.databaseInfo, _workerQueue, _credentialsProvider);

  _remoteStore = absl::make_unique<RemoteStore>(
      _localStore, std::move(datastore), _workerQueue,
      [self](OnlineState onlineState) { [self.syncEngine applyChangedOnlineState:onlineState]; });

  _syncEngine = [[FSTSyncEngine alloc] initWithLocalStore:_localStore
                                              remoteStore:_remoteStore.get()
                                              initialUser:user];

  _eventManager.Init(_syncEngine);

  // Setup wiring for remote store.
  _remoteStore->set_sync_engine(_syncEngine);

  // NOTE: RemoteStore depends on LocalStore (for persisting stream tokens, refilling mutation
  // queue, etc.) so must be started after LocalStore.
  [_localStore start];
  _remoteStore->Start();
}

/**
 * Schedules a callback to try running LRU garbage collection. Reschedules itself after the GC has
 * run.
 */
- (void)scheduleLruGarbageCollection {
  std::chrono::milliseconds delay = _gcHasRun ? _regularGcDelay : _initialGcDelay;
  _lruCallback = _workerQueue->EnqueueAfterDelay(delay, TimerId::GarbageCollectionDelay, [self]() {
    [self->_localStore collectGarbage:self->_lruDelegate.gc];
    self->_gcHasRun = true;
    [self scheduleLruGarbageCollection];
  });
}

- (void)credentialDidChangeWithUser:(const User &)user {
  _workerQueue->VerifyIsCurrentQueue();

  LOG_DEBUG("Credential Changed. Current user: %s", user.uid());
  [self.syncEngine credentialDidChangeWithUser:user];
}

- (void)disableNetworkWithCallback:(util::StatusCallback)callback {
  [self verifyNotShutdown];
  _workerQueue->Enqueue([self, callback] {
    _remoteStore->DisableNetwork();
    if (callback) {
      self->_userExecutor->Execute([=] { callback(Status::OK()); });
    }
  });
}

- (void)enableNetworkWithCallback:(util::StatusCallback)callback {
  [self verifyNotShutdown];
  _workerQueue->Enqueue([self, callback] {
    _remoteStore->EnableNetwork();
    if (callback) {
      self->_userExecutor->Execute([=] { callback(Status::OK()); });
    }
  });
}

- (void)shutdownWithCallback:(util::StatusCallback)callback {
  _workerQueue->EnqueueAndInitiateShutdown([self, callback] {
    self->_credentialsProvider->SetCredentialChangeListener(nullptr);

    // If we've scheduled LRU garbage collection, cancel it.
    if (self->_lruCallback) {
      self->_lruCallback.Cancel();
    }
    _remoteStore->Shutdown();
    [self.persistence shutdown];
  });

  // This separate enqueue ensures if shutdown is called multiple times
  // every time the callback is triggered. If it is in the above
  // enqueue, it might not get executed because after first shutdown
  // all operations are not executed.
  _workerQueue->EnqueueEvenAfterShutdown([self, callback] {
    if (callback) {
      self->_userExecutor->Execute([=] { callback(Status::OK()); });
    }
  });
}

- (void)verifyNotShutdown {
  if (self.isShutdown) {
    ThrowIllegalState("The client has already been shutdown.");
  }
}

- (std::shared_ptr<QueryListener>)listenToQuery:(Query)query
                                        options:(core::ListenOptions)options
                                       listener:(ViewSnapshot::SharedListener &&)listener {
  auto query_listener =
      QueryListener::Create(std::move(query), std::move(options), std::move(listener));

  _workerQueue->Enqueue(
      [self, query_listener] { _eventManager->AddQueryListener(std::move(query_listener)); });

  return query_listener;
}

- (void)removeListener:(const std::shared_ptr<QueryListener> &)listener {
  [self verifyNotShutdown];
  _workerQueue->Enqueue([self, listener] { _eventManager->RemoveQueryListener(listener); });
}

- (void)getDocumentFromLocalCache:(const DocumentReference &)doc
                         callback:(DocumentSnapshot::Listener &&)callback {
  [self verifyNotShutdown];

  // TODO(c++14): move `callback` into lambda.
  auto shared_callback = absl::ShareUniquePtr(std::move(callback));
  _workerQueue->Enqueue([self, doc, shared_callback] {
    FSTMaybeDocument *maybeDoc = [self.localStore readDocument:doc.key()];
    StatusOr<DocumentSnapshot> maybe_snapshot;

    if ([maybeDoc isKindOfClass:[FSTDocument class]]) {
      FSTDocument *document = (FSTDocument *)maybeDoc;
      maybe_snapshot = DocumentSnapshot{doc.firestore(), doc.key(), document,
                                        /*from_cache=*/true,
                                        /*has_pending_writes=*/document.hasLocalMutations};
    } else if ([maybeDoc isKindOfClass:[FSTDeletedDocument class]]) {
      maybe_snapshot = DocumentSnapshot{doc.firestore(), doc.key(), nil,
                                        /*from_cache=*/true,
                                        /*has_pending_writes=*/false};
    } else {
      maybe_snapshot =
          Status{Error::Unavailable, "Failed to get document from cache. (However, this document "
                                     "may exist on the server. Run again without setting source to "
                                     "FirestoreSourceCache to attempt to retrieve the document "};
    }

    if (shared_callback) {
      self->_userExecutor->Execute([=] { shared_callback->OnEvent(std::move(maybe_snapshot)); });
    }
  });
}

- (void)getDocumentsFromLocalCache:(const api::Query &)query
                          callback:(api::QuerySnapshot::Listener &&)callback {
  [self verifyNotShutdown];

  // TODO(c++14): move `callback` into lambda.
  auto shared_callback = absl::ShareUniquePtr(std::move(callback));
  _workerQueue->Enqueue([self, query, shared_callback] {
    DocumentMap docs = [self.localStore executeQuery:query.query()];

    FSTView *view = [[FSTView alloc] initWithQuery:query.query() remoteDocuments:DocumentKeySet{}];
    FSTViewDocumentChanges *viewDocChanges =
        [view computeChangesWithDocuments:docs.underlying_map()];
    FSTViewChange *viewChange = [view applyChangesToDocuments:viewDocChanges];
    HARD_ASSERT(viewChange.limboChanges.count == 0,
                "View returned limbo documents during local-only query execution.");
    HARD_ASSERT(viewChange.snapshot.has_value(), "Expected a snapshot");

    ViewSnapshot snapshot = std::move(viewChange.snapshot).value();
    SnapshotMetadata metadata(snapshot.has_pending_writes(), snapshot.from_cache());

    api::QuerySnapshot result(query.firestore(), query.query(), std::move(snapshot),
                              std::move(metadata));

    if (shared_callback) {
      self->_userExecutor->Execute([=] { shared_callback->OnEvent(std::move(result)); });
    }
  });
}

- (void)writeMutations:(std::vector<FSTMutation *> &&)mutations
              callback:(util::StatusCallback)callback {
  [self verifyNotShutdown];
  // TODO(c++14): move `mutations` into lambda (C++14).
  _workerQueue->Enqueue([self, mutations, callback]() mutable {
    if (mutations.empty()) {
      if (callback) {
        self->_userExecutor->Execute([=] { callback(Status::OK()); });
      }
    } else {
      [self.syncEngine
          writeMutations:std::move(mutations)
              completion:^(NSError *error) {
                // Dispatch the result back onto the user dispatch queue.
                if (callback) {
                  self->_userExecutor->Execute([=] { callback(Status::FromNSError(error)); });
                }
              }];
    }
  });
};

- (void)transactionWithRetries:(int)retries
                updateCallback:(core::TransactionUpdateCallback)update_callback
                resultCallback:(core::TransactionResultCallback)resultCallback {
  [self verifyNotShutdown];
  // Dispatch the result back onto the user dispatch queue.
  auto async_callback = [self, resultCallback](util::StatusOr<absl::any> maybe_value) {
    if (resultCallback) {
      self->_userExecutor->Execute([=] { resultCallback(std::move(maybe_value)); });
    }
  };

  _workerQueue->Enqueue([self, retries, update_callback, async_callback] {
    [self.syncEngine transactionWithRetries:retries
                                workerQueue:_workerQueue
                             updateCallback:std::move(update_callback)
                             resultCallback:std::move(async_callback)];
  });
}

- (const DatabaseInfo *)databaseInfo {
  return &_databaseInfo;
}

- (const DatabaseId &)databaseID {
  return _databaseInfo.database_id();
}

@end

NS_ASSUME_NONNULL_END
