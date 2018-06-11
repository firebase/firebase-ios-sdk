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

#include <unordered_map>

#import "Firestore/Source/Local/FSTMemoryMutationQueue.h"
#import "Firestore/Source/Local/FSTMemoryQueryCache.h"
#import "Firestore/Source/Local/FSTMemoryRemoteDocumentCache.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;
using MutationQueues = std::unordered_map<User, FSTMemoryMutationQueue *, HashUser>;

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryPersistence ()

@property(nonatomic, readonly) MutationQueues& mutationQueues;

@property(nonatomic, assign, getter=isStarted) BOOL started;
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

  //std::unordered_map<User, id<FSTMutationQueue>, HashUser> _mutationQueues;

  FSTTransactionRunner _transactionRunner;

  _Nullable id<FSTReferenceDelegate> _referenceDelegate;
}

+ (instancetype)persistence {
  return [[FSTMemoryPersistence alloc] init];
}

+ (instancetype)persistenceWithLRUGC {
  return [[FSTMemoryPersistence alloc] initWithReferenceBlock:^id <FSTReferenceDelegate>(FSTMemoryPersistence *persistence) {
    return [[FSTMemoryLRUReferenceDelegate alloc] initWithPersistence:persistence];
  }];
}

- (instancetype)init {
  if (self = [super init]) {
    _queryCache = [[FSTMemoryQueryCache alloc] initWithPersistence:self];
    _remoteDocumentCache = [[FSTMemoryRemoteDocumentCache alloc] init];
  }
  return self;
}

- (instancetype)initWithReferenceBlock:(id<FSTReferenceDelegate> (^)(FSTMemoryPersistence *persistence))block {
  if (self = [super init]) {
    _queryCache = [[FSTMemoryQueryCache alloc] initWithPersistence:self];
    _referenceDelegate = block(self);
    _remoteDocumentCache = [[FSTMemoryRemoteDocumentCache alloc] init];
    id delegate = _referenceDelegate;
    if ([delegate conformsToProtocol:@protocol(FSTTransactional)]) {
      _transactionRunner.SetBackingPersistence((id<FSTTransactional>)_referenceDelegate);
    }
  }
  return self;
}

- (BOOL)start:(NSError **)error {
  // No durable state to read on startup.
  HARD_ASSERT(!self.isStarted, "FSTMemoryPersistence double-started!");
  self.started = YES;
  return YES;
}

- (void)shutdown {
  // No durable state to ensure is closed on shutdown.
  HARD_ASSERT(self.isStarted, "FSTMemoryPersistence shutdown without start!");
  self.started = NO;
}

- (_Nullable id<FSTReferenceDelegate>)referenceDelegate {
  return _referenceDelegate;
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

- (id<FSTQueryCache>)queryCache {
  return _queryCache;
}

- (id<FSTRemoteDocumentCache>)remoteDocumentCache {
  return _remoteDocumentCache;
}

@end

@implementation FSTMemoryLRUReferenceDelegate {
  FSTMemoryPersistence *_persistence;
  NSMutableDictionary<FSTDocumentKey *, NSNumber *> *_sequenceNumbers;
  FSTReferenceSet *_additionalReferences;
  FSTLRUGarbageCollector *_gc;
}

- (instancetype)initWithPersistence:(FSTMemoryPersistence *)persistence {
  if (self = [super init]) {
    _sequenceNumbers = [NSMutableDictionary dictionary];
    _persistence = persistence;
    _gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:[_persistence queryCache]
                                                    delegate:self];
  }
  return self;
}

- (FSTLRUGarbageCollector *)gc {
  return _gc;
}

- (void)addInMemoryPins:(FSTReferenceSet *)set {
  // Technically can't assert this, due to restartWithNoopGarbageCollector (for now...)
  //FSTAssert(_additionalReferences == nil, @"Overwriting additional references");
  _additionalReferences = set;
}

- (void)removeTarget:(FSTQueryData *)queryData sequenceNumber:(FSTListenSequenceNumber)sequenceNumber {
  FSTQueryData *updated = [queryData queryDataByReplacingSnapshotVersion:queryData.snapshotVersion
                                                             resumeToken:queryData.resumeToken
                                                          sequenceNumber:sequenceNumber];
  [_persistence.queryCache updateQueryData:updated];
}

- (void)documentUpdated:(FSTDocumentKey *)key sequenceNumber:(FSTListenSequenceNumber)sequenceNumber {
  _sequenceNumbers[key] = @(sequenceNumber);
  // TODO(gsoltis): probably need to implement this
  // Need to bump sequence number?
}


- (void)startTransaction:(absl::string_view)label {
  // wat do?
}

- (void)commitTransaction {
  // TODO(gsoltis): maybe check if we need to schedule a GC?
}

- (void)enumerateTargetsUsingBlock:(void (^)(FSTQueryData *queryData, BOOL *stop))block {
  return [_persistence.queryCache enumerateTargetsUsingBlock:block];
}

- (void)enumerateMutationsUsingBlock:(void (^)(FSTDocumentKey *key, FSTListenSequenceNumber sequenceNumber, BOOL *stop))block {
  [_sequenceNumbers enumerateKeysAndObjectsUsingBlock:^(FSTDocumentKey *key, NSNumber *seq, BOOL *stop) {
    FSTListenSequenceNumber sequenceNumber = [seq longLongValue];
    if (![self->_persistence.queryCache containsKey:key]) {
      block(key, sequenceNumber, stop);
    }
  }];
}

- (NSUInteger)removeQueriesThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                                     liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  return [_persistence.queryCache removeQueriesThroughSequenceNumber:sequenceNumber liveQueries:liveQueries];
}

- (NSUInteger)removeOrphanedDocumentsThroughSequenceNumber:(FSTListenSequenceNumber)upperBound {
  return [(FSTMemoryRemoteDocumentCache *)_persistence.remoteDocumentCache removeOrphanedDocuments:self
                                                                             throughSequenceNumber:upperBound];
}

- (void)addReference:(FSTDocumentKey *)key target:(FSTTargetID)targetID sequenceNumber:(FSTListenSequenceNumber)sequenceNumber {
  _sequenceNumbers[key] = @(sequenceNumber);
}

- (void)removeReference:(FSTDocumentKey *)key target:(FSTTargetID)targetID sequenceNumber:(FSTListenSequenceNumber)sequenceNumber {
  // No-op. LRU doesn't care when references are removed.
}


- (BOOL)mutationQueuesContainKey:(FSTDocumentKey *)key {
  const MutationQueues& queues = [_persistence mutationQueues];
  for (auto it = queues.begin(); it != queues.end(); ++it) {
    if ([it->second containsKey:key]) {
      return YES;
    }
  }
  return NO;
}

- (void)removeMutationReference:(FSTDocumentKey *)key
                 sequenceNumber:(FSTListenSequenceNumber)sequenceNumber {
  _sequenceNumbers[key] = @(sequenceNumber);
}

- (BOOL)isPinnedAtSequenceNumber:(FSTListenSequenceNumber)upperBound document:(FSTDocumentKey *)key {
  if ([self mutationQueuesContainKey:key]) {
    return YES;
  }
  if ([_additionalReferences containsKey:key]) {
    return YES;
  }
  if ([_persistence.queryCache containsKey:key]) {
    return YES;
  }
  NSNumber *orphaned = _sequenceNumbers[key];
  if (orphaned && [orphaned longLongValue] > upperBound) {
    return YES;
  }
  return NO;
}


@end

NS_ASSUME_NONNULL_END
