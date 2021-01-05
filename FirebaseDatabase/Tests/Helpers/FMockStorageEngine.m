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

#import "FirebaseDatabase/Tests/Helpers/FMockStorageEngine.h"

#import "FirebaseDatabase/Sources/Core/FWriteRecord.h"
#import "FirebaseDatabase/Sources/Persistence/FPruneForest.h"
#import "FirebaseDatabase/Sources/Persistence/FTrackedQuery.h"
#import "FirebaseDatabase/Sources/Snapshot/FCompoundWrite.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"

@interface FMockStorageEngine ()

@property(nonatomic) BOOL closed;
@property(nonatomic, strong) NSMutableDictionary *userWritesDict;
@property(nonatomic, strong) FCompoundWrite *serverCache;
@property(nonatomic, strong) NSMutableDictionary *trackedQueries;
@property(nonatomic, strong) NSMutableDictionary *trackedQueryKeys;

@end

@implementation FMockStorageEngine

- (id)init {
  self = [super init];
  if (self != nil) {
    self->_userWritesDict = [NSMutableDictionary dictionary];
    self->_serverCache = [FCompoundWrite emptyWrite];
    self->_trackedQueries = [NSMutableDictionary dictionary];
    self->_trackedQueryKeys = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)close {
  self.closed = YES;
}

- (void)saveUserOverwrite:(id<FNode>)node atPath:(FPath *)path writeId:(NSUInteger)writeId {
  FWriteRecord *writeRecord = [[FWriteRecord alloc] initWithPath:path
                                                       overwrite:node
                                                         writeId:writeId
                                                         visible:YES];
  self.userWritesDict[@(writeId)] = writeRecord;
}

- (void)saveUserMerge:(FCompoundWrite *)merge atPath:(FPath *)path writeId:(NSUInteger)writeId {
  FWriteRecord *writeRecord = [[FWriteRecord alloc] initWithPath:path merge:merge writeId:writeId];
  self.userWritesDict[@(writeId)] = writeRecord;
}

- (void)removeUserWrite:(NSUInteger)writeId {
  [self.userWritesDict removeObjectForKey:@(writeId)];
}

- (void)removeAllUserWrites {
  [self.userWritesDict removeAllObjects];
}

- (NSArray *)userWrites {
  return [[self.userWritesDict allValues]
      sortedArrayUsingComparator:^NSComparisonResult(FWriteRecord *obj1, FWriteRecord *obj2) {
        if (obj1.writeId < obj2.writeId) {
          return NSOrderedAscending;
        } else if (obj1.writeId > obj2.writeId) {
          return NSOrderedDescending;
        } else {
          return NSOrderedSame;
        }
      }];
}

- (id<FNode>)serverCacheAtPath:(FPath *)path {
  return [[self.serverCache childCompoundWriteAtPath:path] applyToNode:[FEmptyNode emptyNode]];
}

- (id<FNode>)serverCacheForKeys:(NSSet *)keys atPath:(FPath *)path {
  __block id<FNode> children = [FEmptyNode emptyNode];
  id<FNode> fullNode =
      [[self.serverCache childCompoundWriteAtPath:path] applyToNode:[FEmptyNode emptyNode]];
  [keys enumerateObjectsUsingBlock:^(NSString *key, BOOL *stop) {
    children = [children updateImmediateChild:key withNewChild:[fullNode getImmediateChild:key]];
  }];
  return children;
}

- (void)updateServerCache:(id<FNode>)node atPath:(FPath *)path merge:(BOOL)merge {
  if (merge) {
    [node enumerateChildrenUsingBlock:^(NSString *key, id<FNode> childNode, BOOL *stop) {
      self.serverCache = [self.serverCache addWrite:childNode atPath:[path childFromString:key]];
    }];
  } else {
    self.serverCache = [self.serverCache addWrite:node atPath:path];
  }
}

- (void)updateServerCacheWithMerge:(FCompoundWrite *)merge atPath:(FPath *)path {
  self.serverCache = [self.serverCache addCompoundWrite:merge atPath:path];
}

- (NSUInteger)serverCacheEstimatedSizeInBytes {
  id data = [[self.serverCache applyToNode:[FEmptyNode emptyNode]] valForExport:YES];
  return [NSJSONSerialization dataWithJSONObject:data options:0 error:nil].length;
}

- (void)pruneCache:(FPruneForest *)pruneForest atPath:(FPath *)prunePath {
  [self.serverCache enumerateWrites:^(FPath *absolutePath, id<FNode> node, BOOL *stop) {
    NSAssert([prunePath isEqual:absolutePath] || ![absolutePath contains:prunePath],
             @"Pruning at %@ but we found data higher up!", prunePath);
    if ([prunePath contains:absolutePath]) {
      FPath *relativePath = [FPath relativePathFrom:prunePath to:absolutePath];
      if ([pruneForest shouldPruneUnkeptDescendantsAtPath:relativePath]) {
        __block FCompoundWrite *newCache = [FCompoundWrite emptyWrite];
        [[pruneForest childAtPath:relativePath] enumarateKeptNodesUsingBlock:^(FPath *keepPath) {
          newCache = [newCache addWrite:[node getChild:keepPath] atPath:keepPath];
        }];
        self.serverCache =
            [[self.serverCache removeWriteAtPath:absolutePath] addCompoundWrite:newCache
                                                                         atPath:absolutePath];
      } else {
        // NOTE: This is technically a valid scenario (e.g. you ask to prune at / but only want to
        // prune 'foo' and 'bar' and ignore everything else).  But currently our pruning will
        // explicitly prune or keep everything we know about, so if we hit this it means our tracked
        // queries and the server cache are out of sync.
        NSAssert([pruneForest shouldKeepPath:relativePath],
                 @"We have data at %@ that is neither pruned nor kept.", relativePath);
      }
    }
  }];
}

- (NSArray *)loadTrackedQueries {
  return self.trackedQueries.allValues;
}

- (void)removeTrackedQuery:(NSUInteger)queryId {
  [self.trackedQueries removeObjectForKey:@(queryId)];
  [self.trackedQueryKeys removeObjectForKey:@(queryId)];
}

- (void)saveTrackedQuery:(FTrackedQuery *)query {
  self.trackedQueries[@(query.queryId)] = query;
}

- (void)setTrackedQueryKeys:(NSSet *)keys forQueryId:(NSUInteger)queryId {
  self.trackedQueryKeys[@(queryId)] = keys;
}

- (void)updateTrackedQueryKeysWithAddedKeys:(NSSet *)added
                                removedKeys:(NSSet *)removed
                                 forQueryId:(NSUInteger)queryId {
  NSSet *oldKeys = [self trackedQueryKeysForQuery:queryId];
  NSMutableSet *newKeys = [NSMutableSet setWithSet:oldKeys];
  [newKeys minusSet:removed];
  [newKeys unionSet:added];
  self.trackedQueryKeys[@(queryId)] = newKeys;
}

- (NSSet *)trackedQueryKeysForQuery:(NSUInteger)queryId {
  NSSet *keys = self.trackedQueryKeys[@(queryId)];
  return keys != nil ? keys : [NSSet set];
}

@end
