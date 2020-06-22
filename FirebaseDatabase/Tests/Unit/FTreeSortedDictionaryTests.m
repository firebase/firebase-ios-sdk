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

#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FLLRBEmptyNode.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FLLRBNode.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FLLRBValueNode.h"
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FTreeSortedDictionary.h"

@interface FLLRBValueNode (Tests)
- (id<FLLRBNode>)rotateLeft;
- (id<FLLRBNode>)rotateRight;
@end

@interface FTreeSortedDictionaryTests : XCTestCase

@end

@implementation FTreeSortedDictionaryTests

- (NSComparator)defaultComparator {
  return ^(id obj1, id obj2) {
    if ([obj1 respondsToSelector:@selector(compare:)] &&
        [obj2 respondsToSelector:@selector(compare:)]) {
      return [obj1 compare:obj2];
    } else {
      if (obj1 < obj2) {
        return (NSComparisonResult)NSOrderedAscending;
      } else if (obj1 > obj2) {
        return (NSComparisonResult)NSOrderedDescending;
      } else {
        return (NSComparisonResult)NSOrderedSame;
      }
    }
  };
}

- (void)testCreateNode {
  FTreeSortedDictionary* map = [[[FTreeSortedDictionary alloc]
      initWithComparator:[self defaultComparator]] insertKey:@"key" withValue:@"value"];
  XCTAssertTrue([map.root.left isEmpty], @"Left child is properly empty");
  XCTAssertTrue([map.root.right isEmpty], @"Right child is properly empty");
}

- (void)testGetNilReturnsNil {
  FImmutableSortedDictionary* map1 = [[[FTreeSortedDictionary alloc]
      initWithComparator:[self defaultComparator]] insertKey:@"key" withValue:@"value"];
  XCTAssertNil([map1 get:nil]);

  FImmutableSortedDictionary* map2 =
      [[[FTreeSortedDictionary alloc] initWithComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
      }] insertKey:@"key" withValue:@"value"];
  XCTAssertNil([map2 get:nil]);
}

- (void)testSearchForSpecificKey {
  FTreeSortedDictionary* map = [[[[FTreeSortedDictionary alloc]
      initWithComparator:[self defaultComparator]] insertKey:@1 withValue:@1] insertKey:@2
                                                                              withValue:@2];

  XCTAssertEqualObjects([map get:@1], @1, @"Found first object");
  XCTAssertEqualObjects([map get:@2], @2, @"Found second object");
  XCTAssertNil([map get:@3], @"Properly not found object");
}

- (void)testInsertNewKeyValuePair {
  FTreeSortedDictionary* map = [[[[FTreeSortedDictionary alloc]
      initWithComparator:[self defaultComparator]] insertKey:@1 withValue:@1] insertKey:@2
                                                                              withValue:@2];

  XCTAssertEqualObjects(map.root.key, @2, @"Check the root key");
  XCTAssertEqualObjects(map.root.left.key, @1, @"Check the root.left key");
}

- (void)testRemoveKeyValuePair {
  FTreeSortedDictionary* map = [[[[FTreeSortedDictionary alloc]
      initWithComparator:[self defaultComparator]] insertKey:@1 withValue:@1] insertKey:@2
                                                                              withValue:@2];

  FImmutableSortedDictionary* newMap = [map removeKey:@1];
  XCTAssertEqualObjects([newMap get:@2], @2, @"Found second object");
  XCTAssertNil([newMap get:@1], @"Properly not found object");

  // Make sure the original one is not mutated
  XCTAssertEqualObjects([map get:@1], @1, @"Found first object");
  XCTAssertEqualObjects([map get:@2], @2, @"Found second object");
}

- (void)testMoreRemovals {
  FTreeSortedDictionary* map =
      [[[[[[[[[[[[[[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]]
          insertKey:@1
          withValue:@1] insertKey:@50 withValue:@50] insertKey:@3 withValue:@3] insertKey:@4
                                                                                withValue:@4]
          insertKey:@7
          withValue:@7] insertKey:@9 withValue:@9] insertKey:@20 withValue:@20] insertKey:@18
                                                                                withValue:@18]
          insertKey:@2
          withValue:@2] insertKey:@71 withValue:@71] insertKey:@42 withValue:@42] insertKey:@88
                                                                                  withValue:@88];
  XCTAssertNotNil([map get:@7], @"Found object");
  XCTAssertNotNil([map get:@3], @"Found object");
  XCTAssertNotNil([map get:@1], @"Found object");

  FImmutableSortedDictionary* m1 = [map removeKey:@7];
  FImmutableSortedDictionary* m2 = [map removeKey:@3];
  FImmutableSortedDictionary* m3 = [map removeKey:@1];

  XCTAssertNil([m1 get:@7], @"Removed object");
  XCTAssertNotNil([m1 get:@3], @"Found object");
  XCTAssertNotNil([m1 get:@1], @"Found object");

  XCTAssertNil([m2 get:@3], @"Removed object");
  XCTAssertNotNil([m2 get:@7], @"Found object");
  XCTAssertNotNil([m2 get:@1], @"Found object");

  XCTAssertNil([m3 get:@1], @"Removed object");
  XCTAssertNotNil([m3 get:@7], @"Found object");
  XCTAssertNotNil([m3 get:@3], @"Found object");
}

- (void)testRemovalBug {
  FTreeSortedDictionary* map =
      [[[[[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]]
          insertKey:@1
          withValue:@1] insertKey:@2 withValue:@2] insertKey:@3 withValue:@3];

  XCTAssertEqualObjects([map get:@1], @1, @"Found object");
  XCTAssertEqualObjects([map get:@2], @2, @"Found object");
  XCTAssertEqualObjects([map get:@3], @3, @"Found object");

  FImmutableSortedDictionary* m1 = [map removeKey:@2];
  XCTAssertEqualObjects([m1 get:@1], @1, @"Found object");
  XCTAssertEqualObjects([m1 get:@3], @3, @"Found object");
  XCTAssertNil([m1 get:@2], @"Removed object");
}

- (void)testIncreasing {
  int total = 100;

  FTreeSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];

  for (int i = 0; i < total; i++) {
    NSNumber* item = [NSNumber numberWithInt:i];
    map = [map insertKey:item withValue:item];
  }

  XCTAssertTrue([map count] == 100, @"Check if all 100 objects are in the map");
  XCTAssertTrue([map.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
  XCTAssertTrue([(FLLRBValueNode*)map.root checkMaxDepth],
                @"Checking valid depth and tree structure");

  for (int i = 0; i < total; i++) {
    NSNumber* item = [NSNumber numberWithInt:i];
    map = [map removeKey:item];
  }

  XCTAssertTrue([map count] == 0, @"Check if all 100 objects were removed");
  // We can't check the depth here because the map no longer contains values, so we check that it
  // doesn't responsd to this check
  XCTAssertTrue([map.root isMemberOfClass:[FLLRBEmptyNode class]], @"Root is an empty node");
  XCTAssertFalse([map respondsToSelector:@selector(checkMaxDepth)],
                 @"The empty node doesn't respond to this selector.");
}

- (void)testStructureShouldBeValidAfterInsertionA {
  FTreeSortedDictionary* map =
      [[[[[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]]
          insertKey:@1
          withValue:@1] insertKey:@2 withValue:@2] insertKey:@3 withValue:@3];

  XCTAssertEqualObjects(map.root.key, @2, @"Check root key");
  XCTAssertEqualObjects(map.root.left.key, @1, @"Check the left key is correct");
  XCTAssertEqualObjects(map.root.right.key, @3, @"Check the right key is correct");
}

- (void)testStructureShouldBeValidAfterInsertionB {
  FTreeSortedDictionary* map =
      [[[[[[[[[[[[[[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]]
          insertKey:@1
          withValue:@1] insertKey:@50 withValue:@50] insertKey:@3 withValue:@3] insertKey:@4
                                                                                withValue:@4]
          insertKey:@7
          withValue:@7] insertKey:@9 withValue:@9] insertKey:@20 withValue:@20] insertKey:@18
                                                                                withValue:@18]
          insertKey:@2
          withValue:@2] insertKey:@71 withValue:@71] insertKey:@42 withValue:@42] insertKey:@88
                                                                                  withValue:@88];

  XCTAssertTrue([map count] == 12, @"Check if all 12 objects are in the map");
  XCTAssertTrue([map.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
  XCTAssertTrue([(FLLRBValueNode*)map.root checkMaxDepth],
                @"Checking valid depth and tree structure");
}

- (void)testRotateLeftLeavesTreeInAValidState {
  FLLRBValueNode* node = [[FLLRBValueNode alloc]
      initWithKey:@4
        withValue:@4
        withColor:BLACK
         withLeft:[[FLLRBValueNode alloc] initWithKey:@2
                                            withValue:@2
                                            withColor:BLACK
                                             withLeft:nil
                                            withRight:nil]
        withRight:[[FLLRBValueNode alloc] initWithKey:@7
                                            withValue:@7
                                            withColor:RED
                                             withLeft:[[FLLRBValueNode alloc] initWithKey:@5
                                                                                withValue:@5
                                                                                withColor:BLACK
                                                                                 withLeft:nil
                                                                                withRight:nil]
                                            withRight:[[FLLRBValueNode alloc] initWithKey:@8
                                                                                withValue:@8
                                                                                withColor:BLACK
                                                                                 withLeft:nil
                                                                                withRight:nil]]];

  FLLRBValueNode* node2 = [node performSelector:@selector(rotateLeft)];

  XCTAssertTrue([node2 count] == 5, @"Make sure the count is correct");
  XCTAssertTrue([node2 checkMaxDepth], @"Check proper structure");
}

- (void)testRotateRightLeavesTreeInAValidState {
  FLLRBValueNode* node = [[FLLRBValueNode alloc]
      initWithKey:@7
        withValue:@7
        withColor:BLACK
         withLeft:[[FLLRBValueNode alloc] initWithKey:@4
                                            withValue:@4
                                            withColor:RED
                                             withLeft:[[FLLRBValueNode alloc] initWithKey:@2
                                                                                withValue:@2
                                                                                withColor:BLACK
                                                                                 withLeft:nil
                                                                                withRight:nil]
                                            withRight:[[FLLRBValueNode alloc] initWithKey:@5
                                                                                withValue:@5
                                                                                withColor:BLACK
                                                                                 withLeft:nil
                                                                                withRight:nil]]
        withRight:[[FLLRBValueNode alloc] initWithKey:@8
                                            withValue:@8
                                            withColor:BLACK
                                             withLeft:nil
                                            withRight:nil]];

  FLLRBValueNode* node2 = [node performSelector:@selector(rotateRight)];

  XCTAssertTrue([node2 count] == 5, @"Make sure the count is correct");
  XCTAssertEqualObjects(node2.key, @4, @"Check roots key");
  XCTAssertEqualObjects(node2.left.key, @2, @"Check first left child key");
  XCTAssertEqualObjects(node2.right.key, @7, @"Check first right child key");
  XCTAssertEqualObjects(node2.right.left.key, @5, @"Check second right left key");
  XCTAssertEqualObjects(node2.right.right.key, @8, @"Check second right left key");
}

- (void)testStructureShouldBeValidAfterInsertionC {
  FTreeSortedDictionary* map =
      [[[[[[[[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]]
          insertKey:@1
          withValue:@1] insertKey:@50 withValue:@50] insertKey:@3 withValue:@3]
          insertKey:@4
          withValue:@4] insertKey:@7 withValue:@7] insertKey:@9 withValue:@9];

  XCTAssertTrue([map count] == 6, @"Check if all 6 objects are in the map");
  XCTAssertTrue([map.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
  XCTAssertTrue([(FLLRBValueNode*)map.root checkMaxDepth],
                @"Checking valid depth and tree structure");

  FTreeSortedDictionary* m2 =
      [[[map insertKey:@20 withValue:@20] insertKey:@18 withValue:@18] insertKey:@2 withValue:@2];
  XCTAssertTrue([m2 count] == 9, @"Check if all 9 objects are in the map");
  XCTAssertTrue([m2.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
  XCTAssertTrue([(FLLRBValueNode*)m2.root checkMaxDepth],
                @"Checking valid depth and tree structure");

  FTreeSortedDictionary* m3 = [[[[m2 insertKey:@71 withValue:@71] insertKey:@42 withValue:@42]
      insertKey:@88
      withValue:@88] insertKey:@20 withValue:@20];  // Add a dupe to see if the size is correct
  XCTAssertTrue([m3 count] == 12, @"Check if all 12 (minus dupe @20) objects are in the map");
  XCTAssertTrue([m3.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
  XCTAssertTrue([(FLLRBValueNode*)m3.root checkMaxDepth],
                @"Checking valid depth and tree structure");
}

- (void)testOverride {
  FTreeSortedDictionary* map = [[[[FTreeSortedDictionary alloc]
      initWithComparator:[self defaultComparator]] insertKey:@10 withValue:@10] insertKey:@10
                                                                                withValue:@8];

  XCTAssertEqualObjects([map get:@10], @8, @"Found first object");
}
- (void)testEmpty {
  FTreeSortedDictionary* map = [[[[FTreeSortedDictionary alloc]
      initWithComparator:[self defaultComparator]] insertKey:@10 withValue:@10] removeKey:@10];

  XCTAssertTrue([map isEmpty], @"Properly empty");
}

- (void)testEmptyGet {
  FTreeSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];
  XCTAssertNil([map get:@"something"], @"Properly nil");
}

- (void)testEmptyCount {
  FTreeSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];
  XCTAssertTrue([map count] == 0, @"Properly zero count");
}

- (void)testEmptyRemoval {
  FTreeSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];
  XCTAssertTrue([[map removeKey:@"sometjhing"] count] == 0, @"Properly zero count");
}

- (void)testReverseTraversal {
  FTreeSortedDictionary* map =
      [[[[[[[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]] insertKey:@1
                                                                                       withValue:@1]
          insertKey:@5
          withValue:@5] insertKey:@3 withValue:@3] insertKey:@2 withValue:@2] insertKey:@4
                                                                              withValue:@4];

  __block int next = 5;
  [map enumerateKeysAndObjectsReverse:YES
                           usingBlock:^(id key, id value, BOOL* stop) {
                             XCTAssertEqualObjects(key, [NSNumber numberWithInt:next],
                                                   @"Properly equal");
                             next = next - 1;
                           }];
}

- (void)testInsertionAndRemovalOfAHundredItems {
  int N = 100;
  NSMutableArray* toInsert = [[NSMutableArray alloc] initWithCapacity:N];
  NSMutableArray* toRemove = [[NSMutableArray alloc] initWithCapacity:N];

  for (int i = 0; i < N; i++) {
    [toInsert addObject:[NSNumber numberWithInt:i]];
    [toRemove addObject:[NSNumber numberWithInt:i]];
  }

  [self shuffleArray:toInsert];
  [self shuffleArray:toRemove];

  FTreeSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (int i = 0; i < N; i++) {
    map = [map insertKey:[toInsert objectAtIndex:i] withValue:[toInsert objectAtIndex:i]];
    XCTAssertTrue([map.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
    XCTAssertTrue([(FLLRBValueNode*)map.root checkMaxDepth],
                  @"Checking valid depth and tree structure");
  }
  XCTAssertTrue([map count] == N, @"Check if all N objects are in the map");

  // check the order is correct
  __block int next = 0;
  [map enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
    XCTAssertEqualObjects(key, [NSNumber numberWithInt:next], @"Correct key");
    XCTAssertEqualObjects(value, [NSNumber numberWithInt:next], @"Correct value");
    next = next + 1;
  }];
  XCTAssertEqual(next, N, @"Check we traversed all of the items");

  // remove them

  for (int i = 0; i < N; i++) {
    if ([map.root isMemberOfClass:[FLLRBValueNode class]]) {
      XCTAssertTrue([map.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
      XCTAssertTrue([(FLLRBValueNode*)map.root checkMaxDepth],
                    @"Checking valid depth and tree structure");
    }
    map = [map removeKey:[toRemove objectAtIndex:i]];
  }

  XCTAssertEqual([map count], 0, @"Check we removed all of the items");
}

- (void)shuffleArray:(NSMutableArray*)array {
  NSUInteger count = [array count];
  for (NSUInteger i = 0; i < count; i++) {
    NSInteger nElements = count - i;
    NSInteger n = (arc4random() % nElements) + i;
    [array exchangeObjectAtIndex:i withObjectAtIndex:n];
  }
}

- (void)testBalanceProblem {
  NSArray* toInsert = [[NSArray alloc] initWithObjects:@1, @7, @8, @5, @2, @6, @4, @0, @3, nil];

  FTreeSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (int i = 0; i < [toInsert count]; i++) {
    map = [map insertKey:[toInsert objectAtIndex:i] withValue:[toInsert objectAtIndex:i]];
    XCTAssertTrue([map.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
    XCTAssertTrue([(FLLRBValueNode*)map.root checkMaxDepth],
                  @"Checking valid depth and tree structure");
  }
  XCTAssertTrue([map count] == [toInsert count], @"Check if all N objects are in the map");

  // check the order is correct
  __block int next = 0;
  [map enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
    XCTAssertEqualObjects(key, [NSNumber numberWithInt:next], @"Correct key");
    XCTAssertEqualObjects(value, [NSNumber numberWithInt:next], @"Correct value");
    next = next + 1;
  }];
  XCTAssertEqual(next, [[NSNumber numberWithUnsignedInteger:[toInsert count]] intValue],
                 @"Check we traversed all of the items");

  // removing one triggers the balance problem

  map = [map removeKey:@5];

  if ([map.root isMemberOfClass:[FLLRBValueNode class]]) {
    XCTAssertTrue([map.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
    XCTAssertTrue([(FLLRBValueNode*)map.root checkMaxDepth],
                  @"Checking valid depth and tree structure");
  }
}

- (void)testPredecessorKey {
  FTreeSortedDictionary* map =
      [[[[[[[[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]]
          insertKey:@1
          withValue:@1] insertKey:@50 withValue:@50] insertKey:@3 withValue:@3]
          insertKey:@4
          withValue:@4] insertKey:@7 withValue:@7] insertKey:@9 withValue:@9];

  XCTAssertNil([map getPredecessorKey:@1], @"First object doesn't have a predecessor");
  XCTAssertEqualObjects([map getPredecessorKey:@3], @1, @"@1");
  XCTAssertEqualObjects([map getPredecessorKey:@4], @3, @"@3");
  XCTAssertEqualObjects([map getPredecessorKey:@7], @4, @"@4");
  XCTAssertEqualObjects([map getPredecessorKey:@9], @7, @"@7");
  XCTAssertEqualObjects([map getPredecessorKey:@50], @9, @"@9");
  XCTAssertThrows([map getPredecessorKey:@777], @"Expect exception about nonexistant key");
}

- (void)testEnumerator {
  int N = 100;
  NSMutableArray* toInsert = [[NSMutableArray alloc] initWithCapacity:N];
  NSMutableArray* toRemove = [[NSMutableArray alloc] initWithCapacity:N];

  for (int i = 0; i < N; i++) {
    [toInsert addObject:[NSNumber numberWithInt:i]];
    [toRemove addObject:[NSNumber numberWithInt:i]];
  }

  [self shuffleArray:toInsert];
  [self shuffleArray:toRemove];

  FTreeSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (int i = 0; i < N; i++) {
    map = [map insertKey:[toInsert objectAtIndex:i] withValue:[toInsert objectAtIndex:i]];
    XCTAssertTrue([map.root isMemberOfClass:[FLLRBValueNode class]], @"Root is a value node");
    XCTAssertTrue([(FLLRBValueNode*)map.root checkMaxDepth],
                  @"Checking valid depth and tree structure");
  }
  XCTAssertTrue([map count] == N, @"Check if all N objects are in the map");

  NSEnumerator* enumerator = [map keyEnumerator];
  id next = [enumerator nextObject];
  int correctValue = 0;
  while (next != nil) {
    XCTAssertEqualObjects(next, [NSNumber numberWithInt:correctValue], @"Correct key");
    next = [enumerator nextObject];
    correctValue = correctValue + 1;
  }
}

- (void)testReverseEnumerator {
  int N = 20;
  NSMutableArray* toInsert = [[NSMutableArray alloc] initWithCapacity:N];

  for (int i = 0; i < N; i++) {
    [toInsert addObject:[NSNumber numberWithInt:i]];
  }

  [self shuffleArray:toInsert];

  FImmutableSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (int i = 0; i < N; i++) {
    map = [map insertKey:[toInsert objectAtIndex:i] withValue:[toInsert objectAtIndex:i]];
  }
  XCTAssertTrue([map count] == N, @"Check if all N objects are in the map");
  XCTAssertTrue([map isKindOfClass:[FTreeSortedDictionary class]],
                @"Make sure we still have a array backed dictionary");

  NSEnumerator* enumerator = [map reverseKeyEnumerator];
  id next = [enumerator nextObject];
  int correctValue = N - 1;
  while (next != nil) {
    XCTAssertEqualObjects(next, [NSNumber numberWithInt:correctValue], @"Correct key");
    next = [enumerator nextObject];
    correctValue--;
  }
}

- (void)testEnumeratorFrom {
  int N = 20;
  NSMutableArray* toInsert = [[NSMutableArray alloc] initWithCapacity:N];

  for (int i = 0; i < N; i++) {
    [toInsert addObject:[NSNumber numberWithInt:i * 2]];
  }

  [self shuffleArray:toInsert];

  FImmutableSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (int i = 0; i < N; i++) {
    map = [map insertKey:[toInsert objectAtIndex:i] withValue:[toInsert objectAtIndex:i]];
  }
  XCTAssertTrue([map count] == N, @"Check if all N objects are in the map");
  XCTAssertTrue([map isKindOfClass:[FTreeSortedDictionary class]],
                @"Make sure we still have a array backed dictionary");

  // Test from inbetween keys
  {
    NSEnumerator* enumerator = [map keyEnumeratorFrom:@11];
    id next = [enumerator nextObject];
    int correctValue = 12;
    while (next != nil) {
      XCTAssertEqualObjects(next, [NSNumber numberWithInt:correctValue], @"Correct key");
      next = [enumerator nextObject];
      correctValue = correctValue + 2;
    }
  }

  // Test from key in map
  {
    NSEnumerator* enumerator = [map keyEnumeratorFrom:@10];
    id next = [enumerator nextObject];
    int correctValue = 10;
    while (next != nil) {
      XCTAssertEqualObjects(next, [NSNumber numberWithInt:correctValue], @"Correct key");
      next = [enumerator nextObject];
      correctValue = correctValue + 2;
    }
  }
}

- (void)testReverseEnumeratorFrom {
  int N = 20;
  NSMutableArray* toInsert = [[NSMutableArray alloc] initWithCapacity:N];

  for (int i = 0; i < N; i++) {
    [toInsert addObject:[NSNumber numberWithInt:i * 2]];
  }

  [self shuffleArray:toInsert];

  FImmutableSortedDictionary* map =
      [[FTreeSortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (int i = 0; i < N; i++) {
    map = [map insertKey:[toInsert objectAtIndex:i] withValue:[toInsert objectAtIndex:i]];
  }
  XCTAssertTrue([map count] == N, @"Check if all N objects are in the map");
  XCTAssertTrue([map isKindOfClass:[FTreeSortedDictionary class]],
                @"Make sure we still have a array backed dictionary");

  // Test from inbetween keys
  {
    NSEnumerator* enumerator = [map reverseKeyEnumeratorFrom:@11];
    id next = [enumerator nextObject];
    int correctValue = 10;
    while (next != nil) {
      XCTAssertEqualObjects(next, [NSNumber numberWithInt:correctValue], @"Correct key");
      next = [enumerator nextObject];
      correctValue = correctValue - 2;
    }
  }

  // Test from key in map
  {
    NSEnumerator* enumerator = [map reverseKeyEnumeratorFrom:@10];
    id next = [enumerator nextObject];
    int correctValue = 10;
    while (next != nil) {
      XCTAssertEqualObjects(next, [NSNumber numberWithInt:correctValue], @"Correct key");
      next = [enumerator nextObject];
      correctValue = correctValue - 2;
    }
  }
}

@end
