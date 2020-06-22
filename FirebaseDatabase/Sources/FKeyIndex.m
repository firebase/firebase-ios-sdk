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

#import "FKeyIndex.h"
#import "FEmptyNode.h"
#import "FNamedNode.h"
#import "FSnapshotUtilities.h"
#import "FUtilities.h"

@interface FKeyIndex ()

@property(nonatomic, strong) FNamedNode *maxPost;

@end

@implementation FKeyIndex

- (id)init {
    self = [super init];
    if (self) {
        self.maxPost = [[FNamedNode alloc] initWithName:[FUtilities maxName]
                                                andNode:[FEmptyNode emptyNode]];
    }
    return self;
}

- (NSComparisonResult)compareKey:(NSString *)key1
                         andNode:(id<FNode>)node1
                      toOtherKey:(NSString *)key2
                         andNode:(id<FNode>)node2 {
    return [FUtilities compareKey:key1 toKey:key2];
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
    return NO; // The key for a node never changes.
}

- (FNamedNode *)minPost {
    return [FNamedNode min];
}

- (FNamedNode *)makePost:(id<FNode>)indexValue name:(NSString *)name {
    NSString *key = indexValue.val;
    NSAssert([key isKindOfClass:[NSString class]],
             @"KeyIndex indexValue must always be a string.");
    // We just use empty node, but it'll never be compared, since our comparator
    // only looks at name.
    return [[FNamedNode alloc] initWithName:key andNode:[FEmptyNode emptyNode]];
}

- (NSString *)queryDefinition {
    return @".key";
}

- (NSString *)description {
    return @"FKeyIndex";
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)isEqual:(id)other {
    // since we're a singleton.
    return (other == self);
}

- (NSUInteger)hash {
    return [@".key" hash];
}

+ (id<FIndex>)keyIndex {
    static id<FIndex> keyIndex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      keyIndex = [[FKeyIndex alloc] init];
    });
    return keyIndex;
}
@end
