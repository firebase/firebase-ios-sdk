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

#import "FirebaseDatabase/Sources/FViewProcessor.h"
#import "FirebaseDatabase/Sources/Core/FWriteTreeRef.h"
#import "FirebaseDatabase/Sources/Core/Operation/FAckUserWrite.h"
#import "FirebaseDatabase/Sources/Core/Operation/FMerge.h"
#import "FirebaseDatabase/Sources/Core/Operation/FOperation.h"
#import "FirebaseDatabase/Sources/Core/Operation/FOperationSource.h"
#import "FirebaseDatabase/Sources/Core/Operation/FOverwrite.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FImmutableTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Core/View/FCacheNode.h"
#import "FirebaseDatabase/Sources/Core/View/FChange.h"
#import "FirebaseDatabase/Sources/Core/View/FViewCache.h"
#import "FirebaseDatabase/Sources/Core/View/Filter/FChildChangeAccumulator.h"
#import "FirebaseDatabase/Sources/Core/View/Filter/FCompleteChildSource.h"
#import "FirebaseDatabase/Sources/Core/View/Filter/FNodeFilter.h"
#import "FirebaseDatabase/Sources/FKeyIndex.h"
#import "FirebaseDatabase/Sources/FViewProcessorResult.h"
#import "FirebaseDatabase/Sources/Public/FIRDataEventType.h"
#import "FirebaseDatabase/Sources/Snapshot/FChildrenNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"

/**
 * An implementation of FCompleteChildSource that never returns any additional
 * children
 */
@interface FNoCompleteChildSource : NSObject <FCompleteChildSource>
@end

@implementation FNoCompleteChildSource
+ (FNoCompleteChildSource *)instance {
    static FNoCompleteChildSource *source = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      source = [[FNoCompleteChildSource alloc] init];
    });
    return source;
}

- (id<FNode>)completeChild:(NSString *)childKey {
    return nil;
}

- (FNamedNode *)childByIndex:(id<FIndex>)index
                  afterChild:(FNamedNode *)child
                   isReverse:(BOOL)reverse {
    return nil;
}
@end

/**
 * An implementation of FCompleteChildSource that uses a FWriteTree in addition
 * to any other server data or old event caches available to calculate complete
 * children.
 */
@interface FWriteTreeCompleteChildSource : NSObject <FCompleteChildSource>
@property(nonatomic, strong) FWriteTreeRef *writes;
@property(nonatomic, strong) FViewCache *viewCache;
@property(nonatomic, strong) id<FNode> optCompleteServerCache;
@end

@implementation FWriteTreeCompleteChildSource
- (id)initWithWrites:(FWriteTreeRef *)writes
           viewCache:(FViewCache *)viewCache
         serverCache:(id<FNode>)optCompleteServerCache {
    self = [super init];
    if (self) {
        self.writes = writes;
        self.viewCache = viewCache;
        self.optCompleteServerCache = optCompleteServerCache;
    }
    return self;
}

- (id<FNode>)completeChild:(NSString *)childKey {
    FCacheNode *node = self.viewCache.cachedEventSnap;
    if ([node isCompleteForChild:childKey]) {
        return [node.node getImmediateChild:childKey];
    } else {
        FCacheNode *serverNode;
        if (self.optCompleteServerCache) {
            // Since we're only ever getting child nodes, we can use the key
            // index here
            FIndexedNode *indexed =
                [FIndexedNode indexedNodeWithNode:self.optCompleteServerCache
                                            index:[FKeyIndex keyIndex]];
            serverNode = [[FCacheNode alloc] initWithIndexedNode:indexed
                                              isFullyInitialized:YES
                                                      isFiltered:NO];
        } else {
            serverNode = self.viewCache.cachedServerSnap;
        }
        return [self.writes calculateCompleteChild:childKey cache:serverNode];
    }
}

- (FNamedNode *)childByIndex:(id<FIndex>)index
                  afterChild:(FNamedNode *)child
                   isReverse:(BOOL)reverse {
    id<FNode> completeServerData = self.optCompleteServerCache != nil
                                       ? self.optCompleteServerCache
                                       : self.viewCache.completeServerSnap;
    return [self.writes calculateNextNodeAfterPost:child
                                completeServerData:completeServerData
                                           reverse:reverse
                                             index:index];
}

@end

@interface FViewProcessor ()
@property(nonatomic, strong) id<FNodeFilter> filter;
@end

@implementation FViewProcessor

- (id)initWithFilter:(id<FNodeFilter>)nodeFilter {
    self = [super init];
    if (self) {
        self.filter = nodeFilter;
    }
    return self;
}

- (FViewProcessorResult *)applyOperationOn:(FViewCache *)oldViewCache
                                 operation:(id<FOperation>)operation
                               writesCache:(FWriteTreeRef *)writesCache
                             completeCache:(id<FNode>)optCompleteCache {
    FChildChangeAccumulator *accumulator =
        [[FChildChangeAccumulator alloc] init];
    FViewCache *newViewCache;

    if (operation.type == FOperationTypeOverwrite) {
        FOverwrite *overwrite = (FOverwrite *)operation;
        if (operation.source.fromUser) {
            newViewCache = [self applyUserOverwriteTo:oldViewCache
                                           changePath:overwrite.path
                                          changedSnap:overwrite.snap
                                          writesCache:writesCache
                                        completeCache:optCompleteCache
                                          accumulator:accumulator];
        } else {
            NSAssert(operation.source.fromServer,
                     @"Unknown source for overwrite.");
            // We filter the node if it's a tagged update or the node has been
            // previously filtered  and the update is not at the root in which
            // case it is ok (and necessary) to mark the node unfiltered again
            BOOL filterServerNode = overwrite.source.isTagged ||
                                    (oldViewCache.cachedServerSnap.isFiltered &&
                                     !overwrite.path.isEmpty);
            newViewCache = [self applyServerOverwriteTo:oldViewCache
                                             changePath:overwrite.path
                                                   snap:overwrite.snap
                                            writesCache:writesCache
                                          completeCache:optCompleteCache
                                       filterServerNode:filterServerNode
                                            accumulator:accumulator];
        }
    } else if (operation.type == FOperationTypeMerge) {
        FMerge *merge = (FMerge *)operation;
        if (operation.source.fromUser) {
            newViewCache = [self applyUserMergeTo:oldViewCache
                                             path:merge.path
                                  changedChildren:merge.children
                                      writesCache:writesCache
                                    completeCache:optCompleteCache
                                      accumulator:accumulator];
        } else {
            NSAssert(operation.source.fromServer, @"Unknown source for merge.");
            // We filter the node if it's a tagged update or the node has been
            // previously filtered
            BOOL filterServerNode = merge.source.isTagged ||
                                    oldViewCache.cachedServerSnap.isFiltered;
            newViewCache = [self applyServerMergeTo:oldViewCache
                                               path:merge.path
                                    changedChildren:merge.children
                                        writesCache:writesCache
                                      completeCache:optCompleteCache
                                   filterServerNode:filterServerNode
                                        accumulator:accumulator];
        }
    } else if (operation.type == FOperationTypeAckUserWrite) {
        FAckUserWrite *ackWrite = (FAckUserWrite *)operation;
        if (!ackWrite.revert) {
            newViewCache = [self ackUserWriteOn:oldViewCache
                                        ackPath:ackWrite.path
                                   affectedTree:ackWrite.affectedTree
                                    writesCache:writesCache
                                  completeCache:optCompleteCache
                                    accumulator:accumulator];
        } else {
            newViewCache = [self revertUserWriteOn:oldViewCache
                                              path:ackWrite.path
                                       writesCache:writesCache
                                     completeCache:optCompleteCache
                                       accumulator:accumulator];
        }
    } else if (operation.type == FOperationTypeListenComplete) {
        newViewCache = [self listenCompleteOldCache:oldViewCache
                                               path:operation.path
                                        writesCache:writesCache
                                        serverCache:optCompleteCache
                                        accumulator:accumulator];
    } else {
        [NSException
             raise:NSInternalInconsistencyException
            format:@"Unknown operation encountered %ld.", (long)operation.type];
        return nil;
    }

    NSArray *changes = [self maybeAddValueFromOldViewCache:oldViewCache
                                              newViewCache:newViewCache
                                                   changes:accumulator.changes];
    FViewProcessorResult *results =
        [[FViewProcessorResult alloc] initWithViewCache:newViewCache
                                                changes:changes];
    return results;
}

- (NSArray *)maybeAddValueFromOldViewCache:(FViewCache *)oldViewCache
                              newViewCache:(FViewCache *)newViewCache
                                   changes:(NSArray *)changes {
    NSArray *newChanges = changes;
    FCacheNode *eventSnap = newViewCache.cachedEventSnap;
    if (eventSnap.isFullyInitialized) {
        BOOL isLeafOrEmpty =
            eventSnap.node.isLeafNode || eventSnap.node.isEmpty;
        if ([changes count] > 0 ||
            !oldViewCache.cachedEventSnap.isFullyInitialized ||
            (isLeafOrEmpty &&
             ![eventSnap.node isEqual:oldViewCache.completeEventSnap]) ||
            ![eventSnap.node.getPriority
                isEqual:oldViewCache.completeEventSnap.getPriority]) {
            FChange *valueChange =
                [[FChange alloc] initWithType:FIRDataEventTypeValue
                                  indexedNode:eventSnap.indexedNode];
            NSMutableArray *mutableChanges = [changes mutableCopy];
            [mutableChanges addObject:valueChange];
            newChanges = mutableChanges;
        }
    }
    return newChanges;
}

- (FViewCache *)
    generateEventCacheAfterServerEvent:(FViewCache *)viewCache
                                  path:(FPath *)changePath
                           writesCache:(FWriteTreeRef *)writesCache
                                source:(id<FCompleteChildSource>)source
                           accumulator:(FChildChangeAccumulator *)accumulator {
    FCacheNode *oldEventSnap = viewCache.cachedEventSnap;
    if ([writesCache shadowingWriteAtPath:changePath] != nil) {
        // we have a shadowing write, ignore changes.
        return viewCache;
    } else {
        FIndexedNode *newEventCache;
        if (changePath.isEmpty) {
            // TODO: figure out how this plays with "sliding ack windows"
            NSAssert(
                viewCache.cachedServerSnap.isFullyInitialized,
                @"If change path is empty, we must have complete server data");
            id<FNode> nodeWithLocalWrites;
            if (viewCache.cachedServerSnap.isFiltered) {
                // We need to special case this, because we need to only apply
                // writes to complete children, or we might end up raising
                // events for incomplete children. If the server data is
                // filtered deep writes cannot be guaranteed to be complete
                id<FNode> serverCache = viewCache.completeServerSnap;
                FChildrenNode *completeChildren =
                    ([serverCache isKindOfClass:[FChildrenNode class]])
                        ? serverCache
                        : [FEmptyNode emptyNode];
                nodeWithLocalWrites = [writesCache
                    calculateCompleteEventChildrenWithCompleteServerChildren:
                        completeChildren];
            } else {
                nodeWithLocalWrites = [writesCache
                    calculateCompleteEventCacheWithCompleteServerCache:
                        viewCache.completeServerSnap];
            }
            FIndexedNode *indexedNode =
                [FIndexedNode indexedNodeWithNode:nodeWithLocalWrites
                                            index:self.filter.index];
            newEventCache = [self.filter
                updateFullNode:viewCache.cachedEventSnap.indexedNode
                   withNewNode:indexedNode
                   accumulator:accumulator];
        } else {
            NSString *childKey = [changePath getFront];
            if ([childKey isEqualToString:@".priority"]) {
                NSAssert(
                    changePath.length == 1,
                    @"Can't have a priority with additional path components");
                id<FNode> oldEventNode = oldEventSnap.node;
                id<FNode> serverNode = viewCache.cachedServerSnap.node;
                // we might have overwrites for this priority
                id<FNode> updatedPriority = [writesCache
                    calculateEventCacheAfterServerOverwriteWithChildPath:
                        changePath
                                                       existingEventSnap:
                                                           oldEventNode
                                                      existingServerSnap:
                                                          serverNode];
                if (updatedPriority != nil) {
                    newEventCache =
                        [self.filter updatePriority:updatedPriority
                                            forNode:oldEventSnap.indexedNode];
                } else {
                    // priority didn't change, keep old node
                    newEventCache = oldEventSnap.indexedNode;
                }
            } else {
                FPath *childChangePath = [changePath popFront];
                id<FNode> newEventChild;
                if ([oldEventSnap isCompleteForChild:childKey]) {
                    id<FNode> serverNode = viewCache.cachedServerSnap.node;
                    id<FNode> eventChildUpdate = [writesCache
                        calculateEventCacheAfterServerOverwriteWithChildPath:
                            changePath
                                                           existingEventSnap:
                                                               oldEventSnap.node
                                                          existingServerSnap:
                                                              serverNode];
                    if (eventChildUpdate != nil) {
                        newEventChild =
                            [[oldEventSnap.node getImmediateChild:childKey]
                                 updateChild:childChangePath
                                withNewChild:eventChildUpdate];
                    } else {
                        // Nothing changed, just keep the old child
                        newEventChild =
                            [oldEventSnap.node getImmediateChild:childKey];
                    }
                } else {
                    newEventChild = [writesCache
                        calculateCompleteChild:childKey
                                         cache:viewCache.cachedServerSnap];
                }
                if (newEventChild != nil) {
                    newEventCache =
                        [self.filter updateChildIn:oldEventSnap.indexedNode
                                       forChildKey:childKey
                                          newChild:newEventChild
                                      affectedPath:childChangePath
                                        fromSource:source
                                       accumulator:accumulator];
                } else {
                    // No complete children available or no change
                    newEventCache = oldEventSnap.indexedNode;
                }
            }
        }
        return [viewCache updateEventSnap:newEventCache
                               isComplete:(oldEventSnap.isFullyInitialized ||
                                           changePath.isEmpty)
                               isFiltered:self.filter.filtersNodes];
    }
}

- (FViewCache *)applyServerOverwriteTo:(FViewCache *)oldViewCache
                            changePath:(FPath *)changePath
                                  snap:(id<FNode>)changedSnap
                           writesCache:(FWriteTreeRef *)writesCache
                         completeCache:(id<FNode>)optCompleteCache
                      filterServerNode:(BOOL)filterServerNode
                           accumulator:(FChildChangeAccumulator *)accumulator {
    FCacheNode *oldServerSnap = oldViewCache.cachedServerSnap;
    FIndexedNode *newServerCache;
    id<FNodeFilter> serverFilter =
        filterServerNode ? self.filter : self.filter.indexedFilter;

    if (changePath.isEmpty) {
        FIndexedNode *indexed =
            [FIndexedNode indexedNodeWithNode:changedSnap
                                        index:serverFilter.index];
        newServerCache = [serverFilter updateFullNode:oldServerSnap.indexedNode
                                          withNewNode:indexed
                                          accumulator:nil];
    } else if (serverFilter.filtersNodes && !oldServerSnap.isFiltered) {
        // We want to filter the server node, but we didn't filter the server
        // node yet, so simulate a full update
        NSAssert(![changePath isEmpty],
                 @"An empty path should been caught in the other branch");
        NSString *childKey = [changePath getFront];
        FPath *updatePath = [changePath popFront];
        id<FNode> newChild = [[oldServerSnap.node getImmediateChild:childKey]
             updateChild:updatePath
            withNewChild:changedSnap];
        FIndexedNode *indexed =
            [oldServerSnap.indexedNode updateChild:childKey
                                      withNewChild:newChild];
        newServerCache = [serverFilter updateFullNode:oldServerSnap.indexedNode
                                          withNewNode:indexed
                                          accumulator:nil];
    } else {
        NSString *childKey = [changePath getFront];
        if (![oldServerSnap isCompleteForPath:changePath] &&
            changePath.length > 1) {
            // We don't update incomplete nodes with updates intended for other
            // listeners.
            return oldViewCache;
        }
        FPath *childChangePath = [changePath popFront];
        id<FNode> childNode = [oldServerSnap.node getImmediateChild:childKey];
        id<FNode> newChildNode = [childNode updateChild:childChangePath
                                           withNewChild:changedSnap];
        if ([childKey isEqualToString:@".priority"]) {
            newServerCache =
                [serverFilter updatePriority:newChildNode
                                     forNode:oldServerSnap.indexedNode];
        } else {
            newServerCache =
                [serverFilter updateChildIn:oldServerSnap.indexedNode
                                forChildKey:childKey
                                   newChild:newChildNode
                               affectedPath:childChangePath
                                 fromSource:[FNoCompleteChildSource instance]
                                accumulator:nil];
        }
    }
    FViewCache *newViewCache =
        [oldViewCache updateServerSnap:newServerCache
                            isComplete:(oldServerSnap.isFullyInitialized ||
                                        changePath.isEmpty)
                            isFiltered:serverFilter.filtersNodes];
    id<FCompleteChildSource> source =
        [[FWriteTreeCompleteChildSource alloc] initWithWrites:writesCache
                                                    viewCache:newViewCache
                                                  serverCache:optCompleteCache];
    return [self generateEventCacheAfterServerEvent:newViewCache
                                               path:changePath
                                        writesCache:writesCache
                                             source:source
                                        accumulator:accumulator];
}

- (FViewCache *)applyUserOverwriteTo:(FViewCache *)oldViewCache
                          changePath:(FPath *)changePath
                         changedSnap:(id<FNode>)changedSnap
                         writesCache:(FWriteTreeRef *)writesCache
                       completeCache:(id<FNode>)optCompleteCache
                         accumulator:(FChildChangeAccumulator *)accumulator {
    FCacheNode *oldEventSnap = oldViewCache.cachedEventSnap;
    FViewCache *newViewCache;
    id<FCompleteChildSource> source =
        [[FWriteTreeCompleteChildSource alloc] initWithWrites:writesCache
                                                    viewCache:oldViewCache
                                                  serverCache:optCompleteCache];
    if (changePath.isEmpty) {
        FIndexedNode *newIndexed =
            [FIndexedNode indexedNodeWithNode:changedSnap
                                        index:self.filter.index];
        FIndexedNode *newEventCache =
            [self.filter updateFullNode:oldEventSnap.indexedNode
                            withNewNode:newIndexed
                            accumulator:accumulator];
        newViewCache = [oldViewCache updateEventSnap:newEventCache
                                          isComplete:YES
                                          isFiltered:self.filter.filtersNodes];
    } else {
        NSString *childKey = [changePath getFront];
        if ([childKey isEqualToString:@".priority"]) {
            FIndexedNode *newEventCache = [self.filter
                updatePriority:changedSnap
                       forNode:oldViewCache.cachedEventSnap.indexedNode];
            newViewCache =
                [oldViewCache updateEventSnap:newEventCache
                                   isComplete:oldEventSnap.isFullyInitialized
                                   isFiltered:oldEventSnap.isFiltered];
        } else {
            FPath *childChangePath = [changePath popFront];
            id<FNode> oldChild = [oldEventSnap.node getImmediateChild:childKey];
            id<FNode> newChild;
            if (childChangePath.isEmpty) {
                // Child overwrite, we can replace the child
                newChild = changedSnap;
            } else {
                id<FNode> childNode = [source completeChild:childKey];
                if (childNode != nil) {
                    if ([[childChangePath getBack]
                            isEqualToString:@".priority"] &&
                        [childNode getChild:[childChangePath parent]].isEmpty) {
                        // This is a priority update on an empty node. If this
                        // node exists on the server, the server will send down
                        // the priority in the update, so ignore for now
                        newChild = childNode;
                    } else {
                        newChild = [childNode updateChild:childChangePath
                                             withNewChild:changedSnap];
                    }
                } else {
                    newChild = [FEmptyNode emptyNode];
                }
            }
            if (![oldChild isEqual:newChild]) {
                FIndexedNode *newEventSnap =
                    [self.filter updateChildIn:oldEventSnap.indexedNode
                                   forChildKey:childKey
                                      newChild:newChild
                                  affectedPath:childChangePath
                                    fromSource:source
                                   accumulator:accumulator];
                newViewCache = [oldViewCache
                    updateEventSnap:newEventSnap
                         isComplete:oldEventSnap.isFullyInitialized
                         isFiltered:self.filter.filtersNodes];
            } else {
                newViewCache = oldViewCache;
            }
        }
    }
    return newViewCache;
}

+ (BOOL)cache:(FViewCache *)viewCache hasChild:(NSString *)childKey {
    return [viewCache.cachedEventSnap isCompleteForChild:childKey];
}

/**
 * @param changedChildren NSDictionary of child name (NSString*) to child value
 * (id<FNode>)
 */
- (FViewCache *)applyUserMergeTo:(FViewCache *)viewCache
                            path:(FPath *)path
                 changedChildren:(FCompoundWrite *)changedChildren
                     writesCache:(FWriteTreeRef *)writesCache
                   completeCache:(id<FNode>)serverCache
                     accumulator:(FChildChangeAccumulator *)accumulator {
    // HACK: In the case of a limit query, there may be some changes that bump
    // things out of the window leaving room for new items.  It's important we
    // process these changes first, so we iterate the changes twice, first
    // processing any that affect items currently in view.
    // TODO: I consider an item "in view" if cacheHasChild is true, which checks
    // both the server and event snap.  I'm not sure if this will result in edge
    // cases when a child is in one but not the other.
    __block FViewCache *curViewCache = viewCache;

    [changedChildren enumerateWrites:^(FPath *relativePath, id<FNode> childNode,
                                       BOOL *stop) {
      FPath *writePath = [path child:relativePath];
      if ([FViewProcessor cache:viewCache hasChild:[writePath getFront]]) {
          curViewCache = [self applyUserOverwriteTo:curViewCache
                                         changePath:writePath
                                        changedSnap:childNode
                                        writesCache:writesCache
                                      completeCache:serverCache
                                        accumulator:accumulator];
      }
    }];

    [changedChildren enumerateWrites:^(FPath *relativePath, id<FNode> childNode,
                                       BOOL *stop) {
      FPath *writePath = [path child:relativePath];
      if (![FViewProcessor cache:viewCache hasChild:[writePath getFront]]) {
          curViewCache = [self applyUserOverwriteTo:curViewCache
                                         changePath:writePath
                                        changedSnap:childNode
                                        writesCache:writesCache
                                      completeCache:serverCache
                                        accumulator:accumulator];
      }
    }];

    return curViewCache;
}

- (FViewCache *)applyServerMergeTo:(FViewCache *)viewCache
                              path:(FPath *)path
                   changedChildren:(FCompoundWrite *)changedChildren
                       writesCache:(FWriteTreeRef *)writesCache
                     completeCache:(id<FNode>)serverCache
                  filterServerNode:(BOOL)filterServerNode
                       accumulator:(FChildChangeAccumulator *)accumulator {
    // If we don't have a cache yet, this merge was intended for a previously
    // listen in the same location. Ignore it and wait for the complete data
    // update coming soon.
    if (viewCache.cachedServerSnap.node.isEmpty &&
        !viewCache.cachedServerSnap.isFullyInitialized) {
        return viewCache;
    }

    // HACK: In the case of a limit query, there may be some changes that bump
    // things out of the window leaving room for new items.  It's important we
    // process these changes first, so we iterate the changes twice, first
    // processing any that affect items currently in view.
    // TODO: I consider an item "in view" if cacheHasChild is true, which checks
    // both the server and event snap.  I'm not sure if this will result in edge
    // cases when a child is in one but not the other.
    __block FViewCache *curViewCache = viewCache;
    FCompoundWrite *actualMerge;
    if (path.isEmpty) {
        actualMerge = changedChildren;
    } else {
        actualMerge =
            [[FCompoundWrite emptyWrite] addCompoundWrite:changedChildren
                                                   atPath:path];
    }
    id<FNode> serverNode = viewCache.cachedServerSnap.node;

    NSDictionary *childCompoundWrites = actualMerge.childCompoundWrites;
    [childCompoundWrites
        enumerateKeysAndObjectsUsingBlock:^(
            NSString *childKey, FCompoundWrite *childMerge, BOOL *stop) {
          if ([serverNode hasChild:childKey]) {
              id<FNode> serverChild =
                  [viewCache.cachedServerSnap.node getImmediateChild:childKey];
              id<FNode> newChild = [childMerge applyToNode:serverChild];
              curViewCache =
                  [self applyServerOverwriteTo:curViewCache
                                    changePath:[[FPath alloc] initWith:childKey]
                                          snap:newChild
                                   writesCache:writesCache
                                 completeCache:serverCache
                              filterServerNode:filterServerNode
                                   accumulator:accumulator];
          }
        }];

    [childCompoundWrites
        enumerateKeysAndObjectsUsingBlock:^(
            NSString *childKey, FCompoundWrite *childMerge, BOOL *stop) {
          bool isUnknownDeepMerge =
              ![viewCache.cachedServerSnap isCompleteForChild:childKey] &&
              childMerge.rootWrite == nil;
          if (![serverNode hasChild:childKey] && !isUnknownDeepMerge) {
              id<FNode> serverChild =
                  [viewCache.cachedServerSnap.node getImmediateChild:childKey];
              id<FNode> newChild = [childMerge applyToNode:serverChild];
              curViewCache =
                  [self applyServerOverwriteTo:curViewCache
                                    changePath:[[FPath alloc] initWith:childKey]
                                          snap:newChild
                                   writesCache:writesCache
                                 completeCache:serverCache
                              filterServerNode:filterServerNode
                                   accumulator:accumulator];
          }
        }];

    return curViewCache;
}

- (FViewCache *)ackUserWriteOn:(FViewCache *)viewCache
                       ackPath:(FPath *)ackPath
                  affectedTree:(FImmutableTree *)affectedTree
                   writesCache:(FWriteTreeRef *)writesCache
                 completeCache:(id<FNode>)optCompleteCache
                   accumulator:(FChildChangeAccumulator *)accumulator {

    if ([writesCache shadowingWriteAtPath:ackPath] != nil) {
        return viewCache;
    }

    // Only filter server node if it is currently filtered
    BOOL filterServerNode = viewCache.cachedServerSnap.isFiltered;

    // Essentially we'll just get our existing server cache for the affected
    // paths and re-apply it as a server update now that it won't be shadowed.
    FCacheNode *serverCache = viewCache.cachedServerSnap;
    if (affectedTree.value != nil) {
        // This is an overwrite.
        if ((ackPath.isEmpty && serverCache.isFullyInitialized) ||
            [serverCache isCompleteForPath:ackPath]) {
            return
                [self applyServerOverwriteTo:viewCache
                                  changePath:ackPath
                                        snap:[serverCache.node getChild:ackPath]
                                 writesCache:writesCache
                               completeCache:optCompleteCache
                            filterServerNode:filterServerNode
                                 accumulator:accumulator];
        } else if (ackPath.isEmpty) {
            // This is a goofy edge case where we are acking data at this
            // location but don't have full data.  We should just re-apply
            // whatever we have in our cache as a merge.
            FCompoundWrite *changedChildren = [FCompoundWrite emptyWrite];
            for (FNamedNode *child in serverCache.node.childEnumerator) {
                changedChildren = [changedChildren addWrite:child.node
                                                      atKey:child.name];
            }
            return [self applyServerMergeTo:viewCache
                                       path:ackPath
                            changedChildren:changedChildren
                                writesCache:writesCache
                              completeCache:optCompleteCache
                           filterServerNode:filterServerNode
                                accumulator:accumulator];
        } else {
            return viewCache;
        }
    } else {
        // This is a merge.
        __block FCompoundWrite *changedChildren = [FCompoundWrite emptyWrite];
        [affectedTree forEach:^(FPath *mergePath, id value) {
          FPath *serverCachePath = [ackPath child:mergePath];
          if ([serverCache isCompleteForPath:serverCachePath]) {
              changedChildren = [changedChildren
                  addWrite:[serverCache.node getChild:serverCachePath]
                    atPath:mergePath];
          }
        }];
        return [self applyServerMergeTo:viewCache
                                   path:ackPath
                        changedChildren:changedChildren
                            writesCache:writesCache
                          completeCache:optCompleteCache
                       filterServerNode:filterServerNode
                            accumulator:accumulator];
    }
}

- (FViewCache *)revertUserWriteOn:(FViewCache *)viewCache
                             path:(FPath *)path
                      writesCache:(FWriteTreeRef *)writesCache
                    completeCache:(id<FNode>)optCompleteCache
                      accumulator:(FChildChangeAccumulator *)accumulator {
    if ([writesCache shadowingWriteAtPath:path] != nil) {
        return viewCache;
    } else {
        id<FCompleteChildSource> source = [[FWriteTreeCompleteChildSource alloc]
            initWithWrites:writesCache
                 viewCache:viewCache
               serverCache:optCompleteCache];
        FIndexedNode *oldEventCache = viewCache.cachedEventSnap.indexedNode;
        FIndexedNode *newEventCache;
        if (path.isEmpty || [[path getFront] isEqualToString:@".priority"]) {
            id<FNode> newNode;
            if (viewCache.cachedServerSnap.isFullyInitialized) {
                newNode = [writesCache
                    calculateCompleteEventCacheWithCompleteServerCache:
                        viewCache.completeServerSnap];
            } else {
                newNode = [writesCache
                    calculateCompleteEventChildrenWithCompleteServerChildren:
                        viewCache.cachedServerSnap.node];
            }
            FIndexedNode *indexedNode =
                [FIndexedNode indexedNodeWithNode:newNode
                                            index:self.filter.index];
            newEventCache = [self.filter updateFullNode:oldEventCache
                                            withNewNode:indexedNode
                                            accumulator:accumulator];
        } else {
            NSString *childKey = [path getFront];
            id<FNode> newChild =
                [writesCache calculateCompleteChild:childKey
                                              cache:viewCache.cachedServerSnap];
            if (newChild == nil &&
                [viewCache.cachedServerSnap isCompleteForChild:childKey]) {
                newChild = [oldEventCache.node getImmediateChild:childKey];
            }
            if (newChild != nil) {
                newEventCache = [self.filter updateChildIn:oldEventCache
                                               forChildKey:childKey
                                                  newChild:newChild
                                              affectedPath:[path popFront]
                                                fromSource:source
                                               accumulator:accumulator];
            } else if (newChild == nil &&
                       [viewCache.cachedEventSnap.node hasChild:childKey]) {
                // No complete child available, delete the existing one, if any
                newEventCache =
                    [self.filter updateChildIn:oldEventCache
                                   forChildKey:childKey
                                      newChild:[FEmptyNode emptyNode]
                                  affectedPath:[path popFront]
                                    fromSource:source
                                   accumulator:accumulator];
            } else {
                newEventCache = oldEventCache;
            }
            if (newEventCache.node.isEmpty &&
                viewCache.cachedServerSnap.isFullyInitialized) {
                // We might have reverted all child writes. Maybe the old event
                // was a leaf node.
                id<FNode> complete = [writesCache
                    calculateCompleteEventCacheWithCompleteServerCache:
                        viewCache.completeServerSnap];
                if (complete.isLeafNode) {
                    FIndexedNode *indexed =
                        [FIndexedNode indexedNodeWithNode:complete];
                    newEventCache = [self.filter updateFullNode:newEventCache
                                                    withNewNode:indexed
                                                    accumulator:accumulator];
                }
            }
        }
        BOOL complete = viewCache.cachedServerSnap.isFullyInitialized ||
                        [writesCache shadowingWriteAtPath:[FPath empty]] != nil;
        return [viewCache updateEventSnap:newEventCache
                               isComplete:complete
                               isFiltered:self.filter.filtersNodes];
    }
}

- (FViewCache *)listenCompleteOldCache:(FViewCache *)viewCache
                                  path:(FPath *)path
                           writesCache:(FWriteTreeRef *)writesCache
                           serverCache:(id<FNode>)servercache
                           accumulator:(FChildChangeAccumulator *)accumulator {
    FCacheNode *oldServerNode = viewCache.cachedServerSnap;
    FViewCache *newViewCache = [viewCache
        updateServerSnap:oldServerNode.indexedNode
              isComplete:(oldServerNode.isFullyInitialized || path.isEmpty)
              isFiltered:oldServerNode.isFiltered];
    return [self
        generateEventCacheAfterServerEvent:newViewCache
                                      path:path
                               writesCache:writesCache
                                    source:[FNoCompleteChildSource instance]
                               accumulator:accumulator];
}

@end
