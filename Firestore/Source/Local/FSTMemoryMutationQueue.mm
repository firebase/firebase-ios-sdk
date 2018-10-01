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

#import "Firestore/Source/Local/FSTMemoryMutationQueue.h"

#import <Protobuf/GPBProtocolBuffers.h>

#include <set>

#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTDocumentReference.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/third_party/Immutable/FSTImmutableSortedSet.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ResourcePath;

NS_ASSUME_NONNULL_BEGIN

static const NSComparator NumberComparator = ^NSComparisonResult(NSNumber *left, NSNumber *right) {
  return [left compare:right];
};

@interface FSTMemoryMutationQueue ()

/**
 * A FIFO queue of all mutations to apply to the backend. Mutations are added to the end of the
 * queue as they're written, and removed from the front of the queue as the mutations become
 * visible or are rejected.
 *
 * When successfully applied, mutations must be acknowledged by the write stream and made visible
 * on the watch stream. It's possible for the watch stream to fall behind in which case the batches
 * at the head of the queue will be acknowledged but held until the watch stream sees the changes.
 *
 * If a batch is rejected while there are held write acknowledgements at the head of the queue
 * the rejected batch is converted to a tombstone: its mutations are removed but the batch remains
 * in the queue. This maintains a simple consecutive ordering of batches in the queue.
 *
 * Once the held write acknowledgements become visible they are removed from the head of the queue
 * along with any tombstones that follow.
 */
@property(nonatomic, strong, readonly) NSMutableArray<FSTMutationBatch *> *queue;

/** An ordered mapping between documents and the mutation batch IDs. */
@property(nonatomic, strong) FSTImmutableSortedSet<FSTDocumentReference *> *batchesByDocumentKey;

/** The next value to use when assigning sequential IDs to each mutation batch. */
@property(nonatomic, assign) BatchId nextBatchID;

/** The highest acknowledged mutation in the queue. */
@property(nonatomic, assign) BatchId highestAcknowledgedBatchID;

/**
 * The last received stream token from the server, used to acknowledge which responses the client
 * has processed. Stream tokens are opaque checkpoint markers whose only real value is their
 * inclusion in the next request.
 */
@property(nonatomic, strong, nullable) NSData *lastStreamToken;

@end

@implementation FSTMemoryMutationQueue {
  FSTMemoryPersistence *_persistence;
}

- (instancetype)initWithPersistence:(FSTMemoryPersistence *)persistence {
  if (self = [super init]) {
    _persistence = persistence;
    _queue = [NSMutableArray array];
    _batchesByDocumentKey =
        [FSTImmutableSortedSet setWithComparator:FSTDocumentReferenceComparatorByKey];

    _nextBatchID = 1;
    _highestAcknowledgedBatchID = kFSTBatchIDUnknown;
  }
  return self;
}

#pragma mark - FSTMutationQueue implementation

- (void)start {
  // Note: The queue may be shutdown / started multiple times, since we maintain the queue for the
  // duration of the app session in case a user logs out / back in. To behave like the
  // LevelDB-backed MutationQueue (and accommodate tests that expect as much), we reset nextBatchID
  // and highestAcknowledgedBatchID if the queue is empty.
  if (self.isEmpty) {
    self.nextBatchID = 1;
    self.highestAcknowledgedBatchID = kFSTBatchIDUnknown;
  }
  HARD_ASSERT(self.highestAcknowledgedBatchID < self.nextBatchID,
              "highestAcknowledgedBatchID must be less than the nextBatchID");
}

- (BOOL)isEmpty {
  // If the queue has any entries at all, the first entry must not be a tombstone (otherwise it
  // would have been removed already).
  return self.queue.count == 0;
}

- (BatchId)highestAcknowledgedBatchID {
  return _highestAcknowledgedBatchID;
}

- (void)acknowledgeBatch:(FSTMutationBatch *)batch streamToken:(nullable NSData *)streamToken {
  NSMutableArray<FSTMutationBatch *> *queue = self.queue;

  BatchId batchID = batch.batchID;
  HARD_ASSERT(batchID > self.highestAcknowledgedBatchID,
              "Mutation batchIDs must be acknowledged in order");

  NSInteger batchIndex = [self indexOfExistingBatchID:batchID action:@"acknowledged"];

  // Verify that the batch in the queue is the one to be acknowledged.
  FSTMutationBatch *check = queue[(NSUInteger)batchIndex];
  HARD_ASSERT(batchID == check.batchID, "Queue ordering failure: expected batch %s, got batch %s",
              batchID, check.batchID);
  HARD_ASSERT(![check isTombstone], "Can't acknowledge a previously removed batch");

  self.highestAcknowledgedBatchID = batchID;
  self.lastStreamToken = streamToken;
}

- (FSTMutationBatch *)addMutationBatchWithWriteTime:(FIRTimestamp *)localWriteTime
                                          mutations:(NSArray<FSTMutation *> *)mutations {
  HARD_ASSERT(mutations.count > 0, "Mutation batches should not be empty");

  BatchId batchID = self.nextBatchID;
  self.nextBatchID += 1;

  NSMutableArray<FSTMutationBatch *> *queue = self.queue;
  if (queue.count > 0) {
    FSTMutationBatch *prior = queue[queue.count - 1];
    HARD_ASSERT(prior.batchID < batchID,
                "Mutation batchIDs must be monotonically increasing order");
  }

  FSTMutationBatch *batch = [[FSTMutationBatch alloc] initWithBatchID:batchID
                                                       localWriteTime:localWriteTime
                                                            mutations:mutations];
  [queue addObject:batch];

  // Track references by document key.
  FSTImmutableSortedSet<FSTDocumentReference *> *references = self.batchesByDocumentKey;
  for (FSTMutation *mutation in batch.mutations) {
    references = [references
        setByAddingObject:[[FSTDocumentReference alloc] initWithKey:mutation.key ID:batchID]];
  }
  self.batchesByDocumentKey = references;

  return batch;
}

- (nullable FSTMutationBatch *)lookupMutationBatch:(BatchId)batchID {
  NSMutableArray<FSTMutationBatch *> *queue = self.queue;

  NSInteger index = [self indexOfBatchID:batchID];
  if (index < 0 || index >= queue.count) {
    return nil;
  }

  FSTMutationBatch *batch = queue[(NSUInteger)index];
  HARD_ASSERT(batch.batchID == batchID, "If found batch must match");
  return [batch isTombstone] ? nil : batch;
}

- (nullable FSTMutationBatch *)nextMutationBatchAfterBatchID:(BatchId)batchID {
  NSMutableArray<FSTMutationBatch *> *queue = self.queue;
  NSUInteger count = queue.count;

  // All batches with batchID <= self.highestAcknowledgedBatchID have been acknowledged so the
  // first unacknowledged batch after batchID will have a batchID larger than both of these values.
  BatchId nextBatchID = MAX(batchID, self.highestAcknowledgedBatchID) + 1;

  // The requested batchID may still be out of range so normalize it to the start of the queue.
  NSInteger rawIndex = [self indexOfBatchID:nextBatchID];
  NSUInteger index = rawIndex < 0 ? 0 : (NSUInteger)rawIndex;

  // Finally return the first non-tombstone batch.
  for (; index < count; index++) {
    FSTMutationBatch *batch = queue[index];
    if (![batch isTombstone]) {
      return batch;
    }
  }

  return nil;
}

- (NSArray<FSTMutationBatch *> *)allMutationBatches {
  return [self allLiveMutationBatchesBeforeIndex:self.queue.count];
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesThroughBatchID:(BatchId)batchID {
  NSMutableArray<FSTMutationBatch *> *queue = self.queue;
  NSUInteger count = queue.count;

  NSInteger endIndex = [self indexOfBatchID:batchID];
  if (endIndex < 0) {
    endIndex = 0;
  } else if (endIndex >= count) {
    endIndex = count;
  } else {
    // The endIndex is in the queue so increment to pull everything in the queue including it.
    endIndex += 1;
  }

  return [self allLiveMutationBatchesBeforeIndex:(NSUInteger)endIndex];
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKey:
    (const DocumentKey &)documentKey {
  FSTDocumentReference *start = [[FSTDocumentReference alloc] initWithKey:documentKey ID:0];

  NSMutableArray<FSTMutationBatch *> *result = [NSMutableArray array];
  FSTDocumentReferenceBlock block = ^(FSTDocumentReference *reference, BOOL *stop) {
    if (![documentKey isEqualToKey:reference.key]) {
      *stop = YES;
      return;
    }

    FSTMutationBatch *batch = [self lookupMutationBatch:reference.ID];
    HARD_ASSERT(batch, "Batches in the index must exist in the main table");
    [result addObject:batch];
  };

  [self.batchesByDocumentKey enumerateObjectsFrom:start to:nil usingBlock:block];
  return result;
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKeys:
    (const DocumentKeySet &)documentKeys {
  // First find the set of affected batch IDs.
  __block std::set<BatchId> batchIDs;
  for (const DocumentKey &key : documentKeys) {
    FSTDocumentReference *start = [[FSTDocumentReference alloc] initWithKey:key ID:0];

    FSTDocumentReferenceBlock block = ^(FSTDocumentReference *reference, BOOL *stop) {
      if (![key isEqualToKey:reference.key]) {
        *stop = YES;
        return;
      }

      batchIDs.insert(reference.ID);
    };

    [self.batchesByDocumentKey enumerateObjectsFrom:start to:nil usingBlock:block];
  }

  return [self allMutationBatchesWithBatchIDs:batchIDs];
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingQuery:(FSTQuery *)query {
  // Use the query path as a prefix for testing if a document matches the query.
  const ResourcePath &prefix = query.path;
  size_t immediateChildrenPathLength = prefix.size() + 1;

  // Construct a document reference for actually scanning the index. Unlike the prefix, the document
  // key in this reference must have an even number of segments. The empty segment can be used as
  // a suffix of the query path because it precedes all other segments in an ordered traversal.
  ResourcePath startPath = query.path;
  if (!DocumentKey::IsDocumentKey(startPath)) {
    startPath = startPath.Append("");
  }
  FSTDocumentReference *start =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey{startPath} ID:0];

  // Find unique batchIDs referenced by all documents potentially matching the query.
  __block std::set<BatchId> uniqueBatchIDs;
  FSTDocumentReferenceBlock block = ^(FSTDocumentReference *reference, BOOL *stop) {
    const ResourcePath &rowKeyPath = reference.key.path();
    if (!prefix.IsPrefixOf(rowKeyPath)) {
      *stop = YES;
      return;
    }

    // Rows with document keys more than one segment longer than the query path can't be matches.
    // For example, a query on 'rooms' can't match the document /rooms/abc/messages/xyx.
    // TODO(mcg): we'll need a different scanner when we implement ancestor queries.
    if (rowKeyPath.size() != immediateChildrenPathLength) {
      return;
    }

    uniqueBatchIDs.insert(reference.ID);
  };
  [self.batchesByDocumentKey enumerateObjectsFrom:start to:nil usingBlock:block];

  return [self allMutationBatchesWithBatchIDs:uniqueBatchIDs];
}

/**
 * Constructs an array of matching batches, sorted by batchID to ensure that multiple mutations
 * affecting the same document key are applied in order.
 */
- (NSArray<FSTMutationBatch *> *)allMutationBatchesWithBatchIDs:
    (const std::set<BatchId> &)batchIDs {
  NSMutableArray<FSTMutationBatch *> *result = [NSMutableArray array];
  for (BatchId batchID : batchIDs) {
    FSTMutationBatch *batch = [self lookupMutationBatch:batchID];
    if (batch) {
      [result addObject:batch];
    }
  };

  return result;
}

- (void)removeMutationBatches:(NSArray<FSTMutationBatch *> *)batches {
  NSUInteger batchCount = batches.count;
  HARD_ASSERT(batchCount > 0, "Should not remove mutations when none exist.");

  BatchId firstBatchID = batches[0].batchID;

  NSMutableArray<FSTMutationBatch *> *queue = self.queue;
  NSUInteger queueCount = queue.count;

  // Find the position of the first batch for removal. This need not be the first entry in the
  // queue.
  NSUInteger startIndex = [self indexOfExistingBatchID:firstBatchID action:@"removed"];
  HARD_ASSERT(queue[startIndex].batchID == firstBatchID, "Removed batches must exist in the queue");

  // Check that removed batches are contiguous (while excluding tombstones).
  NSUInteger batchIndex = 1;
  NSUInteger queueIndex = startIndex + 1;
  while (batchIndex < batchCount && queueIndex < queueCount) {
    FSTMutationBatch *batch = queue[queueIndex];
    if ([batch isTombstone]) {
      queueIndex++;
      continue;
    }

    HARD_ASSERT(batch.batchID == batches[batchIndex].batchID,
                "Removed batches must be contiguous in the queue");
    batchIndex++;
    queueIndex++;
  }

  // Only actually remove batches if removing at the front of the queue. Previously rejected batches
  // may have left tombstones in the queue, so expand the removal range to include any tombstones.
  if (startIndex == 0) {
    for (; queueIndex < queueCount; queueIndex++) {
      FSTMutationBatch *batch = queue[queueIndex];
      if (![batch isTombstone]) {
        break;
      }
    }

    NSUInteger length = queueIndex - startIndex;
    [queue removeObjectsInRange:NSMakeRange(startIndex, length)];

  } else {
    // Mark tombstones
    for (NSUInteger i = startIndex; i < queueIndex; i++) {
      queue[i] = [queue[i] toTombstone];
    }
  }

  // Remove entries from the index too.
  FSTImmutableSortedSet<FSTDocumentReference *> *references = self.batchesByDocumentKey;
  for (FSTMutationBatch *batch in batches) {
    BatchId batchID = batch.batchID;
    for (FSTMutation *mutation in batch.mutations) {
      const DocumentKey &key = mutation.key;
      [_persistence.referenceDelegate removeMutationReference:key];

      FSTDocumentReference *reference = [[FSTDocumentReference alloc] initWithKey:key ID:batchID];
      references = [references setByRemovingObject:reference];
    }
  }
  self.batchesByDocumentKey = references;
}

- (void)performConsistencyCheck {
  if (self.queue.count == 0) {
    HARD_ASSERT([self.batchesByDocumentKey isEmpty],
                "Document leak -- detected dangling mutation references when queue is empty.");
  }
}

#pragma mark - FSTGarbageSource implementation

- (BOOL)containsKey:(const DocumentKey &)key {
  // Create a reference with a zero ID as the start position to find any document reference with
  // this key.
  FSTDocumentReference *reference = [[FSTDocumentReference alloc] initWithKey:key ID:0];

  NSEnumerator<FSTDocumentReference *> *enumerator =
      [self.batchesByDocumentKey objectEnumeratorFrom:reference];
  FSTDocumentReference *_Nullable firstReference = [enumerator nextObject];
  return firstReference && firstReference.key == reference.key;
}

#pragma mark - Helpers

/**
 * A private helper that collects all the mutation batches in the queue up to but not including
 * the given endIndex. All tombstones in the queue are excluded.
 */
- (NSArray<FSTMutationBatch *> *)allLiveMutationBatchesBeforeIndex:(NSUInteger)endIndex {
  NSMutableArray<FSTMutationBatch *> *result = [NSMutableArray arrayWithCapacity:endIndex];

  NSUInteger index = 0;
  for (FSTMutationBatch *batch in self.queue) {
    if (index++ >= endIndex) break;

    if (![batch isTombstone]) {
      [result addObject:batch];
    }
  }

  return result;
}

/**
 * Finds the index of the given batchID in the mutation queue. This operation is O(1).
 *
 * @return The computed index of the batch with the given batchID, based on the state of the
 *     queue. Note this index can negative if the requested batchID has already been removed from
 *     the queue or past the end of the queue if the batchID is larger than the last added batch.
 */
- (NSInteger)indexOfBatchID:(BatchId)batchID {
  NSMutableArray<FSTMutationBatch *> *queue = self.queue;
  NSUInteger count = queue.count;
  if (count == 0) {
    // As an index this is past the end of the queue
    return 0;
  }

  // Examine the front of the queue to figure out the difference between the batchID and indexes
  // in the array. Note that since the queue is ordered by batchID, if the first batch has a larger
  // batchID then the requested batchID doesn't exist in the queue.
  FSTMutationBatch *firstBatch = queue[0];
  BatchId firstBatchID = firstBatch.batchID;
  return batchID - firstBatchID;
}

/**
 * Finds the index of the given batchID in the mutation queue and asserts that the resulting
 * index is within the bounds of the queue.
 *
 * @param batchID The batchID to search for
 * @param action A description of what the caller is doing, phrased in passive form (e.g.
 *     "acknowledged" in a routine that acknowledges batches).
 */
- (NSUInteger)indexOfExistingBatchID:(BatchId)batchID action:(NSString *)action {
  NSInteger index = [self indexOfBatchID:batchID];
  HARD_ASSERT(index >= 0 && index < self.queue.count, "Batches must exist to be %s", action);
  return (NSUInteger)index;
}

- (size_t)byteSizeWithSerializer:(FSTLocalSerializer *)serializer {
  size_t count = 0;
  for (FSTMutationBatch *batch in self.queue) {
    count += [[[serializer encodedMutationBatch:batch] data] length];
  };
  return count;
}

@end

NS_ASSUME_NONNULL_END
