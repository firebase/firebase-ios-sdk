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

#import <XCTest/XCTest.h>
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/FPathIndex.h"
#import "FirebaseDatabase/Sources/Persistence/FPersistenceManager.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FIndexedNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Tests/Helpers/FMockStorageEngine.h"
#import "FirebaseDatabase/Tests/Helpers/FTestCachePolicy.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FPersistenceManagerTest : XCTestCase

@end

@implementation FPersistenceManagerTest

- (FPersistenceManager *)newTestPersistenceManager {
  FMockStorageEngine *engine = [[FMockStorageEngine alloc] init];
  FPersistenceManager *manager =
      [[FPersistenceManager alloc] initWithStorageEngine:engine
                                             cachePolicy:[FNoCachePolicy noCachePolicy]];
  return manager;
}

- (void)testServerCacheFiltersResults1 {
  FPersistenceManager *manager = [self newTestPersistenceManager];

  [manager updateServerCacheWithNode:NODE(@"1")
                            forQuery:[FQuerySpec defaultQueryAtPath:PATH(@"foo/bar")]];
  [manager updateServerCacheWithNode:NODE(@"2")
                            forQuery:[FQuerySpec defaultQueryAtPath:PATH(@"foo/baz")]];
  [manager updateServerCacheWithNode:NODE(@"3")
                            forQuery:[FQuerySpec defaultQueryAtPath:PATH(@"foo/quu/1")]];
  [manager updateServerCacheWithNode:NODE(@"4")
                            forQuery:[FQuerySpec defaultQueryAtPath:PATH(@"foo/quu/2")]];

  FCacheNode *cache = [manager serverCacheForQuery:[FQuerySpec defaultQueryAtPath:PATH(@"foo")]];
  XCTAssertFalse(cache.isFullyInitialized);
  XCTAssertEqualObjects(cache.node, [FEmptyNode emptyNode]);
}

- (void)testServerCacheFiltersResults2 {
  FPersistenceManager *manager = [self newTestPersistenceManager];

  FQuerySpec *limit2FooQuery =
      [[FQuerySpec alloc] initWithPath:PATH(@"foo")
                                params:[[FQueryParams defaultInstance] limitToFirst:2]];
  FQuerySpec *limit3FooQuery =
      [[FQuerySpec alloc] initWithPath:PATH(@"foo")
                                params:[[FQueryParams defaultInstance] limitToFirst:3]];

  [manager setQueryActive:limit2FooQuery];
  [manager updateServerCacheWithNode:NODE((@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}))
                            forQuery:limit2FooQuery];
  [manager setTrackedQueryKeys:[NSSet setWithArray:@[ @"a", @"b" ]] forQuery:limit2FooQuery];

  FCacheNode *cache = [manager serverCacheForQuery:limit3FooQuery];
  XCTAssertFalse(cache.isFullyInitialized);
  XCTAssertEqualObjects(cache.node, NODE((@{@"a" : @1, @"b" : @2})));
}

- (void)testNoLimitNonDefaultQueryIsTreatedAsDefaultQuery {
  FPersistenceManager *manager = [self newTestPersistenceManager];

  FQuerySpec *defaultQuery = [FQuerySpec defaultQueryAtPath:PATH(@"foo")];
  id<FIndex> index = [[FPathIndex alloc] initWithPath:PATH(@"index-key")];
  FQuerySpec *orderByQuery =
      [[FQuerySpec alloc] initWithPath:PATH(@"foo")
                                params:[[FQueryParams defaultInstance] orderBy:index]];
  [manager setQueryActive:defaultQuery];
  [manager updateServerCacheWithNode:NODE((@{@"foo" : @1, @"bar" : @2})) forQuery:defaultQuery];
  [manager setQueryComplete:defaultQuery];

  FCacheNode *node = [manager serverCacheForQuery:orderByQuery];

  XCTAssertEqualObjects(node.node, NODE((@{@"foo" : @1, @"bar" : @2})));
  XCTAssertTrue(node.isFullyInitialized);
  XCTAssertFalse(node.isFiltered);
  XCTAssertTrue([node.indexedNode hasIndex:orderByQuery.index]);
}

- (void)testApplyUserMergeUsesRelativePath {
  FMockStorageEngine *engine = [[FMockStorageEngine alloc] init];

  id<FNode> initialData = NODE((@{@"foo" : @{@"bar" : @"bar-value", @"baz" : @"baz-value"}}));
  [engine updateServerCache:initialData atPath:PATH(@"") merge:NO];

  FPersistenceManager *manager =
      [[FPersistenceManager alloc] initWithStorageEngine:engine
                                             cachePolicy:[FNoCachePolicy noCachePolicy]];

  FCompoundWrite *update =
      [FCompoundWrite compoundWriteWithValueDictionary:@{@"baz" : @"new-baz", @"qux" : @"qux"}];
  [manager applyUserMerge:update toServerCacheAtPath:PATH(@"foo")];

  id<FNode> expected =
      NODE((@{@"foo" : @{@"bar" : @"bar-value", @"baz" : @"new-baz", @"qux" : @"qux"}}));
  id<FNode> actual = [engine serverCacheAtPath:PATH(@"")];
  XCTAssertEqualObjects(actual, expected);
}

@end
