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

#import <Foundation/Foundation.h>

#import "FirebaseDatabase/Sources/Core/FCompoundHash.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Utilities/FStringUtilities.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FCompoundHashTest : XCTestCase

@end

@implementation FCompoundHashTest

static FCompoundHashSplitStrategy NEVER_SPLIT_STRATEGY = ^BOOL(FCompoundHashBuilder *builder) {
  return NO;
};

- (FCompoundHashSplitStrategy)splitAtPaths:(NSArray *)paths {
  return ^BOOL(FCompoundHashBuilder *builder) {
    return [paths containsObject:builder.currentPath];
  };
}

- (void)testEmptyNodeYieldsEmptyHash {
  FCompoundHash *hash = [FCompoundHash fromNode:[FEmptyNode emptyNode]];
  XCTAssertEqualObjects(hash.posts, @[]);
  XCTAssertEqualObjects(hash.hashes, @[ @"" ]);
}

- (void)testCompoundHashIsAlwaysFollowedByEmptyHash {
  id<FNode> node = NODE(@{@"foo" : @"bar"});
  FCompoundHash *hash = [FCompoundHash fromNode:node splitStrategy:NEVER_SPLIT_STRATEGY];
  NSString *expectedHash = [FStringUtilities base64EncodedSha1:@"(\"foo\":(string:\"bar\"))"];

  XCTAssertEqualObjects(hash.posts, @[ PATH(@"foo") ]);
  XCTAssertEqualObjects(hash.hashes, (@[ expectedHash, @"" ]));
}

- (void)testCompoundHashCanSplitAtPriority {
  id<FNode> node = NODE((@{
    @"foo" : @{@"!beforePriority" : @"before", @".priority" : @"prio", @"afterPriority" : @"after"},
    @"qux" : @"qux"
  }));
  FCompoundHash *hash = [FCompoundHash fromNode:node
                                  splitStrategy:[self splitAtPaths:@[ PATH(@"foo/.priority") ]]];
  NSString *firstHash = [FStringUtilities
      base64EncodedSha1:
          @"(\"foo\":(\"!beforePriority\":(string:\"before\"),\".priority\":(string:\"prio\")))"];
  NSString *secondHash = [FStringUtilities
      base64EncodedSha1:
          @"(\"foo\":(\"afterPriority\":(string:\"after\")),\"qux\":(string:\"qux\"))"];
  XCTAssertEqualObjects(hash.posts, (@[ PATH(@"foo/.priority"), PATH(@"qux") ]));
  XCTAssertEqualObjects(hash.hashes, (@[ firstHash, secondHash, @"" ]));
}

- (void)testHashesPriorityLeafNodes {
  id<FNode> node = NODE((@{@"foo" : @{@".value" : @"bar", @".priority" : @"baz"}}));
  FCompoundHash *hash = [FCompoundHash fromNode:node splitStrategy:NEVER_SPLIT_STRATEGY];
  NSString *expectedHash =
      [FStringUtilities base64EncodedSha1:@"(\"foo\":(priority:string:\"baz\":string:\"bar\"))"];

  XCTAssertEqualObjects(hash.posts, @[ PATH(@"foo") ]);
  XCTAssertEqualObjects(hash.hashes, (@[ expectedHash, @"" ]));
}

- (void)testHashingFollowsFirebaseKeySemantics {
  id<FNode> node = NODE((@{@"1" : @"one", @"2" : @"two", @"10" : @"ten"}));
  // 10 is after 2 in Firebase key semantics, but would be before 2 in string semantics
  FCompoundHash *hash = [FCompoundHash fromNode:node
                                  splitStrategy:[self splitAtPaths:@[ PATH(@"2") ]]];
  NSString *firstHash =
      [FStringUtilities base64EncodedSha1:@"(\"1\":(string:\"one\"),\"2\":(string:\"two\"))"];
  NSString *secondHash = [FStringUtilities base64EncodedSha1:@"(\"10\":(string:\"ten\"))"];
  XCTAssertEqualObjects(hash.posts, (@[ PATH(@"2"), PATH(@"10") ]));
  XCTAssertEqualObjects(hash.hashes, (@[ firstHash, secondHash, @"" ]));
}

- (void)testHashingOnChildBoundariesWorks {
  id<FNode> node = NODE((@{@"bar" : @{@"deep" : @"value"}, @"foo" : @{@"other-deep" : @"value"}}));
  FCompoundHash *hash = [FCompoundHash fromNode:node
                                  splitStrategy:[self splitAtPaths:@[ PATH(@"bar/deep") ]]];
  NSString *firstHash =
      [FStringUtilities base64EncodedSha1:@"(\"bar\":(\"deep\":(string:\"value\")))"];
  NSString *secondHash =
      [FStringUtilities base64EncodedSha1:@"(\"foo\":(\"other-deep\":(string:\"value\")))"];
  XCTAssertEqualObjects(hash.posts, (@[ PATH(@"bar/deep"), PATH(@"foo/other-deep") ]));
  XCTAssertEqualObjects(hash.hashes, (@[ firstHash, secondHash, @"" ]));
}

- (void)testCommasAreSetForNestedChildren {
  id<FNode> node = NODE((@{@"bar" : @{@"deep" : @"value"}, @"foo" : @{@"other-deep" : @"value"}}));
  FCompoundHash *hash = [FCompoundHash fromNode:node splitStrategy:NEVER_SPLIT_STRATEGY];
  NSString *expectedHash = [FStringUtilities
      base64EncodedSha1:
          @"(\"bar\":(\"deep\":(string:\"value\")),\"foo\":(\"other-deep\":(string:\"value\")))"];

  XCTAssertEqualObjects(hash.posts, @[ PATH(@"foo/other-deep") ]);
  XCTAssertEqualObjects(hash.hashes, (@[ expectedHash, @"" ]));
}

- (void)testQuotedStringsAndKeys {
  id<FNode> node = NODE((@{@"\"" : @"\\", @"\"\\\"\\" : @"\"\\\"\\"}));
  FCompoundHash *hash = [FCompoundHash fromNode:node splitStrategy:NEVER_SPLIT_STRATEGY];
  NSString *expectedHash = [FStringUtilities
      base64EncodedSha1:
          @"(\"\\\"\":(string:\"\\\\\"),\"\\\"\\\\\\\"\\\\\":(string:\"\\\"\\\\\\\"\\\\\"))"];

  XCTAssertEqualObjects(hash.posts, @[ PATH(@"\"\\\"\\") ]);
  XCTAssertEqualObjects(hash.hashes, (@[ expectedHash, @"" ]));
}

- (void)testDefaultSplitHasSensibleAmountOfHashes {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  for (int i = 0; i < 500; i++) {
    // roughly 15-20 bytes serialized per node, 10k total
    dict[[NSString stringWithFormat:@"%d", i]] = @"value";
  }
  id<FNode> node10k = NODE(dict);

  dict = [NSMutableDictionary dictionary];
  for (int i = 0; i < 5000; i++) {
    // roughly 15-20 bytes serialized per node, 100k total
    dict[[NSString stringWithFormat:@"%d", i]] = @"value";
  }
  id<FNode> node100k = NODE(dict);

  dict = [NSMutableDictionary dictionary];
  for (int i = 0; i < 50000; i++) {
    // roughly 15-20 bytes serialized per node, 1M total
    dict[[NSString stringWithFormat:@"%d", i]] = @"value";
  }
  id<FNode> node1M = NODE(dict);

  FCompoundHash *hash10k = [FCompoundHash fromNode:node10k];
  FCompoundHash *hash100k = [FCompoundHash fromNode:node100k];
  FCompoundHash *hash1M = [FCompoundHash fromNode:node1M];
  XCTAssertEqualWithAccuracy(hash10k.hashes.count, 15, 3);
  XCTAssertEqualWithAccuracy(hash100k.hashes.count, 50, 5);
  XCTAssertEqualWithAccuracy(hash1M.hashes.count, 150, 10);
}

@end
