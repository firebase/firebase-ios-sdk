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

@class FIRApp;
@class FIRCollectionReference;
@class FIRDocumentReference;
@class FIRFirestoreSettings;
@class FIRTransaction;
@class FIRWriteBatch;

NS_ASSUME_NONNULL_BEGIN

/**
 * `FIRFirestore` represents a Firestore Database and is the entry point for all Firestore
 * operations.
 */
NS_SWIFT_NAME(Firestore)
@interface FIRFirestore : NSObject

#pragma mark - Initializing
/**   */
- (instancetype)init __attribute__((unavailable("Use a static constructor method.")));

/**
 * Creates, caches, and returns a `FIRFirestore` using the default `FIRApp`. Each subsequent
 * invocation returns the same `FIRFirestore` object.
 *
 * @return The `FIRFirestore` instance.
 */
+ (instancetype)firestore NS_SWIFT_NAME(firestore());

/**
 * Creates, caches, and returns a `FIRFirestore` object for the specified _app_. Each subsequent
 * invocation returns the same `FIRFirestore` object.
 *
 * @param app The `FIRApp` instance to use for authentication and as a source of the Google Cloud
 * Project ID for your Firestore Database. If you want the default instance, you should explicitly
 * set it to `[FIRApp defaultApp]`.
 *
 * @return The `FIRFirestore` instance.
 */
+ (instancetype)firestoreForApp:(FIRApp *)app NS_SWIFT_NAME(firestore(app:));

/**
 * Custom settings used to configure this `FIRFirestore` object.
 */
@property(nonatomic, copy) FIRFirestoreSettings *settings;

/**
 * The Firebase App associated with this Firestore instance.
 */
@property(strong, nonatomic, readonly) FIRApp *app;

#pragma mark - Collections and Documents

/**
 * Gets a `FIRCollectionReference` referring to the collection at the specified path within the
 * database.
 *
 * @param collectionPath The slash-separated path of the collection for which to get a
 * `FIRCollectionReference`.
 *
 * @return The `FIRCollectionReference` at the specified _collectionPath_.
 */
- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath
    NS_SWIFT_NAME(collection(_:));

/**
 * Gets a `FIRDocumentReference` referring to the document at the specified path within the
 * database.
 *
 * @param documentPath The slash-separated path of the document for which to get a
 * `FIRDocumentReference`.
 *
 * @return The `FIRDocumentReference` for the specified _documentPath_.
 */
- (FIRDocumentReference *)documentWithPath:(NSString *)documentPath NS_SWIFT_NAME(document(_:));

#pragma mark - Transactions and Write Batches

/**
 * Executes the given updateBlock and then attempts to commit the changes applied within an atomic
 * transaction.
 *
 * In the updateBlock, a set of reads and writes can be performed atomically using the
 * `FIRTransaction` object passed to the block. After the updateBlock is run, Firestore will attempt
 * to apply the changes to the server. If any of the data read has been modified outside of this
 * transaction since being read, then the transaction will be retried by executing the updateBlock
 * again. If the transaction still fails after 5 retries, then the transaction will fail.
 *
 * Since the updateBlock may be executed multiple times, it should avoiding doing anything that
 * would cause side effects.
 *
 * Any value maybe be returned from the updateBlock. If the transaction is successfully committed,
 * then the completion block will be passed that value. The updateBlock also has an `NSError` out
 * parameter. If this is set, then the transaction will not attempt to commit, and the given error
 * will be passed to the completion block.
 *
 * The `FIRTransaction` object passed to the updateBlock contains methods for accessing documents
 * and collections. Unlike other firestore access, data accessed with the transaction will not
 * reflect local changes that have not been committed. For this reason, it is required that all
 * reads are performed before any writes. Transactions must be performed while online. Otherwise,
 * reads will fail, the final commit will fail, and the completion block will return an error.
 *
 * @param updateBlock The block to execute within the transaction context.
 * @param completion The block to call with the result or error of the transaction. This
 *     block will run even if the client is offline, unless the process is killed.
 */
- (void)runTransactionWithBlock:(id _Nullable (^)(FIRTransaction *, NSError **))updateBlock
                     completion:(void (^)(id _Nullable result, NSError *_Nullable error))completion;

/**
 * Creates a write batch, used for performing multiple writes as a single
 * atomic operation.
 *
 * Unlike transactions, write batches are persisted offline and therefore are preferable when you
 * don't need to condition your writes on read data.
 */
- (FIRWriteBatch *)batch;

#pragma mark - Logging

/** Enables or disables logging from the Firestore client. */
+ (void)enableLogging:(BOOL)logging
    DEPRECATED_MSG_ATTRIBUTE("Use FirebaseConfiguration.shared.setLoggerLevel(.debug) to enable "
                             "logging.");

#pragma mark - Network

/**
 * Re-enables usage of the network by this Firestore instance after a prior call to
 * `disableNetworkWithCompletion`. Completion block, if provided, will be called once network uasge
 * has been enabled.
 */
- (void)enableNetworkWithCompletion:(nullable void (^)(NSError *_Nullable error))completion;

/**
 * Disables usage of the network by this Firestore instance. It can be re-enabled by via
 * `enableNetworkWithCompletion`. While the network is disabled, any snapshot listeners or get calls
 * will return results from cache and any write operations will be queued until the network is
 * restored. The completion block, if provided, will be called once network usage has been disabled.
 */
- (void)disableNetworkWithCompletion:(nullable void (^)(NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
