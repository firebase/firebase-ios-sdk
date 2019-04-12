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

#import "FIRFirestoreSettings.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRTransaction+Internal.h"
#import "Firestore/Source/API/FIRWriteBatch+Internal.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"

#include "Firestore/core/src/firebase/firestore/api/document_reference.h"
#include "Firestore/core/src/firebase/firestore/auth/firebase_credentials_provider_apple.h"
#include "Firestore/core/src/firebase/firestore/core/transaction.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace api {

using firebase::firestore::api::Firestore;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::core::Transaction;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ResourcePath;
using util::AsyncQueue;
using util::Executor;
using util::ExecutorLibdispatch;

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
  settings_ = [[FIRFirestoreSettings alloc] init];
}

AsyncQueue* Firestore::worker_queue() {
  return [client_ workerQueue];
}

FIRFirestoreSettings* Firestore::settings() const {
  std::lock_guard<std::mutex> lock{mutex_};
  // Disallow mutation of our internal settings
  return [settings_ copy];
}

void Firestore::set_settings(FIRFirestoreSettings* settings) {
  std::lock_guard<std::mutex> lock{mutex_};
  // As a special exception, don't throw if the same settings are passed
  // repeatedly. This should make it more friendly to create a Firestore
  // instance.
  if (client_ && ![settings_ isEqual:settings]) {
    HARD_FAIL(
        "Firestore instance has already been started and its settings can "
        "no longer be changed. You can only set settings before calling any "
        "other methods on a Firestore instance.");
  }
  settings_ = [settings copy];
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

void Firestore::RunTransaction(TransactionBlock update_block,
                               dispatch_queue_t queue,
                               ResultOrErrorCompletion completion) {
  EnsureClientConfigured();
  FIRFirestore* wrapper = [FIRFirestore recoverFromFirestore:this];

  FSTTransactionBlock wrapped_update =
      ^(std::shared_ptr<Transaction> internal_transaction,
        void (^internal_completion)(id _Nullable, NSError* _Nullable)) {
        FIRTransaction* transaction = [FIRTransaction
            transactionWithInternalTransaction:std::move(internal_transaction)
                                     firestore:wrapper];

        dispatch_async(queue, ^{
          NSError* _Nullable error = nil;
          id _Nullable result = update_block(transaction, &error);
          if (error) {
            // Force the result to be nil in the case of an error, in case the
            // user set both.
            result = nil;
          }
          internal_completion(result, error);
        });
      };

  [client_ transactionWithRetries:5
                      updateBlock:wrapped_update
                       completion:completion];
}

void Firestore::Shutdown(ErrorCompletion completion) {
  if (!client_) {
    if (completion) {
      // We should be dispatching the callback on the user dispatch queue
      // but if the client is nil here that queue was never created.
      completion(nil);
    }
  } else {
    [client_ shutdownWithCompletion:completion];
  }
}

void Firestore::EnableNetwork(ErrorCompletion completion) {
  EnsureClientConfigured();
  [client_ enableNetworkWithCompletion:completion];
}

void Firestore::DisableNetwork(ErrorCompletion completion) {
  EnsureClientConfigured();
  [client_ disableNetworkWithCompletion:completion];
}

void Firestore::EnsureClientConfigured() {
  std::lock_guard<std::mutex> lock{mutex_};

  if (!client_) {
    // These values are validated elsewhere; this is just double-checking:
    HARD_ASSERT(settings_.host, "FirestoreSettings.host cannot be nil.");
    HARD_ASSERT(settings_.dispatchQueue,
                "FirestoreSettings.dispatchQueue cannot be nil.");

    DatabaseInfo database_info(database_id_, persistence_key_,
                               util::MakeString(settings_.host),
                               settings_.sslEnabled);

    std::unique_ptr<Executor> user_executor =
        absl::make_unique<ExecutorLibdispatch>(settings_.dispatchQueue);

    HARD_ASSERT(worker_queue_, "Expected non-null worker queue");
    client_ =
        [FSTFirestoreClient clientWithDatabaseInfo:database_info
                                          settings:settings_
                               credentialsProvider:credentials_provider_.get()
                                      userExecutor:std::move(user_executor)
                                       workerQueue:std::move(worker_queue_)];
  }
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
