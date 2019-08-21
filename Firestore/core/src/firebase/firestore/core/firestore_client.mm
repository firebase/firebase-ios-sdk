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

#include "Firestore/core/src/firebase/firestore/core/firestore_client.h"

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
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/src/firebase/firestore/api/settings.h"
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/core/event_manager.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
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

namespace firebase {
namespace firestore {
namespace core {

using firestore::Error;
using api::DocumentReference;
using api::DocumentSnapshot;
using api::QuerySnapshot;
using api::Settings;
using api::SnapshotMetadata;
using api::ThrowIllegalState;
using auth::CredentialsProvider;
using auth::User;
using core::DatabaseInfo;
using core::ListenOptions;
using core::EventManager;
using core::Query;
using core::QueryListener;
using core::ViewSnapshot;
using local::LruParams;
using model::DatabaseId;
using model::Document;
using model::DocumentKeySet;
using model::DocumentMap;
using model::MaybeDocument;
using model::Mutation;
using model::OnlineState;
using remote::Datastore;
using remote::RemoteStore;
using util::Path;
using util::AsyncQueue;
using util::DelayedConstructor;
using util::DelayedOperation;
using util::Executor;
using util::Status;
using util::StatusCallback;
using util::StatusOr;
using util::StatusOrCallback;
using util::TimerId;

FirestoreClient::FirestoreClient(
    const DatabaseInfo& database_info,
    std::shared_ptr<auth::CredentialsProvider> credentials_provider,
    std::shared_ptr<util::Executor> user_executor,
    std::shared_ptr<util::AsyncQueue> worker_queue)
    : database_info_(database_info),
      credentials_provider_(std::move(credentials_provider)),
      user_executor_(std::move(user_executor)),
      worker_queue_(std::move(worker_queue)) {
}

void FirestoreClient::Initialize(const api::Settings& settings) {
  if (client_initialized_) {
    return;
  }
  auto user_promise = std::make_shared<std::promise<User>>();
  bool credentials_initialized = false;

  std::weak_ptr<FirestoreClient> weak_self(shared_from_this());
  auto credentialChangeListener = [credentials_initialized, user_promise,
                                   weak_self](User user) mutable {
    auto shared_self = weak_self.lock();
    if (!shared_self) return;

    if (!credentials_initialized) {
      credentials_initialized = true;
      user_promise->set_value(user);
    } else {
      shared_self->worker_queue_->Enqueue(
          [shared_self, user] { shared_self->CredentialsChanged(user); });
    }
  };

  credentials_provider_->SetCredentialChangeListener(credentialChangeListener);

  // Defer initialization until we get the current user from the
  // credentialChangeListener. This is guaranteed to be synchronously dispatched
  // onto our worker queue, so we will be initialized before any subsequently
  // queued work runs.
  auto shared_self = shared_from_this();
  worker_queue_->Enqueue([shared_self, user_promise, settings] {
    User user = user_promise->get_future().get();
    shared_self->InitializeInternal(user, settings);
  });

  client_initialized_ = true;
}

void FirestoreClient::VerifyInitialized() {
  if (!client_initialized_) {
    ThrowIllegalState("The client has not been initialized yet, have you call "
                      "'Initialize()' yet?");
  }
}

void FirestoreClient::CredentialsChanged(const User& user) {
  worker_queue_->VerifyIsCurrentQueue();

  LOG_DEBUG("Credential Changed. Current user: %s", user.uid());
  [sync_engine_ credentialDidChangeWithUser:user];
}

void FirestoreClient::InitializeInternal(const User& user,
                                         const Settings& settings) {
  // Do all of our initialization on our own dispatch queue.
  worker_queue_->VerifyIsCurrentQueue();
  LOG_DEBUG("Initializing. Current user: %s", user.uid());

  // Note: The initialization work must all be synchronous (we can't dispatch
  // more work) since external write/listen operations could get queued to run
  // before that subsequent work completes.
  if (settings.persistence_enabled()) {
    Path dir = [FSTLevelDB
        storageDirectoryForDatabaseInfo:database_info_
                     documentsDirectory:[FSTLevelDB documentsDirectory]];

    FSTSerializerBeta* remote_serializer = [[FSTSerializerBeta alloc]
        initWithDatabaseID:database_info_.database_id()];
    FSTLocalSerializer* serializer =
        [[FSTLocalSerializer alloc] initWithRemoteSerializer:remote_serializer];
    FSTLevelDB* ldb;
    Status level_db_status = [FSTLevelDB
        dbWithDirectory:std::move(dir)
             serializer:serializer
              lruParams:LruParams::WithCacheSize(settings.cache_size_bytes())
                    ptr:&ldb];
    if (!level_db_status.ok()) {
      // If leveldb fails to start then just throw up our hands: the error is
      // unrecoverable. There's nothing an end-user can do and nearly all
      // failures indicate the developer is doing something grossly wrong so we
      // should stop them cold in their tracks with a failure they can't ignore.
      [NSException
           raise:NSInternalInconsistencyException
          format:@"Failed to open DB: %s", level_db_status.ToString().c_str()];
    }
    lru_delegate_ = ldb.referenceDelegate;
    persistence_ = ldb;
    if (settings.gc_enabled()) {
      ScheduleLruGarbageCollection();
    }
  } else {
    persistence_ = [FSTMemoryPersistence persistenceWithEagerGC];
  }

  local_store_ = [[FSTLocalStore alloc] initWithPersistence:persistence_
                                                initialUser:user];

  auto datastore = std::make_shared<Datastore>(database_info_, worker_queue_,
                                               credentials_provider_);

  auto shared_self = shared_from_this();
  remote_store_ = absl::make_unique<RemoteStore>(
      local_store_, std::move(datastore), worker_queue_,
      [shared_self](OnlineState online_state) {
        [shared_self->sync_engine_ applyChangedOnlineState:online_state];
      });

  sync_engine_ = [[FSTSyncEngine alloc] initWithLocalStore:local_store_
                                               remoteStore:remote_store_.get()
                                               initialUser:user];

  event_manager_.Init(sync_engine_);

  // Setup wiring for remote store.
  remote_store_->set_sync_engine(sync_engine_);

  // NOTE: RemoteStore depends on LocalStore (for persisting stream tokens,
  // refilling mutation queue, etc.) so must be started after LocalStore.
  [local_store_ start];
  remote_store_->Start();
}

/**
 * Schedules a callback to try running LRU garbage collection. Reschedules
 * itself after the GC has run.
 */
void FirestoreClient::ScheduleLruGarbageCollection() {
  std::chrono::milliseconds delay =
      gc_has_run_ ? regular_gc_delay_ : initial_gc_delay_;
  auto shared_self = shared_from_this();
  lru_callback_ = worker_queue_->EnqueueAfterDelay(
      delay, TimerId::GarbageCollectionDelay, [shared_self]() {
        [shared_self->local_store_
            collectGarbage:shared_self->lru_delegate_.gc];
        shared_self->gc_has_run_ = true;
        shared_self->ScheduleLruGarbageCollection();
      });
}

void FirestoreClient::DisableNetwork(StatusCallback callback) {
  VerifyInitialized();
  VerifyNotShutdown();
  auto shared_self = shared_from_this();
  worker_queue_->Enqueue([shared_self, callback] {
    shared_self->remote_store_->DisableNetwork();
    if (callback) {
      shared_self->user_executor_->Execute([=] { callback(Status::OK()); });
    }
  });
}

void FirestoreClient::EnableNetwork(StatusCallback callback) {
  VerifyInitialized();
  VerifyNotShutdown();
  auto shared_self = shared_from_this();
  worker_queue_->Enqueue([shared_self, callback] {
    shared_self->remote_store_->EnableNetwork();
    if (callback) {
      shared_self->user_executor_->Execute([=] { callback(Status::OK()); });
    }
  });
}

void FirestoreClient::Shutdown(StatusCallback callback) {
  VerifyInitialized();
  auto shared_self = shared_from_this();
  worker_queue_->EnqueueAndInitiateShutdown([shared_self, callback] {
    shared_self->credentials_provider_->SetCredentialChangeListener(nullptr);

    // If we've scheduled LRU garbage collection, cancel it.
    if (shared_self->lru_callback_) {
      shared_self->lru_callback_.Cancel();
    }
    shared_self->remote_store_->Shutdown();
    [shared_self->persistence_ shutdown];
  });

  // This separate enqueue ensures if shutdown is called multiple times
  // every time the callback is triggered. If it is in the above
  // enqueue, it might not get executed because after first shutdown
  // all operations are not executed.
  worker_queue_->EnqueueEvenAfterShutdown([shared_self, callback] {
    if (callback) {
      shared_self->user_executor_->Execute([=] { callback(Status::OK()); });
    }
  });
}

void FirestoreClient::WaitForPendingWrites(StatusCallback callback) {
  VerifyInitialized();
  VerifyNotShutdown();

  // Dispatch the result back onto the user dispatch queue.
  auto shared_self = shared_from_this();
  auto async_callback = [shared_self, callback](util::Status status) {
    if (callback) {
      shared_self->user_executor_->Execute(
          [=] { callback(std::move(status)); });
    }
  };

  worker_queue_->Enqueue([shared_self, async_callback]() {
    [shared_self->sync_engine_
        registerPendingWritesCallback:std::move(async_callback)];
  });
}

void FirestoreClient::VerifyNotShutdown() {
  if (is_shutdown()) {
    ThrowIllegalState("The client has already been shutdown.");
  }
}

bool FirestoreClient::is_shutdown() const {
  // Technically, the worker queue is still running, but only accepting tasks
  // related to shutdown or supposed to be run after shutdown. It is effectively
  // shut down to the eyes of users.
  return worker_queue_->is_shutting_down();
}

std::shared_ptr<QueryListener> FirestoreClient::ListenToQuery(
    Query query, ListenOptions options, ViewSnapshot::SharedListener listener) {
  VerifyInitialized();
  VerifyNotShutdown();

  auto query_listener = QueryListener::Create(
      std::move(query), std::move(options), std::move(listener));

  auto shared_self = shared_from_this();
  worker_queue_->Enqueue([shared_self, query_listener] {
    shared_self->event_manager_->AddQueryListener(std::move(query_listener));
  });

  return query_listener;
}

void FirestoreClient::RemoveListener(
    const std::shared_ptr<QueryListener>& listener) {
  VerifyInitialized();
  // Checks for shutdown but does not throw error, allowing it to be an no-op if
  // client is already shutdown.
  if (is_shutdown()) {
    return;
  }
  auto shared_self = shared_from_this();
  worker_queue_->Enqueue([shared_self, listener] {
    shared_self->event_manager_->RemoveQueryListener(listener);
  });
}

void FirestoreClient::GetDocumentFromLocalCache(
    const DocumentReference& doc, DocumentSnapshot::Listener&& callback) {
  VerifyInitialized();
  VerifyNotShutdown();

  // TODO(c++14): move `callback` into lambda.
  auto shared_callback = absl::ShareUniquePtr(std::move(callback));
  auto shared_self = shared_from_this();
  worker_queue_->Enqueue([shared_self, doc, shared_callback] {
    absl::optional<MaybeDocument> maybe_doccument =
        [shared_self->local_store_ readDocument:doc.key()];
    StatusOr<DocumentSnapshot> maybe_snapshot;

    if (maybe_doccument && maybe_doccument->is_document()) {
      Document document(*maybe_doccument);
      maybe_snapshot = DocumentSnapshot{
          doc.firestore(), doc.key(), document,
          /*from_cache=*/true,
          /*has_pending_writes=*/document.has_local_mutations()};
    } else if (maybe_doccument && maybe_doccument->is_no_document()) {
      maybe_snapshot =
          DocumentSnapshot{doc.firestore(), doc.key(), absl::nullopt,
                           /*from_cache=*/true,
                           /*has_pending_writes=*/false};
    } else {
      maybe_snapshot =
          Status{Error::Unavailable,
                 "Failed to get document from cache. (However, this document "
                 "may exist on the server. Run again without setting source to "
                 "FirestoreSourceCache to attempt to retrieve the document "};
    }

    if (shared_callback) {
      shared_self->user_executor_->Execute(
          [=] { shared_callback->OnEvent(std::move(maybe_snapshot)); });
    }
  });
}

void FirestoreClient::GetDocumentsFromLocalCache(
    const api::Query& query, QuerySnapshot::Listener&& callback) {
  VerifyInitialized();
  VerifyNotShutdown();

  // TODO(c++14): move `callback` into lambda.
  auto shared_callback = absl::ShareUniquePtr(std::move(callback));
  auto shared_self = shared_from_this();
  worker_queue_->Enqueue([shared_self, query, shared_callback] {
    DocumentMap docs = [shared_self->local_store_ executeQuery:query.query()];

    FSTView* view = [[FSTView alloc] initWithQuery:query.query()
                                   remoteDocuments:DocumentKeySet{}];
    FSTViewDocumentChanges* view_doc_changes =
        [view computeChangesWithDocuments:docs.underlying_map()];
    FSTViewChange* view_change =
        [view applyChangesToDocuments:view_doc_changes];
    HARD_ASSERT(
        view_change.limboChanges.count == 0,
        "View returned limbo documents during local-only query execution.");
    HARD_ASSERT(view_change.snapshot.has_value(), "Expected a snapshot");

    ViewSnapshot snapshot = std::move(view_change.snapshot).value();
    SnapshotMetadata metadata(snapshot.has_pending_writes(),
                              snapshot.from_cache());

    QuerySnapshot result(query.firestore(), query.query(), std::move(snapshot),
                         std::move(metadata));

    if (shared_callback) {
      shared_self->user_executor_->Execute(
          [=] { shared_callback->OnEvent(std::move(result)); });
    }
  });
}

void FirestoreClient::WriteMutations(std::vector<Mutation>&& mutations,
                                     StatusCallback callback) {
  VerifyInitialized();
  VerifyNotShutdown();

  // TODO(c++14): move `mutations` into lambda (C++14).
  auto shared_self = shared_from_this();
  worker_queue_->Enqueue([shared_self, mutations, callback]() mutable {
    if (mutations.empty()) {
      if (callback) {
        shared_self->user_executor_->Execute([=] { callback(Status::OK()); });
      }
    } else {
      [shared_self->sync_engine_
          writeMutations:std::move(mutations)
              completion:^(NSError* error) {
                // Dispatch the result back onto the user dispatch queue.
                if (callback) {
                  shared_self->user_executor_->Execute(
                      [=] { callback(Status::FromNSError(error)); });
                }
              }];
    }
  });
}

void FirestoreClient::TransactionWithRetries(
    int retries,
    TransactionUpdateCallback update_callback,
    TransactionResultCallback result_callback) {
  VerifyInitialized();
  VerifyNotShutdown();

  // Dispatch the result back onto the user dispatch queue.
  auto shared_self = shared_from_this();
  auto async_callback =
      [shared_self, result_callback](util::StatusOr<absl::any> maybe_value) {
        if (result_callback) {
          shared_self->user_executor_->Execute(
              [=] { result_callback(std::move(maybe_value)); });
        }
      };

  worker_queue_->Enqueue(
      [shared_self, retries, update_callback, async_callback] {
        [shared_self->sync_engine_
            transactionWithRetries:retries
                       workerQueue:shared_self->worker_queue_
                    updateCallback:std::move(update_callback)
                    resultCallback:std::move(async_callback)];
      });
}

const DatabaseId& FirestoreClient::database_id() const {
  return database_info_.database_id();
}

const std::shared_ptr<util::Executor>& FirestoreClient::user_executor() const {
  return user_executor_;
}

const std::shared_ptr<util::AsyncQueue>& FirestoreClient::worker_queue() const {
  return worker_queue_;
}
}  // namespace core
}  // namespace firestore
}  // namespace firebase
