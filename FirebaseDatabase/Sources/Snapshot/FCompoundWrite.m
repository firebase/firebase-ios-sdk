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

#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FImmutableTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/FNamedNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"

@interface FCompoundWrite ()
@property(nonatomic, strong) FImmutableTree *writeTree;
@end

@implementation FCompoundWrite

- (id)initWithWriteTree:(FImmutableTree *)tree {
    self = [super init];
    if (self) {
        self.writeTree = tree;
    }
    return self;
}

+ (FCompoundWrite *)compoundWriteWithValueDictionary:
    (NSDictionary *)dictionary {
    __block FImmutableTree *writeTree = [FImmutableTree empty];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *pathString,
                                                    id value, BOOL *stop) {
      id<FNode> node = [FSnapshotUtilities nodeFrom:value];
      FImmutableTree *tree = [[FImmutableTree alloc] initWithValue:node];
      writeTree = [writeTree setTree:tree
                              atPath:[[FPath alloc] initWith:pathString]];
    }];
    return [[FCompoundWrite alloc] initWithWriteTree:writeTree];
}

+ (FCompoundWrite *)compoundWriteWithNodeDictionary:(NSDictionary *)dictionary {
    __block FImmutableTree *writeTree = [FImmutableTree empty];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *pathString,
                                                    id node, BOOL *stop) {
      FImmutableTree *tree = [[FImmutableTree alloc] initWithValue:node];
      writeTree = [writeTree setTree:tree
                              atPath:[[FPath alloc] initWith:pathString]];
    }];
    return [[FCompoundWrite alloc] initWithWriteTree:writeTree];
}

+ (FCompoundWrite *)emptyWrite {
    static dispatch_once_t pred = 0;
    static FCompoundWrite *empty = nil;
    dispatch_once(&pred, ^{
      empty = [[FCompoundWrite alloc]
          initWithWriteTree:[[FImmutableTree alloc] initWithValue:nil]];
    });
    return empty;
}

- (FCompoundWrite *)addWrite:(id<FNode>)node atPath:(FPath *)path {
    if (path.isEmpty) {
        return [[FCompoundWrite alloc]
            initWithWriteTree:[[FImmutableTree alloc] initWithValue:node]];
    } else {
        FTuplePathValue *rootMost =
            [self.writeTree findRootMostValueAndPath:path];
        if (rootMost != nil) {
            FPath *relativePath = [FPath relativePathFrom:rootMost.path
                                                       to:path];
            id<FNode> value = [rootMost.value updateChild:relativePath
                                             withNewChild:node];
            return [[FCompoundWrite alloc]
                initWithWriteTree:[self.writeTree setValue:value
                                                    atPath:rootMost.path]];
        } else {
            FImmutableTree *subtree =
                [[FImmutableTree alloc] initWithValue:node];
            FImmutableTree *newWriteTree = [self.writeTree setTree:subtree
                                                            atPath:path];
            return [[FCompoundWrite alloc] initWithWriteTree:newWriteTree];
        }
    }
}

- (FCompoundWrite *)addWrite:(id<FNode>)node atKey:(NSString *)key {
    return [self addWrite:node atPath:[[FPath alloc] initWith:key]];
}

- (FCompoundWrite *)addCompoundWrite:(FCompoundWrite *)compoundWrite
                              atPath:(FPath *)path {
    __block FCompoundWrite *newWrite = self;
    [compoundWrite.writeTree forEach:^(FPath *childPath, id<FNode> value) {
      newWrite = [newWrite addWrite:value atPath:[path child:childPath]];
    }];
    return newWrite;
}

/**
 * Will remove a write at the given path and deeper paths. This will
 * <em>not</em> modify a write at a higher location, which must be removed by
 * calling this method with that path.
 * @param path The path at which a write and all deeper writes should be
 * removed.
 * @return The new FWriteCompound with the removed path.
 */
- (FCompoundWrite *)removeWriteAtPath:(FPath *)path {
    if (path.isEmpty) {
        return [FCompoundWrite emptyWrite];
    } else {
        FImmutableTree *newWriteTree =
            [self.writeTree setTree:[FImmutableTree empty] atPath:path];
        return [[FCompoundWrite alloc] initWithWriteTree:newWriteTree];
    }
}

/**
 * Returns whether this FCompoundWrite will fully overwrite a node at a given
 * location and can therefore be considered "complete".
 * @param path The path to check for
 * @return Whether there is a complete write at that path.
 */
- (BOOL)hasCompleteWriteAtPath:(FPath *)path {
    return [self completeNodeAtPath:path] != nil;
}

/**
 * Returns a node for a path if and only if the node is a "complete" overwrite
 * at that path. This will not aggregate writes from depeer paths, but will
 * return child nodes from a more shallow path.
 * @param path The path to get a complete write
 * @return The node if complete at that path, or nil otherwise.
 */
- (id<FNode>)completeNodeAtPath:(FPath *)path {
    FTuplePathValue *rootMost = [self.writeTree findRootMostValueAndPath:path];
    if (rootMost != nil) {
        FPath *relativePath = [FPath relativePathFrom:rootMost.path to:path];
        return [rootMost.value getChild:relativePath];
    } else {
        return nil;
    }
}

// TODO: change into traversal method...
- (NSArray *)completeChildren {
    NSMutableArray *children = [[NSMutableArray alloc] init];
    if (self.writeTree.value != nil) {
        id<FNode> node = self.writeTree.value;
        [node enumerateChildrenUsingBlock:^(NSString *key, id<FNode> node,
                                            BOOL *stop) {
          [children addObject:[[FNamedNode alloc] initWithName:key
                                                       andNode:node]];
        }];
    } else {
        [self.writeTree.children
            enumerateKeysAndObjectsUsingBlock:^(
                NSString *childKey, FImmutableTree *childTree, BOOL *stop) {
              if (childTree.value != nil) {
                  [children addObject:[[FNamedNode alloc]
                                          initWithName:childKey
                                               andNode:childTree.value]];
              }
            }];
    }
    return children;
}

// TODO: change into enumerate method
- (NSDictionary *)childCompoundWrites {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [self.writeTree.children
        enumerateKeysAndObjectsUsingBlock:^(
            NSString *key, FImmutableTree *childWrite, BOOL *stop) {
          dict[key] = [[FCompoundWrite alloc] initWithWriteTree:childWrite];
        }];
    return dict;
}

- (FCompoundWrite *)childCompoundWriteAtPath:(FPath *)path {
    if (path.isEmpty) {
        return self;
    } else {
        id<FNode> shadowingNode = [self completeNodeAtPath:path];
        if (shadowingNode != nil) {
            return [[FCompoundWrite alloc]
                initWithWriteTree:[[FImmutableTree alloc]
                                      initWithValue:shadowingNode]];
        } else {
            return [[FCompoundWrite alloc]
                initWithWriteTree:[self.writeTree subtreeAtPath:path]];
        }
    }
}

- (id<FNode>)applySubtreeWrite:(FImmutableTree *)subtreeWrite
                        atPath:(FPath *)relativePath
                        toNode:(id<FNode>)node {
    if (subtreeWrite.value != nil) {
        // Since a write there is always a leaf, we're done here.
        return [node updateChild:relativePath withNewChild:subtreeWrite.value];
    } else {
        __block id<FNode> priorityWrite = nil;
        __block id<FNode> blockNode = node;
        [subtreeWrite.children
            enumerateKeysAndObjectsUsingBlock:^(
                NSString *childKey, FImmutableTree *childTree, BOOL *stop) {
              if ([childKey isEqualToString:@".priority"]) {
                  // Apply priorities at the end so we don't update priorities
                  // for either empty nodes or forget to apply priorities to
                  // empty nodes that are later filled.
                  NSAssert(childTree.value != nil,
                           @"Priority writes must always be leaf nodes");
                  priorityWrite = childTree.value;
              } else {
                  blockNode = [self
                      applySubtreeWrite:childTree
                                 atPath:[relativePath childFromString:childKey]
                                 toNode:blockNode];
              }
            }];
        // If there was a priority write, we only apply it if the node is not
        // empty
        if (![blockNode getChild:relativePath].isEmpty &&
            priorityWrite != nil) {
            blockNode = [blockNode
                 updateChild:[relativePath childFromString:@".priority"]
                withNewChild:priorityWrite];
        }
        return blockNode;
    }
}

- (void)enumerateWrites:(void (^)(FPath *, id<FNode>, BOOL *))block {
    __block BOOL stop = NO;
    // TODO: add stop to tree iterator...
    [self.writeTree forEach:^(FPath *path, id value) {
      if (!stop) {
          block(path, value, &stop);
      }
    }];
}

/**
 * Applies this FCompoundWrite to a node. The node is returned with all writes
 * from this FCompoundWrite applied to the node.
 * @param node The node to apply this FCompoundWrite to
 * @return The node with all writes applied
 */
- (id<FNode>)applyToNode:(id<FNode>)node {
    return [self applySubtreeWrite:self.writeTree
                            atPath:[FPath empty]
                            toNode:node];
}

/**
 * Return true if this CompoundWrite is empty and therefore does not modify any
 * nodes.
 * @return Whether this CompoundWrite is empty
 */
- (BOOL)isEmpty {
    return self.writeTree.isEmpty;
}

- (id<FNode>)rootWrite {
    return self.writeTree.value;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[FCompoundWrite class]]) {
        return NO;
    }
    FCompoundWrite *other = (FCompoundWrite *)object;
    return
        [[self valForExport:YES] isEqualToDictionary:[other valForExport:YES]];
}

- (NSUInteger)hash {
    return [[self valForExport:YES] hash];
}

- (NSDictionary *)valForExport:(BOOL)exportFormat {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [self.writeTree forEach:^(FPath *path, id<FNode> value) {
      dictionary[path.wireFormat] = [value valForExport:exportFormat];
    }];
    return dictionary;
}

- (NSString *)description {
    return [[self valForExport:YES] description];
}

@end
