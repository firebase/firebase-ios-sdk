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

#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/FWriteRecord.h"
#import "FirebaseDatabase/Sources/FPathIndex.h"
#import "FirebaseDatabase/Sources/Persistence/FLevelDBStorageEngine.h"
#import "FirebaseDatabase/Sources/Persistence/FTrackedQuery.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FLevelDBStorageEngineTests : XCTestCase

@end

@implementation FLevelDBStorageEngineTests

- (FLevelDBStorageEngine *)cleanStorageEngine {
  NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test-db"];
  FLevelDBStorageEngine *db = [[FLevelDBStorageEngine alloc] initWithPath:path];
  [db purgeEverything];
  return db;
}

#define SAMPLE_NODE    \
  ([FSnapshotUtilities \
      nodeFrom:@{@"foo" : @{@"bar" : @YES, @"baz" : @"string"}, @"qux" : @2, @"quu" : @1.2}])

#define ONE_MEG_NODE ([FTestHelpers leafNodeOfSize:1024 * 1024])
#define FIVE_MEG_NODE ([FTestHelpers leafNodeOfSize:5 * 1024 * 1024])
#define TEN_MEG_NODE ([FTestHelpers leafNodeOfSize:10 * 1024 * 1024])
#define TEN_MEG_MINUS_ONE_NODE ([FTestHelpers leafNodeOfSize:10 * 1024 * 1024 - 1])

#define SAMPLE_PARAMS                                                                           \
  ([[[[[FQueryParams defaultInstance] orderBy:[[FPathIndex alloc] initWithPath:PATH(@"child")]] \
       startAt:[FSnapshotUtilities nodeFrom:@"startVal"]                                        \
      childKey:@"startKey"] endAt:[FSnapshotUtilities nodeFrom:@"endVal"]                       \
                         childKey:@"endKey"] limitToLast:5])

#define SAMPLE_QUERY \
  ([[FQuerySpec alloc] initWithPath:[FPath pathWithString:@"foo"] params:SAMPLE_PARAMS])

#define DEFAULT_FOO_QUERY                                         \
  ([[FQuerySpec alloc] initWithPath:[FPath pathWithString:@"foo"] \
                             params:[FQueryParams defaultInstance]])

#define SAMPLE_TRACKED_QUERY                      \
  ([[FTrackedQuery alloc] initWithId:1            \
                               query:SAMPLE_QUERY \
                            isPinned:NO           \
                             lastUse:100          \
                              Active:NO           \
                          isComplete:NO])
#define OVERWRITE_RECORD(__path, __node, __writeId)                 \
  ([[FWriteRecord alloc] initWithPath:[FPath pathWithString:__path] \
                            overwrite:__node                        \
                              writeId:__writeId                     \
                              visible:YES])

#define MERGE_RECORD(__path, __merge, __writeId)                    \
  ([[FWriteRecord alloc] initWithPath:[FPath pathWithString:__path] \
                                merge:__merge                       \
                              writeId:__writeId])

- (void)testRecocversFromBadCache {
  NSString *dbPath = @"corrupted-db";
  NSString *serverData = [[FLevelDBStorageEngine firebaseDir]
      stringByAppendingPathComponent:@"corrupted-db/server_data/CURRENT"];
  [@"Corrupted" writeToFile:serverData atomically:YES encoding:NSUTF8StringEncoding error:nil];
  NSString *userData = [[FLevelDBStorageEngine firebaseDir]
      stringByAppendingPathComponent:@"corrupted-db/writes/CURRENT"];
  [@"Corrupted" writeToFile:userData atomically:YES encoding:NSUTF8StringEncoding error:nil];
  FLevelDBStorageEngine *db = [[FLevelDBStorageEngine alloc] initWithPath:dbPath];
  XCTAssertNotNil(db);
}

- (void)testUserWriteIsPersisted {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine saveUserOverwrite:SAMPLE_NODE atPath:[FPath pathWithString:@"foo/bar"] writeId:1];
  XCTAssertEqualObjects(engine.userWrites, @[ OVERWRITE_RECORD(@"foo/bar", SAMPLE_NODE, 1) ]);
}

- (void)testUserMergeIsPersisted {
  FCompoundWrite *merge = [FCompoundWrite compoundWriteWithValueDictionary:@{
    @"foo" : @{@"bar" : @1, @"baz" : @"string"},
    @"quu" : @YES
  }];
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine saveUserMerge:merge atPath:PATH(@"foo/bar") writeId:1];
  XCTAssertEqualObjects(engine.userWrites, @[ MERGE_RECORD(@"foo/bar", merge, 1) ]);
}

- (void)testDeepUserMergeIsPersisted {
  FCompoundWrite *merge = [FCompoundWrite compoundWriteWithValueDictionary:@{
    @"foo/bar" : @1,
    @"foo/baz" : @"string",
    @"quu/qux" : @YES,
    @"shallow" : @2
  }];
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine saveUserMerge:merge atPath:PATH(@"foo/bar") writeId:1];
  XCTAssertEqualObjects(engine.userWrites, @[ MERGE_RECORD(@"foo/bar", merge, 1) ]);
}

- (void)testSameWriteIdOverwritesOldWrite {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine saveUserOverwrite:NODE(@"first") atPath:PATH(@"foo/bar") writeId:1];
  [engine saveUserOverwrite:NODE(@"second") atPath:PATH(@"other/path") writeId:1];
  XCTAssertEqualObjects(engine.userWrites,
                        @[ OVERWRITE_RECORD(@"other/path", NODE(@"second"), 1) ]);
}

- (void)testHugeWriteWorks {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine saveUserOverwrite:TEN_MEG_NODE atPath:PATH(@"foo/bar") writeId:1];
  FCompoundWrite *merge = [[FCompoundWrite emptyWrite] addWrite:TEN_MEG_NODE atKey:@"update"];
  [engine saveUserMerge:merge atPath:PATH(@"foo/bar") writeId:2];
  NSArray *expected =
      @[ OVERWRITE_RECORD(@"foo/bar", TEN_MEG_NODE, 1), MERGE_RECORD(@"foo/bar", merge, 2) ];
  XCTAssertEqualObjects(engine.userWrites, expected);
}

- (void)testHugeWritesCanBeDeleted {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine saveUserOverwrite:TEN_MEG_NODE atPath:PATH(@"foo/bar") writeId:1];
  [engine removeUserWrite:1];
  XCTAssertTrue(engine.userWrites.count == 0);
}

- (void)testHugeWritesCanBeInterleavedWithSmallWrites {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  [engine saveUserOverwrite:NODE(@"node-1") atPath:PATH(@"foo/1") writeId:1];
  [engine saveUserOverwrite:TEN_MEG_NODE atPath:PATH(@"foo/2") writeId:2];
  [engine saveUserOverwrite:NODE(@"node-3") atPath:PATH(@"foo/3") writeId:3];
  [engine saveUserOverwrite:FIVE_MEG_NODE atPath:PATH(@"foo/4") writeId:4];

  NSArray *expected = @[
    OVERWRITE_RECORD(@"foo/1", NODE(@"node-1"), 1), OVERWRITE_RECORD(@"foo/2", TEN_MEG_NODE, 2),
    OVERWRITE_RECORD(@"foo/3", NODE(@"node-3"), 3), OVERWRITE_RECORD(@"foo/4", FIVE_MEG_NODE, 4)
  ];
  XCTAssertEqualObjects(engine.userWrites, expected);
}

// This is ported from the Android client and doesn't really make sense since we don't have multi
// part writes, but It's always good to have tests, so what the heck...
- (void)testSameWriteIdOverwritesOldMultiPartWrite {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  [engine saveUserOverwrite:TEN_MEG_NODE atPath:PATH(@"foo/bar") writeId:1];
  [engine saveUserOverwrite:NODE(@"second") atPath:PATH(@"other/path") writeId:1];

  XCTAssertEqualObjects(engine.userWrites,
                        @[ OVERWRITE_RECORD(@"other/path", NODE(@"second"), 1) ]);
}

- (void)testWritesAreReturnedInOrder {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  NSUInteger count = 20;
  for (NSUInteger i = count - 1; i > 0; i--) {
    NSString *path = [NSString stringWithFormat:@"foo/%lu", (unsigned long)i];
    [engine saveUserOverwrite:NODE(@(i)) atPath:PATH(path) writeId:i];
  }
  NSString *path = [NSString stringWithFormat:@"foo/%lu", (unsigned long)count];
  [engine saveUserOverwrite:NODE(@(count)) atPath:PATH(path) writeId:count];
  NSArray *userWrites = engine.userWrites;
  XCTAssertEqual(userWrites.count, count);
  for (NSUInteger i = 1; i <= count; i++) {
    NSString *path = [NSString stringWithFormat:@"foo/%lu", (unsigned long)i];
    XCTAssertEqualObjects(userWrites[i - 1], OVERWRITE_RECORD(path, NODE(@(i)), i));
  }
}

- (void)testRemoveAllUserWrites {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  [engine saveUserOverwrite:NODE(@"node-1") atPath:PATH(@"foo/1") writeId:1];
  [engine saveUserOverwrite:TEN_MEG_NODE atPath:PATH(@"foo/2") writeId:2];
  FCompoundWrite *merge = [[FCompoundWrite emptyWrite] addWrite:TEN_MEG_NODE atKey:@"update"];
  [engine saveUserMerge:merge atPath:PATH(@"foo/bar") writeId:3];
  [engine removeAllUserWrites];
  XCTAssertEqualObjects(engine.userWrites, @[]);
}

- (void)testCacheSavedIsReturned {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:SAMPLE_NODE atPath:PATH(@"foo") merge:NO];
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], SAMPLE_NODE);
}

- (void)testCacheSavedIsReturnedAtRoot {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:SAMPLE_NODE atPath:PATH(@"") merge:NO];
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"")], SAMPLE_NODE);
}

- (void)testLaterCacheWritesOverwriteOlderWrites {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:SAMPLE_NODE atPath:PATH(@"foo") merge:NO];
  [engine updateServerCache:NODE(@"later-bar") atPath:PATH(@"foo/bar") merge:NO];
  // this does not affect the node
  [engine updateServerCache:NODE(@"unaffected") atPath:PATH(@"unaffected") merge:NO];
  [engine updateServerCache:NODE(@"later-qux") atPath:PATH(@"foo/later-qux") merge:NO];
  [engine updateServerCache:NODE(@"latest-bar") atPath:PATH(@"foo/bar") merge:NO];

  id<FNode> expected = [[SAMPLE_NODE updateImmediateChild:@"bar" withNewChild:NODE(@"latest-bar")]
      updateImmediateChild:@"later-qux"
              withNewChild:NODE(@"later-qux")];
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], expected);
}

- (void)testLaterCacheWritesOverwriteOlderDeeperWrites {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:SAMPLE_NODE atPath:PATH(@"foo") merge:NO];
  [engine updateServerCache:NODE(@"later-bar") atPath:PATH(@"foo/bar") merge:NO];
  // this does not affect the node
  [engine updateServerCache:NODE(@"unaffected") atPath:PATH(@"unaffected") merge:NO];
  [engine updateServerCache:NODE(@"later-qux") atPath:PATH(@"foo/later-qux") merge:NO];
  [engine updateServerCache:NODE(@"latest-bar") atPath:PATH(@"foo/bar") merge:NO];
  [engine updateServerCache:NODE(@"latest-foo") atPath:PATH(@"foo") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], NODE(@"latest-foo"));
}

- (void)testLaterCacheWritesDontAffectEarlierWritesAtUnaffectedPath {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:SAMPLE_NODE atPath:PATH(@"foo") merge:NO];
  // this does not affect the node
  [engine updateServerCache:NODE(@"unaffected") atPath:PATH(@"unaffected") merge:NO];
  [engine updateServerCache:NODE(@"latest-foo") atPath:PATH(@"foo") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"unaffected")], NODE(@"unaffected"));
}

- (void)testMergeOnEmptyCacheGivesResults {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  NSDictionary *mergeData = @{@"foo" : @"foo-value", @"bar" : @"bar-value"};
  FCompoundWrite *merge = [FCompoundWrite compoundWriteWithValueDictionary:mergeData];
  [engine updateServerCacheWithMerge:merge atPath:PATH(@"foo")];
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], NODE(mergeData));
}

- (void)testMergePartlyOverwritingPreviousWrite {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  id<FNode> existingNode = NODE((@{@"foo" : @"foo-value", @"bar" : @"bar-value"}));
  [engine updateServerCache:existingNode atPath:PATH(@"foo") merge:NO];

  FCompoundWrite *merge = [FCompoundWrite
      compoundWriteWithValueDictionary:@{@"foo" : @"new-foo-value", @"baz" : @"baz-value"}];
  [engine updateServerCacheWithMerge:merge atPath:PATH(@"foo")];

  id<FNode> expected =
      NODE((@{@"foo" : @"new-foo-value", @"bar" : @"bar-value", @"baz" : @"baz-value"}));
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], expected);
}

- (void)testDeepMergePartlyOverwritingPreviousWrite {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  id<FNode> existingNode =
      NODE((@{@"foo" : @{@"bar" : @"bar-value", @"baz" : @"baz-value"}, @"qux" : @"qux-value"}));
  [engine updateServerCache:existingNode atPath:PATH(@"foo") merge:NO];

  FCompoundWrite *merge = [FCompoundWrite
      compoundWriteWithValueDictionary:@{@"foo/bar" : @"new-bar-value", @"quu" : @"quu-value"}];
  [engine updateServerCacheWithMerge:merge atPath:PATH(@"foo")];

  id<FNode> expected = NODE((@{
    @"foo" : @{@"bar" : @"new-bar-value", @"baz" : @"baz-value"},
    @"qux" : @"qux-value",
    @"quu" : @"quu-value"
  }));
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], expected);
}

- (void)testMergePartlyOverwritingPreviousMerge {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  FCompoundWrite *merge1 = [FCompoundWrite
      compoundWriteWithValueDictionary:@{@"foo" : @"foo-value", @"bar" : @"bar-value"}];
  [engine updateServerCacheWithMerge:merge1 atPath:PATH(@"foo")];

  FCompoundWrite *merge2 = [FCompoundWrite
      compoundWriteWithValueDictionary:@{@"foo" : @"new-foo-value", @"baz" : @"baz-value"}];
  [engine updateServerCacheWithMerge:merge2 atPath:PATH(@"foo")];

  id<FNode> expected =
      NODE((@{@"foo" : @"new-foo-value", @"bar" : @"bar-value", @"baz" : @"baz-value"}));
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], expected);
}

- (void)testOverwriteRemovesPreviousMerge {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  id<FNode> initial = NODE((@{@"foo" : @"foo-value", @"bar" : @"bar-value"}));
  [engine updateServerCache:initial atPath:PATH(@"foo") merge:NO];

  FCompoundWrite *merge2 = [FCompoundWrite
      compoundWriteWithValueDictionary:@{@"foo" : @"new-foo-value", @"baz" : @"baz-value"}];
  [engine updateServerCacheWithMerge:merge2 atPath:PATH(@"foo")];

  id<FNode> replacingNode = NODE((@{@"qux" : @"qux-value", @"quu" : @"quu-value"}));
  [engine updateServerCache:replacingNode atPath:PATH(@"foo") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], replacingNode);
}

- (void)testEmptyOverwriteDeletesNodeFromHigherWrite {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  id<FNode> initial = NODE((@{@"foo" : @"foo-value", @"bar" : @"bar-value"}));
  [engine updateServerCache:initial atPath:PATH(@"foo") merge:NO];

  // delete bar
  [engine updateServerCache:NODE(nil) atPath:PATH(@"foo/bar") merge:NO];

  id<FNode> expected = NODE((@{@"foo" : @"foo-value"}));
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], expected);
}

- (void)testDeeperReadFromHigherSet {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  id<FNode> initial = NODE((@{@"foo" : @"foo-value", @"bar" : @"bar-value"}));
  [engine updateServerCache:initial atPath:PATH(@"foo") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo/bar")], NODE(@"bar-value"));
}

- (void)testDeeperLeafNodeSetRemovesHigherLeafNodes {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:NODE(@"level-0") atPath:PATH(@"") merge:NO];
  [engine updateServerCache:NODE(@"level-1") atPath:PATH(@"lvl1") merge:NO];
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"")], NODE((@{@"lvl1" : @"level-1"})));

  [engine updateServerCache:NODE(@"level-2") atPath:PATH(@"lvl1/lvl2") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"lvl1")], NODE((@{@"lvl2" : @"level-2"})));

  [engine updateServerCache:NODE(@"level-4") atPath:PATH(@"lvl1/lvl2/lvl3/lvl4") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"lvl1")],
                        NODE((@{@"lvl2" : @{@"lvl3" : @{@"lvl4" : @"level-4"}}})));
}

// This test causes a split on Android so it doesn't really make sense here, but why not test
// anyways...
- (void)testHugeNodeWithSplit {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  id<FNode> outer = [FEmptyNode emptyNode];
  // This structure ensures splits at various depths
  for (NSUInteger i = 0; i < 100; i++) {  // Outer
    id<FNode> inner = [FEmptyNode emptyNode];
    for (NSUInteger j = 0; j < i; j++) {  // Inner
      id<FNode> innerMost = [FEmptyNode emptyNode];
      for (NSUInteger k = 0; k < j; k++) {
        NSString *key = [NSString stringWithFormat:@"key-%lu", (unsigned long)k];
        id<FNode> node = NODE(([NSString stringWithFormat:@"leaf-%lu", (unsigned long)k]));
        innerMost = [innerMost updateImmediateChild:key withNewChild:node];
      }
      NSString *innerKey = [NSString stringWithFormat:@"key-%lu", (unsigned long)j];
      inner = [inner updateImmediateChild:innerKey withNewChild:innerMost];
    }
    NSString *outerKey = [NSString stringWithFormat:@"key-%lu", (unsigned long)i];
    outer = [outer updateImmediateChild:outerKey withNewChild:inner];
  }
  [engine updateServerCache:outer atPath:PATH(@"foo") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], outer);
}

- (void)testManyLargeLeafNodes {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  id<FNode> outer = [FEmptyNode emptyNode];
  for (NSUInteger i = 0; i < 30; i++) {
    NSString *outerKey = [NSString stringWithFormat:@"key-%lu", (unsigned long)i];
    outer = [outer updateImmediateChild:outerKey withNewChild:ONE_MEG_NODE];
  }

  [engine updateServerCache:outer atPath:PATH(@"foo") merge:NO];
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], outer);
}

- (void)testPriorityWorks {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  [engine updateServerCache:NODE(@"bar-value") atPath:PATH(@"foo/bar") merge:NO];
  [engine updateServerCache:NODE(@"prio-value") atPath:PATH(@"foo/.priority") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")],
                        NODE((@{@".priority" : @"prio-value", @"bar" : @"bar-value"})));
}

- (void)testSimilarSiblingsAreNotLoaded {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  [engine updateServerCache:NODE(@"value") atPath:PATH(@"foo/123") merge:NO];
  [engine updateServerCache:NODE(@"sibling-value") atPath:PATH(@"foo/1230") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo/123")], NODE(@"value"));
}

// TODO: this test fails, but it is a rare edge case around priorities which would require a bunch
// of code Fix whenever we have too much time on our hands
- (void)priorityIsCleared {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  [engine updateServerCache:NODE((@{@"bar" : @"bar-value"})) atPath:PATH(@"foo") merge:NO];
  [engine updateServerCache:NODE(@"prio-value") atPath:PATH(@"foo/.priority") merge:NO];
  [engine updateServerCache:NODE(nil) atPath:PATH(@"foo/bar") merge:NO];
  [engine updateServerCache:NODE(@"baz-value") atPath:PATH(@"foo/baz") merge:NO];

  // Priority should have been cleaned out
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], NODE(@{@"baz" : @"baz-value"}));
}

- (void)testHugeLeafNode {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:TEN_MEG_NODE atPath:PATH(@"foo") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], TEN_MEG_NODE);
}

- (void)testHugeLeafNodeSiblings {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:TEN_MEG_NODE atPath:PATH(@"foo/one") merge:NO];
  [engine updateServerCache:TEN_MEG_MINUS_ONE_NODE atPath:PATH(@"foo/two") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo/one")], TEN_MEG_NODE);
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo/two")], TEN_MEG_MINUS_ONE_NODE);
}

- (void)testHugeLeafNodeThenTinyLeafNode {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:TEN_MEG_NODE atPath:PATH(@"foo") merge:NO];
  [engine updateServerCache:NODE(@"tiny") atPath:PATH(@"foo") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], NODE(@"tiny"));
}

- (void)testHugeLeafNodeThenSmallerLeafNode {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:TEN_MEG_NODE atPath:PATH(@"foo") merge:NO];
  [engine updateServerCache:FIVE_MEG_NODE atPath:PATH(@"foo") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], FIVE_MEG_NODE);
}

- (void)testHugeLeafNodeThenDeeperSet {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:TEN_MEG_NODE atPath:PATH(@"foo") merge:NO];
  [engine updateServerCache:NODE(@"deep-value") atPath:PATH(@"foo/deep") merge:NO];

  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")],
                        NODE((@{@"deep" : @"deep-value"})));
}

// Well this is awkward, but NSJSONSerialization fails to deserialize JSON with tiny/huge doubles
// It is kind of bad we raise "invalid" data, but at least we don't crash *trollface*
- (void)testExtremeDoublesAsServerCache {
#ifdef TARGET_OS_IOS
  if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion >= 11) {
    // NSJSONSerialization on iOS 11 correctly serializes small and large doubles.
    return;
  }
#endif
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
  return;
#endif

  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:NODE((@{@"works" : @"value", @"fails" : @(2.225073858507201e-308)}))
                     atPath:PATH(@"foo")
                      merge:NO];

  // Will drop the tiny double
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo")], NODE(@{@"works" : @"value"}));
  XCTAssertEqualObjects([engine serverCacheAtPath:PATH(@"foo/fails")], [FEmptyNode emptyNode]);
}

- (void)testLongValuesDontLosePrecision {
  id longValue = @1542405709418655810;
  id floatValue = @2.47;
  id<FNode> expectedData = NODE((@{@"long" : longValue, @"float" : floatValue}));
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:expectedData atPath:PATH(@"foo") merge:NO];
  id<FNode> actualData = [engine serverCacheAtPath:PATH(@"foo")];
  NSDictionary *value = [actualData val];
  XCTAssertEqualObjects([value[@"long"] stringValue], [longValue stringValue]);
  XCTAssertEqualObjects([value[@"float"] stringValue], [floatValue stringValue]);
}

// NSJSONSerialization has a bug in which it rounds doubles wrongly so hashes end up not matching on
// the server for some doubles (including 2.47). Make sure LevelDB has the correct hash for that
- (void)testDoublesAreRoundedProperly {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:NODE(@(2.47)) atPath:PATH(@"foo") merge:NO];

  // Expected hash for 2.47 parsed correctly
  NSString *hashFor247 = @"EsibHXKcBp2/b/bn/a0C5WffcUU=";
  XCTAssertEqualObjects([[engine serverCacheAtPath:PATH(@"foo")] dataHash], hashFor247);
}

// NOTE: This deals with part of the NSDecimalNumber issue: namely that
// [NSDecimalNumber longLongValue] is completely bonkers for decimals with
// high precision. The decimal value below (close to 1000) is returned as -844!
// http://www.openradar.me/radar?id=5007005597040640
// This does not deal with the fact that this is not the same behavior as the
// RTDB server. Given an NSDecimalNumber, the server stores decimals with the
// full precision and returns these as NSDecimalNumbers too.
// This means that the RTDB server can store the double value 2.47 as 2.47.
// But if the double is wrapped in an NSDecimalNumber, the server apparently
// stores the value 2.470000000000000512.
// This means that the persistence layer will have a hard time determining whether
// rounding is appropriate or not.
// Similarly, as an NSDecimalNumber, the RTDB gladly stores and returns
// 999.9999999999999487 without any rounding, although considered as a double,
// the value will be 1000.
- (void)testNSDecimalsAreRoundedProperly {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  id decimalValue = [NSDecimalNumber decimalNumberWithString:@"999.9999999999999487"];
  id expectedDecimalValue = [NSDecimalNumber decimalNumberWithString:@"1000"];
  [engine updateServerCache:NODE(decimalValue) atPath:PATH(@"foo") merge:NO];

  id<FNode> actualData = [engine serverCacheAtPath:PATH(@"foo")];
  NSNumber *actualDecimal = [actualData val];
  XCTAssertEqualObjects([actualDecimal stringValue], [expectedDecimalValue stringValue]);
  XCTAssertEqual(CFNumberGetType((CFNumberRef)actualDecimal), kCFNumberFloat64Type);
}

- (void)testIntegersAreReturnedsAsIntegers {
  id intValue = @247;
  id longValue = @1542405709418655810;
  id doubleValue = @0xFFFFFFFFFFFFFFFFUL;  // This number can't be represented as a signed long.

  id<FNode> expectedData =
      NODE((@{@"int" : intValue, @"long" : longValue, @"double" : doubleValue}));
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine updateServerCache:expectedData atPath:PATH(@"foo") merge:NO];
  id<FNode> actualData = [engine serverCacheAtPath:PATH(@"foo")];
  NSNumber *actualInt = [actualData val][@"int"];
  NSNumber *actualLong = [actualData val][@"long"];
  NSNumber *actualDouble = [actualData val][@"double"];

  XCTAssertEqualObjects([actualInt stringValue], [intValue stringValue]);
  XCTAssertEqual(CFNumberGetType((CFNumberRef)actualInt), kCFNumberSInt64Type);
  XCTAssertEqualObjects([actualLong stringValue], [longValue stringValue]);
  XCTAssertEqual(CFNumberGetType((CFNumberRef)actualLong), kCFNumberSInt64Type);
  XCTAssertEqual(CFNumberGetType((CFNumberRef)actualDouble), kCFNumberSInt64Type);
}

// TODO[offline]: Somehow test estimated server size?
// TODO[offline]: Test pruning!

- (void)testSaveAndLoadTrackedQueries {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  NSArray *queries = @[
    [[FTrackedQuery alloc] initWithId:1 query:SAMPLE_QUERY lastUse:100 isActive:NO isComplete:NO],
    [[FTrackedQuery alloc] initWithId:2
                                query:[FQuerySpec defaultQueryAtPath:PATH(@"a")]
                              lastUse:200
                             isActive:NO
                           isComplete:NO],
    [[FTrackedQuery alloc] initWithId:3
                                query:[FQuerySpec defaultQueryAtPath:PATH(@"b")]
                              lastUse:300
                             isActive:YES
                           isComplete:NO],
    [[FTrackedQuery alloc] initWithId:4
                                query:[FQuerySpec defaultQueryAtPath:PATH(@"c")]
                              lastUse:400
                             isActive:NO
                           isComplete:YES],
    [[FTrackedQuery alloc] initWithId:5
                                query:[FQuerySpec defaultQueryAtPath:PATH(@"foo")]
                              lastUse:500
                             isActive:NO
                           isComplete:NO]
  ];

  [queries enumerateObjectsUsingBlock:^(FTrackedQuery *query, NSUInteger idx, BOOL *stop) {
    [engine saveTrackedQuery:query];
  }];

  XCTAssertEqualObjects([engine loadTrackedQueries], queries);
}

- (void)testOverwriteTrackedQueryById {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];

  FTrackedQuery *first = [[FTrackedQuery alloc] initWithId:1
                                                     query:SAMPLE_QUERY
                                                   lastUse:100
                                                  isActive:NO
                                                isComplete:NO];
  FTrackedQuery *second = [[FTrackedQuery alloc] initWithId:1
                                                      query:DEFAULT_FOO_QUERY
                                                    lastUse:200
                                                   isActive:YES
                                                 isComplete:YES];
  [engine saveTrackedQuery:first];
  [engine saveTrackedQuery:second];

  XCTAssertEqualObjects([engine loadTrackedQueries], @[ second ]);
}

- (void)testDeleteTrackedQuery {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  FTrackedQuery *query1 =
      [[FTrackedQuery alloc] initWithId:1
                                  query:[FQuerySpec defaultQueryAtPath:PATH(@"a")]
                                lastUse:100
                               isActive:NO
                             isComplete:NO];
  FTrackedQuery *query2 =
      [[FTrackedQuery alloc] initWithId:2
                                  query:[FQuerySpec defaultQueryAtPath:PATH(@"b")]
                                lastUse:200
                               isActive:YES
                             isComplete:NO];
  FTrackedQuery *query3 =
      [[FTrackedQuery alloc] initWithId:3
                                  query:[FQuerySpec defaultQueryAtPath:PATH(@"c")]
                                lastUse:300
                               isActive:NO
                             isComplete:YES];
  [engine saveTrackedQuery:query1];
  [engine saveTrackedQuery:query2];
  [engine saveTrackedQuery:query3];

  [engine removeTrackedQuery:2];
  XCTAssertEqualObjects([engine loadTrackedQueries], (@[ query1, query3 ]));
}

- (void)testSaveAndLoadTrackedQueryKeys {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  NSSet *keys = [NSSet setWithArray:@[ @"foo", @"☁", @"10", @"٩(͡๏̯͡๏)۶" ]];
  [engine setTrackedQueryKeys:keys forQueryId:1];
  [engine setTrackedQueryKeys:[NSSet setWithArray:@[ @"not", @"included" ]] forQueryId:2];

  XCTAssertEqualObjects([engine trackedQueryKeysForQuery:1], keys);
}

- (void)testSaveOverwritesTrackedQueryKeys {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine setTrackedQueryKeys:[NSSet setWithArray:@[ @"a", @"b", @"c" ]] forQueryId:1];
  [engine setTrackedQueryKeys:[NSSet setWithArray:@[ @"c", @"d", @"e" ]] forQueryId:1];

  XCTAssertEqualObjects([engine trackedQueryKeysForQuery:1],
                        ([NSSet setWithArray:@[ @"c", @"d", @"e" ]]));
}

- (void)testUpdateTrackedQueryKeys {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  [engine setTrackedQueryKeys:[NSSet setWithArray:@[ @"a", @"b", @"c" ]] forQueryId:1];
  [engine updateTrackedQueryKeysWithAddedKeys:[NSSet setWithArray:@[ @"c", @"d", @"e" ]]
                                  removedKeys:[NSSet setWithArray:@[ @"a", @"b" ]]
                                   forQueryId:1];
  XCTAssertEqualObjects([engine trackedQueryKeysForQuery:1],
                        ([NSSet setWithArray:@[ @"c", @"d", @"e" ]]));
}

- (void)testRemoveTrackedQueryRemovesTrackedQueryKeys {
  FLevelDBStorageEngine *engine = [self cleanStorageEngine];
  FTrackedQuery *query1 =
      [[FTrackedQuery alloc] initWithId:1
                                  query:[FQuerySpec defaultQueryAtPath:PATH(@"a")]
                                lastUse:100
                               isActive:NO
                             isComplete:NO];
  FTrackedQuery *query2 =
      [[FTrackedQuery alloc] initWithId:2
                                  query:[FQuerySpec defaultQueryAtPath:PATH(@"b")]
                                lastUse:200
                               isActive:NO
                             isComplete:NO];
  [engine saveTrackedQuery:query1];
  [engine saveTrackedQuery:query2];
  [engine setTrackedQueryKeys:[NSSet setWithArray:@[ @"a", @"b" ]] forQueryId:1];
  [engine setTrackedQueryKeys:[NSSet setWithArray:@[ @"b", @"c" ]] forQueryId:2];

  XCTAssertEqualObjects([engine loadTrackedQueries], (@[ query1, query2 ]));
  XCTAssertEqualObjects([engine trackedQueryKeysForQuery:1],
                        ([NSSet setWithArray:@[ @"a", @"b" ]]));
  XCTAssertEqualObjects([engine trackedQueryKeysForQuery:2],
                        ([NSSet setWithArray:@[ @"b", @"c" ]]));

  [engine removeTrackedQuery:1];

  XCTAssertEqualObjects([engine loadTrackedQueries], (@[ query2 ]));
  XCTAssertEqualObjects([engine trackedQueryKeysForQuery:1], [NSSet set]);
  XCTAssertEqualObjects([engine trackedQueryKeysForQuery:2],
                        ([NSSet setWithArray:@[ @"b", @"c" ]]));
}

@end
