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
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/FClock.h"
#import "FirebaseDatabase/Sources/FPathIndex.h"
#import "FirebaseDatabase/Sources/Persistence/FPruneForest.h"
#import "FirebaseDatabase/Sources/Persistence/FTrackedQuery.h"
#import "FirebaseDatabase/Sources/Persistence/FTrackedQueryManager.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Tests/Helpers/FMockStorageEngine.h"
#import "FirebaseDatabase/Tests/Helpers/FTestCachePolicy.h"
#import "FirebaseDatabase/Tests/Helpers/FTestClock.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FPruneForest (Test)

- (FImmutableSortedDictionary *)pruneForest;

@end

@interface FTrackedQueryManagerTest : XCTestCase

@end

@implementation FTrackedQueryManagerTest

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

#define DEFAULT_BAR_QUERY                                         \
  ([[FQuerySpec alloc] initWithPath:[FPath pathWithString:@"bar"] \
                             params:[FQueryParams defaultInstance]])

- (FTrackedQueryManager *)newManager {
  return [self newManagerWithClock:[FSystemClock clock]];
}

- (FTrackedQueryManager *)newManagerWithClock:(id<FClock>)clock {
  return [[FTrackedQueryManager alloc] initWithStorageEngine:[[FMockStorageEngine alloc] init]
                                                       clock:clock];
}

- (FTrackedQueryManager *)newManagerWithStorageEngine:(id<FStorageEngine>)storageEngine {
  return [[FTrackedQueryManager alloc] initWithStorageEngine:storageEngine
                                                       clock:[FSystemClock clock]];
}

- (void)testFindTrackedQuery {
  FTrackedQueryManager *manager = [self newManager];
  XCTAssertNil([manager findTrackedQuery:SAMPLE_QUERY]);
  [manager setQueryActive:SAMPLE_QUERY];
  XCTAssertNotNil([manager findTrackedQuery:SAMPLE_QUERY]);
}

- (void)testRemoveTrackedQuery {
  FTrackedQueryManager *manager = [self newManager];
  [manager setQueryActive:SAMPLE_QUERY];
  XCTAssertNotNil([manager findTrackedQuery:SAMPLE_QUERY]);
  [manager removeTrackedQuery:SAMPLE_QUERY];
  XCTAssertNil([manager findTrackedQuery:SAMPLE_QUERY]);
  [manager verifyCache];
}

- (void)testSetQueryActiveAndInactive {
  FTestClock *clock = [[FTestClock alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithClock:clock];

  [manager setQueryActive:SAMPLE_QUERY];
  FTrackedQuery *q = [manager findTrackedQuery:SAMPLE_QUERY];
  XCTAssertTrue(q.isActive);
  XCTAssertEqual(q.lastUse, clock.currentTime);
  [manager verifyCache];

  [clock tick];
  [manager setQueryInactive:SAMPLE_QUERY];
  q = [manager findTrackedQuery:SAMPLE_QUERY];
  XCTAssertFalse(q.isActive);
  XCTAssertEqual(q.lastUse, clock.currentTime);
  [manager verifyCache];
}

- (void)testSetQueryComplete {
  FTrackedQueryManager *manager = [self newManager];
  [manager setQueryActive:SAMPLE_QUERY];
  [manager setQueryComplete:SAMPLE_QUERY];
  XCTAssertTrue([manager findTrackedQuery:SAMPLE_QUERY].isComplete);
  [manager verifyCache];
}

- (void)testSetQueriesComplete {
  FTrackedQueryManager *manager = [self newManager];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"foo")]];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"foo/bar")]];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"elsewhere")]];
  [manager setQueryActive:[[FQuerySpec alloc] initWithPath:PATH(@"foo") params:SAMPLE_PARAMS]];
  [manager setQueryActive:[[FQuerySpec alloc] initWithPath:PATH(@"foo/baz") params:SAMPLE_PARAMS]];
  [manager setQueryActive:[[FQuerySpec alloc] initWithPath:PATH(@"elsewhere")
                                                    params:SAMPLE_PARAMS]];

  [manager setQueriesCompleteAtPath:PATH(@"foo")];

  XCTAssertTrue([manager findTrackedQuery:[FQuerySpec defaultQueryAtPath:PATH(@"foo")]].isComplete);
  XCTAssertTrue(
      [manager findTrackedQuery:[FQuerySpec defaultQueryAtPath:PATH(@"foo/bar")]].isComplete);
  XCTAssertTrue([manager findTrackedQuery:[[FQuerySpec alloc] initWithPath:PATH(@"foo")
                                                                    params:SAMPLE_PARAMS]]
                    .isComplete);
  XCTAssertTrue([manager findTrackedQuery:[[FQuerySpec alloc] initWithPath:PATH(@"foo/baz")
                                                                    params:SAMPLE_PARAMS]]
                    .isComplete);
  XCTAssertFalse(
      [manager findTrackedQuery:[FQuerySpec defaultQueryAtPath:PATH(@"elsewhere")]].isComplete);
  XCTAssertFalse([manager findTrackedQuery:[[FQuerySpec alloc] initWithPath:PATH(@"elsewhere")
                                                                     params:SAMPLE_PARAMS]]
                     .isComplete);
  [manager verifyCache];
}

- (void)testIsQueryComplete {
  FTrackedQueryManager *manager = [self newManager];

  [manager setQueryActive:SAMPLE_QUERY];
  [manager setQueryComplete:SAMPLE_QUERY];

  [manager setQueryActive:DEFAULT_BAR_QUERY];

  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"baz")]];
  [manager setQueryComplete:[FQuerySpec defaultQueryAtPath:PATH(@"baz")]];

  XCTAssertTrue([manager isQueryComplete:SAMPLE_QUERY]);
  XCTAssertFalse([manager isQueryComplete:DEFAULT_BAR_QUERY]);

  XCTAssertFalse([manager isQueryComplete:[FQuerySpec defaultQueryAtPath:PATH(@"")]]);
  XCTAssertTrue([manager isQueryComplete:[FQuerySpec defaultQueryAtPath:PATH(@"baz")]]);
  XCTAssertTrue([manager isQueryComplete:[FQuerySpec defaultQueryAtPath:PATH(@"baz/quu")]]);
}

- (void)testPruneOldQueries {
  FTestClock *clock = [[FTestClock alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithClock:clock];

  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"active1")]];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"active2")]];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"pinned1")]];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"pinned2")]];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"inactive1")]];
  [manager setQueryInactive:[FQuerySpec defaultQueryAtPath:PATH(@"inactive1")]];
  [clock tick];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"inactive2")]];
  [manager setQueryInactive:[FQuerySpec defaultQueryAtPath:PATH(@"inactive2")]];
  [clock tick];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"inactive3")]];
  [manager setQueryInactive:[FQuerySpec defaultQueryAtPath:PATH(@"inactive3")]];
  [clock tick];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"inactive4")]];
  [manager setQueryInactive:[FQuerySpec defaultQueryAtPath:PATH(@"inactive4")]];
  [clock tick];

  // Should remove the first two inactive queries
  FPruneForest *forest = [manager
      pruneOldQueries:[[FTestCachePolicy alloc] initWithPercent:0.5 maxQueries:NSUIntegerMax]];
  [self checkPruneForest:forest
             pathsToKeep:@[
               @"active1", @"active2", @"pinned1", @"pinned2", @"inactive3", @"inactive4"
             ]
            pathsToPrune:@[ @"inactive1", @"inactive2" ]];

  // Should remove the other two inactive queries
  forest = [manager pruneOldQueries:[[FTestCachePolicy alloc] initWithPercent:1
                                                                   maxQueries:NSUIntegerMax]];
  [self checkPruneForest:forest
             pathsToKeep:@[ @"active1", @"active2", @"pinned1", @"pinned2" ]
            pathsToPrune:@[ @"inactive3", @"inactive4" ]];

  // Nothing left to prune
  forest = [manager pruneOldQueries:[[FTestCachePolicy alloc] initWithPercent:1
                                                                   maxQueries:NSUIntegerMax]];
  XCTAssertFalse([forest prunesAnything]);

  [manager verifyCache];
}

- (void)testPruneQueriesOverMaxSize {
  FTestClock *clock = [[FTestClock alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithClock:clock];

  for (NSUInteger i = 0; i < 10; i++) {
    [manager
        setQueryActive:[FQuerySpec
                           defaultQueryAtPath:PATH(([NSString
                                                  stringWithFormat:@"%lu", (unsigned long)i]))]];
    [manager
        setQueryInactive:[FQuerySpec
                             defaultQueryAtPath:PATH(([NSString
                                                    stringWithFormat:@"%lu", (unsigned long)i]))]];
    [clock tick];
  }

  FPruneForest *forest = [manager pruneOldQueries:[[FTestCachePolicy alloc] initWithPercent:0.2
                                                                                 maxQueries:6]];
  [self checkPruneForest:forest
             pathsToKeep:@[ @"4", @"5", @"6", @"7", @"8", @"9" ]
            pathsToPrune:@[ @"0", @"1", @"2", @"3" ]];
}

- (void)testPruneDefaultWithDeeperQueries {
  FTestClock *clock = [[FTestClock alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithClock:clock];

  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"foo")]];
  [manager setQueryActive:[[FQuerySpec alloc] initWithPath:PATH(@"foo/a") params:SAMPLE_PARAMS]];
  [manager setQueryActive:[[FQuerySpec alloc] initWithPath:PATH(@"foo/b") params:SAMPLE_PARAMS]];
  [manager setQueryInactive:[FQuerySpec defaultQueryAtPath:PATH(@"foo")]];

  FPruneForest *forest = [manager
      pruneOldQueries:[[FTestCachePolicy alloc] initWithPercent:1.0 maxQueries:NSUIntegerMax]];
  [self checkPruneForest:forest pathsToKeep:@[ @"foo/a", @"foo/b" ] pathsToPrune:@[ @"foo" ]];
  [manager verifyCache];
}

- (void)testPruneQueriesWithDefaultQueryOnParent {
  FTestClock *clock = [[FTestClock alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithClock:clock];

  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"foo")]];
  [manager setQueryActive:[[FQuerySpec alloc] initWithPath:PATH(@"foo/a") params:SAMPLE_PARAMS]];
  [manager setQueryActive:[[FQuerySpec alloc] initWithPath:PATH(@"foo/b") params:SAMPLE_PARAMS]];
  [manager setQueryInactive:[[FQuerySpec alloc] initWithPath:PATH(@"foo/a") params:SAMPLE_PARAMS]];
  [manager setQueryInactive:[[FQuerySpec alloc] initWithPath:PATH(@"foo/b") params:SAMPLE_PARAMS]];

  FPruneForest *forest = [manager
      pruneOldQueries:[[FTestCachePolicy alloc] initWithPercent:1.0 maxQueries:NSUIntegerMax]];
  [self checkPruneForest:forest pathsToKeep:@[ @"foo" ] pathsToPrune:@[]];
  [manager verifyCache];
}

- (void)testPruneQueriesOverMaxSizeUsingPercent {
  FTestClock *clock = [[FTestClock alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithClock:clock];

  for (NSUInteger i = 0; i < 10; i++) {
    [manager
        setQueryActive:[FQuerySpec
                           defaultQueryAtPath:PATH(([NSString
                                                  stringWithFormat:@"%lu", (unsigned long)i]))]];
    [manager
        setQueryInactive:[FQuerySpec
                             defaultQueryAtPath:PATH(([NSString
                                                    stringWithFormat:@"%lu", (unsigned long)i]))]];
    [clock tick];
  }

  FPruneForest *forest = [manager pruneOldQueries:[[FTestCachePolicy alloc] initWithPercent:0.6
                                                                                 maxQueries:6]];
  [self checkPruneForest:forest
             pathsToKeep:@[ @"6", @"7", @"8", @"9" ]
            pathsToPrune:@[ @"0", @"1", @"2", @"3", @"4", @"5" ]];
}

- (void)checkPruneForest:(FPruneForest *)pruneForest
             pathsToKeep:(NSArray *)toKeep
            pathsToPrune:(NSArray *)toPrune {
  FPruneForest *checkForest = [FPruneForest empty];
  for (NSString *path in toPrune) {
    checkForest = [checkForest prunePath:PATH(path)];
  }
  for (NSString *path in toKeep) {
    checkForest = [checkForest keepPath:PATH(path)];
  }
  XCTAssertEqualObjects([pruneForest pruneForest], [checkForest pruneForest]);
}

- (void)testKnownCompleteChildren {
  FMockStorageEngine *engine = [[FMockStorageEngine alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithStorageEngine:engine];

  XCTAssertEqualObjects([manager knownCompleteChildrenAtPath:PATH(@"foo")], [NSSet set]);

  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"foo/a")]];
  [manager setQueryComplete:[FQuerySpec defaultQueryAtPath:PATH(@"foo/a")]];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"foo/not-included")]];
  [manager setQueryActive:[FQuerySpec defaultQueryAtPath:PATH(@"foo/deep/not-included")]];

  [manager setQueryActive:SAMPLE_QUERY];
  FTrackedQuery *query = [manager findTrackedQuery:SAMPLE_QUERY];
  [engine setTrackedQueryKeys:[NSSet setWithArray:@[ @"d", @"e" ]] forQueryId:query.queryId];

  XCTAssertEqualObjects([manager knownCompleteChildrenAtPath:PATH(@"foo")],
                        ([NSSet setWithArray:@[ @"a", @"d", @"e" ]]));
  XCTAssertEqualObjects([manager knownCompleteChildrenAtPath:PATH(@"")], [NSSet set]);
  XCTAssertEqualObjects([manager knownCompleteChildrenAtPath:PATH(@"foo/baz")], [NSSet set]);
}

- (void)testEnsureTrackedQueryForNewQuery {
  FTestClock *clock = [[FTestClock alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithClock:clock];

  [manager ensureCompleteTrackedQueryAtPath:PATH(@"foo")];
  FTrackedQuery *query = [manager findTrackedQuery:DEFAULT_FOO_QUERY];
  XCTAssertTrue(query.isComplete);
  XCTAssertEqual(query.lastUse, clock.currentTime);
}

- (void)testEnsureTrackedQueryForAlreadyTrackedQuery {
  FTestClock *clock = [[FTestClock alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithClock:clock];

  [manager setQueryActive:DEFAULT_FOO_QUERY];

  NSTimeInterval lastTick = clock.currentTime;
  [clock tick];
  [manager ensureCompleteTrackedQueryAtPath:PATH(@"foo")];
  XCTAssertEqual([manager findTrackedQuery:DEFAULT_FOO_QUERY].lastUse, lastTick);
}

- (void)testHasActiveDefaultQuery {
  FTrackedQueryManager *manager = [self newManager];

  [manager setQueryActive:SAMPLE_QUERY];
  [manager setQueryActive:DEFAULT_BAR_QUERY];
  XCTAssertFalse([manager hasActiveDefaultQueryAtPath:PATH(@"foo")]);
  XCTAssertFalse([manager hasActiveDefaultQueryAtPath:PATH(@"")]);
  XCTAssertTrue([manager hasActiveDefaultQueryAtPath:PATH(@"bar")]);
  XCTAssertTrue([manager hasActiveDefaultQueryAtPath:PATH(@"bar/baz")]);
}

- (void)testCacheSanity {
  FMockStorageEngine *engine = [[FMockStorageEngine alloc] init];
  FTrackedQueryManager *manager = [self newManagerWithStorageEngine:engine];

  [manager setQueryActive:SAMPLE_QUERY];
  [manager setQueryActive:DEFAULT_FOO_QUERY];
  [manager verifyCache];

  [manager setQueryComplete:SAMPLE_QUERY];
  [manager verifyCache];

  [manager setQueryInactive:DEFAULT_FOO_QUERY];
  [manager verifyCache];

  FTrackedQueryManager *manager2 = [self newManagerWithStorageEngine:engine];
  XCTAssertNotNil([manager2 findTrackedQuery:SAMPLE_QUERY]);
  XCTAssertNotNil([manager2 findTrackedQuery:DEFAULT_FOO_QUERY]);
  [manager2 verifyCache];
}

@end
