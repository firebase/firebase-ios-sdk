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

#include <unordered_map>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

@class FIRTimestamp;
@class FSTMaybeDocument;
@class FSTMutation;
@class FSTMutationResult;
@class FSTMutationBatchResult;

namespace firebase {
namespace firestore {
namespace model {

// TODO(wilhuff): make this type a member of MutationBatchResult once that's a C++ class.
using DocumentVersionMap = std::unordered_map<DocumentKey, SnapshotVersion, DocumentKeyHash>;

}  // namespace model
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_BEGIN

/**
 * A batch of mutations that will be sent as one unit to the backend. Batches can be marked as a
 * tombstone if the mutation queue does not remove them immediately. When a batch is a tombstone
 * it has no mutations.
 */
@interface FSTMutationBatch : NSObject

/**
 * Initializes a mutation batch with the given batchID, localWriteTime, base mutations, and
 * mutations.
 */
- (instancetype)initWithBatchID:(firebase::firestore::model::BatchId)batchID
                 localWriteTime:(FIRTimestamp *)localWriteTime
                  baseMutations:(std::vector<FSTMutation *> &&)baseMutations
                      mutations:(std::vector<FSTMutation *> &&)mutations NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

/**
 * Applies all the mutations in this FSTMutationBatch to the specified document to create a new
 * remote document.
 *
 * @param maybeDoc The document to apply mutations to.
 * @param documentKey The key of the document to apply mutations to.
 * @param mutationBatchResult The result of applying the MutationBatch to the backend. If omitted
 *   it's assumed that this is a local (latency-compensated) application and documents will have
 *   their hasLocalMutations flag set.
 */
- (FSTMaybeDocument *_Nullable)
    applyToRemoteDocument:(FSTMaybeDocument *_Nullable)maybeDoc
              documentKey:(const firebase::firestore::model::DocumentKey &)documentKey
      mutationBatchResult:(FSTMutationBatchResult *_Nullable)mutationBatchResult;

/**
 * A helper version of applyTo for applying mutations locally (without a mutation batch result from
 * the backend).
 */
- (FSTMaybeDocument *_Nullable)
    applyToLocalDocument:(FSTMaybeDocument *_Nullable)maybeDoc
             documentKey:(const firebase::firestore::model::DocumentKey &)documentKey;

/** Computes the local view for all provided documents given the mutations in this batch. */
- (firebase::firestore::model::MaybeDocumentMap)applyToLocalDocumentSet:
    (const firebase::firestore::model::MaybeDocumentMap &)documentSet;

/** Returns the set of unique keys referenced by all mutations in the batch. */
- (firebase::firestore::model::DocumentKeySet)keys;

/** The unique ID of this mutation batch. */
@property(nonatomic, assign, readonly) firebase::firestore::model::BatchId batchID;

/** The original write time of this mutation. */
@property(nonatomic, strong, readonly) FIRTimestamp *localWriteTime;

/**
 * Mutations that are used to populate the base values when this mutation is applied locally. This
 * can be used to locally overwrite values that are persisted in the remote document cache. Base
 * mutations are never sent to the backend.
 */
- (const std::vector<FSTMutation *> &)baseMutations;

/**
 * The user-provided mutations in this mutation batch. User-provided mutations are applied both
 * locally and remotely on the backend.
 */
- (const std::vector<FSTMutation *> &)mutations;

@end

#pragma mark - FSTMutationBatchResult

/** The result of applying a mutation batch to the backend. */
@interface FSTMutationBatchResult : NSObject

- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a new FSTMutationBatchResult for the given batch and results. There must be one result
 * for each mutation in the batch. This static factory caches a document=>version mapping
 * (as docVersions).
 */
+ (instancetype)resultWithBatch:(FSTMutationBatch *)batch
                  commitVersion:(firebase::firestore::model::SnapshotVersion)commitVersion
                mutationResults:(std::vector<FSTMutationResult *>)mutationResults
                    streamToken:(nullable NSData *)streamToken;

- (const firebase::firestore::model::SnapshotVersion &)commitVersion;
- (const std::vector<FSTMutationResult *> &)mutationResults;

@property(nonatomic, strong, readonly) FSTMutationBatch *batch;
@property(nonatomic, strong, readonly, nullable) NSData *streamToken;

- (const firebase::firestore::model::DocumentVersionMap &)docVersions;

@end

NS_ASSUME_NONNULL_END
