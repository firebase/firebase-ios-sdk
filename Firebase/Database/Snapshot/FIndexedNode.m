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

#import "FIndexedNode.h"

#import "FImmutableSortedSet.h"
#import "FIndex.h"
#import "FPriorityIndex.h"
#import "FKeyIndex.h"
#import "FChildrenNode.h"

static FImmutableSortedSet *FALLBACK_INDEX;

@interface FIndexedNode ()

@property (nonatomic, strong) id<FNode> node;
/**
 * The indexed set is initialized lazily to prevent creation when it is not needed
 */
@property (nonatomic, strong) FImmutableSortedSet *indexed;
@property (nonatomic, strong) id<FIndex> index;

@end

@implementation FIndexedNode

+ (FImmutableSortedSet *)fallbackIndex {
    static FImmutableSortedSet *fallbackIndex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fallbackIndex = [[FImmutableSortedSet alloc] init];
    });
    return fallbackIndex;
}

+ (FIndexedNode *)indexedNodeWithNode:(id<FNode>)node
{
    return [[FIndexedNode alloc] initWithNode:node index:[FPriorityIndex priorityIndex]];
}

+ (FIndexedNode *)indexedNodeWithNode:(id<FNode>)node index:(id<FIndex>)index
{
    return [[FIndexedNode alloc] initWithNode:node index:index];
}

- (id)initWithNode:(id<FNode>)node index:(id<FIndex>)index
{
    // Initialize indexed lazily
    return [self initWithNode:node index:index indexed:nil];
}

- (id)initWithNode:(id<FNode>)node index:(id<FIndex>)index indexed:(FImmutableSortedSet *)indexed
{
    self = [super init];
    if (self != nil) {
        self->_node = node;
        self->_index = index;
        self->_indexed = indexed;
    }
    return self;
}

- (void)ensureIndexed
{
    if (!self.indexed) {
        if ([self.index isEqual:[FKeyIndex keyIndex]]) {
            self.indexed = [FIndexedNode fallbackIndex];
        } else {
            __block BOOL sawChild;
            [self.node enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node, BOOL *stop) {
                sawChild = sawChild || [self.index isDefinedOn:node];
                *stop = sawChild;
            }];
            if (sawChild) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                [self.node enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node, BOOL *stop) {
                    FNamedNode *namedNode = [[FNamedNode alloc] initWithName:key andNode:node];
                    dict[namedNode] = [NSNull null];
                }];
                // Make sure to assign index here, because the comparator will be retained and using self will cause a
                // cycle
                id<FIndex> index = self.index;
                self.indexed = [FImmutableSortedSet setWithKeysFromDictionary:dict
                                                                   comparator:^NSComparisonResult(FNamedNode *namedNode1, FNamedNode *namedNode2) {
                    return [index compareNamedNode:namedNode1 toNamedNode:namedNode2];
                }];
            } else {
                self.indexed = [FIndexedNode fallbackIndex];
            }
        }
    }
}

- (BOOL)hasIndex:(id<FIndex>)index
{
    return [self.index isEqual:index];
}

- (FIndexedNode *)updateChild:(NSString *)key withNewChild:(id<FNode>)newChildNode
{
    id<FNode> newNode = [self.node updateImmediateChild:key withNewChild:newChildNode];
    if (self.indexed == [FIndexedNode fallbackIndex] && ![self.index isDefinedOn:newChildNode]) {
        // doesn't affect the index, no need to create an index
        return [[FIndexedNode alloc] initWithNode:newNode index:self.index indexed:[FIndexedNode fallbackIndex]];
    } else if (!self.indexed || self.indexed == [FIndexedNode fallbackIndex]) {
        // No need to index yet, index lazily
        return [[FIndexedNode alloc] initWithNode:newNode index:self.index];
    } else {
        id<FNode> oldChild = [self.node getImmediateChild:key];
        FImmutableSortedSet *newIndexed = [self.indexed removeObject:[FNamedNode nodeWithName:key node:oldChild]];
        if (![newChildNode isEmpty]) {
            newIndexed = [newIndexed addObject:[FNamedNode nodeWithName:key node:newChildNode]];
        }
        return [[FIndexedNode alloc] initWithNode:newNode index:self.index indexed:newIndexed];
    }
}

- (FIndexedNode *)updatePriority:(id<FNode>)priority
{
    return [[FIndexedNode alloc] initWithNode:[self.node updatePriority:priority]
                                        index:self.index
                                      indexed:self.indexed];
}

- (FNamedNode *)firstChild
{
    if (![self.node isKindOfClass:[FChildrenNode class]]) {
        return nil;
    } else {
        [self ensureIndexed];
        if (self.indexed == [FIndexedNode fallbackIndex]) {
            return [((FChildrenNode *)self.node) firstChild];
        } else {
            return self.indexed.firstObject;
        }
    }
}

- (FNamedNode *)lastChild
{
    if (![self.node isKindOfClass:[FChildrenNode class]]) {
        return nil;
    } else {
        [self ensureIndexed];
        if (self.indexed == [FIndexedNode fallbackIndex]) {
            return [((FChildrenNode *)self.node) lastChild];
        } else {
            return self.indexed.lastObject;
        }
    }
}

- (NSString *)predecessorForChildKey:(NSString *)childKey childNode:(id<FNode>)childNode index:(id<FIndex>)index
{
    if (![self.index isEqual:index]) {
        [NSException raise:NSInvalidArgumentException format:@"Index not available in IndexedNode!"];
    }
    [self ensureIndexed];
    if (self.indexed == [FIndexedNode fallbackIndex]) {
        return [self.node predecessorChildKey:childKey];
    } else {
        FNamedNode *node = [self.indexed predecessorEntry:[FNamedNode nodeWithName:childKey node:childNode]];
        return node.name;
    }
}

- (void)enumerateChildrenReverse:(BOOL)reverse usingBlock:(void (^)(NSString *, id<FNode>, BOOL *))block
{
    [self ensureIndexed];
    if (self.indexed == [FIndexedNode fallbackIndex]) {
        [self.node enumerateChildrenReverse:reverse usingBlock:block];
    } else {
        [self.indexed enumerateObjectsReverse:reverse usingBlock:^(FNamedNode *namedNode, BOOL *stop) {
            block(namedNode.name, namedNode.node, stop);
        }];
    }
}

- (NSEnumerator *)childEnumerator
{
    [self ensureIndexed];
    if (self.indexed == [FIndexedNode fallbackIndex]) {
        return [self.node childEnumerator];
    } else {
        return [self.indexed objectEnumerator];
    }
}

@end
