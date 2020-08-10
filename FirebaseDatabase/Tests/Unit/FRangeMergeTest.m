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

#import <XCTest/XCTest.h>

#import "FirebaseDatabase/Sources/Core/FRangeMerge.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FNode.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FRangeMergeTest : XCTestCase

@end

@implementation FRangeMergeTest

- (void)testSmokeTest {
  id<FNode> node = NODE((@{
    @"bar" : @"bar-value",
    @"foo" : @{@"a" : @{@"deep-a-1" : @1, @"deep-a-2" : @2}, @"b" : @"b", @"c" : @"c", @"d" : @"d"},
    @"quu" : @"quu-value"
  }));

  id<FNode> updates = NODE((@{
    @"foo" :
        @{@"a" : @{@"deep-a-2" : @"new-a-2", @"deep-a-3" : @3}, @"b-2" : @"new-b", @"c" : @"new-c"}
  }));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"foo/a/deep-a-1")
                                                      end:PATH(@"foo/c")
                                                  updates:updates];

  id<FNode> expected = NODE((@{
    @"bar" : @"bar-value",
    @"foo" : @{
      @"a" : @{@"deep-a-1" : @1, @"deep-a-2" : @"new-a-2", @"deep-a-3" : @3},
      @"b-2" : @"new-b",
      @"c" : @"new-c",
      @"d" : @"d"
    },
    @"quu" : @"quu-value"
  }));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testStartIsExclusive {
  id<FNode> node = NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value", @"quu" : @"quu-value"}));

  id<FNode> updates = NODE((@{@"foo" : @"new-foo-value"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"bar")
                                                      end:PATH(@"foo")
                                                  updates:updates];

  id<FNode> expected =
      NODE((@{@"bar" : @"bar-value", @"foo" : @"new-foo-value", @"quu" : @"quu-value"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testStartIsExclusiveButIncludesChildren {
  id<FNode> node = NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value", @"quu" : @"quu-value"}));

  id<FNode> updates =
      NODE((@{@"bar" : @{@"bar-child" : @"bar-child-value"}, @"foo" : @"new-foo-value"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"bar")
                                                      end:PATH(@"foo")
                                                  updates:updates];

  id<FNode> expected = NODE((@{
    @"bar" : @{@"bar-child" : @"bar-child-value"},
    @"foo" : @"new-foo-value",
    @"quu" : @"quu-value"
  }));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testEndIsInclusive {
  id<FNode> node = NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value", @"quu" : @"quu-value"}));

  id<FNode> updates = NODE((@{@"baz" : @"baz-value"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"bar")
                                                      end:PATH(@"foo")
                                                  updates:updates];  // foo should be deleted

  id<FNode> expected =
      NODE((@{@"bar" : @"bar-value", @"baz" : @"baz-value", @"quu" : @"quu-value"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testEndIsInclusiveButExcludesChildren {
  id<FNode> node = NODE((@{
    @"bar" : @"bar-value",
    @"foo" : @{@"foo-child" : @"foo-child-value"},
    @"quu" : @"quu-value"
  }));

  id<FNode> updates = NODE((@{@"baz" : @"baz-value"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"bar")
                                                      end:PATH(@"foo")
                                                  updates:updates];  // foo should be deleted

  id<FNode> expected = NODE((@{
    @"bar" : @"bar-value",
    @"baz" : @"baz-value",
    @"foo" : @{@"foo-child" : @"foo-child-value"},
    @"quu" : @"quu-value"
  }));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testCanUpdateLeafNode {
  id<FNode> node = NODE(@"leaf-value");

  id<FNode> updates = NODE((@{@"bar" : @"bar-value"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil end:PATH(@"foo") updates:updates];
  id<FNode> expected = NODE((@{@"bar" : @"bar-value"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testCanReplaceLeafNodeWithLeafNode {
  id<FNode> node = NODE(@"leaf-value");

  id<FNode> updates = NODE(@"new-leaf-value");

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil end:PATH(@"") updates:updates];
  id<FNode> expected = NODE(@"new-leaf-value");
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testLeafsAreUpdatedWhenRangesIncludeDeeperPath {
  id<FNode> node = NODE((@{@"foo" : @{@"bar" : @"bar-value"}}));

  id<FNode> updates = NODE((@{@"foo" : @{@"bar" : @"new-bar-value"}}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"foo")
                                                      end:PATH(@"foo/bar/deep")
                                                  updates:updates];

  id<FNode> expected = NODE((@{@"foo" : @{@"bar" : @"new-bar-value"}}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testLeafsAreNotUpdatedWhenRangesIncludeDeeperPaths {
  id<FNode> node = NODE((@{@"foo" : @{@"bar" : @"bar-value"}}));

  id<FNode> updates = NODE((@{@"foo" : @{@"bar" : @"new-bar-value"}}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"foo/bar")
                                                      end:PATH(@"foo/bar/deep")
                                                  updates:updates];

  id<FNode> expected = NODE((@{@"foo" : @{@"bar" : @"bar-value"}}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testUpdatingEntireRangeUpdatesEverything {
  id<FNode> node = [FEmptyNode emptyNode];

  id<FNode> updates = NODE((@{@"foo" : @"foo-value", @"bar" : @{@"child" : @"bar-child-value"}}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil end:nil updates:updates];

  id<FNode> expected = NODE((@{@"foo" : @"foo-value", @"bar" : @{@"child" : @"bar-child-value"}}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testUpdatingRangeWithUnboundedLeftPostWorks {
  id<FNode> node = NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value"}));

  id<FNode> updates = NODE((@{@"bar" : @"new-bar"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil end:PATH(@"bar") updates:updates];

  id<FNode> expected = NODE((@{@"bar" : @"new-bar", @"foo" : @"foo-value"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testUpdatingRangeWithRightPostChildOfLeftPostWorks {
  id<FNode> node =
      NODE((@{@"foo" : @{@"a" : @"a", @"b" : @{@"1" : @"1", @"2" : @"2"}, @"c" : @"c"}}));

  id<FNode> updates = NODE((@{@"foo" : @{@"a" : @"new-a", @"b" : @{@"1" : @"new-1"}}}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"foo")
                                                      end:PATH(@"foo/b/1")
                                                  updates:updates];

  id<FNode> expected =
      NODE((@{@"foo" : @{@"a" : @"new-a", @"b" : @{@"1" : @"new-1", @"2" : @"2"}, @"c" : @"c"}}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testUpdatingRangeWithRightPostChildOfLeftPostWorksWithIntegerKeys {
  id<FNode> node = NODE(
      (@{@"foo" : @{@"a" : @"a", @"b" : @{@"1" : @"1", @"2" : @"2", @"10" : @"10"}, @"c" : @"c"}}));

  id<FNode> updates = NODE((@{@"foo" : @{@"a" : @"new-a", @"b" : @{@"1" : @"new-1"}}}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"foo")
                                                      end:PATH(@"foo/b/2")
                                                  updates:updates];

  id<FNode> expected =
      NODE((@{@"foo" : @{@"a" : @"new-a", @"b" : @{@"1" : @"new-1", @"10" : @"10"}, @"c" : @"c"}}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testUpdatingLeafIncludesPriority {
  id<FNode> node = NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value", @"quu" : @"quu-value"}));

  id<FNode> updates = NODE((@{@"foo" : @{@".value" : @"new-foo", @".priority" : @"prio"}}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"bar")
                                                      end:PATH(@"foo")
                                                  updates:updates];

  id<FNode> expected = NODE((@{
    @"bar" : @"bar-value",
    @"foo" : @{@".value" : @"new-foo", @".priority" : @"prio"},
    @"quu" : @"quu-value"
  }));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testUpdatingPriorityInChildrenNodeWorks {
  id<FNode> node = NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value"}));

  id<FNode> updates = NODE((@{@"bar" : @"new-bar", @".priority" : @"prio"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil end:PATH(@"bar") updates:updates];

  id<FNode> expected =
      NODE((@{@"bar" : @"new-bar", @"foo" : @"foo-value", @".priority" : @"prio"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

// TODO: this test should actuall;y work, but priorities on empty nodes are ignored :(
- (void)updatingPriorityInChildrenNodeWorksAlone {
  id<FNode> node = NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value"}));

  id<FNode> updates = NODE((@{@".priority" : @"prio"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil
                                                      end:PATH(@".priority")
                                                  updates:updates];

  id<FNode> expected =
      NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value", @".priority" : @"prio"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testUpdatingPriorityOnInitiallyEmptyNodeDoesNotBreak {
  id<FNode> node = NODE((@{}));

  id<FNode> updates = NODE((@{@".priority" : @"prio", @"foo" : @"foo-value"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil end:PATH(@"foo") updates:updates];

  id<FNode> expected = NODE((@{@"foo" : @"foo-value", @".priority" : @"prio"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testPriorityIsDeletedWhenIncludedInChildrenRange {
  id<FNode> node = NODE((@{@"bar" : @"bar-value", @"foo" : @"foo-value", @".priority" : @"prio"}));

  id<FNode> updates = NODE((@{@"bar" : @"new-bar"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil
                                                      end:PATH(@"bar")
                                                  updates:updates];  // deletes priority

  id<FNode> expected = NODE((@{@"bar" : @"new-bar", @"foo" : @"foo-value"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testPriorityIsIncludedInOpenStart {
  id<FNode> node = NODE((@{@"foo" : @{@"bar" : @"bar-value"}}));

  id<FNode> updates = NODE((@{@".priority" : @"prio", @"baz" : @"baz"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:nil end:PATH(@"foo/bar") updates:updates];

  id<FNode> expected = NODE((@{@"baz" : @"baz", @".priority" : @"prio"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testPriorityIsIncludedInOpenEnd {
  id<FNode> node = NODE(@"leaf-node");

  id<FNode> updates = NODE((@{@".priority" : @"prio", @"foo" : @"bar"}));

  FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:PATH(@"/") end:nil updates:updates];

  id<FNode> expected = NODE((@{@"foo" : @"bar", @".priority" : @"prio"}));
  id<FNode> actual = [merge applyToNode:node];
  XCTAssertEqualObjects(actual, expected);
}

@end
