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

#import "Firestore/Source/Core/FSTTypes.h"

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"

@class FSTDocumentKey;
@class FSTDispatchQueue;
@class FSTMutation;
@class FSTMutationResult;
@class FSTQueryData;
@class FSTSerializerBeta;
@class FSTSnapshotVersion;
@class FSTWatchChange;
@class FSTWatchStream;
@class FSTWriteStream;
@class GRPCCall;
@class GRXWriter;

@protocol FSTCredentialsProvider;

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTDatastore represents a proxy for the remote server, hiding details of the RPC layer. It:
 *
 *   - Manages connections to the server
 *   - Authenticates to the server
 *   - Manages threading and keeps higher-level code running on the worker queue
 *   - Serializes internal model objects to and from protocol buffers
 *
 * The FSTDatastore is generally not responsible for understanding the higher-level protocol
 * involved in actually making changes or reading data, and aside from the connections it manages
 * is otherwise stateless.
 */
@interface FSTDatastore : NSObject

/** Creates a new Datastore instance with the given database info. */
+ (instancetype)datastoreWithDatabase:(const firebase::firestore::core::DatabaseInfo *)databaseInfo
                  workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                          credentials:(id<FSTCredentialsProvider>)credentials;

- (instancetype)init __attribute__((unavailable("Use a static constructor method.")));

- (instancetype)initWithDatabaseInfo:(const firebase::firestore::core::DatabaseInfo *)databaseInfo
                 workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                         credentials:(id<FSTCredentialsProvider>)credentials
    NS_DESIGNATED_INITIALIZER;

/**
 * Takes a dictionary of (HTTP) response headers and returns the set of whitelisted headers
 * (for logging purposes).
 */
+ (NSDictionary<NSString *, NSString *> *)extractWhiteListedHeaders:
    (NSDictionary<NSString *, NSString *> *)header;

/** Converts the error to a FIRFirestoreErrorDomain error. */
+ (NSError *)firestoreErrorForError:(NSError *)error;

/** Returns YES if the given error is a GRPC ABORTED error. **/
+ (BOOL)isAbortedError:(NSError *)error;

/** Returns YES if the given error indicates the RPC associated with it may not be retried. */
+ (BOOL)isPermanentWriteError:(NSError *)error;

/** Adds headers to the RPC including any OAuth access token if provided .*/
+ (void)prepareHeadersForRPC:(GRPCCall *)rpc
                  databaseID:(const firebase::firestore::model::DatabaseId *)databaseID
                       token:(nullable NSString *)token;

/** Looks up a list of documents in datastore. */
- (void)lookupDocuments:(NSArray<FSTDocumentKey *> *)keys
             completion:(FSTVoidMaybeDocumentArrayErrorBlock)completion;

/** Commits data to datastore. */
- (void)commitMutations:(NSArray<FSTMutation *> *)mutations
             completion:(FSTVoidErrorBlock)completion;

/** Creates a new watch stream. */
- (FSTWatchStream *)createWatchStream;

/** Creates a new write stream. */
- (FSTWriteStream *)createWriteStream;

/** The name of the database and the backend. */
// Does not own this DatabaseInfo.
@property(nonatomic, assign, readonly) const firebase::firestore::core::DatabaseInfo *databaseInfo;

@end

NS_ASSUME_NONNULL_END
