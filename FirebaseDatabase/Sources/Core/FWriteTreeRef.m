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

#import "FirebaseDatabase/Sources/Core/FWriteTreeRef.h"
#import "FirebaseDatabase/Sources/Core/FWriteRecord.h"
#import "FirebaseDatabase/Sources/Core/FWriteTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Core/View/FCacheNode.h"
#import "FirebaseDatabase/Sources/FIndex.h"
#import "FirebaseDatabase/Sources/FNamedNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FChildrenNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"

@interface FWriteTreeRef ()
/**
 * The path to this particular FWriteTreeRef. Used for calling methods on
 * writeTree while exposing a simpler interface to callers.
 */
@property(nonatomic, strong) FPath *path;
/**
 * A reference to the actual tree of the write data. All methods are
 * pass-through to the tree, but with the appropriate path prefixed.
 *
 * This lets us make cheap references to points in the tree for sync points
 * without having to copy and maintain all of the data.
 */
@property(nonatomic, strong) FWriteTree *writeTree;
@end

/**
 * A FWriteTreeRef wraps a FWriteTree and a FPath, for convenient access to a
 * particular subtree. All the methods just proxy to the underlying FWriteTree.
 */
@implementation FWriteTreeRef
- (id)initWithPath:(FPath *)aPath writeTree:(FWriteTree *)tree {
    self = [super init];
    if (self) {
        self.path = aPath;
        self.writeTree = tree;
    }
    return self;
}

/**
 * @return If possible, returns a complete event cache, using the underlying
 * server data if possible. In addition, can be used to get a cache that
 * includes hidden writes, and excludes arbitrary writes. Note that customizing
 * the returned node can lead to a more expensive calculation.
 */
- (id<FNode>)calculateCompleteEventCacheWithCompleteServerCache:
    (id<FNode>)completeServerCache {
    return [self.writeTree calculateCompleteEventCacheAtPath:self.path
                                         completeServerCache:completeServerCache
                                             excludeWriteIds:nil
                                         includeHiddenWrites:NO];
}

/**
 * @return If possible, returns a children node containing all of the complete
 * children we have data for. The returned data is a mix of the given server
 * data and write data.
 */
- (FChildrenNode *)calculateCompleteEventChildrenWithCompleteServerChildren:
    (id<FNode>)completeServerChildren {
    return [self.writeTree
        calculateCompleteEventChildrenAtPath:self.path
                      completeServerChildren:completeServerChildren];
}

/**
 * Given that either the underlying server data has updated or the outstanding
 * writes have been updating, determine what, if anything, needs to be applied
 * to the event cache.
 *
 * Possibilities:
 *
 * 1. No writes are shadowing. Events should be raised, the snap to be applied
 * comes from the server data.
 *
 * 2. Some writes are completly shadowing. No events to be raised.
 *
 * 3. Is partially shadowed. Events should be raised.
 *
 * Either existingEventSnap or existingServerSnap must exist, this is validated
 * via an assert.
 */
- (id<FNode>)
    calculateEventCacheAfterServerOverwriteWithChildPath:(FPath *)childPath
                                       existingEventSnap:
                                           (id<FNode>)existingEventSnap
                                      existingServerSnap:
                                          (id<FNode>)existingServerSnap {
    return [self.writeTree
        calculateEventCacheAfterServerOverwriteAtPath:self.path
                                            childPath:childPath
                                    existingEventSnap:existingEventSnap
                                   existingServerSnap:existingServerSnap];
}

/**
 * Returns a node if there is a complete overwrite for this path. More
 * specifically, if there is a write at a higher path, this will return the
 * child of that write relative to the write and this path. Returns nil if there
 * is no write at this path.
 */
- (id<FNode>)shadowingWriteAtPath:(FPath *)path {
    return [self.writeTree shadowingWriteAtPath:[self.path child:path]];
}

/**
 * This method is used when processing child remove events on a query. If we
 * can, we pull in children that are outside the window, but may now be in the
 * window.
 */
- (FNamedNode *)calculateNextNodeAfterPost:(FNamedNode *)post
                        completeServerData:(id<FNode>)completeServerData
                                   reverse:(BOOL)reverse
                                     index:(id<FIndex>)index {
    return [self.writeTree calculateNextNodeAfterPost:post
                                               atPath:self.path
                                   completeServerData:completeServerData
                                              reverse:reverse
                                                index:index];
}

/**
 * Returns a complete child for a given server snap after applying all user
 * writes or nil if there is no complete child for this child key.
 */
- (id<FNode>)calculateCompleteChild:(NSString *)childKey
                              cache:(FCacheNode *)existingServerCache {
    return [self.writeTree calculateCompleteChildAtPath:self.path
                                               childKey:childKey
                                                  cache:existingServerCache];
}

/**
 * @return a WriteTreeref for a child.
 */
- (FWriteTreeRef *)childWriteTreeRef:(NSString *)childKey {
    return
        [[FWriteTreeRef alloc] initWithPath:[self.path childFromString:childKey]
                                  writeTree:self.writeTree];
}

@end
