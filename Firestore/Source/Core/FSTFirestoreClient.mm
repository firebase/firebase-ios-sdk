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
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/src/firebase/firestore/api/settings.h"
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/core/event_manager.h"
#include "Firestore/core/src/firebase/firestore/core/firestore_client.h"
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

namespace util = firebase::firestore::util;
using firebase::firestore::Error;
using firebase::firestore::api::DocumentReference;
using firebase::firestore::api::DocumentSnapshot;
using firebase::firestore::api::Settings;
using firebase::firestore::api::SnapshotMetadata;
using firebase::firestore::api::ThrowIllegalState;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::EventManager;
using firebase::firestore::core::FirestoreClient;
using firebase::firestore::core::Query;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::local::LruParams;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::Mutation;
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

@interface FSTFirestoreClient () {
}

- (instancetype)initWithDatabaseInfo:(const DatabaseInfo &)databaseInfo
                            settings:(const Settings &)settings
                 credentialsProvider:(std::shared_ptr<CredentialsProvider>)credentialsProvider
                        userExecutor:(std::shared_ptr<Executor>)userExecutor
                         workerQueue:(std::shared_ptr<AsyncQueue>)queue NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTFirestoreClient {
  // Firestore client is supposed to be accessed via shared_ptr.
  std::shared_ptr<FirestoreClient> internalClient_;
}

- (const std::shared_ptr<util::Executor> &)userExecutor {
  return internalClient_->user_executor();
}

- (const std::shared_ptr<util::AsyncQueue> &)workerQueue {
  return internalClient_->worker_queue();
}

- (bool)isShutdown {
  return internalClient_->is_shutdown();
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
    internalClient_ =
        FirestoreClient::Create(databaseInfo, settings, std::move(credentialsProvider),
                                std::move(userExecutor), std::move(workerQueue));
  }
  return self;
}

- (void)disableNetworkWithCallback:(util::StatusCallback)callback {
  internalClient_->DisableNetwork(std::move(callback));
}

- (void)enableNetworkWithCallback:(util::StatusCallback)callback {
  internalClient_->EnableNetwork(std::move(callback));
}

- (void)shutdownWithCallback:(util::StatusCallback)callback {
  internalClient_->Shutdown(std::move(callback));
}

- (std::shared_ptr<QueryListener>)listenToQuery:(Query)query
                                        options:(core::ListenOptions)options
                                       listener:(ViewSnapshot::SharedListener &&)listener {
  return internalClient_->ListenToQuery(std::move(query), std::move(options), std::move(listener));
}

- (void)removeListener:(const std::shared_ptr<QueryListener> &)listener {
  internalClient_->RemoveListener(std::move(listener));
}

- (void)getDocumentFromLocalCache:(const DocumentReference &)doc
                         callback:(DocumentSnapshot::Listener &&)callback {
  internalClient_->GetDocumentFromLocalCache(doc, std::move(callback));
}

- (void)getDocumentsFromLocalCache:(const api::Query &)query
                          callback:(api::QuerySnapshot::Listener &&)callback {
  internalClient_->GetDocumentsFromLocalCache(query, std::move(callback));
}

- (void)writeMutations:(std::vector<Mutation> &&)mutations callback:(util::StatusCallback)callback {
  internalClient_->WriteMutations(std::move(mutations), std::move(callback));
};

- (void)waitForPendingWritesWithCallback:(util::StatusCallback)callback {
  internalClient_->WaitForPendingWrites(std::move(callback));
}

- (void)transactionWithRetries:(int)retries
                updateCallback:(core::TransactionUpdateCallback)update_callback
                resultCallback:(core::TransactionResultCallback)resultCallback {
  internalClient_->Transaction(retries, std::move(update_callback), std::move(resultCallback));
}

- (const DatabaseId &)databaseID {
  return internalClient_->database_id();
}

@end

NS_ASSUME_NONNULL_END
