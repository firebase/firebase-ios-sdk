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

#import "FirebaseDatabase/Sources/FValueIndex.h"
#import "FirebaseDatabase/Sources/FMaxNode.h"
#import "FirebaseDatabase/Sources/FNamedNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

@implementation FValueIndex

- (NSComparisonResult)compareKey:(NSString *)key1
                         andNode:(id<FNode>)node1
                      toOtherKey:(NSString *)key2
                         andNode:(id<FNode>)node2 {
    NSComparisonResult indexCmp = [node1 compare:node2];
    if (indexCmp == NSOrderedSame) {
        return [FUtilities compareKey:key1 toKey:key2];
    } else {
        return indexCmp;
    }
}

- (NSComparisonResult)compareKey:(NSString *)key1
                         andNode:(id<FNode>)node1
                      toOtherKey:(NSString *)key2
                         andNode:(id<FNode>)node2
                         reverse:(BOOL)reverse {
    if (reverse) {
        return [self compareKey:key2
                        andNode:node2
                     toOtherKey:key1
                        andNode:node1];
    } else {
        return [self compareKey:key1
                        andNode:node1
                     toOtherKey:key2
                        andNode:node2];
    }
}

- (NSComparisonResult)compareNamedNode:(FNamedNode *)namedNode1
                           toNamedNode:(FNamedNode *)namedNode2 {
    return [self compareKey:namedNode1.name
                    andNode:namedNode1.node
                 toOtherKey:namedNode2.name
                    andNode:namedNode2.node];
}

- (BOOL)isDefinedOn:(id<FNode>)node {
    return YES;
}

- (BOOL)indexedValueChangedBetween:(id<FNode>)oldNode and:(id<FNode>)newNode {
    return ![oldNode isEqual:newNode];
}

- (FNamedNode *)minPost {
    return FNamedNode.min;
}

- (FNamedNode *)maxPost {
    return FNamedNode.max;
}

- (FNamedNode *)makePost:(id<FNode>)indexValue name:(NSString *)name {
    return [[FNamedNode alloc] initWithName:name andNode:indexValue];
}

- (NSString *)queryDefinition {
    return @".value";
}

- (NSString *)description {
    return @"FValueIndex";
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)isEqual:(id)other {
    // since we're a singleton.
    return (other == self);
}

- (NSUInteger)hash {
    return [@".value" hash];
}

+ (id<FIndex>)valueIndex {
    static id<FIndex> valueIndex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      valueIndex = [[FValueIndex alloc] init];
    });
    return valueIndex;
}
@end
