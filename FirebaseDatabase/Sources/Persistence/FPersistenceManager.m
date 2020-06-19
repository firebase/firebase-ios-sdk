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

#import "FPersistenceManager.h"
#import "FCacheNode.h"
#import "FClock.h"
#import "FIndexedNode.h"
#import "FLevelDBStorageEngine.h"
#import "FPruneForest.h"
#import "FTrackedQuery.h"
#import "FTrackedQueryManager.h"
#import "FUtilities.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

@interface FPersistenceManager ()

@property(nonatomic, strong) id<FStorageEngine> storageEngine;
@property(nonatomic, strong) id<FCachePolicy> cachePolicy;
@property(nonatomic, strong) FTrackedQueryManager *trackedQueryManager;
@property(nonatomic) NSUInteger serverCacheUpdatesSinceLastPruneCheck;

@end

@implementation FPersistenceManager

- (id)initWithStorageEngine:(id<FStorageEngine>)storageEngine
                cachePolicy:(id<FCachePolicy>)cachePolicy {
    self = [super init];
    if (self != nil) {
        self->_storageEngine = storageEngine;
        self->_cachePolicy = cachePolicy;
        self->_trackedQueryManager = [[FTrackedQueryManager alloc]
            initWithStorageEngine:self.storageEngine
                            clock:[FSystemClock clock]];
    }
    return self;
}

- (void)close {
    [self.storageEngine close];
    self.storageEngine = nil;
    self.trackedQueryManager = nil;
}

- (void)saveUserOverwrite:(id<FNode>)node
                   atPath:(FPath *)path
                  writeId:(NSUInteger)writeId {
    [self.storageEngine saveUserOverwrite:node atPath:path writeId:writeId];
}

- (void)saveUserMerge:(FCompoundWrite *)merge
               atPath:(FPath *)path
              writeId:(NSUInteger)writeId {
    [self.storageEngine saveUserMerge:merge atPath:path writeId:writeId];
}

- (void)removeUserWrite:(NSUInteger)writeId {
    [self.storageEngine removeUserWrite:writeId];
}

- (void)removeAllUserWrites {
    [self.storageEngine removeAllUserWrites];
}

- (NSArray *)userWrites {
    return [self.storageEngine userWrites];
}

- (FCacheNode *)serverCacheForQuery:(FQuerySpec *)query {
    NSSet *trackedKeys;
    BOOL complete;
    // TODO[offline]: Should we use trackedKeys to find out if this location is
    // a child of a complete query?
    if ([self.trackedQueryManager isQueryComplete:query]) {
        complete = YES;
        FTrackedQuery *trackedQuery =
            [self.trackedQueryManager findTrackedQuery:query];
        if (!query.loadsAllData && trackedQuery.isComplete) {
            trackedKeys = [self.storageEngine
                trackedQueryKeysForQuery:trackedQuery.queryId];
        } else {
            trackedKeys = nil;
        }
    } else {
        complete = NO;
        trackedKeys =
            [self.trackedQueryManager knownCompleteChildrenAtPath:query.path];
    }

    id<FNode> node;
    if (trackedKeys != nil) {
        node = [self.storageEngine serverCacheForKeys:trackedKeys
                                               atPath:query.path];
    } else {
        node = [self.storageEngine serverCacheAtPath:query.path];
    }

    FIndexedNode *indexedNode = [FIndexedNode indexedNodeWithNode:node
                                                            index:query.index];
    return [[FCacheNode alloc] initWithIndexedNode:indexedNode
                                isFullyInitialized:complete
                                        isFiltered:(trackedKeys != nil)];
}

- (void)updateServerCacheWithNode:(id<FNode>)node forQuery:(FQuerySpec *)query {
    BOOL merge = !query.loadsAllData;
    [self.storageEngine updateServerCache:node atPath:query.path merge:merge];
    [self setQueryComplete:query];
    [self doPruneCheckAfterServerUpdate];
}

- (void)updateServerCacheWithMerge:(FCompoundWrite *)merge
                            atPath:(FPath *)path {
    [self.storageEngine updateServerCacheWithMerge:merge atPath:path];
    [self doPruneCheckAfterServerUpdate];
}

- (void)applyUserMerge:(FCompoundWrite *)merge
    toServerCacheAtPath:(FPath *)path {
    // TODO[offline]: rework this to be more efficient
    [merge enumerateWrites:^(FPath *relativePath, id<FNode> node, BOOL *stop) {
      [self applyUserWrite:node toServerCacheAtPath:[path child:relativePath]];
    }];
}

- (void)applyUserWrite:(id<FNode>)write toServerCacheAtPath:(FPath *)path {
    // This is a hack to guess whether we already cached this because we got a
    // server data update for this write via an existing active default query.
    // If we didn't, then we'll manually cache this and add a tracked query to
    // mark it complete and keep it cached. Unfortunately this is just a guess
    // and it's possible that we *did* get an update (e.g. via a filtered query)
    // and by overwriting the cache here, we'll actually store an incorrect
    // value (e.g. in the case that we wrote a ServerValue.TIMESTAMP and the
    // server resolved it to a different value).
    // TODO[offline]: Consider reworking.
    if (![self.trackedQueryManager hasActiveDefaultQueryAtPath:path]) {
        [self.storageEngine updateServerCache:write atPath:path merge:NO];
        [self.trackedQueryManager ensureCompleteTrackedQueryAtPath:path];
    }
}

- (void)setQueryComplete:(FQuerySpec *)query {
    if (query.loadsAllData) {
        [self.trackedQueryManager setQueriesCompleteAtPath:query.path];
    } else {
        [self.trackedQueryManager setQueryComplete:query];
    }
}

- (void)setQueryActive:(FQuerySpec *)spec {
    [self.trackedQueryManager setQueryActive:spec];
}

- (void)setQueryInactive:(FQuerySpec *)spec {
    [self.trackedQueryManager setQueryInactive:spec];
}

- (void)doPruneCheckAfterServerUpdate {
    self.serverCacheUpdatesSinceLastPruneCheck++;
    if ([self.cachePolicy
            shouldCheckCacheSize:self.serverCacheUpdatesSinceLastPruneCheck]) {
        FFDebug(@"I-RDB078001", @"Reached prune check threshold. Checking...");
        NSDate *date = [NSDate date];
        self.serverCacheUpdatesSinceLastPruneCheck = 0;
        BOOL canPrune = YES;
        NSUInteger cacheSize =
            [self.storageEngine serverCacheEstimatedSizeInBytes];
        FFDebug(@"I-RDB078002", @"Server cache size: %lu",
                (unsigned long)cacheSize);
        while (canPrune &&
               [self.cachePolicy
                   shouldPruneCacheWithSize:cacheSize
                     numberOfTrackedQueries:self.trackedQueryManager
                                                .numberOfPrunableQueries]) {
            FPruneForest *pruneForest =
                [self.trackedQueryManager pruneOldQueries:self.cachePolicy];
            if (pruneForest.prunesAnything) {
                [self.storageEngine pruneCache:pruneForest
                                        atPath:[FPath empty]];
            } else {
                canPrune = NO;
            }
            cacheSize = [self.storageEngine serverCacheEstimatedSizeInBytes];
            FFDebug(@"I-RDB078003", @"Cache size after pruning: %lu",
                    (unsigned long)cacheSize);
        }
        FFDebug(@"I-RDB078004", @"Pruning round took %fms",
                [date timeIntervalSinceNow] * -1000);
    }
}

- (void)setTrackedQueryKeys:(NSSet *)keys forQuery:(FQuerySpec *)query {
    NSAssert(!query.loadsAllData,
             @"We should only track keys for filtered queries");
    FTrackedQuery *trackedQuery =
        [self.trackedQueryManager findTrackedQuery:query];
    NSAssert(trackedQuery.isActive,
             @"We only expect tracked keys for currently-active queries.");
    [self.storageEngine setTrackedQueryKeys:keys
                                 forQueryId:trackedQuery.queryId];
}

- (void)updateTrackedQueryKeysWithAddedKeys:(NSSet *)added
                                removedKeys:(NSSet *)removed
                                   forQuery:(FQuerySpec *)query {
    NSAssert(!query.loadsAllData,
             @"We should only track keys for filtered queries");
    FTrackedQuery *trackedQuery =
        [self.trackedQueryManager findTrackedQuery:query];
    NSAssert(trackedQuery.isActive,
             @"We only expect tracked keys for currently-active queries.");
    [self.storageEngine
        updateTrackedQueryKeysWithAddedKeys:added
                                removedKeys:removed
                                 forQueryId:trackedQuery.queryId];
}

@end
