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
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"

using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryPersistence ()
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

  std::unordered_map<User, id<FSTMutationQueue>, HashUser> _mutationQueues;

  FSTTransactionRunner _transactionRunner;
}

+ (instancetype)persistence {
  return [[FSTMemoryPersistence alloc] init];
}

- (instancetype)init {
  if (self = [super init]) {
    _queryCache = [[FSTMemoryQueryCache alloc] initWithPersistence:self];
    _remoteDocumentCache = [[FSTMemoryRemoteDocumentCache alloc] init];
  }
  return self;
}

- (BOOL)start:(NSError **)error {
  // No durable state to read on startup.
  FSTAssert(!self.isStarted, @"FSTMemoryPersistence double-started!");
  self.started = YES;
  return YES;
}

- (void)shutdown {
  // No durable state to ensure is closed on shutdown.
  FSTAssert(self.isStarted, @"FSTMemoryPersistence shutdown without start!");
  self.started = NO;
}

- (_Nullable id<FSTReferenceDelegate>)referenceDelegate {
  return nil;
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

NS_ASSUME_NONNULL_END
