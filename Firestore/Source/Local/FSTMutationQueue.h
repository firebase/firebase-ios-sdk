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

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

@class FSTMutation;
@class FSTMutationBatch;
@class FSTQuery;
@class FIRTimestamp;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMutationQueue

/** A queue of mutations to apply to the remote store. */
@protocol FSTMutationQueue <NSObject>

/**
 * Starts the mutation queue, performing any initial reads that might be required to establish
 * invariants, etc.
 *
 * After starting, the mutation queue must guarantee that the highestAcknowledgedBatchID is less
 * than nextBatchID. This prevents the local store from creating new batches that the mutation
 * queue would consider erroneously acknowledged.
 */
- (void)start;

/** Returns YES if this queue contains no mutation batches. */
- (BOOL)isEmpty;

/**
 * Returns the highest batchID that has been acknowledged. If no batches have been acknowledged
 * or if there are no batches in the queue this can return kFSTBatchIDUnknown.
 */
- (firebase::firestore::model::BatchId)highestAcknowledgedBatchID;

/** Acknowledges the given batch. */
- (void)acknowledgeBatch:(FSTMutationBatch *)batch streamToken:(nullable NSData *)streamToken;

/** Returns the current stream token for this mutation queue. */
- (nullable NSData *)lastStreamToken;

/** Sets the stream token for this mutation queue. */
- (void)setLastStreamToken:(nullable NSData *)streamToken;

/** Creates a new mutation batch and adds it to this mutation queue. */
- (FSTMutationBatch *)addMutationBatchWithWriteTime:(FIRTimestamp *)localWriteTime
                                          mutations:(NSArray<FSTMutation *> *)mutations;

/** Loads the mutation batch with the given batchID. */
- (nullable FSTMutationBatch *)lookupMutationBatch:(firebase::firestore::model::BatchId)batchID;

/**
 * Gets the first unacknowledged mutation batch after the passed in batchId in the mutation queue
 * or nil if empty.
 *
 * @param batchID The batch to search after, or kFSTBatchIDUnknown for the first mutation in the
 * queue.
 *
 * @return the next mutation or nil if there wasn't one.
 */
- (nullable FSTMutationBatch *)nextMutationBatchAfterBatchID:
    (firebase::firestore::model::BatchId)batchID;

/** Gets all mutation batches in the mutation queue. */
// TODO(mikelehen): PERF: Current consumer only needs mutated keys; if we can provide that
// cheaply, we should replace this.
- (NSArray<FSTMutationBatch *> *)allMutationBatches;

/**
 * Finds all mutation batches that could @em possibly affect the given document key. Not all
 * mutations in a batch will necessarily affect the document key, so when looping through the
 * batch you'll need to check that the mutation itself matches the key.
 *
 * Note that because of this requirement implementations are free to return mutation batches that
 * don't contain the document key at all if it's convenient.
 */
// TODO(mcg): This should really return an NSEnumerator
- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKey:
    (const firebase::firestore::model::DocumentKey &)documentKey;

/**
 * Finds all mutation batches that could @em possibly affect the given document keys. Not all
 * mutations in a batch will necessarily affect each key, so when looping through the batches you'll
 * need to check that the mutation itself matches the key.
 *
 * Note that because of this requirement implementations are free to return mutation batches that
 * don't contain any of the given document keys at all if it's convenient.
 */
// TODO(mcg): This should really return an NSEnumerator
- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKeys:
    (const firebase::firestore::model::DocumentKeySet &)documentKeys;

/**
 * Finds all mutation batches that could affect the results for the given query. Not all
 * mutations in a batch will necessarily affect the query, so when looping through the batch
 * you'll need to check that the mutation itself matches the query.
 *
 * Note that because of this requirement implementations are free to return mutation batches that
 * don't match the query at all if it's convenient.
 *
 * NOTE: A FSTPatchMutation does not need to include all fields in the query filter criteria in
 * order to be a match (but any fields it does contain do need to match).
 */
// TODO(mikelehen): This should perhaps return an NSEnumerator, though I'm not sure we can avoid
// loading them all in memory.
- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingQuery:(FSTQuery *)query;

/**
 * Removes the given mutation batch from the queue. This is useful in two circumstances:
 *
 * + Removing applied mutations from the head of the queue
 * + Removing rejected mutations from anywhere in the queue
 */
- (void)removeMutationBatch:(FSTMutationBatch *)batch;

/** Performs a consistency check, examining the mutation queue for any leaks, if possible. */
- (void)performConsistencyCheck;

@end

NS_ASSUME_NONNULL_END
