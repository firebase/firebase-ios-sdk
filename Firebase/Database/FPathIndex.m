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

#import "FPathIndex.h"
#import "FUtilities.h"
#import "FMaxNode.h"
#import "FEmptyNode.h"
#import "FSnapshotUtilities.h"
#import "FNamedNode.h"
#import "FPath.h"

@interface FPathIndex ()
    @property (nonatomic, strong) FPath *path;
@end

@implementation FPathIndex

- (id) initWithPath:(FPath *)path {
    self = [super init];
    if (self) {
        if (path.isEmpty || [path.getFront isEqualToString:@".priority"]) {
            [NSException raise:NSInvalidArgumentException format:@"Invalid path for PathIndex: %@", path];
        }
        _path = path;
    }
    return self;
}

- (NSComparisonResult) compareKey:(NSString *)key1
                          andNode:(id<FNode>)node1
                       toOtherKey:(NSString *)key2
                          andNode:(id<FNode>)node2
{
    id<FNode> child1 = [node1 getChild:self.path];
    id<FNode> child2 = [node2 getChild:self.path];
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
    return ![node getChild:self.path].isEmpty;
}

- (BOOL)indexedValueChangedBetween:(id <FNode>)oldNode and:(id <FNode>)newNode {
    id<FNode> oldValue = [oldNode getChild:self.path];
    id<FNode> newValue = [newNode getChild:self.path];
    return [oldValue compare:newValue] != NSOrderedSame;
}

- (FNamedNode *)minPost {
    return FNamedNode.min;
}

- (FNamedNode *)maxPost {
    id<FNode> maxNode = [[FEmptyNode emptyNode] updateChild:self.path
                                               withNewChild:[FMaxNode maxNode]];

    return [[FNamedNode alloc] initWithName:[FUtilities maxName] andNode:maxNode];
}

- (FNamedNode*)makePost:(id<FNode>)indexValue name:(NSString*)name {
    id<FNode> node = [[FEmptyNode emptyNode] updateChild:self.path withNewChild:indexValue];
    return [[FNamedNode alloc] initWithName:name andNode:node];
}

- (NSString *)queryDefinition {
    return [self.path wireFormat];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FPathIndex(%@)", self.path];
}

- (id)copyWithZone:(NSZone *)zone {
    // Safe since we're immutable.
    return self;
}

- (BOOL) isEqual:(id)other {
    if (![other isKindOfClass:[FPathIndex class]]) {
        return NO;
    }
    return ([self.path isEqual:((FPathIndex*)other).path]);
}

- (NSUInteger) hash {
    return [self.path hash];
}

@end
