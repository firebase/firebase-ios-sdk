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

#import "FSTRemoteStore.h"
#import "FSTTypes.h"
#import "FSTViewSnapshot.h"

@class FSTDatabaseID;
@class FSTDatabaseInfo;
@class FSTDispatchQueue;
@class FSTDocument;
@class FSTListenOptions;
@class FSTMutation;
@class FSTQuery;
@class FSTQueryListener;
@class FSTTransaction;
@protocol FSTCredentialsProvider;

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
 * All callbacks and events will be triggered on the provided userDispatchQueue.
 */
+ (instancetype)clientWithDatabaseInfo:(FSTDatabaseInfo *)databaseInfo
                        usePersistence:(BOOL)usePersistence
                   credentialsProvider:(id<FSTCredentialsProvider>)credentialsProvider
                     userDispatchQueue:(FSTDispatchQueue *)userDispatchQueue
                   workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue;

- (instancetype)init __attribute__((unavailable("Use static constructor method.")));

/** Shuts down this client, cancels all writes / listeners, and releases all resources. */
- (void)shutdownWithCompletion:(nullable FSTVoidErrorBlock)completion;

/** Starts listening to a query. */
- (FSTQueryListener *)listenToQuery:(FSTQuery *)query
                            options:(FSTListenOptions *)options
                viewSnapshotHandler:(FSTViewSnapshotHandler)viewSnapshotHandler;

/** Stops listening to a query previously listened to. */
- (void)removeListener:(FSTQueryListener *)listener;

/** Write mutations. completion will be notified when it's written to the backend. */
- (void)writeMutations:(NSArray<FSTMutation *> *)mutations
            completion:(nullable FSTVoidErrorBlock)completion;

/** Tries to execute the transaction in updateBlock up to retries times. */
- (void)transactionWithRetries:(int)retries
                   updateBlock:(FSTTransactionBlock)updateBlock
                    completion:(FSTVoidIDErrorBlock)completion;

/** The database ID of the databaseInfo this client was initialized with. */
@property(nonatomic, strong, readonly) FSTDatabaseID *databaseID;

/**
 * Dispatch queue for user callbacks / events. This will often be the "Main Dispatch Queue" of the
 * app but the developer can configure it to a different queue if they so choose.
 */
@property(nonatomic, strong, readonly) FSTDispatchQueue *userDispatchQueue;

@end

NS_ASSUME_NONNULL_END
