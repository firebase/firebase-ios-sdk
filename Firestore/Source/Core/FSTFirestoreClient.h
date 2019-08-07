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

#import <Foundation/Foundation.h>

#include <memory>
#include <vector>

#import "Firestore/Source/Core/FSTTypes.h"

#include "Firestore/core/src/firebase/firestore/api/document_reference.h"
#include "Firestore/core/src/firebase/firestore/api/document_snapshot.h"
#include "Firestore/core/src/firebase/firestore/api/query_core.h"
#include "Firestore/core/src/firebase/firestore/api/settings.h"
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/core/listen_options.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/core/query_listener.h"
#include "Firestore/core/src/firebase/firestore/core/transaction.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "Firestore/core/src/firebase/firestore/util/statusor_callback.h"

@class FIRDocumentReference;
@class FIRDocumentSnapshot;
@class FIRQuery;
@class FIRQuerySnapshot;
@class FSTDatabaseID;
@class FSTDatabaseInfo;
@class FSTMutation;
@class FSTTransaction;

namespace api = firebase::firestore::api;
namespace auth = firebase::firestore::auth;
namespace core = firebase::firestore::core;
namespace model = firebase::firestore::model;
namespace util = firebase::firestore::util;

NS_ASSUME_NONNULL_BEGIN

/**
 * FirestoreClient is a top-level class that constructs and owns all of the pieces of the client
 * SDK architecture. It is responsible for creating the worker queue that is shared by all of the
 * other components in the system.
 */
@interface FSTFirestoreClient : NSObject

/**
 * Creates and returns a FSTFirestoreClient with the given parameters.
 *
 * All callbacks and events will be triggered on the provided userExecutor.
 */
+ (instancetype)clientWithDatabaseInfo:(const core::DatabaseInfo &)databaseInfo
                              settings:(const api::Settings &)settings
                   credentialsProvider:
                       (std::shared_ptr<auth::CredentialsProvider>)credentialsProvider
                          userExecutor:(std::shared_ptr<util::Executor>)userExecutor
                           workerQueue:(std::shared_ptr<util::AsyncQueue>)workerQueue;

- (instancetype)init NS_UNAVAILABLE;

/** Shuts down this client, cancels all writes / listeners, and releases all resources. */
- (void)shutdownWithCallback:(util::StatusCallback)callback;

/** Disables the network connection. Pending operations will not complete. */
- (void)disableNetworkWithCallback:(util::StatusCallback)callback;

/** Enables the network connection and requeues all pending operations. */
- (void)enableNetworkWithCallback:(util::StatusCallback)callback;

/** Starts listening to a query. */
- (std::shared_ptr<core::QueryListener>)listenToQuery:(core::Query)query
                                              options:(core::ListenOptions)options
                                             listener:
                                                 (core::ViewSnapshot::SharedListener &&)listener;

/** Stops listening to a query previously listened to. */
- (void)removeListener:(const std::shared_ptr<core::QueryListener> &)listener;

/**
 * Retrieves a document from the cache via the indicated callback. If the doc
 * doesn't exist, an error will be sent to the callback.
 */
- (void)getDocumentFromLocalCache:(const api::DocumentReference &)doc
                         callback:(api::DocumentSnapshot::Listener &&)callback;

/**
 * Retrieves a (possibly empty) set of documents from the cache via the
 * indicated completion.
 */
- (void)getDocumentsFromLocalCache:(const api::Query &)query
                          callback:(api::QuerySnapshot::Listener &&)callback;

/** Write mutations. callback will be notified when it's written to the backend. */
- (void)writeMutations:(std::vector<FSTMutation *> &&)mutations
              callback:(util::StatusCallback)callback;

/** Tries to execute the transaction in updateCallback up to retries times. */
- (void)transactionWithRetries:(int)retries
                updateCallback:(core::TransactionUpdateCallback)updateCallback
                resultCallback:(core::TransactionResultCallback)resultCallback;

/** The database ID of the databaseInfo this client was initialized with. */
@property(nonatomic, assign, readonly) const model::DatabaseId &databaseID;

/**
 * Dispatch queue for user callbacks / events. This will often be the "Main Dispatch Queue" of the
 * app but the developer can configure it to a different queue if they so choose.
 */
- (const std::shared_ptr<util::Executor> &)userExecutor;

/** For testing only. */
- (const std::shared_ptr<util::AsyncQueue> &)workerQueue;

- (bool)isShutdown;

@end

NS_ASSUME_NONNULL_END
