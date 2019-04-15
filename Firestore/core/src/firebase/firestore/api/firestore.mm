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

#include "Firestore/core/src/firebase/firestore/api/firestore.h"

#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRTransaction+Internal.h"
#import "Firestore/Source/API/FIRWriteBatch+Internal.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"

#include "Firestore/core/src/firebase/firestore/api/document_reference.h"
#include "Firestore/core/src/firebase/firestore/api/settings.h"
#include "Firestore/core/src/firebase/firestore/auth/firebase_credentials_provider_apple.h"
#include "Firestore/core/src/firebase/firestore/core/transaction.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace api {

using api::Firestore;
using auth::CredentialsProvider;
using core::DatabaseInfo;
using core::Transaction;
using model::DocumentKey;
using model::ResourcePath;
using util::AsyncQueue;
using util::Executor;
using util::ExecutorLibdispatch;
using util::Status;

Firestore::Firestore(std::string project_id,
                     std::string database,
                     std::string persistence_key,
                     std::unique_ptr<CredentialsProvider> credentials_provider,
                     std::unique_ptr<AsyncQueue> worker_queue,
                     void* extension)
    : database_id_{std::move(project_id), std::move(database)},
      credentials_provider_{std::move(credentials_provider)},
      persistence_key_{std::move(persistence_key)},
      worker_queue_{std::move(worker_queue)},
      extension_{extension} {
}

AsyncQueue* Firestore::worker_queue() {
  return [client_ workerQueue];
}

const Settings& Firestore::settings() const {
  std::lock_guard<std::mutex> lock{mutex_};
  return settings_;
}

void Firestore::set_settings(const Settings& settings) {
  std::lock_guard<std::mutex> lock{mutex_};
  if (client_) {
    HARD_FAIL(
        "Firestore instance has already been started and its settings can "
        "no longer be changed. You can only set settings before calling any "
        "other methods on a Firestore instance.");
  }
  settings_ = settings;
}

void Firestore::set_user_executor(
    std::unique_ptr<util::Executor> user_executor) {
  std::lock_guard<std::mutex> lock{mutex_};
  HARD_ASSERT(!client_ && user_executor,
              "set_user_executor() must be called with a valid executor, "
              "before the client is initialized.");
  user_executor_ = std::move(user_executor);
}

FIRCollectionReference* Firestore::GetCollection(
    absl::string_view collection_path) {
  EnsureClientConfigured();
  ResourcePath path = ResourcePath::FromString(collection_path);
  return [FIRCollectionReference
      referenceWithPath:path
              firestore:[FIRFirestore recoverFromFirestore:this]];
}

DocumentReference Firestore::GetDocument(absl::string_view document_path) {
  EnsureClientConfigured();
  return DocumentReference{ResourcePath::FromString(document_path), this};
}

FIRWriteBatch* Firestore::GetBatch() {
  EnsureClientConfigured();
  FIRFirestore* wrapper = [FIRFirestore recoverFromFirestore:this];

  return [FIRWriteBatch writeBatchWithFirestore:wrapper];
}

FIRQuery* Firestore::GetCollectionGroup(NSString* collection_id) {
  EnsureClientConfigured();
  FIRFirestore* wrapper = [FIRFirestore recoverFromFirestore:this];

  return
      [FIRQuery referenceWithQuery:[FSTQuery queryWithPath:ResourcePath::Empty()
                                           collectionGroup:collection_id]
                         firestore:wrapper];
}

void Firestore::RunTransaction(core::TransactionUpdateBlock update_block,
                               core::TransactionCompletion completion) {
  EnsureClientConfigured();

  [client_ transactionWithRetries:5
                      updateBlock:std::move(update_block)
                       completion:std::move(completion)];
}

void Firestore::Shutdown(util::StatusCallback completion) {
  if (!client_) {
    if (completion) {
      // We should be dispatching the callback on the user dispatch queue
      // but if the client is nil here that queue was never created.
      completion(Status::OK());
    }
  } else {
    [client_ shutdownWithCompletion:completion];
  }
}

void Firestore::EnableNetwork(util::StatusCallback completion) {
  EnsureClientConfigured();
  [client_ enableNetworkWithCompletion:completion];
}

void Firestore::DisableNetwork(util::StatusCallback completion) {
  EnsureClientConfigured();
  [client_ disableNetworkWithCompletion:completion];
}

void Firestore::EnsureClientConfigured() {
  std::lock_guard<std::mutex> lock{mutex_};

  if (!client_) {
    DatabaseInfo database_info(database_id_, persistence_key_, settings_.host(),
                               settings_.ssl_enabled());

    HARD_ASSERT(worker_queue_, "Expected non-null worker queue");
    client_ =
        [FSTFirestoreClient clientWithDatabaseInfo:database_info
                                          settings:settings_
                               credentialsProvider:credentials_provider_.get()
                                      userExecutor:std::move(user_executor_)
                                       workerQueue:std::move(worker_queue_)];
  }
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
