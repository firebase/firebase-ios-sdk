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

#import "FSTMemoryPersistence.h"

#import "FSTAssert.h"
#import "FSTMemoryMutationQueue.h"
#import "FSTMemoryQueryCache.h"
#import "FSTMemoryRemoteDocumentCache.h"
#import "FSTUser.h"
#import "FSTWriteGroup.h"
#import "FSTWriteGroupTracker.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryPersistence ()
@property(nonatomic, strong, nonnull) FSTWriteGroupTracker *writeGroupTracker;
@property(nonatomic, strong, nonnull)
    NSMutableDictionary<FSTUser *, id<FSTMutationQueue>> *mutationQueues;
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
}

+ (instancetype)persistence {
  return [[FSTMemoryPersistence alloc] init];
}

- (instancetype)init {
  if (self = [super init]) {
    _writeGroupTracker = [FSTWriteGroupTracker tracker];
    _queryCache = [[FSTMemoryQueryCache alloc] init];
    _remoteDocumentCache = [[FSTMemoryRemoteDocumentCache alloc] init];
    _mutationQueues = [NSMutableDictionary dictionary];
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

- (id<FSTMutationQueue>)mutationQueueForUser:(FSTUser *)user {
  id<FSTMutationQueue> queue = self.mutationQueues[user];
  if (!queue) {
    queue = [FSTMemoryMutationQueue mutationQueue];
    self.mutationQueues[user] = queue;
  }
  return queue;
}

- (id<FSTQueryCache>)queryCache {
  return _queryCache;
}

- (id<FSTRemoteDocumentCache>)remoteDocumentCache {
  return _remoteDocumentCache;
}

- (FSTWriteGroup *)startGroupWithAction:(NSString *)action {
  return [self.writeGroupTracker startGroupWithAction:action];
}

- (void)commitGroup:(FSTWriteGroup *)group {
  [self.writeGroupTracker endGroup:group];

  FSTAssert(group.isEmpty, @"Memory persistence shouldn't use write groups: %@", group.action);
}

@end

NS_ASSUME_NONNULL_END
