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

#import "FChildrenNode.h"
#import "FConstants.h"
#import "FEmptyNode.h"
#import "FMaxNode.h"
#import "FNamedNode.h"
#import "FPriorityIndex.h"
#import "FSnapshotUtilities.h"
#import "FStringUtilities.h"
#import "FTransformedEnumerator.h"
#import "FUtilities.h"

@interface FChildrenNode ()
@property(nonatomic, strong) NSString *lazyHash;
@end

@implementation FChildrenNode

// Note: The only reason we allow nil priority is to for EmptyNode, since we
// can't use EmptyNode as the priority of EmptyNode.  We might want to consider
// making EmptyNode its own class instead of an empty ChildrenNode.

- (id)init {
    return [self
        initWithPriority:nil
                children:[FImmutableSortedDictionary
                             dictionaryWithComparator:[FUtilities
                                                          keyComparator]]];
}

- (id)initWithChildren:(FImmutableSortedDictionary *)someChildren {
    return [self initWithPriority:nil children:someChildren];
}

- (id)initWithPriority:(id<FNode>)aPriority
              children:(FImmutableSortedDictionary *)someChildren {
    if (someChildren.isEmpty && aPriority != nil && ![aPriority isEmpty]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Can't create empty node with priority!"];
    }
    self = [super init];
    if (self) {
        self.children = someChildren;
        self.priorityNode = aPriority;
    }
    return self;
}

- (NSString *)description {
    return [[self valForExport:YES] description];
}

#pragma mark -
#pragma mark FNode methods

- (BOOL)isLeafNode {
    return NO;
}

- (id<FNode>)getPriority {
    if (self.priorityNode) {
        return self.priorityNode;
    } else {
        return [FEmptyNode emptyNode];
    }
}

- (id<FNode>)updatePriority:(id<FNode>)aPriority {
    if ([self.children isEmpty]) {
        return [FEmptyNode emptyNode];
    } else {
        return [[FChildrenNode alloc] initWithPriority:aPriority
                                              children:self.children];
    }
}

- (id<FNode>)getImmediateChild:(NSString *)childName {
    if ([childName isEqualToString:@".priority"]) {
        return [self getPriority];
    } else {
        id<FNode> child = [self.children objectForKey:childName];
        return (child == nil) ? [FEmptyNode emptyNode] : child;
    }
}

- (id<FNode>)getChild:(FPath *)path {
    NSString *front = [path getFront];
    if (front == nil) {
        return self;
    } else {
        return [[self getImmediateChild:front] getChild:[path popFront]];
    }
}

- (BOOL)hasChild:(NSString *)childName {
    return ![self getImmediateChild:childName].isEmpty;
}

- (id<FNode>)updateImmediateChild:(NSString *)childName
                     withNewChild:(id<FNode>)newChildNode {
    NSAssert(newChildNode != nil, @"Should always be passing nodes.");

    if ([childName isEqualToString:@".priority"]) {
        return [self updatePriority:newChildNode];
    } else {
        FImmutableSortedDictionary *newChildren;
        if (newChildNode.isEmpty) {
            newChildren = [self.children removeObjectForKey:childName];
        } else {
            newChildren = [self.children setObject:newChildNode
                                            forKey:childName];
        }
        if (newChildren.isEmpty) {
            return [FEmptyNode emptyNode];
        } else {
            return [[FChildrenNode alloc] initWithPriority:self.getPriority
                                                  children:newChildren];
        }
    }
}

- (id<FNode>)updateChild:(FPath *)path withNewChild:(id<FNode>)newChildNode {
    NSString *front = [path getFront];
    if (front == nil) {
        return newChildNode;
    } else {
        NSAssert(![front isEqualToString:@".priority"] || path.length == 1,
                 @".priority must be the last token in a path.");
        id<FNode> newImmediateChild =
            [[self getImmediateChild:front] updateChild:[path popFront]
                                           withNewChild:newChildNode];
        return [self updateImmediateChild:front withNewChild:newImmediateChild];
    }
}

- (BOOL)isEmpty {
    return [self.children isEmpty];
}

- (int)numChildren {
    return [self.children count];
}

- (id)val {
    return [self valForExport:NO];
}

- (id)valForExport:(BOOL)exp {
    if ([self isEmpty]) {
        return [NSNull null];
    }

    __block int numKeys = 0;
    __block NSInteger maxKey = 0;
    __block BOOL allIntegerKeys = YES;

    NSMutableDictionary *obj =
        [[NSMutableDictionary alloc] initWithCapacity:[self.children count]];
    [self enumerateChildrenUsingBlock:^(NSString *key, id<FNode> childNode,
                                        BOOL *stop) {
      [obj setObject:[childNode valForExport:exp] forKey:key];

      numKeys++;

      // If we already found a string key, don't bother with any of this
      if (!allIntegerKeys) {
          return;
      }

      // Treat leading zeroes that are not exactly "0" as strings
      NSString *firstChar = [key substringWithRange:NSMakeRange(0, 1)];
      if ([firstChar isEqualToString:@"0"] && [key length] > 1) {
          allIntegerKeys = NO;
      } else {
          NSNumber *keyAsNum = [FUtilities intForString:key];
          if (keyAsNum != nil) {
              NSInteger keyAsInt = [keyAsNum integerValue];
              if (keyAsInt > maxKey) {
                  maxKey = keyAsInt;
              }
          } else {
              allIntegerKeys = NO;
          }
      }
    }];

    if (!exp && allIntegerKeys && maxKey < 2 * numKeys) {
        // convert to an array
        NSMutableArray *array =
            [[NSMutableArray alloc] initWithCapacity:maxKey + 1];
        for (int i = 0; i <= maxKey; ++i) {
            NSString *keyString = [NSString stringWithFormat:@"%i", i];
            id child = obj[keyString];
            if (child != nil) {
                [array addObject:child];
            } else {
                [array addObject:[NSNull null]];
            }
        }
        return array;
    } else {

        if (exp && [self getPriority] != nil && !self.getPriority.isEmpty) {
            obj[kPayloadPriority] = [self.getPriority val];
        }

        return obj;
    }
}

- (NSString *)dataHash {
    if (self.lazyHash == nil) {
        NSMutableString *toHash = [[NSMutableString alloc] init];

        if (!self.getPriority.isEmpty) {
            [toHash appendString:@"priority:"];
            [FSnapshotUtilities
                appendHashRepresentationForLeafNode:(FLeafNode *)
                                                        self.getPriority
                                           toString:toHash
                                        hashVersion:FDataHashVersionV1];
            [toHash appendString:@":"];
        }

        __block BOOL sawPriority = NO;
        [self enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                            BOOL *stop) {
          sawPriority = sawPriority || [[node getPriority] isEmpty];
          *stop = sawPriority;
        }];
        if (sawPriority) {
            NSMutableArray *array = [NSMutableArray array];
            [self enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                                BOOL *stop) {
              FNamedNode *namedNode = [[FNamedNode alloc] initWithName:key
                                                               andNode:node];
              [array addObject:namedNode];
            }];
            [array sortUsingComparator:^NSComparisonResult(
                       FNamedNode *namedNode1, FNamedNode *namedNode2) {
              return
                  [[FPriorityIndex priorityIndex] compareNamedNode:namedNode1
                                                       toNamedNode:namedNode2];
            }];
            [array enumerateObjectsUsingBlock:^(FNamedNode *namedNode,
                                                NSUInteger idx, BOOL *stop) {
              NSString *childHash = [namedNode.node dataHash];
              if (![childHash isEqualToString:@""]) {
                  [toHash appendFormat:@":%@:%@", namedNode.name, childHash];
              }
            }];
        } else {
            [self enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                                BOOL *stop) {
              NSString *childHash = [node dataHash];
              if (![childHash isEqualToString:@""]) {
                  [toHash appendFormat:@":%@:%@", key, childHash];
              }
            }];
        }
        self.lazyHash = [toHash isEqualToString:@""]
                            ? @""
                            : [FStringUtilities base64EncodedSha1:toHash];
    }
    return self.lazyHash;
}

- (NSComparisonResult)compare:(id<FNode>)other {
    // children nodes come last, unless this is actually an empty node, then we
    // come first.
    if (self.isEmpty) {
        if (other.isEmpty) {
            return NSOrderedSame;
        } else {
            return NSOrderedAscending;
        }
    } else if (other.isLeafNode || other.isEmpty) {
        return NSOrderedDescending;
    } else if (other == [FMaxNode maxNode]) {
        return NSOrderedAscending;
    } else {
        // Must be another node with children.
        return NSOrderedSame;
    }
}

- (BOOL)isEqual:(id<FNode>)other {
    if (other == self) {
        return YES;
    } else if (other == nil) {
        return NO;
    } else if (other.isLeafNode) {
        return NO;
    } else if (self.isEmpty && [other isEmpty]) {
        // Empty nodes do not have priority
        return YES;
    } else {
        FChildrenNode *otherChildrenNode = other;
        if (![self.getPriority isEqual:other.getPriority]) {
            return NO;
        } else if (self.children.count == otherChildrenNode.children.count) {
            __block BOOL equal = YES;
            [self enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                                BOOL *stop) {
              id<FNode> child = [otherChildrenNode getImmediateChild:key];
              if (![child isEqual:node]) {
                  equal = NO;
                  *stop = YES;
              }
            }];
            return equal;
        } else {
            return NO;
        }
    }
}

- (NSUInteger)hash {
    __block NSUInteger hashCode = 0;
    [self enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                        BOOL *stop) {
      hashCode = 31 * hashCode + key.hash;
      hashCode = 17 * hashCode + node.hash;
    }];
    return 17 * hashCode + self.priorityNode.hash;
}

- (void)enumerateChildrenAndPriorityUsingBlock:(void (^)(NSString *, id<FNode>,
                                                         BOOL *))block {
    if ([self.getPriority isEmpty]) {
        [self enumerateChildrenUsingBlock:block];
    } else {
        __block BOOL passedPriorityKey = NO;
        [self enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                            BOOL *stop) {
          if (!passedPriorityKey &&
              [FUtilities compareKey:key
                               toKey:@".priority"] == NSOrderedDescending) {
              passedPriorityKey = YES;
              BOOL stopAfterPriority = NO;
              block(@".priority", [self getPriority], &stopAfterPriority);
              if (stopAfterPriority)
                  return;
          }
          block(key, node, stop);
        }];
    }
}

- (void)enumerateChildrenUsingBlock:(void (^)(NSString *, id<FNode>,
                                              BOOL *))block {
    [self.children enumerateKeysAndObjectsUsingBlock:block];
}

- (void)enumerateChildrenReverse:(BOOL)reverse
                      usingBlock:
                          (void (^)(NSString *, id<FNode>, BOOL *))block {
    [self.children enumerateKeysAndObjectsReverse:reverse usingBlock:block];
}

- (NSEnumerator *)childEnumerator {
    return [[FTransformedEnumerator alloc]
        initWithEnumerator:self.children.keyEnumerator
              andTransform:^id(NSString *key) {
                return [FNamedNode nodeWithName:key
                                           node:[self getImmediateChild:key]];
              }];
}

- (NSString *)predecessorChildKey:(NSString *)childKey {
    return [self.children getPredecessorKey:childKey];
}

#pragma mark -
#pragma mark FChildrenNode specific methods

- (id)childrenGetter:(id)key {
    return [self.children objectForKey:key];
}

- (FNamedNode *)firstChild {
    NSString *childKey = self.children.minKey;
    if (childKey) {
        return
            [[FNamedNode alloc] initWithName:childKey
                                     andNode:[self getImmediateChild:childKey]];
    } else {
        return nil;
    }
}

- (FNamedNode *)lastChild {
    NSString *childKey = self.children.maxKey;
    if (childKey) {
        return
            [[FNamedNode alloc] initWithName:childKey
                                     andNode:[self getImmediateChild:childKey]];
    } else {
        return nil;
    }
}

@end
