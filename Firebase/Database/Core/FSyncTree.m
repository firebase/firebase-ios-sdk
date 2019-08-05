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

#import "FSyncTree.h"
#import "FAckUserWrite.h"
#import "FAtomicNumber.h"
#import "FCacheNode.h"
#import "FChildrenNode.h"
#import "FCompoundHash.h"
#import "FCompoundWrite.h"
#import "FEmptyNode.h"
#import "FEventRaiser.h"
#import "FEventRegistration.h"
#import "FImmutableTree.h"
#import "FKeepSyncedEventRegistration.h"
#import "FListenComplete.h"
#import "FListenProvider.h"
#import "FMerge.h"
#import "FNode.h"
#import "FOperation.h"
#import "FOperationSource.h"
#import "FOverwrite.h"
#import "FPath.h"
#import "FPersistenceManager.h"
#import "FQueryParams.h"
#import "FQuerySpec.h"
#import "FRangeMerge.h"
#import "FServerValues.h"
#import "FSnapshotHolder.h"
#import "FSnapshotUtilities.h"
#import "FSyncPoint.h"
#import "FTupleRemovedQueriesEvents.h"
#import "FUtilities.h"
#import "FView.h"
#import "FWriteRecord.h"
#import "FWriteTree.h"
#import "FWriteTreeRef.h"
#import <FirebaseCore/FIRLogger.h>

// Size after which we start including the compound hash
static const NSUInteger kFSizeThresholdForCompoundHash = 1024;

@interface FListenContainer : NSObject <FSyncTreeHash>

@property(nonatomic, strong) FView *view;
@property(nonatomic, copy) fbt_nsarray_nsstring onComplete;

@end

@implementation FListenContainer

- (instancetype)initWithView:(FView *)view
                  onComplete:(fbt_nsarray_nsstring)onComplete {
    self = [super init];
    if (self != nil) {
        self->_view = view;
        self->_onComplete = onComplete;
    }
    return self;
}

- (id<FNode>)serverCache {
    return self.view.serverCache;
}

- (FCompoundHash *)compoundHash {
    return [FCompoundHash fromNode:[self serverCache]];
}

- (NSString *)simpleHash {
    return [[self serverCache] dataHash];
}

- (BOOL)includeCompoundHash {
    return [FSnapshotUtilities estimateSerializedNodeSize:[self serverCache]] >
           kFSizeThresholdForCompoundHash;
}

@end

@interface FSyncTree ()

/**
 * Tree of SyncPoints. There's a SyncPoint at any location that has 1 or more
 * views.
 */
@property(nonatomic, strong) FImmutableTree *syncPointTree;

/**
 * A tree of all pending user writes (user-initiated set, transactions, updates,
 * etc)
 */
@property(nonatomic, strong) FWriteTree *pendingWriteTree;

/**
 * Maps tagId -> FTuplePathQueryParams
 */
@property(nonatomic, strong) NSMutableDictionary *tagToQueryMap;
@property(nonatomic, strong) NSMutableDictionary *queryToTagMap;
@property(nonatomic, strong) FListenProvider *listenProvider;
@property(nonatomic, strong) FPersistenceManager *persistenceManager;
@property(nonatomic, strong) FAtomicNumber *queryTagCounter;
@property(nonatomic, strong) NSMutableSet *keepSyncedQueries;

@end

/**
 * SyncTree is the central class for managing event callback registration, data
 * caching, views (query processing), and event generation.  There are typically
 * two SyncTree instances for each Repo, one for the normal Firebase data, and
 * one for the .info data.
 *
 * It has a number of responsibilities, including:
 *  - Tracking all user event callbacks (registered via addEventRegistration:
 * and removeEventRegistration:).
 *  - Applying and caching data changes for user setValue:,
 * runTransactionBlock:, and updateChildValues: calls
 *    (applyUserOverwriteAtPath:, applyUserMergeAtPath:).
 *  - Applying and caching data changes for server data changes
 * (applyServerOverwriteAtPath:, applyServerMergeAtPath:).
 *  - Generating user-facing events for server and user changes (all of the
 * apply* methods return the set of events that need to be raised as a result).
 *  - Maintaining the appropriate set of server listens to ensure we are always
 * subscribed to the correct set of paths and queries to satisfy the current set
 * of user event callbacks (listens are started/stopped using the provided
 * listenProvider).
 *
 * NOTE: Although SyncTree tracks event callbacks and calculates events to
 * raise, the actual events are returned to the caller rather than raised
 * synchronously.
 */
@implementation FSyncTree

- (id)initWithListenProvider:(FListenProvider *)provider {
    return [self initWithPersistenceManager:nil listenProvider:provider];
}

- (id)initWithPersistenceManager:(FPersistenceManager *)persistenceManager
                  listenProvider:(FListenProvider *)provider {
    self = [super init];
    if (self) {
        self.syncPointTree = [FImmutableTree empty];
        self.pendingWriteTree = [[FWriteTree alloc] init];
        self.tagToQueryMap = [[NSMutableDictionary alloc] init];
        self.queryToTagMap = [[NSMutableDictionary alloc] init];
        self.listenProvider = provider;
        self.persistenceManager = persistenceManager;
        self.queryTagCounter = [[FAtomicNumber alloc] init];
        self.keepSyncedQueries = [NSMutableSet set];
    }
    return self;
}

#pragma mark -
#pragma mark Apply Operations

/**
 * Apply data changes for a user-generated setValue: runTransactionBlock:
 * updateChildValues:, etc.
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)applyUserOverwriteAtPath:(FPath *)path
                              newData:(id<FNode>)newData
                              writeId:(NSInteger)writeId
                            isVisible:(BOOL)visible {
    // Record pending write
    [self.pendingWriteTree addOverwriteAtPath:path
                                      newData:newData
                                      writeId:writeId
                                    isVisible:visible];
    if (!visible) {
        return @[];
    } else {
        FOverwrite *operation =
            [[FOverwrite alloc] initWithSource:[FOperationSource userInstance]
                                          path:path
                                          snap:newData];
        return [self applyOperationToSyncPoints:operation];
    }
}

/**
 * Apply the data from a user-generated updateChildValues: call
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)applyUserMergeAtPath:(FPath *)path
                  changedChildren:(FCompoundWrite *)changedChildren
                          writeId:(NSInteger)writeId {
    // Record pending merge
    [self.pendingWriteTree addMergeAtPath:path
                          changedChildren:changedChildren
                                  writeId:writeId];

    FMerge *operation =
        [[FMerge alloc] initWithSource:[FOperationSource userInstance]
                                  path:path
                              children:changedChildren];
    return [self applyOperationToSyncPoints:operation];
}

/**
 * Acknowledge a pending user write that was previously registered with
 * applyUserOverwriteAtPath: or applyUserMergeAtPath:
 * TODO[offline]: Taking a serverClock here is awkward, but server values are
 * awkward. :-(
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)ackUserWriteWithWriteId:(NSInteger)writeId
                              revert:(BOOL)revert
                             persist:(BOOL)persist
                               clock:(id<FClock>)clock {
    FWriteRecord *write = [self.pendingWriteTree writeForId:writeId];
    BOOL needToReevaluate = [self.pendingWriteTree removeWriteId:writeId];
    if (write.visible) {
        if (persist) {
            [self.persistenceManager removeUserWrite:writeId];
        }
        if (!revert) {
            NSDictionary *serverValues =
                [FServerValues generateServerValues:clock];
            if ([write isOverwrite]) {
                id<FNode> resolvedNode =
                    [FServerValues resolveDeferredValueSnapshot:write.overwrite
                                               withServerValues:serverValues];
                [self.persistenceManager applyUserWrite:resolvedNode
                                    toServerCacheAtPath:write.path];
            } else {
                FCompoundWrite *resolvedMerge = [FServerValues
                    resolveDeferredValueCompoundWrite:write.merge
                                     withServerValues:serverValues];
                [self.persistenceManager applyUserMerge:resolvedMerge
                                    toServerCacheAtPath:write.path];
            }
        }
    }
    if (!needToReevaluate) {
        return @[];
    } else {
        __block FImmutableTree *affectedTree = [FImmutableTree empty];
        if (write.isOverwrite) {
            affectedTree = [affectedTree setValue:@YES atPath:[FPath empty]];
        } else {
            [write.merge
                enumerateWrites:^(FPath *path, id<FNode> node, BOOL *stop) {
                  affectedTree = [affectedTree setValue:@YES atPath:path];
                }];
        }
        FAckUserWrite *operation =
            [[FAckUserWrite alloc] initWithPath:write.path
                                   affectedTree:affectedTree
                                         revert:revert];
        return [self applyOperationToSyncPoints:operation];
    }
}

/**
 * Apply new server data for the specified path
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)applyServerOverwriteAtPath:(FPath *)path
                                newData:(id<FNode>)newData {
    [self.persistenceManager
        updateServerCacheWithNode:newData
                         forQuery:[FQuerySpec defaultQueryAtPath:path]];
    FOverwrite *operation =
        [[FOverwrite alloc] initWithSource:[FOperationSource serverInstance]
                                      path:path
                                      snap:newData];
    return [self applyOperationToSyncPoints:operation];
}

/**
 * Applied new server data to be merged in at the specified path
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)applyServerMergeAtPath:(FPath *)path
                    changedChildren:(FCompoundWrite *)changedChildren {
    [self.persistenceManager updateServerCacheWithMerge:changedChildren
                                                 atPath:path];
    FMerge *operation =
        [[FMerge alloc] initWithSource:[FOperationSource serverInstance]
                                  path:path
                              children:changedChildren];
    return [self applyOperationToSyncPoints:operation];
}

- (NSArray *)applyServerRangeMergeAtPath:(FPath *)path
                                 updates:(NSArray *)ranges {
    FSyncPoint *syncPoint = [self.syncPointTree valueAtPath:path];
    if (syncPoint == nil) {
        // Removed view, so it's safe to just ignore this update
        return @[];
    } else {
        // This could be for any "complete" (unfiltered) view, and if there is
        // more than one complete view, they should each have the same cache so
        // it doesn't matter which one we use.
        FView *view = [syncPoint completeView];
        if (view != nil) {
            id<FNode> serverNode = [view serverCache];
            for (FRangeMerge *merge in ranges) {
                serverNode = [merge applyToNode:serverNode];
            }
            return [self applyServerOverwriteAtPath:path newData:serverNode];
        } else {
            // There doesn't exist a view for this update, so it was removed and
            // it's safe to just ignore this range merge
            return @[];
        }
    }
}

/**
 * Apply a listen complete to a path
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)applyListenCompleteAtPath:(FPath *)path {
    [self.persistenceManager
        setQueryComplete:[FQuerySpec defaultQueryAtPath:path]];
    id<FOperation> operation = [[FListenComplete alloc]
        initWithSource:[FOperationSource serverInstance]
                  path:path];
    return [self applyOperationToSyncPoints:operation];
}

/**
 * Apply a listen complete to a path
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)applyTaggedListenCompleteAtPath:(FPath *)path
                                       tagId:(NSNumber *)tagId {
    FQuerySpec *query = [self queryForTag:tagId];
    if (query != nil) {
        [self.persistenceManager setQueryComplete:query];
        FPath *relativePath = [FPath relativePathFrom:query.path to:path];
        id<FOperation> op = [[FListenComplete alloc]
            initWithSource:[FOperationSource forServerTaggedQuery:query.params]
                      path:relativePath];
        return [self applyTaggedOperation:op atPath:query.path];
    } else {
        // We've already removed the query. No big deal, ignore the update.
        return @[];
    }
}

/**
 * Internal helper method to apply tagged operation
 */
- (NSArray *)applyTaggedOperation:(id<FOperation>)operation
                           atPath:(FPath *)path {
    FSyncPoint *syncPoint = [self.syncPointTree valueAtPath:path];
    NSAssert(syncPoint != nil,
             @"Missing sync point for query tag that we're tracking.");
    FWriteTreeRef *writesCache =
        [self.pendingWriteTree childWritesForPath:path];
    return [syncPoint applyOperation:operation
                         writesCache:writesCache
                         serverCache:nil];
}

/**
 * Apply new server data for the specified tagged query
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)applyTaggedQueryOverwriteAtPath:(FPath *)path
                                     newData:(id<FNode>)newData
                                       tagId:(NSNumber *)tagId {
    FQuerySpec *query = [self queryForTag:tagId];
    if (query != nil) {
        FPath *relativePath = [FPath relativePathFrom:query.path to:path];
        FQuerySpec *queryToOverwrite =
            relativePath.isEmpty ? query : [FQuerySpec defaultQueryAtPath:path];
        [self.persistenceManager updateServerCacheWithNode:newData
                                                  forQuery:queryToOverwrite];
        FOverwrite *operation = [[FOverwrite alloc]
            initWithSource:[FOperationSource forServerTaggedQuery:query.params]
                      path:relativePath
                      snap:newData];
        return [self applyTaggedOperation:operation atPath:query.path];
    } else {
        // Query must have been removed already
        return @[];
    }
}

/**
 * Apply server data to be merged in for the specified tagged query
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)applyTaggedQueryMergeAtPath:(FPath *)path
                         changedChildren:(FCompoundWrite *)changedChildren
                                   tagId:(NSNumber *)tagId {
    FQuerySpec *query = [self queryForTag:tagId];
    if (query != nil) {
        FPath *relativePath = [FPath relativePathFrom:query.path to:path];
        [self.persistenceManager updateServerCacheWithMerge:changedChildren
                                                     atPath:path];
        FMerge *operation = [[FMerge alloc]
            initWithSource:[FOperationSource forServerTaggedQuery:query.params]
                      path:relativePath
                  children:changedChildren];
        return [self applyTaggedOperation:operation atPath:query.path];
    } else {
        // We've already removed the query. No big deal, ignore the update.
        return @[];
    }
}

- (NSArray *)applyTaggedServerRangeMergeAtPath:(FPath *)path
                                       updates:(NSArray *)ranges
                                         tagId:(NSNumber *)tagId {
    FQuerySpec *query = [self queryForTag:tagId];
    if (query != nil) {
        NSAssert([path isEqual:query.path],
                 @"Tagged update path and query path must match");
        FSyncPoint *syncPoint = [self.syncPointTree valueAtPath:path];
        NSAssert(syncPoint != nil,
                 @"Missing sync point for query tag that we're tracking.");
        FView *view = [syncPoint viewForQuery:query];
        NSAssert(view != nil,
                 @"Missing view for query tag that we're tracking");
        id<FNode> serverNode = [view serverCache];
        for (FRangeMerge *merge in ranges) {
            serverNode = [merge applyToNode:serverNode];
        }
        return [self applyTaggedQueryOverwriteAtPath:path
                                             newData:serverNode
                                               tagId:tagId];
    } else {
        // We've already removed the query. No big deal, ignore the update.
        return @[];
    }
}

/**
 * Add an event callback for the specified query
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)addEventRegistration:(id<FEventRegistration>)eventRegistration
                         forQuery:(FQuerySpec *)query {
    FPath *path = query.path;

    __block BOOL foundAncestorDefaultView = NO;
    [self.syncPointTree
        forEachOnPath:query.path
           whileBlock:^BOOL(FPath *pathToSyncPoint, FSyncPoint *syncPoint) {
             foundAncestorDefaultView =
                 foundAncestorDefaultView || [syncPoint hasCompleteView];
             return !foundAncestorDefaultView;
           }];

    [self.persistenceManager setQueryActive:query];

    FSyncPoint *syncPoint = [self.syncPointTree valueAtPath:path];
    if (syncPoint == nil) {
        syncPoint = [[FSyncPoint alloc]
            initWithPersistenceManager:self.persistenceManager];
        self.syncPointTree = [self.syncPointTree setValue:syncPoint
                                                   atPath:path];
    }

    BOOL viewAlreadyExists = [syncPoint viewExistsForQuery:query];
    NSArray *events;
    if (viewAlreadyExists) {
        events = [syncPoint addEventRegistration:eventRegistration
                         forExistingViewForQuery:query];
    } else {
        if (![query loadsAllData]) {
            // We need to track a tag for this query
            NSAssert(self.queryToTagMap[query] == nil,
                     @"View does not exist, but we have a tag");
            NSNumber *tagId = [self.queryTagCounter getAndIncrement];
            self.queryToTagMap[query] = tagId;
            self.tagToQueryMap[tagId] = query;
        }

        FWriteTreeRef *writesCache =
            [self.pendingWriteTree childWritesForPath:path];
        FCacheNode *serverCache = [self serverCacheForQuery:query];
        events = [syncPoint addEventRegistration:eventRegistration
                      forNonExistingViewForQuery:query
                                     writesCache:writesCache
                                     serverCache:serverCache];

        // There was no view and no default listen
        if (!foundAncestorDefaultView) {
            FView *view = [syncPoint viewForQuery:query];
            NSMutableArray *mutableEvents = [events mutableCopy];
            [mutableEvents
                addObjectsFromArray:[self setupListenerOnQuery:query
                                                          view:view]];
            events = mutableEvents;
        }
    }

    return events;
}

- (FCacheNode *)serverCacheForQuery:(FQuerySpec *)query {
    __block id<FNode> serverCacheNode = nil;

    [self.syncPointTree
        forEachOnPath:query.path
           whileBlock:^BOOL(FPath *pathToSyncPoint, FSyncPoint *syncPoint) {
             FPath *relativePath = [FPath relativePathFrom:pathToSyncPoint
                                                        to:query.path];
             serverCacheNode =
                 [syncPoint completeServerCacheAtPath:relativePath];
             return serverCacheNode == nil;
           }];

    FCacheNode *serverCache;
    if (serverCacheNode != nil) {
        FIndexedNode *indexed =
            [FIndexedNode indexedNodeWithNode:serverCacheNode
                                        index:query.index];
        serverCache = [[FCacheNode alloc] initWithIndexedNode:indexed
                                           isFullyInitialized:YES
                                                   isFiltered:NO];
    } else {
        FCacheNode *persistenceServerCache =
            [self.persistenceManager serverCacheForQuery:query];
        if (persistenceServerCache.isFullyInitialized) {
            serverCache = persistenceServerCache;
        } else {
            serverCacheNode = [FEmptyNode emptyNode];

            FImmutableTree *subtree =
                [self.syncPointTree subtreeAtPath:query.path];
            [subtree
                forEachChild:^(NSString *childKey, FSyncPoint *childSyncPoint) {
                  id<FNode> completeCache =
                      [childSyncPoint completeServerCacheAtPath:[FPath empty]];
                  if (completeCache) {
                      serverCacheNode =
                          [serverCacheNode updateImmediateChild:childKey
                                                   withNewChild:completeCache];
                  }
                }];
            // Fill the node with any available children we have
            [persistenceServerCache.node
                enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                              BOOL *stop) {
                  if (![serverCacheNode hasChild:key]) {
                      serverCacheNode =
                          [serverCacheNode updateImmediateChild:key
                                                   withNewChild:node];
                  }
                }];
            FIndexedNode *indexed =
                [FIndexedNode indexedNodeWithNode:serverCacheNode
                                            index:query.index];
            serverCache = [[FCacheNode alloc] initWithIndexedNode:indexed
                                               isFullyInitialized:NO
                                                       isFiltered:NO];
        }
    }

    return serverCache;
}

/**
 * Remove event callback(s).
 *
 * If query is the default query, we'll check all queries for the specified
 * eventRegistration. If eventRegistration is null, we'll remove all callbacks
 * for the specified query/queries.
 *
 * @param eventRegistration if nil, all callbacks are removed
 * @param cancelError If provided, appropriate cancel events will be returned
 * @return NSArray of FEvent to raise.
 */
- (NSArray *)removeEventRegistration:(id<FEventRegistration>)eventRegistration
                            forQuery:(FQuerySpec *)query
                         cancelError:(NSError *)cancelError {
    // Find the syncPoint first. Then deal with whether or not it has matching
    // listeners
    FPath *path = query.path;
    FSyncPoint *maybeSyncPoint = [self.syncPointTree valueAtPath:path];
    NSArray *cancelEvents = @[];

    // A removal on a default query affects all queries at that location. A
    // removal on an indexed query, even one without other query constraints,
    // does *not* affect all queries at that location. So this check must be for
    // 'default', and not loadsAllData:
    if (maybeSyncPoint &&
        ([query isDefault] || [maybeSyncPoint viewExistsForQuery:query])) {
        FTupleRemovedQueriesEvents *removedAndEvents =
            [maybeSyncPoint removeEventRegistration:eventRegistration
                                           forQuery:query
                                        cancelError:cancelError];
        if ([maybeSyncPoint isEmpty]) {
            self.syncPointTree = [self.syncPointTree removeValueAtPath:path];
        }
        NSArray *removed = removedAndEvents.removedQueries;
        cancelEvents = removedAndEvents.cancelEvents;

        // We may have just removed one of many listeners and can short-circuit
        // this whole process We may also not have removed a default listener,
        // in which case all of the descendant listeners should already be
        // properly set up.
        //
        // Since indexed queries can shadow if they don't have other query
        // constraints, check for loadsAllData: instead of isDefault:
        NSUInteger defaultQueryIndex = [removed
            indexOfObjectPassingTest:^BOOL(FQuerySpec *q, NSUInteger idx,
                                           BOOL *stop) {
              return [q loadsAllData];
            }];
        BOOL removingDefault = defaultQueryIndex != NSNotFound;
        [removed enumerateObjectsUsingBlock:^(FQuerySpec *query, NSUInteger idx,
                                              BOOL *stop) {
          [self.persistenceManager setQueryInactive:query];
        }];
        NSNumber *covered = [self.syncPointTree
               findOnPath:path
            andApplyBlock:^id(FPath *relativePath,
                              FSyncPoint *parentSyncPoint) {
              return
                  [NSNumber numberWithBool:[parentSyncPoint hasCompleteView]];
            }];

        if (removingDefault && ![covered boolValue]) {
            FImmutableTree *subtree = [self.syncPointTree subtreeAtPath:path];
            // There are potentially child listeners. Determine what if any
            // listens we need to send before executing the removal
            if (![subtree isEmpty]) {
                // We need to fold over our subtree and collect the listeners to
                // send
                NSArray *newViews =
                    [self collectDistinctViewsForSubTree:subtree];

                // Ok, we've collected all the listens we need. Set them up.
                [newViews enumerateObjectsUsingBlock:^(
                              FView *view, NSUInteger idx, BOOL *stop) {
                  FQuerySpec *newQuery = view.query;
                  FListenContainer *listenContainer =
                      [self createListenerForView:view];
                  self.listenProvider.startListening(
                      [self queryForListening:newQuery],
                      [self tagForQuery:newQuery], listenContainer,
                      listenContainer.onComplete);
                }];
            } else {
                // There's nothing below us, so nothing we need to start
                // listening on
            }
        }

        // If we removed anything and we're not covered by a higher up listen,
        // we need to stop listening on this query. The above block has us
        // covered in terms of making sure we're set up on listens lower in the
        // tree. Also, note that if we have a cancelError, it's already been
        // removed at the provider level.
        if (![covered boolValue] && [removed count] > 0 && cancelError == nil) {
            // If we removed a default, then we weren't listening on any of the
            // other queries here. Just cancel the one default. Otherwise, we
            // need to iterate through and cancel each individual query
            if (removingDefault) {
                // We don't tag default listeners
                self.listenProvider.stopListening(
                    [self queryForListening:query], nil);
            } else {
                [removed
                    enumerateObjectsUsingBlock:^(FQuerySpec *queryToRemove,
                                                 NSUInteger idx, BOOL *stop) {
                      NSNumber *tagToRemove =
                          [self.queryToTagMap objectForKey:queryToRemove];
                      self.listenProvider.stopListening(
                          [self queryForListening:queryToRemove], tagToRemove);
                    }];
            }
        }
        // Now, clear all the tags we're tracking for the removed listens.
        [self removeTags:removed];
    } else {
        // No-op, this listener must've been already removed
    }
    return cancelEvents;
}

- (void)keepQuery:(FQuerySpec *)query synced:(BOOL)keepSynced {
    // Only do something if we actually need to add/remove an event registration
    if (keepSynced && ![self.keepSyncedQueries containsObject:query]) {
        [self addEventRegistration:[FKeepSyncedEventRegistration instance]
                          forQuery:query];
        [self.keepSyncedQueries addObject:query];
    } else if (!keepSynced && [self.keepSyncedQueries containsObject:query]) {
        [self removeEventRegistration:[FKeepSyncedEventRegistration instance]
                             forQuery:query
                          cancelError:nil];
        [self.keepSyncedQueries removeObject:query];
    }
}

- (NSArray *)removeAllWrites {
    [self.persistenceManager removeAllUserWrites];
    NSArray *removedWrites = [self.pendingWriteTree removeAllWrites];
    if (removedWrites.count > 0) {
        FImmutableTree *affectedTree =
            [[FImmutableTree empty] setValue:@YES atPath:[FPath empty]];
        return [self applyOperationToSyncPoints:[[FAckUserWrite alloc]
                                                    initWithPath:[FPath empty]
                                                    affectedTree:affectedTree
                                                          revert:YES]];
    } else {
        return @[];
    }
}

/**
 * Returns a complete cache, if we have one, of the data at a particular path.
 * The location must have a listener above it, but as this is only used by
 * transaction code, that should always be the case anyways.
 *
 * Note: this method will *include* hidden writes from transaction with
 * applyLocally set to false.
 * @param path The path to the data we want
 * @param writeIdsToExclude A specific set to be excluded
 */
- (id<FNode>)calcCompleteEventCacheAtPath:(FPath *)path
                          excludeWriteIds:(NSArray *)writeIdsToExclude {
    BOOL includeHiddenSets = YES;
    FWriteTree *writeTree = self.pendingWriteTree;
    id<FNode> serverCache = [self.syncPointTree
           findOnPath:path
        andApplyBlock:^id<FNode>(FPath *pathSoFar, FSyncPoint *syncPoint) {
          FPath *relativePath = [FPath relativePathFrom:pathSoFar to:path];
          id<FNode> serverCache =
              [syncPoint completeServerCacheAtPath:relativePath];
          if (serverCache) {
              return serverCache;
          } else {
              return nil;
          }
        }];
    return [writeTree calculateCompleteEventCacheAtPath:path
                                    completeServerCache:serverCache
                                        excludeWriteIds:writeIdsToExclude
                                    includeHiddenWrites:includeHiddenSets];
}

#pragma mark -
#pragma mark Private Methods
/**
 * This collapses multiple unfiltered views into a single view, since we only
 * need a single listener for them.
 * @return NSArray of FView
 */
- (NSArray *)collectDistinctViewsForSubTree:(FImmutableTree *)subtree {
    return [subtree foldWithBlock:^NSArray *(FPath *relativePath,
                                             FSyncPoint *maybeChildSyncPoint,
                                             NSDictionary *childMap) {
      if (maybeChildSyncPoint && [maybeChildSyncPoint hasCompleteView]) {
          FView *completeView = [maybeChildSyncPoint completeView];
          return @[ completeView ];
      } else {
          // No complete view here, flatten any deeper listens into an array
          NSMutableArray *views = [[NSMutableArray alloc] init];
          if (maybeChildSyncPoint) {
              views = [[maybeChildSyncPoint queryViews] mutableCopy];
          }
          [childMap enumerateKeysAndObjectsUsingBlock:^(
                        NSString *childKey, NSArray *childViews, BOOL *stop) {
            [views addObjectsFromArray:childViews];
          }];
          return views;
      }
    }];
}

/**
 * @param queries NSArray of FQuerySpec
 */
- (void)removeTags:(NSArray *)queries {
    [queries enumerateObjectsUsingBlock:^(FQuerySpec *removedQuery,
                                          NSUInteger idx, BOOL *stop) {
      if (![removedQuery loadsAllData]) {
          // We should have a tag for this
          NSNumber *removedQueryTag = self.queryToTagMap[removedQuery];
          [self.queryToTagMap removeObjectForKey:removedQuery];
          [self.tagToQueryMap removeObjectForKey:removedQueryTag];
      }
    }];
}

- (FQuerySpec *)queryForListening:(FQuerySpec *)query {
    if (query.loadsAllData && !query.isDefault) {
        // We treat queries that load all data as default queries
        return [FQuerySpec defaultQueryAtPath:query.path];
    } else {
        return query;
    }
}

/**
 * For a given new listen, manage the de-duplication of outstanding
 * subscriptions.
 * @return NSArray of FEvent events to support synchronous data sources
 */
- (NSArray *)setupListenerOnQuery:(FQuerySpec *)query view:(FView *)view {
    FPath *path = query.path;
    NSNumber *tagId = [self tagForQuery:query];
    FListenContainer *listenContainer = [self createListenerForView:view];

    NSArray *events = self.listenProvider.startListening(
        [self queryForListening:query], tagId, listenContainer,
        listenContainer.onComplete);

    FImmutableTree *subtree = [self.syncPointTree subtreeAtPath:path];
    // The root of this subtree has our query. We're here because we definitely
    // need to send a listen for that, but we may need to shadow other listens
    // as well.
    if (tagId != nil) {
        NSAssert(![subtree.value hasCompleteView],
                 @"If we're adding a query, it shouldn't be shadowed");
    } else {
        // Shadow everything at or below this location, this is a default
        // listener.
        NSArray *queriesToStop =
            [subtree foldWithBlock:^id(FPath *relativePath,
                                       FSyncPoint *maybeChildSyncPoint,
                                       NSDictionary *childMap) {
              if (![relativePath isEmpty] && maybeChildSyncPoint != nil &&
                  [maybeChildSyncPoint hasCompleteView]) {
                  return @[ [maybeChildSyncPoint completeView].query ];
              } else {
                  // No default listener here, flatten any deeper queries into
                  // an array
                  NSMutableArray *queries = [[NSMutableArray alloc] init];
                  if (maybeChildSyncPoint != nil) {
                      for (FView *view in [maybeChildSyncPoint queryViews]) {
                          [queries addObject:view.query];
                      }
                  }
                  [childMap
                      enumerateKeysAndObjectsUsingBlock:^(
                          NSString *key, NSArray *childQueries, BOOL *stop) {
                        [queries addObjectsFromArray:childQueries];
                      }];
                  return queries;
              }
            }];
        for (FQuerySpec *queryToStop in queriesToStop) {
            self.listenProvider.stopListening(
                [self queryForListening:queryToStop],
                [self tagForQuery:queryToStop]);
        }
    }
    return events;
}

- (FListenContainer *)createListenerForView:(FView *)view {
    FQuerySpec *query = view.query;
    NSNumber *tagId = [self tagForQuery:query];

    FListenContainer *listenContainer = [[FListenContainer alloc]
        initWithView:view
          onComplete:^(NSString *status) {
            if ([status isEqualToString:@"ok"]) {
                if (tagId != nil) {
                    return [self applyTaggedListenCompleteAtPath:query.path
                                                           tagId:tagId];
                } else {
                    return [self applyListenCompleteAtPath:query.path];
                }
            } else {
                // If a listen failed, kill all of the listeners here, not just
                // the one that triggered the error. Note that this may need to
                // be scoped to just this listener if we change permissions on
                // filtered children
                NSError *error = [FUtilities errorForStatus:status
                                                  andReason:nil];
                FFWarn(@"I-RDB038012", @"Listener at %@ failed: %@", query.path,
                       status);
                return [self removeEventRegistration:nil
                                            forQuery:query
                                         cancelError:error];
            }
          }];

    return listenContainer;
}

/**
 * @return The query associated with the given tag, if we have one
 */
- (FQuerySpec *)queryForTag:(NSNumber *)tagId {
    return self.tagToQueryMap[tagId];
}

/**
 * @return The tag associated with the given query
 */
- (NSNumber *)tagForQuery:(FQuerySpec *)query {
    return self.queryToTagMap[query];
}

#pragma mark -
#pragma mark applyOperation Helpers

/**
* A helper method that visits all descendant and ancestor SyncPoints, applying
the operation.
*
* NOTES:
* - Descendant SyncPoints will be visited first (since we raise events
depth-first).

* - We call applyOperation: on each SyncPoint passing three things:
*   1. A version of the Operation that has been made relative to the SyncPoint
location.
*   2. A WriteTreeRef of any writes we have cached at the SyncPoint location.
*   3. A snapshot Node with cached server data, if we have it.

* - We concatenate all of the events returned by each SyncPoint and return the
result.
*
* @return Array of FEvent
*/
- (NSArray *)applyOperationToSyncPoints:(id<FOperation>)operation {
    return [self applyOperationHelper:operation
                        syncPointTree:self.syncPointTree
                          serverCache:nil
                          writesCache:[self.pendingWriteTree
                                          childWritesForPath:[FPath empty]]];
}

/**
 * Recursive helper for applyOperationToSyncPoints_
 */
- (NSArray *)applyOperationHelper:(id<FOperation>)operation
                    syncPointTree:(FImmutableTree *)syncPointTree
                      serverCache:(id<FNode>)serverCache
                      writesCache:(FWriteTreeRef *)writesCache {
    if ([operation.path isEmpty]) {
        return [self applyOperationDescendantsHelper:operation
                                       syncPointTree:syncPointTree
                                         serverCache:serverCache
                                         writesCache:writesCache];
    } else {
        FSyncPoint *syncPoint = syncPointTree.value;

        // If we don't have cached server data, see if we can get it from this
        // SyncPoint
        if (serverCache == nil && syncPoint != nil) {
            serverCache = [syncPoint completeServerCacheAtPath:[FPath empty]];
        }

        NSMutableArray *events = [[NSMutableArray alloc] init];
        NSString *childKey = [operation.path getFront];
        id<FOperation> childOperation = [operation operationForChild:childKey];
        FImmutableTree *childTree = [syncPointTree.children get:childKey];
        if (childTree != nil && childOperation != nil) {
            id<FNode> childServerCache =
                serverCache ? [serverCache getImmediateChild:childKey] : nil;
            FWriteTreeRef *childWritesCache =
                [writesCache childWriteTreeRef:childKey];
            [events
                addObjectsFromArray:[self
                                        applyOperationHelper:childOperation
                                               syncPointTree:childTree
                                                 serverCache:childServerCache
                                                 writesCache:childWritesCache]];
        }

        if (syncPoint) {
            [events addObjectsFromArray:[syncPoint applyOperation:operation
                                                      writesCache:writesCache
                                                      serverCache:serverCache]];
        }

        return events;
    }
}

/**
 *  Recursive helper for applyOperationToSyncPoints:
 */
- (NSArray *)applyOperationDescendantsHelper:(id<FOperation>)operation
                               syncPointTree:(FImmutableTree *)syncPointTree
                                 serverCache:(id<FNode>)serverCache
                                 writesCache:(FWriteTreeRef *)writesCache {
    FSyncPoint *syncPoint = syncPointTree.value;

    // If we don't have cached server data, see if we can get it from this
    // SyncPoint
    id<FNode> resolvedServerCache;
    if (serverCache == nil & syncPoint != nil) {
        resolvedServerCache =
            [syncPoint completeServerCacheAtPath:[FPath empty]];
    } else {
        resolvedServerCache = serverCache;
    }

    NSMutableArray *events = [[NSMutableArray alloc] init];
    [syncPointTree.children enumerateKeysAndObjectsUsingBlock:^(
                                NSString *childKey, FImmutableTree *childTree,
                                BOOL *stop) {
      id<FNode> childServerCache = nil;
      if (resolvedServerCache != nil) {
          childServerCache = [resolvedServerCache getImmediateChild:childKey];
      }
      FWriteTreeRef *childWritesCache =
          [writesCache childWriteTreeRef:childKey];
      id<FOperation> childOperation = [operation operationForChild:childKey];
      if (childOperation != nil) {
          [events addObjectsFromArray:
                      [self applyOperationDescendantsHelper:childOperation
                                              syncPointTree:childTree
                                                serverCache:childServerCache
                                                writesCache:childWritesCache]];
      }
    }];

    if (syncPoint) {
        [events
            addObjectsFromArray:[syncPoint applyOperation:operation
                                              writesCache:writesCache
                                              serverCache:resolvedServerCache]];
    }

    return events;
}

@end
