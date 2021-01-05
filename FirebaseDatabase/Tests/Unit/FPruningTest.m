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

#import "FirebaseDatabase/Sources/Persistence/FLevelDBStorageEngine.h"
#import "FirebaseDatabase/Sources/Persistence/FPruneForest.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Tests/Helpers/FMockStorageEngine.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FPruningTest : XCTestCase

@end

static id<FNode> ABC_NODE = nil;
static id<FNode> DEF_NODE = nil;
static id<FNode> A_NODE = nil;
static id<FNode> D_NODE = nil;
static id<FNode> BC_NODE = nil;
static id<FNode> LARGE_NODE = nil;

@implementation FPruningTest

+ (void)initStatics {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ABC_NODE = NODE((@{@"a" : @{@"aa" : @1.1, @"ab" : @1.2}, @"b" : @2, @"c" : @3}));
    DEF_NODE = NODE((@{@"d" : @4, @"e" : @5, @"f" : @6}));
    A_NODE = NODE((@{@"a" : @{@"aa" : @1.1, @"ab" : @1.2}}));
    D_NODE = NODE(@{@"d" : @4});
    LARGE_NODE = [FTestHelpers leafNodeOfSize:5 * 1024 * 1024];
    BC_NODE = [ABC_NODE updateImmediateChild:@"a" withNewChild:[FEmptyNode emptyNode]];
  });
}

- (void)runWithDb:(void (^)(id<FStorageEngine> engine))block {
  [FPruningTest initStatics];
  {
    // Run with level DB implementation
    FLevelDBStorageEngine *engine = [[FLevelDBStorageEngine alloc]
        initWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"purge-tests"]];
    block(engine);
    [engine purgeEverything];
    [engine close];
  }
  {
    // Run with mock implementation
    FMockStorageEngine *engine = [[FMockStorageEngine alloc] init];
    block(engine);
    [engine close];
  }
}

- (FPruneForest *)prune:(NSString *)pathStr {
  return [[FPruneForest empty] prunePath:PATH(pathStr)];
}

- (FPruneForest *)prune:(NSString *)path exceptRelative:(NSArray *)except {
  __block FPruneForest *pruneForest = [FPruneForest empty];
  pruneForest = [pruneForest prunePath:PATH(path)];
  [except enumerateObjectsUsingBlock:^(NSString *keepPath, NSUInteger idx, BOOL *stop) {
    pruneForest = [pruneForest keepPath:[PATH(path) childFromString:keepPath]];
  }];
  return pruneForest;
}

// Write document at root, prune it.
- (void)test010 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"") merge:NO];
    [engine pruneCache:[self prune:@""] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"")], [FEmptyNode emptyNode]);
  }];
}

// Write document at /x, prune it via PruneForest for /x, at root.
- (void)test020 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine pruneCache:[self prune:@"x"] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"")], [FEmptyNode emptyNode]);
  }];
}

// Write document at /x, prune it via PruneForest for root, at /x.
- (void)test030 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine pruneCache:[self prune:@""] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")], [FEmptyNode emptyNode]);
  }];
}

// Write document at /x, prune it via PruneForest for root, at root
- (void)test040 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine pruneCache:[self prune:@""] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")], [FEmptyNode emptyNode]);
  }];
}

// Write document at /x/y, prune it via PruneForest for /y, at /x
- (void)test050 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x/y") merge:NO];
    [engine pruneCache:[self prune:@"y"] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x/y")], [FEmptyNode emptyNode]);
  }];
}

// Write abc at /x/y, prune /x/y except b,c via PruneForest for /x/y -b,c, at root
- (void)test060 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x/y") merge:NO];
    [engine pruneCache:[self prune:@"x/y" exceptRelative:@[ @"b", @"c" ]] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x/y")], BC_NODE);
  }];
}

// Write abc at /x/y, prune /x/y except b,c via PruneForest for /y -b,c, at /x
- (void)test070 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x/y") merge:NO];
    [engine pruneCache:[self prune:@"y" exceptRelative:@[ @"b", @"c" ]] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x/y")], BC_NODE);
  }];
}

// Write abc at /x/y, prune /x/y except not-there via PruneForest for /x/y -d, at root
- (void)test080 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x/y") merge:NO];
    [engine pruneCache:[self prune:@"x/y" exceptRelative:@[ @"not-there" ]] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x/y")], [FEmptyNode emptyNode]);
  }];
}

// Write abc at / and def at /a, prune all via PruneForest for / at root
- (void)test090 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"a") merge:NO];
    [engine pruneCache:[self prune:@""] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"")], [FEmptyNode emptyNode]);
  }];
}

// Write abc at / and def at /a, prune all except b,c via PruneForest for root -b,c, at root
- (void)test100 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"a") merge:NO];
    [engine pruneCache:[self prune:@"" exceptRelative:@[ @"b", @"c" ]] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"")], BC_NODE);
  }];
}

// Write abc at /x and def at /x/a, prune /x except b,c via PruneForest for /x -b,c, at root
- (void)test110 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a") merge:NO];
    [engine pruneCache:[self prune:@"x" exceptRelative:@[ @"b", @"c" ]] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")], BC_NODE);
  }];
}

// Write abc at /x and def at /x/a, prune /x except b,c via PruneForest for root -b,c, at /x
- (void)test120 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a") merge:NO];
    [engine pruneCache:[self prune:@"" exceptRelative:@[ @"b", @"c" ]] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")], BC_NODE);
  }];
}

// Write abc at /x and def at /x/a, prune /x except a via PruneForest for /x -a, at root
- (void)test130 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a") merge:NO];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [ABC_NODE updateImmediateChild:@"a" withNewChild:DEF_NODE]);
    [engine pruneCache:[self prune:@"x" exceptRelative:@[ @"a" ]] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [[FEmptyNode emptyNode] updateImmediateChild:@"a" withNewChild:DEF_NODE]);
  }];
}

// Write abc at /x and def at /x/a, prune /x except a via PruneForest for root -a, at /x
- (void)test140 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a") merge:NO];
    [engine pruneCache:[self prune:@"" exceptRelative:@[ @"a" ]] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [[FEmptyNode emptyNode] updateImmediateChild:@"a" withNewChild:DEF_NODE]);
  }];
}

// Write abc at /x and def at /x/a, prune /x except a/d via PruneForest for /x -a/d, at root
- (void)test150 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a") merge:NO];
    [engine pruneCache:[self prune:@"x" exceptRelative:@[ @"a/d" ]] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [[FEmptyNode emptyNode] updateImmediateChild:@"a" withNewChild:D_NODE]);
  }];
}

// Write abc at /x and def at /x/a, prune /x except a/d via PruneForest for / -a/d, at /x
- (void)test160 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a") merge:NO];
    [engine pruneCache:[self prune:@"" exceptRelative:@[ @"a/d" ]] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [[FEmptyNode emptyNode] updateImmediateChild:@"a" withNewChild:D_NODE]);
  }];
}

// Write abc at /x and def at /x/a/aa, prune /x except a via PruneForest for /x -a, at root
- (void)test170 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a/aa") merge:NO];
    [engine pruneCache:[self prune:@"x" exceptRelative:@[ @"a" ]] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")], [A_NODE updateChild:PATH(@"a/aa")
                                                                        withNewChild:DEF_NODE]);
  }];
}

// Write abc at /x and def at /x/a/aa, prune /x except a via PruneForest for / -a, at /x
- (void)test180 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a/aa") merge:NO];
    [engine pruneCache:[self prune:@"" exceptRelative:@[ @"a/aa" ]] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [[FEmptyNode emptyNode] updateChild:PATH(@"a/aa") withNewChild:DEF_NODE]);
  }];
}

// Write abc at /x and def at /x/a/aa, prune /x except a/aa via PruneForest for /x -a/aa, at root
- (void)test190 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a/aa") merge:NO];
    [engine pruneCache:[self prune:@"x" exceptRelative:@[ @"a/aa" ]] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [[FEmptyNode emptyNode] updateChild:PATH(@"a/aa") withNewChild:DEF_NODE]);
  }];
}

// Write abc at /x and def at /x/a/aa, prune /x except a/aa via PruneForest for / -a/aa, at /x
- (void)test200 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:DEF_NODE atPath:PATH(@"x/a/aa") merge:NO];
    [engine pruneCache:[self prune:@"" exceptRelative:@[ @"a/aa" ]] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [[FEmptyNode emptyNode] updateChild:PATH(@"a/aa") withNewChild:DEF_NODE]);
  }];
}

// Write large node at /x, prune x via PruneForest for x at root
- (void)test210 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:LARGE_NODE atPath:PATH(@"x") merge:NO];
    [engine pruneCache:[self prune:@"x"] atPath:PATH(@"")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")], [FEmptyNode emptyNode]);
  }];
}

// Write abc at x and large node at /x/a, prune x except a via PruneForest for / -a, at x
- (void)test220 {
  [self runWithDb:^(id<FStorageEngine> engine) {
    [engine updateServerCache:ABC_NODE atPath:PATH(@"x") merge:NO];
    [engine updateServerCache:LARGE_NODE atPath:PATH(@"x/a") merge:NO];
    [engine pruneCache:[self prune:@"" exceptRelative:@[ @"a" ]] atPath:PATH(@"x")];
    XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"x")],
                          [[FEmptyNode emptyNode] updateImmediateChild:@"a"
                                                          withNewChild:LARGE_NODE]);
  }];
}

@end
