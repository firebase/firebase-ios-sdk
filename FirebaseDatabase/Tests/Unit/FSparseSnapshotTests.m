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

#import "FirebaseDatabase/Tests/Unit/FSparseSnapshotTests.h"
#import "FirebaseDatabase/Sources/Core/FSparseSnapshotTree.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"

@implementation FSparseSnapshotTests

- (void)testBasicRememberAndFind {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  FPath* path = [[FPath alloc] initWith:@"a/b"];
  id<FNode> node = [FSnapshotUtilities nodeFrom:@"sdfsd"];

  [st rememberData:node onPath:path];
  id<FNode> found = [st findPath:path];
  XCTAssertFalse([found isEmpty], @"Should find node");
  found = [st findPath:path.parent];
  XCTAssertTrue(found == nil, @"Should not find a node");
}

- (void)testFindInsideAnExistingSnapshot {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  FPath* path = [[FPath alloc] initWith:@"t/tt"];
  id<FNode> node = [FSnapshotUtilities nodeFrom:@{@"a" : @"sdfsd", @"x" : @5, @"999i" : @YES}];
  id<FNode> update = [FSnapshotUtilities nodeFrom:@{@"goats" : @88}];
  node = [node updateImmediateChild:@"apples" withNewChild:update];
  [st rememberData:node onPath:path];

  id<FNode> found = [st findPath:path];
  XCTAssertFalse([found isEmpty], @"Should find the node we set");
  found = [st findPath:[path childFromString:@"a"]];
  XCTAssertTrue([[found val] isEqualToString:@"sdfsd"], @"Find works inside data snapshot");
  found = [st findPath:[path childFromString:@"999i"]];
  XCTAssertTrue([[found val] isEqualToNumber:@YES], @"Find works inside data snapshot");
  found = [st findPath:[path childFromString:@"apples"]];
  XCTAssertFalse([found isEmpty], @"Should find the node we set");
  found = [st findPath:[path childFromString:@"apples/goats"]];
  XCTAssertTrue([[found val] isEqualToNumber:@88], @"Find works inside data snapshot");
}

- (void)testWriteASnapshotInsideASnapshot {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  [st rememberData:[FSnapshotUtilities nodeFrom:@{@"a" : @{@"b" : @"v"}}]
            onPath:[[FPath alloc] initWith:@"t"]];
  [st rememberData:[FSnapshotUtilities nodeFrom:@19] onPath:[[FPath alloc] initWith:@"t/a/rr"]];
  id<FNode> found = [st findPath:[[FPath alloc] initWith:@"t/a/b"]];
  XCTAssertTrue([[found val] isEqualToString:@"v"], @"Find inside snap");
  found = [st findPath:[[FPath alloc] initWith:@"t/a/rr"]];
  XCTAssertTrue([[found val] isEqualToNumber:@19], @"Find inside snap");
}

- (void)testWriteANullValueAndConfirmItIsRemembered {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  [st rememberData:[FSnapshotUtilities nodeFrom:[NSNull null]]
            onPath:[[FPath alloc] initWith:@"awq/fff"]];
  id<FNode> found = [st findPath:[[FPath alloc] initWith:@"awq/fff"]];
  XCTAssertTrue([found isEmpty], @"Empty node");
  found = [st findPath:[[FPath alloc] initWith:@"awq/sdf"]];
  XCTAssertTrue(found == nil, @"No node here");
  found = [st findPath:[[FPath alloc] initWith:@"awq/fff/jjj"]];
  XCTAssertTrue([found isEmpty], @"Empty node");
  found = [st findPath:[[FPath alloc] initWith:@"awq/sdf/sdj/q"]];
  XCTAssertTrue(found == nil, @"No node here");
}

- (void)testOverwriteWithNullAndConfirmItIsRemembered {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  [st rememberData:[FSnapshotUtilities nodeFrom:@{@"a" : @{@"b" : @"v"}}]
            onPath:[[FPath alloc] initWith:@"t"]];
  id<FNode> found = [st findPath:[[FPath alloc] initWith:@"t"]];
  XCTAssertFalse([found isEmpty], @"non-empty node");
  [st rememberData:[FSnapshotUtilities nodeFrom:[NSNull null]]
            onPath:[[FPath alloc] initWith:@"t"]];
  found = [st findPath:[[FPath alloc] initWith:@"t"]];
  XCTAssertTrue([found isEmpty], @"Empty node");
}

- (void)testSimpleRememberAndForget {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  [st rememberData:[FSnapshotUtilities nodeFrom:@{@"a" : @{@"b" : @"v"}}]
            onPath:[[FPath alloc] initWith:@"t"]];
  id<FNode> found = [st findPath:[[FPath alloc] initWith:@"t"]];
  XCTAssertFalse([found isEmpty], @"non-empty node");
  [st forgetPath:[[FPath alloc] initWith:@"t"]];
  found = [st findPath:[[FPath alloc] initWith:@"t"]];
  XCTAssertTrue(found == nil, @"node is gone");
}

- (void)testForgetTheRoot {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  [st rememberData:[FSnapshotUtilities nodeFrom:@{@"a" : @{@"b" : @"v"}}]
            onPath:[[FPath alloc] initWith:@"t"]];
  id<FNode> found = [st findPath:[[FPath alloc] initWith:@"t"]];
  XCTAssertFalse([found isEmpty], @"non-empty node");
  found = [st findPath:[[FPath alloc] initWith:@""]];
  XCTAssertTrue(found == nil, @"node is gone");
}

- (void)testForgetSnapshotInsideSnapshot {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  [st rememberData:[FSnapshotUtilities nodeFrom:@{@"a" : @{@"b" : @"v", @"c" : @9, @"art" : @NO}}]
            onPath:[[FPath alloc] initWith:@"t"]];
  id<FNode> found = [st findPath:[[FPath alloc] initWith:@"t/a/c"]];
  XCTAssertFalse([found isEmpty], @"non-empty node");
  found = [st findPath:[[FPath alloc] initWith:@"t"]];
  XCTAssertFalse([found isEmpty], @"non-empty node");
  [st forgetPath:PATH(@"t/a/c")];
  XCTAssertTrue([st findPath:PATH(@"t")] == nil, @"no more node here");
  XCTAssertTrue([st findPath:PATH(@"t/a")] == nil, @"no more node here");
  XCTAssertTrue([[[st findPath:PATH(@"t/a/b")] val] isEqualToString:@"v"], @"child still exists");
  XCTAssertTrue([st findPath:PATH(@"t/a/c")] == nil, @"no more node here");
  XCTAssertTrue([[[st findPath:PATH(@"t/a/art")] val] isEqualToNumber:@NO], @"child still exists");
}

- (void)testPathShallowerThanSnapshots {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  [st rememberData:NODE(@NO) onPath:PATH(@"t/x1")];
  [st rememberData:NODE(@YES) onPath:PATH(@"t/x2")];

  [st forgetPath:PATH(@"t")];
  XCTAssertTrue([st findPath:PATH(@"t")] == nil, @"No more node here");
}

- (void)testIterateChildren {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  id<FNode> node = [FSnapshotUtilities nodeFrom:@{@"b" : @"v", @"c" : @9, @"art" : @NO}];
  [st rememberData:node onPath:PATH(@"t")];
  [st rememberData:[FEmptyNode emptyNode] onPath:PATH(@"q")];

  __block int num = 0;
  __block BOOL gotT = NO;
  __block BOOL gotQ = NO;
  [st forEachChild:^(NSString* key, FSparseSnapshotTree* tree) {
    num++;
    if ([key isEqualToString:@"t"]) {
      gotT = YES;
    } else if ([key isEqualToString:@"q"]) {
      gotQ = YES;
    } else {
      XCTFail(@"Unknown child");
    }
  }];

  XCTAssertTrue(gotT, @"Saw t");
  XCTAssertTrue(gotQ, @"Saw q");
  XCTAssertTrue(num == 2, @"Saw two children");
}

- (void)testIterateTrees {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  __block int count = 0;
  [st forEachTreeAtPath:PATH(@"")
                     do:^(FPath* path, id<FNode> data) {
                       count++;
                     }];
  XCTAssertTrue(count == 0, @"No trees to iterate through");

  [st rememberData:NODE(@1) onPath:PATH(@"t")];
  [st rememberData:NODE(@2) onPath:PATH(@"a/b")];
  [st rememberData:NODE(@3) onPath:PATH(@"a/x/g")];
  [st rememberData:NODE([NSNull null]) onPath:PATH(@"a/x/null")];

  __block int num = 0;
  __block BOOL got1 = NO;
  __block BOOL got2 = NO;
  __block BOOL got3 = NO;
  __block BOOL gotNull = NO;

  [st forEachTreeAtPath:PATH(@"q")
                     do:^(FPath* path, id<FNode> data) {
                       num++;
                       NSString* pathString = [path description];
                       if ([pathString isEqualToString:@"/q/t"]) {
                         got1 = YES;
                         XCTAssertTrue([[data val] isEqualToNumber:@1], @"got 1");
                       } else if ([pathString isEqualToString:@"/q/a/b"]) {
                         got2 = YES;
                         XCTAssertTrue([[data val] isEqualToNumber:@2], @"got 2");
                       } else if ([pathString isEqualToString:@"/q/a/x/g"]) {
                         got3 = YES;
                         XCTAssertTrue([[data val] isEqualToNumber:@3], @"got 3");
                       } else if ([pathString isEqualToString:@"/q/a/x/null"]) {
                         gotNull = YES;
                         XCTAssertTrue([data val] == [NSNull null], @"got null");
                       } else {
                         XCTFail(@"unknown tree");
                       }
                     }];

  XCTAssertTrue(got1 && got2 && got3 && gotNull, @"saw all the children");
  XCTAssertTrue(num == 4, @"Saw the right number of children");
}

- (void)testSetLeafAndForgetDeeperPath {
  FSparseSnapshotTree* st = [[FSparseSnapshotTree alloc] init];
  [st rememberData:NODE(@"bar") onPath:PATH(@"foo")];
  BOOL safeToRemove = [st forgetPath:PATH(@"foo/baz")];
  XCTAssertFalse(safeToRemove, @"Should not have deleted anything, nothing to remove");
}

@end
