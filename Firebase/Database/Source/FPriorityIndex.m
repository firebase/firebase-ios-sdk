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

#import "FPriorityIndex.h"

#import "FNode.h"
#import "FUtilities.h"
#import "FNamedNode.h"
#import "FEmptyNode.h"
#import "FLeafNode.h"
#import "FMaxNode.h"

// TODO: Abstract into some common base class?

@implementation FPriorityIndex

- (NSComparisonResult) compareKey:(NSString *)key1
                          andNode:(id<FNode>)node1
                       toOtherKey:(NSString *)key2
                          andNode:(id<FNode>)node2
{
    id<FNode> child1 = [node1 getPriority];
    id<FNode> child2 = [node2 getPriority];
    NSComparisonResult indexCmp = [child1 compare:child2];
    if (indexCmp == NSOrderedSame) {
        return [FUtilities compareKey:key1 toKey:key2];
    } else {
        return indexCmp;
    }
}

- (NSComparisonResult) compareKey:(NSString *)key1
                          andNode:(id<FNode>)node1
                       toOtherKey:(NSString *)key2
                          andNode:(id<FNode>)node2
                          reverse:(BOOL)reverse
{
    if (reverse) {
        return [self compareKey:key2 andNode:node2 toOtherKey:key1 andNode:node1];
    } else {
        return [self compareKey:key1 andNode:node1 toOtherKey:key2 andNode:node2];
    }
}

- (NSComparisonResult) compareNamedNode:(FNamedNode *)namedNode1 toNamedNode:(FNamedNode *)namedNode2
{
    return [self compareKey:namedNode1.name andNode:namedNode1.node toOtherKey:namedNode2.name andNode:namedNode2.node];
}

- (BOOL)isDefinedOn:(id <FNode>)node {
    return !node.getPriority.isEmpty;
}

- (BOOL)indexedValueChangedBetween:(id <FNode>)oldNode and:(id <FNode>)newNode {
    id<FNode> oldValue = [oldNode getPriority];
    id<FNode> newValue = [newNode getPriority];
    return ![oldValue isEqual:newValue];
}

- (FNamedNode *)minPost {
    return FNamedNode.min;
}

- (FNamedNode *)maxPost {
    return [self makePost:[FMaxNode maxNode] name:[FUtilities maxName]];
}

- (FNamedNode*)makePost:(id<FNode>)indexValue name:(NSString*)name {
    id<FNode> node = [[FLeafNode alloc] initWithValue:@"[PRIORITY-POST]" withPriority:indexValue];
    return [[FNamedNode alloc] initWithName:name andNode:node];
}

- (NSString *)queryDefinition {
    return @".priority";
}

- (NSString *)description {
    return @"FPriorityIndex";
}

- (id)copyWithZone:(NSZone *)zone {
    // Safe since we're immutable.
    return self;
}

- (BOOL) isEqual:(id)other {
    return [other isKindOfClass:[FPriorityIndex class]];
}

- (NSUInteger) hash {
    // chosen by a fair dice roll. Guaranteed to be random
    return 3155577;
}

+ (id<FIndex>) priorityIndex {
    static id<FIndex> index;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        index = [[FPriorityIndex alloc] init];
    });

    return index;
}

@end
