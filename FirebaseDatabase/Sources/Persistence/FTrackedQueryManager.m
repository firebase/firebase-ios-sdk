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

#import "FirebaseDatabase/Sources/Persistence/FTrackedQueryManager.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FImmutableTree.h"
#import "FirebaseDatabase/Sources/FClock.h"
#import "FirebaseDatabase/Sources/Persistence/FCachePolicy.h"
#import "FirebaseDatabase/Sources/Persistence/FLevelDBStorageEngine.h"
#import "FirebaseDatabase/Sources/Persistence/FPruneForest.h"
#import "FirebaseDatabase/Sources/Persistence/FTrackedQuery.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

@interface FTrackedQueryManager ()

@property(nonatomic, strong) FImmutableTree *trackedQueryTree;
@property(nonatomic, strong) id<FStorageEngine> storageEngine;
@property(nonatomic, strong) id<FClock> clock;
@property(nonatomic) NSUInteger currentQueryId;

@end

@implementation FTrackedQueryManager

- (id)initWithStorageEngine:(id<FStorageEngine>)storageEngine
                      clock:(id<FClock>)clock {
    self = [super init];
    if (self != nil) {
        self->_storageEngine = storageEngine;
        self->_clock = clock;
        self->_trackedQueryTree = [FImmutableTree empty];

        NSTimeInterval lastUse = [clock currentTime];

        NSArray *trackedQueries = [self.storageEngine loadTrackedQueries];
        [trackedQueries enumerateObjectsUsingBlock:^(
                            FTrackedQuery *trackedQuery, NSUInteger idx,
                            BOOL *stop) {
          self.currentQueryId =
              MAX(trackedQuery.queryId + 1, self.currentQueryId);
          if (trackedQuery.isActive) {
              trackedQuery =
                  [[trackedQuery setActiveState:NO] updateLastUse:lastUse];
              FFDebug(
                  @"I-RDB081001",
                  @"Setting active query %lu from previous app start inactive",
                  (unsigned long)trackedQuery.queryId);
              [self.storageEngine saveTrackedQuery:trackedQuery];
          }
          [self cacheTrackedQuery:trackedQuery];
        }];
    }
    return self;
}

+ (void)assertValidTrackedQuery:(FQuerySpec *)query {
    NSAssert(!query.loadsAllData || query.isDefault,
             @"Can't have tracked non-default query that loads all data");
}

+ (FQuerySpec *)normalizeQuery:(FQuerySpec *)query {
    return query.loadsAllData ? [FQuerySpec defaultQueryAtPath:query.path]
                              : query;
}

- (FTrackedQuery *)findTrackedQuery:(FQuerySpec *)query {
    query = [FTrackedQueryManager normalizeQuery:query];
    NSDictionary *set = [self.trackedQueryTree valueAtPath:query.path];
    return set[query.params];
}

- (void)removeTrackedQuery:(FQuerySpec *)query {
    query = [FTrackedQueryManager normalizeQuery:query];
    FTrackedQuery *trackedQuery = [self findTrackedQuery:query];
    NSAssert(trackedQuery, @"Tracked query must exist to be removed!");

    [self.storageEngine removeTrackedQuery:trackedQuery.queryId];
    NSMutableDictionary *trackedQueries =
        [self.trackedQueryTree valueAtPath:query.path];
    [trackedQueries removeObjectForKey:query.params];
}

- (void)setQueryActive:(FQuerySpec *)query {
    [self setQueryActive:YES forQuery:query];
}

- (void)setQueryInactive:(FQuerySpec *)query {
    [self setQueryActive:NO forQuery:query];
}

- (void)setQueryActive:(BOOL)isActive forQuery:(FQuerySpec *)query {
    query = [FTrackedQueryManager normalizeQuery:query];
    FTrackedQuery *trackedQuery = [self findTrackedQuery:query];

    // Regardless of whether it's now active or no langer active, we update the
    // lastUse time
    NSTimeInterval lastUse = [self.clock currentTime];
    if (trackedQuery != nil) {
        trackedQuery =
            [[trackedQuery updateLastUse:lastUse] setActiveState:isActive];
        [self.storageEngine saveTrackedQuery:trackedQuery];
    } else {
        NSAssert(isActive, @"If we're setting the query to inactive, we should "
                           @"already be tracking it!");
        trackedQuery = [[FTrackedQuery alloc] initWithId:self.currentQueryId++
                                                   query:query
                                                 lastUse:lastUse
                                                isActive:isActive];
        [self.storageEngine saveTrackedQuery:trackedQuery];
    }

    [self cacheTrackedQuery:trackedQuery];
}

- (void)setQueryComplete:(FQuerySpec *)query {
    query = [FTrackedQueryManager normalizeQuery:query];
    FTrackedQuery *trackedQuery = [self findTrackedQuery:query];
    if (!trackedQuery) {
        // We might have removed a query and pruned it before we got the
        // complete message from the server...
        FFWarn(@"I-RDB081002",
               @"Trying to set a query complete that is not tracked!");
    } else if (!trackedQuery.isComplete) {
        trackedQuery = [trackedQuery setComplete];
        [self.storageEngine saveTrackedQuery:trackedQuery];
        [self cacheTrackedQuery:trackedQuery];
    } else {
        // Nothing to do, already marked complete
    }
}

- (void)setQueriesCompleteAtPath:(FPath *)path {
    [[self.trackedQueryTree subtreeAtPath:path]
        forEach:^(FPath *childPath, NSDictionary *trackedQueries) {
          [trackedQueries enumerateKeysAndObjectsUsingBlock:^(
                              FQueryParams *parms, FTrackedQuery *trackedQuery,
                              BOOL *stop) {
            if (!trackedQuery.isComplete) {
                FTrackedQuery *newTrackedQuery = [trackedQuery setComplete];
                [self.storageEngine saveTrackedQuery:newTrackedQuery];
                [self cacheTrackedQuery:newTrackedQuery];
            }
          }];
        }];
}

- (BOOL)isQueryComplete:(FQuerySpec *)query {
    if ([self isIncludedInDefaultCompleteQuery:query]) {
        return YES;
    } else if (query.loadsAllData) {
        // We didn't find a default complete query, so must not be complete.
        return NO;
    } else {
        NSDictionary *trackedQueries =
            [self.trackedQueryTree valueAtPath:query.path];
        return [trackedQueries[query.params] isComplete];
    }
}

- (BOOL)hasActiveDefaultQueryAtPath:(FPath *)path {
    return [self.trackedQueryTree
               rootMostValueOnPath:path
                          matching:^BOOL(NSDictionary *trackedQueries) {
                            return
                                [trackedQueries[[FQueryParams defaultInstance]]
                                    isActive];
                          }] != nil;
}

- (void)ensureCompleteTrackedQueryAtPath:(FPath *)path {
    FQuerySpec *query = [FQuerySpec defaultQueryAtPath:path];
    if (![self isIncludedInDefaultCompleteQuery:query]) {
        FTrackedQuery *trackedQuery = [self findTrackedQuery:query];
        if (trackedQuery == nil) {
            trackedQuery =
                [[FTrackedQuery alloc] initWithId:self.currentQueryId++
                                            query:query
                                          lastUse:[self.clock currentTime]
                                         isActive:NO
                                       isComplete:YES];
        } else {
            NSAssert(!trackedQuery.isComplete,
                     @"This should have been handled above!");
            trackedQuery = [trackedQuery setComplete];
        }
        [self.storageEngine saveTrackedQuery:trackedQuery];
        [self cacheTrackedQuery:trackedQuery];
    }
}

- (BOOL)isIncludedInDefaultCompleteQuery:(FQuerySpec *)query {
    return
        [self.trackedQueryTree
            findRootMostMatchingPath:query.path
                           predicate:^BOOL(NSDictionary *trackedQueries) {
                             return
                                 [trackedQueries[[FQueryParams defaultInstance]]
                                     isComplete];
                           }] != nil;
}

- (void)cacheTrackedQuery:(FTrackedQuery *)query {
    [FTrackedQueryManager assertValidTrackedQuery:query.query];
    NSMutableDictionary *trackedDict =
        [self.trackedQueryTree valueAtPath:query.query.path];
    if (trackedDict == nil) {
        trackedDict = [NSMutableDictionary dictionary];
        self.trackedQueryTree =
            [self.trackedQueryTree setValue:trackedDict
                                     atPath:query.query.path];
    }
    trackedDict[query.query.params] = query;
}

- (NSUInteger)numberOfQueriesToPrune:(id<FCachePolicy>)cachePolicy
                       prunableCount:(NSUInteger)numPrunable {
    NSUInteger numPercent = (NSUInteger)ceilf(
        numPrunable * [cachePolicy percentOfQueriesToPruneAtOnce]);
    NSUInteger maxToKeep = [cachePolicy maxNumberOfQueriesToKeep];
    NSUInteger numMax = (numPrunable > maxToKeep) ? numPrunable - maxToKeep : 0;
    // Make sure we get below number of max queries to prune
    return MAX(numMax, numPercent);
}

- (FPruneForest *)pruneOldQueries:(id<FCachePolicy>)cachePolicy {
    NSMutableArray *pruneableQueries = [NSMutableArray array];
    NSMutableArray *unpruneableQueries = [NSMutableArray array];
    [self.trackedQueryTree
        forEach:^(FPath *path, NSDictionary *trackedQueries) {
          [trackedQueries enumerateKeysAndObjectsUsingBlock:^(
                              FQueryParams *params, FTrackedQuery *trackedQuery,
                              BOOL *stop) {
            if (!trackedQuery.isActive) {
                [pruneableQueries addObject:trackedQuery];
            } else {
                [unpruneableQueries addObject:trackedQuery];
            }
          }];
        }];
    [pruneableQueries sortUsingComparator:^NSComparisonResult(
                          FTrackedQuery *q1, FTrackedQuery *q2) {
      if (q1.lastUse < q2.lastUse) {
          return NSOrderedAscending;
      } else if (q1.lastUse > q2.lastUse) {
          return NSOrderedDescending;
      } else {
          return NSOrderedSame;
      }
    }];

    __block FPruneForest *pruneForest = [FPruneForest empty];
    NSUInteger numToPrune =
        [self numberOfQueriesToPrune:cachePolicy
                       prunableCount:pruneableQueries.count];

    // TODO: do in transaction
    for (NSUInteger i = 0; i < numToPrune; i++) {
        FTrackedQuery *toPrune = pruneableQueries[i];
        pruneForest = [pruneForest prunePath:toPrune.query.path];
        [self removeTrackedQuery:toPrune.query];
    }

    // Keep the rest of the prunable queries
    for (NSUInteger i = numToPrune; i < pruneableQueries.count; i++) {
        FTrackedQuery *toKeep = pruneableQueries[i];
        pruneForest = [pruneForest keepPath:toKeep.query.path];
    }

    // Also keep unprunable queries
    [unpruneableQueries enumerateObjectsUsingBlock:^(
                            FTrackedQuery *toKeep, NSUInteger idx, BOOL *stop) {
      pruneForest = [pruneForest keepPath:toKeep.query.path];
    }];

    return pruneForest;
}

- (NSUInteger)numberOfPrunableQueries {
    __block NSUInteger count = 0;
    [self.trackedQueryTree
        forEach:^(FPath *path, NSDictionary *trackedQueries) {
          [trackedQueries enumerateKeysAndObjectsUsingBlock:^(
                              FQueryParams *params, FTrackedQuery *trackedQuery,
                              BOOL *stop) {
            if (!trackedQuery.isActive) {
                count++;
            }
          }];
        }];
    return count;
}

- (NSSet *)filteredQueryIdsAtPath:(FPath *)path {
    NSDictionary *queries = [self.trackedQueryTree valueAtPath:path];
    if (queries) {
        NSMutableSet *ids = [NSMutableSet set];
        [queries enumerateKeysAndObjectsUsingBlock:^(
                     FQueryParams *params, FTrackedQuery *query, BOOL *stop) {
          if (!query.query.loadsAllData) {
              [ids addObject:@(query.queryId)];
          }
        }];
        return ids;
    } else {
        return [NSSet set];
    }
}

- (NSSet *)knownCompleteChildrenAtPath:(FPath *)path {
    NSAssert(![self isQueryComplete:[FQuerySpec defaultQueryAtPath:path]],
             @"Path is fully complete");

    NSMutableSet *completeChildren = [NSMutableSet set];
    // First, get complete children from any queries at this location.
    NSSet *queryIds = [self filteredQueryIdsAtPath:path];
    [queryIds enumerateObjectsUsingBlock:^(NSNumber *queryId, BOOL *stop) {
      NSSet *keys = [self.storageEngine
          trackedQueryKeysForQuery:[queryId unsignedIntegerValue]];
      [completeChildren unionSet:keys];
    }];

    // Second, get any complete default queries immediately below us.
    [[[self.trackedQueryTree subtreeAtPath:path] children]
        enumerateKeysAndObjectsUsingBlock:^(
            NSString *childKey, FImmutableTree *childTree, BOOL *stop) {
          if ([childTree.value[[FQueryParams defaultInstance]] isComplete]) {
              [completeChildren addObject:childKey];
          }
        }];

    return completeChildren;
}

- (void)verifyCache {
    NSArray *storedTrackedQueries = [self.storageEngine loadTrackedQueries];
    NSMutableArray *trackedQueries = [NSMutableArray array];

    [self.trackedQueryTree forEach:^(FPath *path, NSDictionary *queryDict) {
      [trackedQueries addObjectsFromArray:queryDict.allValues];
    }];
    NSComparator comparator =
        ^NSComparisonResult(FTrackedQuery *q1, FTrackedQuery *q2) {
          if (q1.queryId < q2.queryId) {
              return NSOrderedAscending;
          } else if (q1.queryId > q2.queryId) {
              return NSOrderedDescending;
          } else {
              return NSOrderedSame;
          }
        };
    [trackedQueries sortUsingComparator:comparator];
    storedTrackedQueries =
        [storedTrackedQueries sortedArrayUsingComparator:comparator];

    if (![trackedQueries isEqualToArray:storedTrackedQueries]) {
        [NSException
             raise:NSInternalInconsistencyException
            format:@"Tracked queries and queries stored on disk don't match"];
    }
}

@end
