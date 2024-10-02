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

#import "FirebaseDatabase/Sources/Core/FWriteTree.h"
#import "FirebaseDatabase/Sources/Core/FWriteRecord.h"
#import "FirebaseDatabase/Sources/Core/FWriteTreeRef.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FImmutableTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Core/View/FCacheNode.h"
#import "FirebaseDatabase/Sources/FIndex.h"
#import "FirebaseDatabase/Sources/FNamedNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FChildrenNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"

@interface FWriteTree ()
/**
 * A tree tracking the results of applying all visible writes. This does not
 * include transactions with applyLocally=false or writes that are completely
 * shadowed by other writes. Contains id<FNode> as values.
 */
@property(nonatomic, strong) FCompoundWrite *visibleWrites;
/**
 * A list of pending writes, regardless of visibility and shadowed-ness. Used to
 * calculate arbitrary sets of the changed data, such as hidden writes (from
 * transactions) or changes with certain writes excluded (also used by
 * transactions). Contains FWriteRecords.
 */
@property(nonatomic, strong) NSMutableArray *allWrites;
@property(nonatomic) NSInteger lastWriteId;
@end

/**
 * FWriteTree tracks all pending user-initiated writes and has methods to
 * calculate the result of merging them with underlying server data (to create
 * "event cache" data). Pending writes are added with addOverwriteAtPath: and
 * addMergeAtPath: and removed with removeWriteId:.
 */
@implementation FWriteTree

@synthesize allWrites;
@synthesize lastWriteId;

- (id)init {
    self = [super init];
    if (self) {
        self.visibleWrites = [FCompoundWrite emptyWrite];
        self.allWrites = [[NSMutableArray alloc] init];
        self.lastWriteId = -1;
    }
    return self;
}

/**
 * Create a new WriteTreeRef for the given path. For use with a new sync point
 * at the given path.
 */
- (FWriteTreeRef *)childWritesForPath:(FPath *)path {
    return [[FWriteTreeRef alloc] initWithPath:path writeTree:self];
}

/**
 * Record a new overwrite from user code.
 * @param visible Is set to false by some transactions. It should be excluded
 * from event caches.
 */
- (void)addOverwriteAtPath:(FPath *)path
                   newData:(id<FNode>)newData
                   writeId:(NSInteger)writeId
                 isVisible:(BOOL)visible {
    NSAssert(writeId > self.lastWriteId,
             @"Stacking an older write on top of a newer one");
    FWriteRecord *record = [[FWriteRecord alloc] initWithPath:path
                                                    overwrite:newData
                                                      writeId:writeId
                                                      visible:visible];
    [self.allWrites addObject:record];

    if (visible) {
        self.visibleWrites = [self.visibleWrites addWrite:newData atPath:path];
    }

    self.lastWriteId = writeId;
}

/**
 * Record a new merge from user code.
 * @param changedChildren maps NSString -> id<FNode>
 */
- (void)addMergeAtPath:(FPath *)path
       changedChildren:(FCompoundWrite *)changedChildren
               writeId:(NSInteger)writeId {
    NSAssert(writeId > self.lastWriteId,
             @"Stacking an older merge on top of newer one");
    FWriteRecord *record = [[FWriteRecord alloc] initWithPath:path
                                                        merge:changedChildren
                                                      writeId:writeId];
    [self.allWrites addObject:record];

    self.visibleWrites = [self.visibleWrites addCompoundWrite:changedChildren
                                                       atPath:path];
    self.lastWriteId = writeId;
}

- (FWriteRecord *)writeForId:(NSInteger)writeId {
    NSUInteger index = [self.allWrites
        indexOfObjectPassingTest:^BOOL(FWriteRecord *write, NSUInteger idx,
                                       BOOL *stop) {
          return write.writeId == writeId;
        }];
    return (index == NSNotFound) ? nil : self.allWrites[index];
}

/**
 * Remove a write (either an overwrite or merge) that has been successfully
 * acknowledged by the server. Recalculates the tree if necessary. We return the
 * path of the write and whether it may have been visible, meaning views need to
 * reevaluate.
 *
 * @return YES if the write may have been visible (meaning we'll need to
 * reevaluate / raise events as a result).
 */
- (BOOL)removeWriteId:(NSInteger)writeId {
    NSUInteger index = [self.allWrites
        indexOfObjectPassingTest:^BOOL(FWriteRecord *record, NSUInteger idx,
                                       BOOL *stop) {
          if (record.writeId == writeId) {
              return YES;
          } else {
              return NO;
          }
        }];
    NSAssert(index != NSNotFound,
             @"[FWriteTree removeWriteId:] called with nonexistent writeId.");
    FWriteRecord *writeToRemove = self.allWrites[index];
    [self.allWrites removeObjectAtIndex:index];

    BOOL removedWriteWasVisible = writeToRemove.visible;
    BOOL removedWriteOverlapsWithOtherWrites = NO;
    NSInteger i = [self.allWrites count] - 1;

    while (removedWriteWasVisible && i >= 0) {
        FWriteRecord *currentWrite = [self.allWrites objectAtIndex:i];
        if (currentWrite.visible) {
            if (i >= index && [self record:currentWrite
                                  containsPath:writeToRemove.path]) {
                // The removed write was completely shadowed by a subsequent
                // write.
                removedWriteWasVisible = NO;
            } else if ([writeToRemove.path contains:currentWrite.path]) {
                // Either we're covering some writes or they're covering part of
                // us (depending on which came first).
                removedWriteOverlapsWithOtherWrites = YES;
            }
        }
        i--;
    }

    if (!removedWriteWasVisible) {
        return NO;
    } else if (removedWriteOverlapsWithOtherWrites) {
        // There's some shadowing going on. Just rebuild the visible writes from
        // scratch.
        [self resetTree];
        return YES;
    } else {
        // There's no shadowing.  We can safely just remove the write(s) from
        // visibleWrites.
        if ([writeToRemove isOverwrite]) {
            self.visibleWrites =
                [self.visibleWrites removeWriteAtPath:writeToRemove.path];
        } else {
            FCompoundWrite *merge = writeToRemove.merge;
            [merge enumerateWrites:^(FPath *path, id<FNode> node, BOOL *stop) {
              self.visibleWrites = [self.visibleWrites
                  removeWriteAtPath:[writeToRemove.path child:path]];
            }];
        }
        return YES;
    }
}

- (NSArray *)removeAllWrites {
    NSArray *writes = self.allWrites;
    self.visibleWrites = [FCompoundWrite emptyWrite];
    self.allWrites = [NSMutableArray array];
    return writes;
}

/**
 * @return A complete snapshot for the given path if there's visible write data
 * at that path, else nil. No server data is considered.
 */
- (id<FNode>)completeWriteDataAtPath:(FPath *)path {
    return [self.visibleWrites completeNodeAtPath:path];
}

/**
 * Given optional, underlying server data, and an optional set of constraints
 * (exclude some sets, include hidden writes), attempt to calculate a complete
 * snapshot for the given path
 * @param includeHiddenWrites Defaults to false, whether or not to layer on
 * writes with visible set to false
 */
- (id<FNode>)calculateCompleteEventCacheAtPath:(FPath *)treePath
                           completeServerCache:(id<FNode>)completeServerCache
                               excludeWriteIds:(NSArray *)writeIdsToExclude
                           includeHiddenWrites:(BOOL)includeHiddenWrites {
    if (writeIdsToExclude == nil && !includeHiddenWrites) {
        id<FNode> shadowingNode =
            [self.visibleWrites completeNodeAtPath:treePath];
        if (shadowingNode != nil) {
            return shadowingNode;
        } else {
            // No cache here. Can't claim complete knowledge.
            FCompoundWrite *subMerge =
                [self.visibleWrites childCompoundWriteAtPath:treePath];
            if (subMerge.isEmpty) {
                return completeServerCache;
            } else if (completeServerCache == nil &&
                       ![subMerge hasCompleteWriteAtPath:[FPath empty]]) {
                // We wouldn't have a complete snapshot since there's no
                // underlying data and no complete shadow
                return nil;
            } else {
                id<FNode> layeredCache = completeServerCache != nil
                                             ? completeServerCache
                                             : [FEmptyNode emptyNode];
                return [subMerge applyToNode:layeredCache];
            }
        }
    } else {
        FCompoundWrite *merge =
            [self.visibleWrites childCompoundWriteAtPath:treePath];
        if (!includeHiddenWrites && merge.isEmpty) {
            return completeServerCache;
        } else {
            // If the server cache is null and we don't have a complete cache,
            // we need to return nil
            if (!includeHiddenWrites && completeServerCache == nil &&
                ![merge hasCompleteWriteAtPath:[FPath empty]]) {
                return nil;
            } else {
                BOOL (^filter)(FWriteRecord *) = ^(FWriteRecord *record) {
                  return (BOOL)((record.visible || includeHiddenWrites) &&
                                (writeIdsToExclude == nil ||
                                 ![writeIdsToExclude
                                     containsObject:[NSNumber
                                                        numberWithInteger:
                                                            record.writeId]]) &&
                                ([record.path contains:treePath] ||
                                 [treePath contains:record.path]));
                };
                FCompoundWrite *mergeAtPath =
                    [FWriteTree layerTreeFromWrites:self.allWrites
                                             filter:filter
                                           treeRoot:treePath];
                id<FNode> layeredCache = completeServerCache
                                             ? completeServerCache
                                             : [FEmptyNode emptyNode];
                return [mergeAtPath applyToNode:layeredCache];
            }
        }
    }
}

/**
 * With optional, underlying server data, attempt to return a children node of
 * children that we have complete data for. Used when creating new views, to
 * pre-fill their complete event children snapshot.
 */
- (FChildrenNode *)calculateCompleteEventChildrenAtPath:(FPath *)treePath
                                 completeServerChildren:
                                     (id<FNode>)completeServerChildren {
    __block id<FNode> completeChildren = [FEmptyNode emptyNode];
    id<FNode> topLevelSet = [self.visibleWrites completeNodeAtPath:treePath];
    if (topLevelSet != nil) {
        if (![topLevelSet isLeafNode]) {
            // We're shadowing everything. Return the children.
            FChildrenNode *topChildrenNode = topLevelSet;
            [topChildrenNode enumerateChildrenUsingBlock:^(
                                 NSString *key, id<FNode> node, BOOL *stop) {
              completeChildren = [completeChildren updateImmediateChild:key
                                                           withNewChild:node];
            }];
        }
        return completeChildren;
    } else {
        // Layer any children we have on top of this
        // We know we don't have a top-level set, so just enumerate existing
        // children, and apply any updates
        FCompoundWrite *merge =
            [self.visibleWrites childCompoundWriteAtPath:treePath];
        [completeServerChildren enumerateChildrenUsingBlock:^(
                                    NSString *key, id<FNode> node, BOOL *stop) {
          FCompoundWrite *childMerge =
              [merge childCompoundWriteAtPath:[[FPath alloc] initWith:key]];
          id<FNode> newChildNode = [childMerge applyToNode:node];
          completeChildren =
              [completeChildren updateImmediateChild:key
                                        withNewChild:newChildNode];
        }];
        // Add any complete children we have from the set.
        for (FNamedNode *node in merge.completeChildren) {
            completeChildren =
                [completeChildren updateImmediateChild:node.name
                                          withNewChild:node.node];
        }
        return completeChildren;
    }
}

/**
 * Given that the underlying server data has updated, determine what, if
 * anything, needs to be applied to the event cache.
 *
 * Possibilities
 *
 * 1. No write are shadowing. Events should be raised, the snap to be applied
 * comes from the server data.
 *
 * 2. Some write is completely shadowing. No events to be raised.
 *
 * 3. Is partially shadowed. Events ..
 *
 * Either existingEventSnap or existingServerSnap must exist.
 */
- (id<FNode>)calculateEventCacheAfterServerOverwriteAtPath:(FPath *)treePath
                                                 childPath:(FPath *)childPath
                                         existingEventSnap:
                                             (id<FNode>)existingEventSnap
                                        existingServerSnap:
                                            (id<FNode>)existingServerSnap {
    NSAssert(existingEventSnap != nil || existingServerSnap != nil,
             @"Either existingEventSnap or existingServerSanp must exist.");

    FPath *path = [treePath child:childPath];
    if ([self.visibleWrites hasCompleteWriteAtPath:path]) {
        // At this point we can probably guarantee that we're in case 2, meaning
        // no events May need to check visibility while doing the
        // findRootMostValueAndPath call
        return nil;
    } else {
        // This could be more efficient if the serverNode + updates doesn't
        // change the eventSnap However this is tricky to find out, since user
        // updates don't necessary change the server snap, e.g. priority updates
        // on empty nodes, or deep deletes. Another special case is if the
        // server adds nodes, but doesn't change any existing writes. It is
        // therefore not enough to only check if the updates change the
        // serverNode. Maybe check if the merge tree contains these special
        // cases and only do a full overwrite in that case?
        FCompoundWrite *childMerge =
            [self.visibleWrites childCompoundWriteAtPath:path];
        if (childMerge.isEmpty) {
            // We're not shadowing at all. Case 1
            return [existingServerSnap getChild:childPath];
        } else {
            return [childMerge
                applyToNode:[existingServerSnap getChild:childPath]];
        }
    }
}

/**
 * Returns a complete child for a given server snap after applying all user
 * writes or nil if there is no complete child for this child key.
 */
- (id<FNode>)calculateCompleteChildAtPath:(FPath *)treePath
                                 childKey:(NSString *)childKey
                                    cache:(FCacheNode *)existingServerCache {
    FPath *path = [treePath childFromString:childKey];
    id<FNode> shadowingNode = [self.visibleWrites completeNodeAtPath:path];
    if (shadowingNode != nil) {
        return shadowingNode;
    } else {
        if ([existingServerCache isCompleteForChild:childKey]) {
            FCompoundWrite *childMerge =
                [self.visibleWrites childCompoundWriteAtPath:path];
            return [childMerge applyToNode:[existingServerCache.node
                                               getImmediateChild:childKey]];
        } else {
            return nil;
        }
    }
}

/**
 * Returns a node if there is a complete overwrite for this path. More
 * specifically, if there is a write at a higher path, this will return the
 * child of that write relative to the write and this path. Returns null if
 * there is no write at this path.
 */
- (id<FNode>)shadowingWriteAtPath:(FPath *)path {
    return [self.visibleWrites completeNodeAtPath:path];
}

/**
 * This method is used when processing child remove events on a query. If we
 * can, we pull in children that were outside the window, but may now be in the
 * window.
 */
- (FNamedNode *)calculateNextNodeAfterPost:(FNamedNode *)post
                                    atPath:(FPath *)treePath
                        completeServerData:(id<FNode>)completeServerData
                                   reverse:(BOOL)reverse
                                     index:(id<FIndex>)index {
    __block id<FNode> toIterate;
    FCompoundWrite *merge =
        [self.visibleWrites childCompoundWriteAtPath:treePath];
    id<FNode> shadowingNode = [merge completeNodeAtPath:[FPath empty]];
    if (shadowingNode != nil) {
        toIterate = shadowingNode;
    } else if (completeServerData != nil) {
        toIterate = [merge applyToNode:completeServerData];
    } else {
        return nil;
    }

    __block NSString *currentNextKey = nil;
    __block id<FNode> currentNextNode = nil;
    [toIterate enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                             BOOL *stop) {
      if ([index compareKey:key
                    andNode:node
                 toOtherKey:post.name
                    andNode:post.node
                    reverse:reverse] > NSOrderedSame &&
          (!currentNextKey || [index compareKey:key
                                        andNode:node
                                     toOtherKey:currentNextKey
                                        andNode:currentNextNode
                                        reverse:reverse] < NSOrderedSame)) {
          currentNextKey = key;
          currentNextNode = node;
      }
    }];

    if (currentNextKey != nil) {
        return [FNamedNode nodeWithName:currentNextKey node:currentNextNode];
    } else {
        return nil;
    }
}

#pragma mark -
#pragma mark Private Methods

- (BOOL)record:(FWriteRecord *)record containsPath:(FPath *)path {
    if ([record isOverwrite]) {
        return [record.path contains:path];
    } else {
        __block BOOL contains = NO;
        [record.merge
            enumerateWrites:^(FPath *childPath, id<FNode> node, BOOL *stop) {
              contains = [[record.path child:childPath] contains:path];
              *stop = contains;
            }];
        return contains;
    }
}

/**
 * Re-layer the writes and merges into a tree so we can efficiently calculate
 * event snapshots
 */
- (void)resetTree {
    self.visibleWrites =
        [FWriteTree layerTreeFromWrites:self.allWrites
                                 filter:[FWriteTree defaultFilter]
                               treeRoot:[FPath empty]];
    if ([self.allWrites count] > 0) {
        FWriteRecord *lastRecord = self.allWrites[[self.allWrites count] - 1];
        self.lastWriteId = lastRecord.writeId;
    } else {
        self.lastWriteId = -1;
    }
}

/**
 * The default filter used when constructing the tree. Keep everything that's
 * visible.
 */
+ (BOOL (^)(FWriteRecord *record))defaultFilter {
    static BOOL (^filter)(FWriteRecord *);
    static dispatch_once_t filterToken;
    dispatch_once(&filterToken, ^{
      filter = ^(FWriteRecord *record) {
        return YES;
      };
    });
    return filter;
}

/**
 * Static method. Given an array of WriteRecords, a filter for which ones to
 * include, and a path, construct a merge at that path
 * @return An FImmutableTree of id<FNode>s.
 */
+ (FCompoundWrite *)layerTreeFromWrites:(NSArray *)writes
                                 filter:(BOOL (^)(FWriteRecord *record))filter
                               treeRoot:(FPath *)treeRoot {
    __block FCompoundWrite *compoundWrite = [FCompoundWrite emptyWrite];
    [writes enumerateObjectsUsingBlock:^(FWriteRecord *record, NSUInteger idx,
                                         BOOL *stop) {
      // Theory, a later set will either:
      // a) abort a relevant transaction, so no need to worry about excluding it
      // from calculating that transaction b) not be relevant to a transaction
      // (separate branch), so again will not affect the data for that
      // transaction
      if (filter(record)) {
          FPath *writePath = record.path;
          if ([record isOverwrite]) {
              if ([treeRoot contains:writePath]) {
                  FPath *relativePath = [FPath relativePathFrom:treeRoot
                                                             to:writePath];
                  compoundWrite = [compoundWrite addWrite:record.overwrite
                                                   atPath:relativePath];
              } else if ([writePath contains:treeRoot]) {
                  id<FNode> child = [record.overwrite
                      getChild:[FPath relativePathFrom:writePath to:treeRoot]];
                  compoundWrite = [compoundWrite addWrite:child
                                                   atPath:[FPath empty]];
              } else {
                  // There is no overlap between root path and write path,
                  // ignore write
              }
          } else {
              if ([treeRoot contains:writePath]) {
                  FPath *relativePath = [FPath relativePathFrom:treeRoot
                                                             to:writePath];
                  compoundWrite = [compoundWrite addCompoundWrite:record.merge
                                                           atPath:relativePath];
              } else if ([writePath contains:treeRoot]) {
                  FPath *relativePath = [FPath relativePathFrom:writePath
                                                             to:treeRoot];
                  if (relativePath.isEmpty) {
                      compoundWrite =
                          [compoundWrite addCompoundWrite:record.merge
                                                   atPath:[FPath empty]];
                  } else {
                      id<FNode> child =
                          [record.merge completeNodeAtPath:relativePath];
                      if (child != nil) {
                          // There exists a child in this node that matches the
                          // root path
                          id<FNode> deepNode =
                              [child getChild:[relativePath popFront]];
                          compoundWrite =
                              [compoundWrite addWrite:deepNode
                                               atPath:[FPath empty]];
                      }
                  }
              } else {
                  // There is no overlap between root path and write path,
                  // ignore write
              }
          }
      }
    }];
    return compoundWrite;
}

@end
