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

#import "FirebaseDatabase/Sources/FRangedFilter.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/View/Filter/FChildChangeAccumulator.h"
#import "FirebaseDatabase/Sources/Core/View/Filter/FIndexedFilter.h"
#import "FirebaseDatabase/Sources/FNamedNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FChildrenNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FIndexedNode.h"

@interface FRangedFilter ()
@property(nonatomic, strong, readwrite) id<FNodeFilter> indexedFilter;
@property(nonatomic, strong, readwrite) id<FIndex> index;
@property(nonatomic, strong, readwrite) FNamedNode *startPost;
@property(nonatomic, strong, readwrite) FNamedNode *endPost;
@end

@implementation FRangedFilter
- (id)initWithQueryParams:(FQueryParams *)params {
    self = [super init];
    if (self) {
        self.indexedFilter =
            [[FIndexedFilter alloc] initWithIndex:params.index];
        self.index = params.index;
        self.startPost = [FRangedFilter startPostFromQueryParams:params];
        self.endPost = [FRangedFilter endPostFromQueryParams:params];
    }
    return self;
}

+ (FNamedNode *)startPostFromQueryParams:(FQueryParams *)params {
    if ([params hasStart]) {
        NSString *startKey = params.indexStartKey;
        return [params.index makePost:params.indexStartValue name:startKey];
    } else {
        return params.index.minPost;
    }
}

+ (FNamedNode *)endPostFromQueryParams:(FQueryParams *)params {
    if ([params hasEnd]) {
        NSString *endKey = params.indexEndKey;
        return [params.index makePost:params.indexEndValue name:endKey];
    } else {
        return params.index.maxPost;
    }
}

- (BOOL)matchesKey:(NSString *)key andNode:(id<FNode>)node {
    return ([self.index compareKey:self.startPost.name
                           andNode:self.startPost.node
                        toOtherKey:key
                           andNode:node] <= NSOrderedSame &&
            [self.index compareKey:key
                           andNode:node
                        toOtherKey:self.endPost.name
                           andNode:self.endPost.node] <= NSOrderedSame);
}

- (FIndexedNode *)updateChildIn:(FIndexedNode *)oldSnap
                    forChildKey:(NSString *)childKey
                       newChild:(id<FNode>)newChildSnap
                   affectedPath:(FPath *)affectedPath
                     fromSource:(id<FCompleteChildSource>)source
                    accumulator:
                        (FChildChangeAccumulator *)optChangeAccumulator {
    if (![self matchesKey:childKey andNode:newChildSnap]) {
        newChildSnap = [FEmptyNode emptyNode];
    }
    return [self.indexedFilter updateChildIn:oldSnap
                                 forChildKey:childKey
                                    newChild:newChildSnap
                                affectedPath:affectedPath
                                  fromSource:source
                                 accumulator:optChangeAccumulator];
}

- (FIndexedNode *)updateFullNode:(FIndexedNode *)oldSnap
                     withNewNode:(FIndexedNode *)newSnap
                     accumulator:
                         (FChildChangeAccumulator *)optChangeAccumulator {
    __block FIndexedNode *filtered;
    if (newSnap.node.isLeafNode) {
        // Make sure we have a children node with the correct index, not a leaf
        // node
        filtered = [FIndexedNode indexedNodeWithNode:[FEmptyNode emptyNode]
                                               index:self.index];
    } else {
        // Dont' support priorities on queries
        filtered = [newSnap updatePriority:[FEmptyNode emptyNode]];
        [newSnap.node enumerateChildrenUsingBlock:^(
                          NSString *key, id<FNode> node, BOOL *stop) {
          if (![self matchesKey:key andNode:node]) {
              filtered = [filtered updateChild:key
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
    // Don't support priorities on queries
    return oldSnap;
}

- (BOOL)filtersNodes {
    return YES;
}

@end
