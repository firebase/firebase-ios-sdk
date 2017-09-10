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

#import "FLimitedFilter.h"
#import "FChange.h"
#import "FChildChangeAccumulator.h"
#import "FChildrenNode.h"
#import "FCompleteChildSource.h"
#import "FEmptyNode.h"
#import "FIndex.h"
#import "FNamedNode.h"
#import "FQueryParams.h"
#import "FRangedFilter.h"
#import "FTreeSortedDictionary.h"

@interface FLimitedFilter ()
@property(nonatomic, strong) FRangedFilter *rangedFilter;
@property(nonatomic, strong, readwrite) id<FIndex> index;
@property(nonatomic) NSInteger limit;
@property(nonatomic) BOOL reverse;

@end

@implementation FLimitedFilter
- (id)initWithQueryParams:(FQueryParams *)params {
    self = [super init];
    if (self) {
        self.rangedFilter = [[FRangedFilter alloc] initWithQueryParams:params];
        self.index = params.index;
        self.limit = params.limit;
        self.reverse = !params.isViewFromLeft;
    }
    return self;
}

- (FIndexedNode *)updateChildIn:(FIndexedNode *)oldSnap
                    forChildKey:(NSString *)childKey
                       newChild:(id<FNode>)newChildSnap
                   affectedPath:(FPath *)affectedPath
                     fromSource:(id<FCompleteChildSource>)source
                    accumulator:
                        (FChildChangeAccumulator *)optChangeAccumulator {
    if (![self.rangedFilter matchesKey:childKey andNode:newChildSnap]) {
        newChildSnap = [FEmptyNode emptyNode];
    }
    if ([[oldSnap.node getImmediateChild:childKey] isEqual:newChildSnap]) {
        // No change
        return oldSnap;
    } else if (oldSnap.node.numChildren < self.limit) {
        return [[self.rangedFilter indexedFilter]
            updateChildIn:oldSnap
              forChildKey:childKey
                 newChild:newChildSnap
             affectedPath:affectedPath
               fromSource:source
              accumulator:optChangeAccumulator];
    } else {
        return [self fullLimitUpdateNode:oldSnap
                             forChildKey:childKey
                                newChild:newChildSnap
                              fromSource:source
                             accumulator:optChangeAccumulator];
    }
}

- (FIndexedNode *)fullLimitUpdateNode:(FIndexedNode *)oldIndexed
                          forChildKey:(NSString *)childKey
                             newChild:(id<FNode>)newChildSnap
                           fromSource:(id<FCompleteChildSource>)source
                          accumulator:
                              (FChildChangeAccumulator *)optChangeAccumulator {
    NSAssert(oldIndexed.node.numChildren == self.limit,
             @"Should have number of children equal to limit.");

    FNamedNode *windowBoundary =
        self.reverse ? oldIndexed.firstChild : oldIndexed.lastChild;

    BOOL inRange = [self.rangedFilter matchesKey:childKey andNode:newChildSnap];
    if ([oldIndexed.node hasChild:childKey]) {
        // `childKey` was already in `oldSnap`. Figure out if it remains in the
        // window or needs to be replaced.
        id<FNode> oldChildSnap = [oldIndexed.node getImmediateChild:childKey];

        // In case the `newChildSnap` falls outside the window, get the
        // `nextChild` that might replace it.
        FNamedNode *nextChild = [source childByIndex:self.index
                                          afterChild:windowBoundary
                                           isReverse:(BOOL)self.reverse];
        if (nextChild != nil && ([nextChild.name isEqualToString:childKey] ||
                                 [oldIndexed.node hasChild:nextChild.name])) {
            // There is a weird edge case where a node is updated as part of a
            // merge in the write tree, but hasn't been applied to the limited
            // filter yet. Ignore this next child which will be updated later in
            // the limited filter...
            nextChild = [source childByIndex:self.index
                                  afterChild:nextChild
                                   isReverse:self.reverse];
        }

        // Figure out if `newChildSnap` is in range and ordered before
        // `nextChild`
        BOOL remainsInWindow = inRange && !newChildSnap.isEmpty;
        remainsInWindow = remainsInWindow &&
                          (!nextChild || [self.index compareKey:nextChild.name
                                                        andNode:nextChild.node
                                                     toOtherKey:childKey
                                                        andNode:newChildSnap
                                                        reverse:self.reverse] >=
                                             NSOrderedSame);
        if (remainsInWindow) {
            // `newChildSnap` is ordered before `nextChild`, so it's a child
            // changed event
            if (optChangeAccumulator != nil) {
                FChange *change = [[FChange alloc]
                      initWithType:FIRDataEventTypeChildChanged
                       indexedNode:[FIndexedNode
                                       indexedNodeWithNode:newChildSnap]
                          childKey:childKey
                    oldIndexedNode:[FIndexedNode
                                       indexedNodeWithNode:oldChildSnap]];
                [optChangeAccumulator trackChildChange:change];
            }
            return [oldIndexed updateChild:childKey withNewChild:newChildSnap];
        } else {
            // `newChildSnap` is ordered after `nextChild`, so it's a child
            // removed event
            if (optChangeAccumulator != nil) {
                FChange *change = [[FChange alloc]
                    initWithType:FIRDataEventTypeChildRemoved
                     indexedNode:[FIndexedNode indexedNodeWithNode:oldChildSnap]
                        childKey:childKey];
                [optChangeAccumulator trackChildChange:change];
            }
            FIndexedNode *newIndexed =
                [oldIndexed updateChild:childKey
                           withNewChild:[FEmptyNode emptyNode]];

            // We need to check if the `nextChild` is actually in range before
            // adding it
            BOOL nextChildInRange =
                (nextChild != nil) &&
                [self.rangedFilter matchesKey:nextChild.name
                                      andNode:nextChild.node];
            if (nextChildInRange) {
                if (optChangeAccumulator != nil) {
                    FChange *change = [[FChange alloc]
                        initWithType:FIRDataEventTypeChildAdded
                         indexedNode:[FIndexedNode
                                         indexedNodeWithNode:nextChild.node]
                            childKey:nextChild.name];
                    [optChangeAccumulator trackChildChange:change];
                }
                return [newIndexed updateChild:nextChild.name
                                  withNewChild:nextChild.node];
            } else {
                return newIndexed;
            }
        }
    } else if (newChildSnap.isEmpty) {
        // We're deleting a node, but it was not in the window, so ignore it.
        return oldIndexed;
    } else if (inRange) {
        // `newChildSnap` is in range, but was ordered after `windowBoundary`.
        // If this has changed, we bump out the `windowBoundary` and add the
        // `newChildSnap`
        if ([self.index compareKey:windowBoundary.name
                           andNode:windowBoundary.node
                        toOtherKey:childKey
                           andNode:newChildSnap
                           reverse:self.reverse] >= NSOrderedSame) {
            if (optChangeAccumulator != nil) {
                FChange *removedChange = [[FChange alloc]
                    initWithType:FIRDataEventTypeChildRemoved
                     indexedNode:[FIndexedNode
                                     indexedNodeWithNode:windowBoundary.node]
                        childKey:windowBoundary.name];
                FChange *addedChange = [[FChange alloc]
                    initWithType:FIRDataEventTypeChildAdded
                     indexedNode:[FIndexedNode indexedNodeWithNode:newChildSnap]
                        childKey:childKey];
                [optChangeAccumulator trackChildChange:removedChange];
                [optChangeAccumulator trackChildChange:addedChange];
            }
            return [[oldIndexed updateChild:childKey withNewChild:newChildSnap]
                 updateChild:windowBoundary.name
                withNewChild:[FEmptyNode emptyNode]];
        } else {
            return oldIndexed;
        }
    } else {
        // `newChildSnap` was not in range and remains not in range, so ignore
        // it.
        return oldIndexed;
    }
}

- (FIndexedNode *)updateFullNode:(FIndexedNode *)oldSnap
                     withNewNode:(FIndexedNode *)newSnap
                     accumulator:
                         (FChildChangeAccumulator *)optChangeAccumulator {
    __block FIndexedNode *filtered;
    if (newSnap.node.isLeafNode || newSnap.node.isEmpty) {
        // Make sure we have a children node with the correct index, not a leaf
        // node
        filtered = [FIndexedNode indexedNodeWithNode:[FEmptyNode emptyNode]
                                               index:self.index];
    } else {
        filtered = newSnap;
        // Don't support priorities on queries.
        filtered = [filtered updatePriority:[FEmptyNode emptyNode]];
        FNamedNode *startPost = nil;
        FNamedNode *endPost = nil;
        if (self.reverse) {
            startPost = self.rangedFilter.endPost;
            endPost = self.rangedFilter.startPost;
        } else {
            startPost = self.rangedFilter.startPost;
            endPost = self.rangedFilter.endPost;
        }
        __block BOOL foundStartPost = NO;
        __block NSUInteger count = 0;
        [newSnap
            enumerateChildrenReverse:self.reverse
                          usingBlock:^(NSString *childKey, id<FNode> childNode,
                                       BOOL *stop) {
                            if (!foundStartPost &&
                                [self.index
                                    compareKey:startPost.name
                                       andNode:startPost.node
                                    toOtherKey:childKey
                                       andNode:childNode
                                       reverse:self.reverse] <= NSOrderedSame) {
                                // Start adding
                                foundStartPost = YES;
                            }
                            BOOL inRange = foundStartPost && count < self.limit;
                            inRange = inRange &&
                                      [self.index compareKey:childKey
                                                     andNode:childNode
                                                  toOtherKey:endPost.name
                                                     andNode:endPost.node
                                                     reverse:self.reverse] <=
                                          NSOrderedSame;
                            if (inRange) {
                                count++;
                            } else {
                                filtered = [filtered
                                     updateChild:childKey
                                    withNewChild:[FEmptyNode emptyNode]];
                            }
                          }];
    }
    return [self.indexedFilter updateFullNode:oldSnap
                                  withNewNode:filtered
                                  accumulator:optChangeAccumulator];
}

- (FIndexedNode *)updatePriority:(id<FNode>)priority
                         forNode:(FIndexedNode *)oldSnap {
    // Don't support priorities on queries.
    return oldSnap;
}

- (BOOL)filtersNodes {
    return YES;
}

- (id<FNodeFilter>)indexedFilter {
    return self.rangedFilter.indexedFilter;
}

@end
