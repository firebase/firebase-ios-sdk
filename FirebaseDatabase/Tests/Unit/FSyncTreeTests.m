/*
 * Copyright 2026 Google LLC
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

#import "FirebaseDatabase/Sources/Core/FListenProvider.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Core/FSyncTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FImmutableTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FSyncTree (Testing)

- (FImmutableTree *)syncPointTree;

@end

@interface FSyncTreeTests : XCTestCase

@property(nonatomic, strong) FSyncTree *syncTree;
/** The tags of the queries that the sync tree started listening to, in order. */
@property(nonatomic, strong) NSMutableArray<NSNumber *> *listenTags;

@end

@implementation FSyncTreeTests

- (void)setUp {
  [super setUp];
  NSMutableArray<NSNumber *> *listenTags = [NSMutableArray array];
  FListenProvider *listenProvider = [[FListenProvider alloc] init];
  listenProvider.startListening = ^NSArray *(
      FQuerySpec *query, NSNumber *tagId, id<FSyncTreeHash> hash, fbt_nsarray_nsstring onComplete) {
    if (tagId != nil) {
      [listenTags addObject:tagId];
    }
    return @[];
  };
  listenProvider.stopListening = ^(FQuerySpec *query, NSNumber *tagId) {
  };
  self.listenTags = listenTags;
  self.syncTree = [[FSyncTree alloc] initWithListenProvider:listenProvider];
}

- (void)testGetServerValueAtSyncedPathReturnsValue {
  [self syncQuery:[FQuerySpec defaultQueryAtPath:PATH(@"cashiers")]
      withServerData:@{@"a" : @{@"name" : @"Test"}}];

  id<FNode> value =
      [self.syncTree getServerValue:[FQuerySpec defaultQueryAtPath:PATH(@"cashiers")]];

  XCTAssertEqualObjects([value val], (@{@"a" : @{@"name" : @"Test"}}));
}

- (void)testGetServerValueForChildOfSyncedPathReturnsChild {
  [self syncQuery:[FQuerySpec defaultQueryAtPath:PATH(@"cashiers")]
      withServerData:@{@"a" : @{@"name" : @"Test"}, @"b" : @{@"name" : @"Test2"}}];

  id<FNode> value =
      [self.syncTree getServerValue:[FQuerySpec defaultQueryAtPath:PATH(@"cashiers/a")]];

  XCTAssertEqualObjects([value val], (@{@"name" : @"Test"}));
}

- (void)testGetServerValueForGrandchildOfSyncedPathReturnsGrandchild {
  [self syncQuery:[FQuerySpec defaultQueryAtPath:PATH(@"cashiers")]
      withServerData:@{@"a" : @{@"name" : @"Test"}, @"b" : @{@"name" : @"Test2"}}];

  id<FNode> value =
      [self.syncTree getServerValue:[FQuerySpec defaultQueryAtPath:PATH(@"cashiers/a/name")]];

  XCTAssertEqualObjects([value val], @"Test");
}

- (void)testGetServerValueForChildOfFilteredQueryReturnsChild {
  FQueryParams *params = [[FQueryParams defaultInstance] limitToFirst:1];
  [self syncQuery:[[FQuerySpec alloc] initWithPath:PATH(@"cashiers") params:params]
      withServerData:@{@"a" : @{@"name" : @"Test"}}];

  id<FNode> value =
      [self.syncTree getServerValue:[FQuerySpec defaultQueryAtPath:PATH(@"cashiers/a")]];

  XCTAssertEqualObjects([value val], (@{@"name" : @"Test"}));
}

- (void)testGetServerValueForFilteredQueryUnderSyncedPathAppliesFilter {
  FQueryParams *params = [[FQueryParams defaultInstance] limitToFirst:1];
  [self syncQuery:[FQuerySpec defaultQueryAtPath:PATH(@"shop")]
      withServerData:@{@"cashiers" : @{@"a" : @{@"name" : @"Test"}, @"b" : @{@"name" : @"Test2"}}}];
  // The synced path also has a view for the same params, which holds the data at that path.
  [self.syncTree keepQuery:[[FQuerySpec alloc] initWithPath:PATH(@"shop") params:params]
                    synced:YES];

  id<FNode> value = [self.syncTree
      getServerValue:[[FQuerySpec alloc] initWithPath:PATH(@"shop/cashiers") params:params]];

  XCTAssertEqualObjects([value val], (@{@"a" : @{@"name" : @"Test"}}));
}

- (void)testGetServerValueForUnsyncedPathReturnsNilAndAddsNoSyncPoint {
  id<FNode> value =
      [self.syncTree getServerValue:[FQuerySpec defaultQueryAtPath:PATH(@"cashiers/a")]];

  XCTAssertNil(value);
  XCTAssertTrue([self.syncTree syncPointTree].isEmpty);
}

/** Keeps `query` synced, and applies `data` from the server to it. */
- (void)syncQuery:(FQuerySpec *)query withServerData:(id)data {
  [self.syncTree keepQuery:query synced:YES];
  if (query.loadsAllData) {
    [self.syncTree applyServerOverwriteAtPath:query.path newData:NODE(data)];
  } else {
    [self.syncTree applyTaggedQueryOverwriteAtPath:query.path
                                           newData:NODE(data)
                                             tagId:self.listenTags.lastObject];
  }
}

@end
