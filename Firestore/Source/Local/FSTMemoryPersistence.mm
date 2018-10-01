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

#import "Firestore/Source/Local/FSTMemoryPersistence.h"

#include <memory>
#include <unordered_map>
#include <unordered_set>

#import "Firestore/Source/Core/FSTListenSequence.h"
#import "Firestore/Source/Local/FSTMemoryMutationQueue.h"
#import "Firestore/Source/Local/FSTMemoryQueryCache.h"
#import "Firestore/Source/Local/FSTMemoryRemoteDocumentCache.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"
#include "absl/memory/memory.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeyHash;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::util::Status;

using MutationQueues = std::unordered_map<User, FSTMemoryMutationQueue *, HashUser>;

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryPersistence ()

- (FSTMemoryQueryCache *)queryCache;

- (FSTMemoryRemoteDocumentCache *)remoteDocumentCache;

@property(nonatomic, readonly) MutationQueues &mutationQueues;

@property(nonatomic, assign, getter=isStarted) BOOL started;

// Make this property writable so we can wire up a delegate.
@property(nonatomic, strong) id<FSTReferenceDelegate> referenceDelegate;

@end

@implementation FSTMemoryPersistence {
  /**
   * The FSTQueryCache representing the persisted cache of queries.
   *
   * Note that this is retained here to make it easier to write tests affecting both the in-memory
   * and LevelDB-backed persistence layers. Tests can create a new FSTLocalStore wrapping this
   * FSTPersistence instance and this will make the in-memory persistence layer behave as if it
   * were actually persisting values.
   */
  FSTMemoryQueryCache *_queryCache;

  /** The FSTRemoteDocumentCache representing the persisted cache of remote documents. */
  FSTMemoryRemoteDocumentCache *_remoteDocumentCache;

  FSTTransactionRunner _transactionRunner;

  id<FSTReferenceDelegate> _referenceDelegate;
}

+ (instancetype)persistenceWithEagerGC {
  FSTMemoryPersistence *persistence = [[FSTMemoryPersistence alloc] init];
  persistence.referenceDelegate =
      [[FSTMemoryEagerReferenceDelegate alloc] initWithPersistence:persistence];
  return persistence;
}

+ (instancetype)persistenceWithLRUGCAndSerializer:(FSTLocalSerializer *)serializer {
  FSTMemoryPersistence *persistence = [[FSTMemoryPersistence alloc] init];
  persistence.referenceDelegate =
      [[FSTMemoryLRUReferenceDelegate alloc] initWithPersistence:persistence serializer:serializer];
  return persistence;
}

- (instancetype)init {
  if (self = [super init]) {
    _queryCache = [[FSTMemoryQueryCache alloc] initWithPersistence:self];
    _remoteDocumentCache = [[FSTMemoryRemoteDocumentCache alloc] init];
  }
  return self;
}

- (void)setReferenceDelegate:(id<FSTReferenceDelegate>)referenceDelegate {
  _referenceDelegate = referenceDelegate;
  id delegate = _referenceDelegate;
  if ([delegate conformsToProtocol:@protocol(FSTTransactional)]) {
    _transactionRunner.SetBackingPersistence((id<FSTTransactional>)_referenceDelegate);
  }
}

- (Status)start {
  // No durable state to read on startup.
  HARD_ASSERT(!self.isStarted, "FSTMemoryPersistence double-started!");
  self.started = YES;
  return Status::OK();
}

- (void)shutdown {
  // No durable state to ensure is closed on shutdown.
  HARD_ASSERT(self.isStarted, "FSTMemoryPersistence shutdown without start!");
  self.started = NO;
}

- (id<FSTReferenceDelegate>)referenceDelegate {
  return _referenceDelegate;
}

- (ListenSequenceNumber)currentSequenceNumber {
  return [_referenceDelegate currentSequenceNumber];
}

- (const FSTTransactionRunner &)run {
  return _transactionRunner;
}

- (id<FSTMutationQueue>)mutationQueueForUser:(const User &)user {
  id<FSTMutationQueue> queue = _mutationQueues[user];
  if (!queue) {
    queue = [[FSTMemoryMutationQueue alloc] initWithPersistence:self];
    _mutationQueues[user] = queue;
  }
  return queue;
}

- (FSTMemoryQueryCache *)queryCache {
  return _queryCache;
}

- (id<FSTRemoteDocumentCache>)remoteDocumentCache {
  return _remoteDocumentCache;
}

@end

@implementation FSTMemoryLRUReferenceDelegate {
  // This delegate should have the same lifetime as the persistence layer, but mark as
  // weak to avoid retain cycle.
  __weak FSTMemoryPersistence *_persistence;
  std::unordered_map<DocumentKey, ListenSequenceNumber, DocumentKeyHash> _sequenceNumbers;
  FSTReferenceSet *_additionalReferences;
  FSTLRUGarbageCollector *_gc;
  FSTListenSequence *_listenSequence;
  ListenSequenceNumber _currentSequenceNumber;
  FSTLocalSerializer *_serializer;
}

- (instancetype)initWithPersistence:(FSTMemoryPersistence *)persistence
                         serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _persistence = persistence;
    _gc =
        [[FSTLRUGarbageCollector alloc] initWithQueryCache:[_persistence queryCache] delegate:self];
    _currentSequenceNumber = kFSTListenSequenceNumberInvalid;
    // Theoretically this is always 0, since this is all in-memory...
    ListenSequenceNumber highestSequenceNumber =
        _persistence.queryCache.highestListenSequenceNumber;
    _listenSequence = [[FSTListenSequence alloc] initStartingAfter:highestSequenceNumber];
    _serializer = serializer;
  }
  return self;
}

- (FSTLRUGarbageCollector *)gc {
  return _gc;
}

- (ListenSequenceNumber)currentSequenceNumber {
  HARD_ASSERT(_currentSequenceNumber != kFSTListenSequenceNumberInvalid,
              "Asking for a sequence number outside of a transaction");
  return _currentSequenceNumber;
}

- (void)addInMemoryPins:(FSTReferenceSet *)set {
  // Technically can't assert this, due to restartWithNoopGarbageCollector (for now...)
  // FSTAssert(_additionalReferences == nil, @"Overwriting additional references");
  _additionalReferences = set;
}

- (void)removeTarget:(FSTQueryData *)queryData {
  FSTQueryData *updated = [queryData queryDataByReplacingSnapshotVersion:queryData.snapshotVersion
                                                             resumeToken:queryData.resumeToken
                                                          sequenceNumber:_currentSequenceNumber];
  [_persistence.queryCache updateQueryData:updated];
}

- (void)limboDocumentUpdated:(const DocumentKey &)key {
  _sequenceNumbers[key] = self.currentSequenceNumber;
}

- (void)startTransaction:(absl::string_view)label {
  _currentSequenceNumber = [_listenSequence next];
}

- (void)commitTransaction {
  _currentSequenceNumber = kFSTListenSequenceNumberInvalid;
}

- (void)enumerateTargetsUsingBlock:(void (^)(FSTQueryData *queryData, BOOL *stop))block {
  return [_persistence.queryCache enumerateTargetsUsingBlock:block];
}

- (void)enumerateMutationsUsingBlock:
    (void (^)(const DocumentKey &key, ListenSequenceNumber sequenceNumber, BOOL *stop))block {
  BOOL stop = NO;
  for (auto it = _sequenceNumbers.begin(); !stop && it != _sequenceNumbers.end(); ++it) {
    ListenSequenceNumber sequenceNumber = it->second;
    const DocumentKey &key = it->first;
    if (![_persistence.queryCache containsKey:key]) {
      block(key, sequenceNumber, &stop);
    }
  }
}

- (int)removeTargetsThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber
                              liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  return [_persistence.queryCache removeQueriesThroughSequenceNumber:sequenceNumber
                                                         liveQueries:liveQueries];
}

- (int)removeOrphanedDocumentsThroughSequenceNumber:(ListenSequenceNumber)upperBound {
  return [(FSTMemoryRemoteDocumentCache *)_persistence.remoteDocumentCache
      removeOrphanedDocuments:self
        throughSequenceNumber:upperBound];
}

- (void)addReference:(const DocumentKey &)key {
  _sequenceNumbers[key] = self.currentSequenceNumber;
}

- (void)removeReference:(const DocumentKey &)key {
  _sequenceNumbers[key] = self.currentSequenceNumber;
}

- (BOOL)mutationQueuesContainKey:(const DocumentKey &)key {
  const MutationQueues &queues = [_persistence mutationQueues];
  for (auto it = queues.begin(); it != queues.end(); ++it) {
    if ([it->second containsKey:key]) {
      return YES;
    }
  }
  return NO;
}

- (void)removeMutationReference:(const DocumentKey &)key {
  _sequenceNumbers[key] = self.currentSequenceNumber;
}

- (BOOL)isPinnedAtSequenceNumber:(ListenSequenceNumber)upperBound
                        document:(const DocumentKey &)key {
  if ([self mutationQueuesContainKey:key]) {
    return YES;
  }
  if ([_additionalReferences containsKey:key]) {
    return YES;
  }
  if ([_persistence.queryCache containsKey:key]) {
    return YES;
  }
  auto it = _sequenceNumbers.find(key);
  if (it != _sequenceNumbers.end() && it->second > upperBound) {
    return YES;
  }
  return NO;
}

- (size_t)byteSize {
  // Note that this method is only used for testing because this delegate is only
  // used for testing. The algorithm here (loop through everything, serialize it
  // and count bytes) is inefficient and inexact, but won't run in production.
  size_t count = 0;
  count += [_persistence.queryCache byteSizeWithSerializer:_serializer];
  count += [_persistence.remoteDocumentCache byteSizeWithSerializer:_serializer];
  const MutationQueues &queues = [_persistence mutationQueues];
  for (auto it = queues.begin(); it != queues.end(); ++it) {
    count += [it->second byteSizeWithSerializer:_serializer];
  }
  return count;
}

@end

@implementation FSTMemoryEagerReferenceDelegate {
  std::unique_ptr<std::unordered_set<DocumentKey, DocumentKeyHash>> _orphaned;
  // This delegate should have the same lifetime as the persistence layer, but mark as
  // weak to avoid retain cycle.
  __weak FSTMemoryPersistence *_persistence;
  FSTReferenceSet *_additionalReferences;
}

- (instancetype)initWithPersistence:(FSTMemoryPersistence *)persistence {
  if (self = [super init]) {
    _persistence = persistence;
  }
  return self;
}

- (ListenSequenceNumber)currentSequenceNumber {
  return kFSTListenSequenceNumberInvalid;
}

- (void)addInMemoryPins:(FSTReferenceSet *)set {
  // We should be able to assert that _additionalReferences is nil, but due to restarts in spec
  // tests it would fail.
  _additionalReferences = set;
}

- (void)removeTarget:(FSTQueryData *)queryData {
  for (const DocumentKey &docKey :
       [_persistence.queryCache matchingKeysForTargetID:queryData.targetID]) {
    _orphaned->insert(docKey);
  }
  [_persistence.queryCache removeQueryData:queryData];
}

- (void)addReference:(const DocumentKey &)key {
  _orphaned->erase(key);
}

- (void)removeReference:(const DocumentKey &)key {
  _orphaned->insert(key);
}

- (void)removeMutationReference:(const DocumentKey &)key {
  _orphaned->insert(key);
}

- (BOOL)isReferenced:(const DocumentKey &)key {
  if ([[_persistence queryCache] containsKey:key]) {
    return YES;
  }
  if ([self mutationQueuesContainKey:key]) {
    return YES;
  }
  if ([_additionalReferences containsKey:key]) {
    return YES;
  }
  return NO;
}

- (void)limboDocumentUpdated:(const DocumentKey &)key {
  if ([self isReferenced:key]) {
    _orphaned->erase(key);
  } else {
    _orphaned->insert(key);
  }
}

- (void)startTransaction:(__unused absl::string_view)label {
  _orphaned = absl::make_unique<std::unordered_set<DocumentKey, DocumentKeyHash>>();
}

- (BOOL)mutationQueuesContainKey:(const DocumentKey &)key {
  const MutationQueues &queues = [_persistence mutationQueues];
  for (auto it = queues.begin(); it != queues.end(); ++it) {
    if ([it->second containsKey:key]) {
      return YES;
    }
  }
  return NO;
}

- (void)commitTransaction {
  for (auto it = _orphaned->begin(); it != _orphaned->end(); ++it) {
    const DocumentKey key = *it;
    if (![self isReferenced:key]) {
      [[_persistence remoteDocumentCache] removeEntryForKey:key];
    }
  }
  _orphaned.reset();
}

@end

NS_ASSUME_NONNULL_END
