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

#import "FNode.h"
#import "FIndexedFilter.h"
#import "FChildChangeAccumulator.h"
#import "FIndex.h"
#import "FChange.h"
#import "FChildrenNode.h"
#import "FKeyIndex.h"
#import "FEmptyNode.h"
#import "FIndexedNode.h"

@interface FIndexedFilter ()
@property (nonatomic, strong, readwrite) id<FIndex> index;
@end

@implementation FIndexedFilter
- (id) initWithIndex:(id<FIndex>)theIndex {
    self = [super init];
    if (self) {
        self.index = theIndex;
    }
    return self;
}

- (FIndexedNode *)updateChildIn:(FIndexedNode *)indexedNode
                    forChildKey:(NSString *)childKey
                       newChild:(id<FNode>)newChildSnap
                   affectedPath:(FPath *)affectedPath
                     fromSource:(id<FCompleteChildSource>)source
                    accumulator:(FChildChangeAccumulator *)optChangeAccumulator
{
    NSAssert([indexedNode hasIndex:self.index], @"The index in FIndexedNode must match the index of the filter");
    id<FNode> node = indexedNode.node;
    id<FNode> oldChildSnap = [node getImmediateChild:childKey];

    // Check if anything actually changed.
    if ([[oldChildSnap getChild:affectedPath] isEqual:[newChildSnap getChild:affectedPath]]) {
        // There's an edge case where a child can enter or leave the view because affectedPath was set to null.
        // In this case, affectedPath will appear null in both the old and new snapshots.  So we need
        // to avoid treating these cases as "nothing changed."
        if (oldChildSnap.isEmpty == newChildSnap.isEmpty) {
            // Nothing changed.
            #ifdef DEBUG
            NSAssert([oldChildSnap isEqual:newChildSnap], @"Old and new snapshots should be equal.");
            #endif

            return indexedNode;
        }
    }
    if (optChangeAccumulator) {
        if (newChildSnap.isEmpty) {
            if ([node hasChild:childKey]) {
                FChange *change = [[FChange alloc] initWithType:FIRDataEventTypeChildRemoved
                                                    indexedNode:[FIndexedNode indexedNodeWithNode:oldChildSnap]
                                                       childKey:childKey];
                [optChangeAccumulator trackChildChange:change];
            } else {
                NSAssert(node.isLeafNode, @"A child remove without an old child only makes sense on a leaf node.");
            }
        } else if (oldChildSnap.isEmpty) {
            FChange *change = [[FChange alloc] initWithType:FIRDataEventTypeChildAdded
                                                indexedNode:[FIndexedNode indexedNodeWithNode:newChildSnap]
                                                   childKey:childKey];
            [optChangeAccumulator trackChildChange:change];
        } else {
            FChange *change = [[FChange alloc] initWithType:FIRDataEventTypeChildChanged
                                                indexedNode:[FIndexedNode indexedNodeWithNode:newChildSnap]
                                                   childKey:childKey
                                             oldIndexedNode:[FIndexedNode indexedNodeWithNode:oldChildSnap]];
            [optChangeAccumulator trackChildChange:change];
        }
    }
    if (node.isLeafNode && newChildSnap.isEmpty) {
        return indexedNode;
    } else {
        return [indexedNode updateChild:childKey withNewChild:newChildSnap];
    }
}

- (FIndexedNode *)updateFullNode:(FIndexedNode *)oldSnap
                     withNewNode:(FIndexedNode *)newSnap
                     accumulator:(FChildChangeAccumulator *)optChangeAccumulator
{
    if (optChangeAccumulator) {
        [oldSnap.node enumerateChildrenUsingBlock:^(NSString *childKey, id<FNode> childNode, BOOL *stop) {
            if (![newSnap.node hasChild:childKey]) {
                FChange *change = [[FChange alloc] initWithType:FIRDataEventTypeChildRemoved
                                                    indexedNode:[FIndexedNode indexedNodeWithNode:childNode]
                                                       childKey:childKey];
                [optChangeAccumulator trackChildChange:change];
            }
        }];

        [newSnap.node enumerateChildrenUsingBlock:^(NSString *childKey, id<FNode> childNode, BOOL *stop) {
            if ([oldSnap.node hasChild:childKey]) {
                id<FNode> oldChildSnap = [oldSnap.node getImmediateChild:childKey];
                if (![oldChildSnap isEqual:childNode]) {
                    FChange *change = [[FChange alloc] initWithType:FIRDataEventTypeChildChanged
                                                        indexedNode:[FIndexedNode indexedNodeWithNode:childNode]
                                                           childKey:childKey
                                                     oldIndexedNode:[FIndexedNode indexedNodeWithNode:oldChildSnap]];
                    [optChangeAccumulator trackChildChange:change];
                }
            } else {
                FChange *change = [[FChange alloc] initWithType:FIRDataEventTypeChildAdded
                                                    indexedNode:[FIndexedNode indexedNodeWithNode:childNode]
                                                       childKey:childKey];
                [optChangeAccumulator trackChildChange:change];
            }
        }];
    }
    return newSnap;
}

- (FIndexedNode *)updatePriority:(id<FNode>)priority forNode:(FIndexedNode *)oldSnap
{
    if ([oldSnap.node isEmpty]) {
        return oldSnap;
    } else {
        return [oldSnap updatePriority:priority];
    }
}

- (BOOL) filtersNodes {
    return NO;
}

- (id<FNodeFilter>) indexedFilter {
    return self;
}

@end
