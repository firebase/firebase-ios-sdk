/*
 * Copyright 2019 Google LLC
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

#include "Firestore/core/src/core/firestore_client.h"

#include <future>  // NOLINT(build/c++11)
#include <memory>
#include <utility>

#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/api/document_snapshot.h"
#include "Firestore/core/src/api/query_core.h"
#include "Firestore/core/src/api/query_snapshot.h"
#include "Firestore/core/src/api/settings.h"
#include "Firestore/core/src/auth/credentials_provider.h"
#include "Firestore/core/src/core/database_info.h"
#include "Firestore/core/src/core/event_manager.h"
#include "Firestore/core/src/core/query_listener.h"
#include "Firestore/core/src/core/sync_engine.h"
#include "Firestore/core/src/core/view.h"
#include "Firestore/core/src/local/index_free_query_engine.h"
#include "Firestore/core/src/local/leveldb_opener.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_documents_view.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/local/local_store.h"
#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/query_result.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/remote/datastore.h"
#include "Firestore/core/src/remote/remote_store.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/delayed_constructor.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_apple.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace core {

using api::DocumentReference;
using api::DocumentSnapshot;
using api::DocumentSnapshotListener;
using api::ListenerRegistration;
using api::QuerySnapshot;
using api::QuerySnapshotListener;
using api::Settings;
using api::SnapshotMetadata;
using auth::CredentialsProvider;
using auth::User;
using firestore::Error;
using local::IndexFreeQueryEngine;
using local::LevelDbOpener;
using local::LocalSerializer;
using local::LocalStore;
using local::LruParams;
using local::MemoryPersistence;
using local::QueryResult;
using model::DatabaseId;
using model::Document;
using model::DocumentKeySet;
using model::DocumentMap;
using model::MaybeDocument;
using model::Mutation;
using model::OnlineState;
using remote::Datastore;
using remote::RemoteStore;
using remote::Serializer;
using util::AsyncQueue;
using util::DelayedConstructor;
using util::DelayedOperation;
using util::Empty;
using util::Executor;
using util::Path;
using util::Status;
using util::StatusCallback;
using util::StatusOr;
using util::StatusOrCallback;
using util::ThrowIllegalState;
using util::TimerId;

static const size_t kMaxConcurrentLimboResolutions = 100;

std::shared_ptr<FirestoreClient> FirestoreClient::Create(
    const DatabaseInfo& database_info,
    const api::Settings& settings,
    std::shared_ptr<auth::CredentialsProvider> credentials_provider,
    std::shared_ptr<util::Executor> user_executor,
    std::shared_ptr<util::AsyncQueue> worker_queue) {
  // Have to use `new` because `make_shared` cannot access private constructor.
  std::shared_ptr<FirestoreClient> shared_client(
      new FirestoreClient(database_info, std::move(credentials_provider),
                          std::move(user_executor), std::move(worker_queue)));

  std::weak_ptr<FirestoreClient> weak_client(shared_client);
  auto credential_change_listener = [weak_client, settings](User user) mutable {
    auto shared_client = weak_client.lock();
    if (!shared_client) return;

    if (!shared_client->credentials_initialized_) {
      shared_client->credentials_initialized_ = true;

      // When we register the credentials listener for the first time,
      // it is invoked synchronously on the calling thread. This ensures that
      // the first item enqueued on the worker queue is
      // `FirestoreClient::Initialize()`.
      shared_client->worker_queue()->Enqueue([shared_client, user, settings] {
        shared_client->Initialize(user, settings);
      });
    } else {
      shared_client->worker_queue()->Enqueue([shared_client, user] {
        shared_client->worker_queue()->VerifyIsCurrentQueue();

        LOG_DEBUG("Credential Changed. Current user: %s", user.uid());
        shared_client->sync_engine_->HandleCredentialChange(user);
      });
    }
  };

  shared_client->credentials_provider_->SetCredentialChangeListener(
      credential_change_listener);

  HARD_ASSERT(
      shared_client->credentials_initialized_,
      "CredentialChangeListener not invoked during client initialization");

  return shared_client;
}

FirestoreClient::FirestoreClient(
    const DatabaseInfo& database_info,
    std::shared_ptr<auth::CredentialsProvider> credentials_provider,
    std::shared_ptr<util::Executor> user_executor,
    std::shared_ptr<util::AsyncQueue> worker_queue)
    : database_info_(database_info),
      credentials_provider_(std::move(credentials_provider)),
      worker_queue_(std::move(worker_queue)),
      user_executor_(std::move(user_executor)) {
}

void FirestoreClient::Initialize(const User& user, const Settings& settings) {
  // Do all of our initialization on our own dispatch queue.
  worker_queue()->VerifyIsCurrentQueue();
  LOG_DEBUG("Initializing. Current user: %s", user.uid());

  // Note: The initialization work must all be synchronous (we can't dispatch
  // more work) since external write/listen operations could get queued to run
  // before that subsequent work completes.
  if (settings.persistence_enabled()) {
    LevelDbOpener opener(database_info_);

    auto created =
        opener.Create(LruParams::WithCacheSize(settings.cache_size_bytes()));
    // If leveldb fails to start then just throw up our hands: the error is
    // unrecoverable. There's nothing an end-user can do and nearly all
    // failures indicate the developer is doing something grossly wrong so we
    // should stop them cold in their tracks with a failure they can't ignore.
    HARD_ASSERT(created.ok(), "Failed to open DB: %s",
                created.status().ToString());

    auto ldb = std::move(created).ValueOrDie();
    lru_delegate_ = ldb->reference_delegate();

    persistence_ = std::move(ldb);
    if (settings.gc_enabled()) {
      ScheduleLruGarbageCollection();
    }
  } else {
    persistence_ = MemoryPersistence::WithEagerGarbageCollector();
  }

  query_engine_ = absl::make_unique<IndexFreeQueryEngine>();
  local_store_ = absl::make_unique<LocalStore>(persistence_.get(),
                                               query_engine_.get(), user);

  auto datastore = std::make_shared<Datastore>(database_info_, worker_queue(),
                                               credentials_provider_);

  std::weak_ptr<FirestoreClient> weak_this(shared_from_this());
  remote_store_ = absl::make_unique<RemoteStore>(
      local_store_.get(), std::move(datastore), worker_queue(),
      [weak_this](OnlineState online_state) {
        weak_this.lock()->sync_engine_->HandleOnlineStateChange(online_state);
      });

  sync_engine_ =
      absl::make_unique<SyncEngine>(local_store_.get(), remote_store_.get(),
                                    user, kMaxConcurrentLimboResolutions);

  event_manager_ = absl::make_unique<EventManager>(sync_engine_.get());

  // Setup wiring for remote store.
  remote_store_->set_sync_engine(sync_engine_.get());

  // NOTE: RemoteStore depends on LocalStore (for persisting stream tokens,
  // refilling mutation queue, etc.) so must be started after LocalStore.
  local_store_->Start();
  remote_store_->Start();
}

/**
 * Schedules a callback to try running LRU garbage collection. Reschedules
 * itself after the GC has run.
 */
void FirestoreClient::ScheduleLruGarbageCollection() {
  std::chrono::milliseconds delay =
      gc_has_run_ ? regular_gc_delay_ : initial_gc_delay_;
  std::weak_ptr<FirestoreClient> weak_this = shared_from_this();
  lru_callback_ = worker_queue()->EnqueueAfterDelay(
      delay, TimerId::GarbageCollectionDelay, [weak_this] {
        auto shared_this = weak_this.lock();
        if (!shared_this) return;

        shared_this->local_store_->CollectGarbage(
            shared_this->lru_delegate_->garbage_collector());
        shared_this->gc_has_run_ = true;
        shared_this->ScheduleLruGarbageCollection();
      });
}

void FirestoreClient::DisableNetwork(StatusCallback callback) {
  VerifyNotTerminated();
  auto shared_this = shared_from_this();
  worker_queue()->Enqueue([shared_this, callback] {
    shared_this->remote_store_->DisableNetwork();
    if (callback) {
      shared_this->user_executor()->Execute([=] { callback(Status::OK()); });
    }
  });
}

void FirestoreClient::EnableNetwork(StatusCallback callback) {
  VerifyNotTerminated();
  auto shared_this = shared_from_this();
  worker_queue()->Enqueue([shared_this, callback] {
    shared_this->remote_store_->EnableNetwork();
    if (callback) {
      shared_this->user_executor()->Execute([=] { callback(Status::OK()); });
    }
  });
}

void FirestoreClient::TerminateAsync(StatusCallback callback) {
  auto shared_this = shared_from_this();
  worker_queue()->EnqueueAndInitiateShutdown([shared_this, callback] {
    shared_this->TerminateInternal();

    if (callback) {
      shared_this->user_executor()->Execute([=] { callback(Status::OK()); });
    }
  });
}

void FirestoreClient::Terminate() {
  std::promise<void> signal_terminated;
  worker_queue()->EnqueueAndInitiateShutdown([&, this] {
    TerminateInternal();
    signal_terminated.set_value();
  });
  signal_terminated.get_future().wait();
}

void FirestoreClient::TerminateInternal() {
  if (!remote_store_) return;

  credentials_provider_->SetCredentialChangeListener(nullptr);

  // If we've scheduled LRU garbage collection, cancel it.
  if (lru_callback_) {
    lru_callback_.Cancel();
  }
  remote_store_->Shutdown();
  persistence_->Shutdown();

  // Clear the remote store to indicate terminate is complete.
  remote_store_.reset();
}

void FirestoreClient::WaitForPendingWrites(StatusCallback callback) {
  VerifyNotTerminated();

  // Dispatch the result back onto the user dispatch queue.
  auto shared_this = shared_from_this();
  auto async_callback = [shared_this, callback](util::Status status) {
    if (callback) {
      shared_this->user_executor()->Execute(
          [=] { callback(std::move(status)); });
    }
  };

  worker_queue()->Enqueue([shared_this, async_callback] {
    shared_this->sync_engine_->RegisterPendingWritesCallback(
        std::move(async_callback));
  });
}

void FirestoreClient::VerifyNotTerminated() {
  if (is_terminated()) {
    ThrowIllegalState("The client has already been terminated.");
  }
}

bool FirestoreClient::is_terminated() const {
  // Technically, the worker queue is still running, but only accepting tasks
  // related to termination or supposed to be run after termination. It is
  // effectively terminated to the eyes of users.
  return worker_queue()->is_shutting_down();
}

std::shared_ptr<QueryListener> FirestoreClient::ListenToQuery(
    Query query, ListenOptions options, ViewSnapshotSharedListener&& listener) {
  VerifyNotTerminated();

  auto query_listener = QueryListener::Create(
      std::move(query), std::move(options), std::move(listener));

  auto shared_this = shared_from_this();
  worker_queue()->Enqueue([shared_this, query_listener] {
    shared_this->event_manager_->AddQueryListener(std::move(query_listener));
  });

  return query_listener;
}

void FirestoreClient::RemoveListener(
    const std::shared_ptr<QueryListener>& listener) {
  // Checks for termination but does not throw error, allowing it to be an no-op
  // if client is already terminated.
  if (is_terminated()) {
    return;
  }
  auto shared_this = shared_from_this();
  worker_queue()->Enqueue([shared_this, listener] {
    shared_this->event_manager_->RemoveQueryListener(listener);
  });
}

void FirestoreClient::GetDocumentFromLocalCache(
    const DocumentReference& doc, DocumentSnapshotListener&& callback) {
  VerifyNotTerminated();

  // TODO(c++14): move `callback` into lambda.
  auto shared_callback = absl::ShareUniquePtr(std::move(callback));
  auto shared_this = shared_from_this();
  worker_queue()->Enqueue([shared_this, doc, shared_callback] {
    absl::optional<MaybeDocument> maybe_document =
        shared_this->local_store_->ReadDocument(doc.key());
    StatusOr<DocumentSnapshot> maybe_snapshot;

    if (maybe_document && maybe_document->is_document()) {
      Document document(*maybe_document);
      maybe_snapshot = DocumentSnapshot::FromDocument(
          doc.firestore(), document,
          SnapshotMetadata{
              /*has_pending_writes=*/document.has_local_mutations(),
              /*from_cache=*/true});
    } else if (maybe_document && maybe_document->is_no_document()) {
      maybe_snapshot = DocumentSnapshot::FromNoDocument(
          doc.firestore(), doc.key(),
          SnapshotMetadata{/*has_pending_writes=*/false,
                           /*from_cache=*/true});
    } else {
      maybe_snapshot =
          Status{Error::kErrorUnavailable,
                 "Failed to get document from cache. (However, this document "
                 "may exist on the server. Run again without setting source to "
                 "FirestoreSourceCache to attempt to retrieve the document "};
    }

    if (shared_callback) {
      shared_this->user_executor()->Execute(
          [=] { shared_callback->OnEvent(std::move(maybe_snapshot)); });
    }
  });
}

void FirestoreClient::GetDocumentsFromLocalCache(
    const api::Query& query, QuerySnapshotListener&& callback) {
  VerifyNotTerminated();

  // TODO(c++14): move `callback` into lambda.
  auto shared_callback = absl::ShareUniquePtr(std::move(callback));
  auto shared_this = shared_from_this();
  worker_queue()->Enqueue([shared_this, query, shared_callback] {
    QueryResult query_result = shared_this->local_store_->ExecuteQuery(
        query.query(), /* use_previous_results= */ true);

    View view(query.query(), query_result.remote_keys());
    ViewDocumentChanges view_doc_changes =
        view.ComputeDocumentChanges(query_result.documents().underlying_map());
    ViewChange view_change = view.ApplyChanges(view_doc_changes);
    HARD_ASSERT(
        view_change.limbo_changes().empty(),
        "View returned limbo documents during local-only query execution.");

    HARD_ASSERT(view_change.snapshot().has_value(), "Expected a snapshot");

    ViewSnapshot snapshot = std::move(view_change.snapshot()).value();
    SnapshotMetadata metadata(snapshot.has_pending_writes(),
                              snapshot.from_cache());

    QuerySnapshot result(query.firestore(), query.query(), std::move(snapshot),
                         std::move(metadata));

    if (shared_callback) {
      shared_this->user_executor()->Execute(
          [=] { shared_callback->OnEvent(std::move(result)); });
    }
  });
}

void FirestoreClient::WriteMutations(std::vector<Mutation>&& mutations,
                                     StatusCallback callback) {
  VerifyNotTerminated();

  // TODO(c++14): move `mutations` into lambda (C++14).
  auto shared_this = shared_from_this();
  worker_queue()->Enqueue([shared_this, mutations, callback]() mutable {
    if (mutations.empty()) {
      if (callback) {
        shared_this->user_executor()->Execute([=] { callback(Status::OK()); });
      }
    } else {
      shared_this->sync_engine_->WriteMutations(
          std::move(mutations), [callback, shared_this](Status error) {
            // Dispatch the result back onto the user dispatch queue.
            if (callback) {
              shared_this->user_executor()->Execute(
                  [=] { callback(std::move(error)); });
            }
          });
    }
  });
}

void FirestoreClient::Transaction(int retries,
                                  TransactionUpdateCallback update_callback,
                                  TransactionResultCallback result_callback) {
  VerifyNotTerminated();

  // Dispatch the result back onto the user dispatch queue.
  auto shared_this = shared_from_this();
  auto async_callback = [shared_this, result_callback](Status status) {
    if (result_callback) {
      shared_this->user_executor()->Execute(
          [=] { result_callback(std::move(status)); });
    }
  };

  worker_queue()->Enqueue([shared_this, retries, update_callback,
                           async_callback] {
    shared_this->sync_engine_->Transaction(retries, shared_this->worker_queue(),
                                           std::move(update_callback),
                                           std::move(async_callback));
  });
}

void FirestoreClient::AddSnapshotsInSyncListener(
    const std::shared_ptr<EventListener<Empty>>& user_listener) {
  auto shared_this = shared_from_this();
  worker_queue()->Enqueue([shared_this, user_listener] {
    shared_this->event_manager_->AddSnapshotsInSyncListener(
        std::move(user_listener));
  });
}

void FirestoreClient::RemoveSnapshotsInSyncListener(
    const std::shared_ptr<EventListener<Empty>>& user_listener) {
  event_manager_->RemoveSnapshotsInSyncListener(user_listener);
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
