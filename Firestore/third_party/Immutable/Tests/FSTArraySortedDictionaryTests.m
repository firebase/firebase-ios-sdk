#import "Firestore/third_party/Immutable/FSTArraySortedDictionary.h"

#import <XCTest/XCTest.h>

#import "Firestore/Source/Util/FSTAssert.h"

@interface FSTArraySortedDictionary (Test)
// Override methods to return subtype.
- (FSTArraySortedDictionary *)dictionaryBySettingObject:(id)aValue forKey:(id)aKey;
- (FSTArraySortedDictionary *)dictionaryByRemovingObjectForKey:(id)aKey;
@end

@interface FSTArraySortedDictionaryTests : XCTestCase
@end

@implementation FSTArraySortedDictionaryTests

- (NSComparator)defaultComparator {
  return ^(id obj1, id obj2) {
    FSTAssert([obj1 respondsToSelector:@selector(compare:)] &&
                  [obj2 respondsToSelector:@selector(compare:)],
              @"Objects must support compare: %@ %@", obj1, obj2);
    return [obj1 compare:obj2];
  };
}

- (void)testSearchForSpecificKey {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@1 forKey:@1];
  map = [map dictionaryBySettingObject:@2 forKey:@2];

  XCTAssertEqualObjects([map objectForKey:@1], @1, @"Found first object");
  XCTAssertEqualObjects([map objectForKey:@2], @2, @"Found second object");
  XCTAssertEqualObjects(map[@1], @1, @"Found first object");
  XCTAssertEqualObjects(map[@2], @2, @"Found second object");
  XCTAssertNil([map objectForKey:@3], @"Properly not found object");
}

- (void)testRemoveKeyValuePair {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@1 forKey:@1];
  map = [map dictionaryBySettingObject:@2 forKey:@2];

  FSTImmutableSortedDictionary *newMap = [map dictionaryByRemovingObjectForKey:@1];
  XCTAssertEqualObjects([newMap objectForKey:@2], @2, @"Found second object");
  XCTAssertNil([newMap objectForKey:@1], @"Properly not found object");

  // Make sure the original one is not mutated
  XCTAssertEqualObjects([map objectForKey:@1], @1, @"Found first object");
  XCTAssertEqualObjects([map objectForKey:@2], @2, @"Found second object");
}

- (void)testMoreRemovals {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@1 forKey:@1];
  map = [map dictionaryBySettingObject:@50 forKey:@50];
  map = [map dictionaryBySettingObject:@3 forKey:@3];
  map = [map dictionaryBySettingObject:@4 forKey:@4];
  map = [map dictionaryBySettingObject:@7 forKey:@7];
  map = [map dictionaryBySettingObject:@9 forKey:@9];
  map = [map dictionaryBySettingObject:@1 forKey:@20];
  map = [map dictionaryBySettingObject:@18 forKey:@18];
  map = [map dictionaryBySettingObject:@3 forKey:@2];
  map = [map dictionaryBySettingObject:@4 forKey:@71];
  map = [map dictionaryBySettingObject:@7 forKey:@42];
  map = [map dictionaryBySettingObject:@9 forKey:@88];

  XCTAssertNotNil([map objectForKey:@7], @"Found object");
  XCTAssertNotNil([map objectForKey:@3], @"Found object");
  XCTAssertNotNil([map objectForKey:@1], @"Found object");

  FSTImmutableSortedDictionary *m1 = [map dictionaryByRemovingObjectForKey:@7];
  FSTImmutableSortedDictionary *m2 = [map dictionaryByRemovingObjectForKey:@3];
  FSTImmutableSortedDictionary *m3 = [map dictionaryByRemovingObjectForKey:@1];

  XCTAssertNil([m1 objectForKey:@7], @"Removed object");
  XCTAssertNotNil([m1 objectForKey:@3], @"Found object");
  XCTAssertNotNil([m1 objectForKey:@1], @"Found object");

  XCTAssertNil([m2 objectForKey:@3], @"Removed object");
  XCTAssertNotNil([m2 objectForKey:@7], @"Found object");
  XCTAssertNotNil([m2 objectForKey:@1], @"Found object");

  XCTAssertNil([m3 objectForKey:@1], @"Removed object");
  XCTAssertNotNil([m3 objectForKey:@7], @"Found object");
  XCTAssertNotNil([m3 objectForKey:@3], @"Found object");
}

- (void)testRemovalBug {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@1 forKey:@1];
  map = [map dictionaryBySettingObject:@2 forKey:@2];
  map = [map dictionaryBySettingObject:@3 forKey:@3];

  XCTAssertEqualObjects([map objectForKey:@1], @1, @"Found object");
  XCTAssertEqualObjects([map objectForKey:@2], @2, @"Found object");
  XCTAssertEqualObjects([map objectForKey:@3], @3, @"Found object");

  FSTImmutableSortedDictionary *m1 = [map dictionaryByRemovingObjectForKey:@2];
  XCTAssertEqualObjects([m1 objectForKey:@1], @1, @"Found object");
  XCTAssertEqualObjects([m1 objectForKey:@3], @3, @"Found object");
  XCTAssertNil([m1 objectForKey:@2], @"Removed object");
}

- (void)testIncreasing {
  int total = 100;

  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];

  for (int i = 0; i < total; i++) {
    NSNumber *item = @(i);
    map = [map dictionaryBySettingObject:item forKey:item];
  }

  XCTAssertTrue(map.count == 100, @"Check if all 100 objects are in the map");

  for (int i = 0; i < total; i++) {
    NSNumber *item = @(i);
    map = [map dictionaryByRemovingObjectForKey:item];
  }

  XCTAssertTrue(map.count == 0, @"Check if all 100 objects were removed");
}

- (void)testOverride {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@10 forKey:@10];
  map = [map dictionaryBySettingObject:@8 forKey:@10];

  XCTAssertEqualObjects([map objectForKey:@10], @8, @"Found first object");
}

- (void)testEmpty {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@10 forKey:@10];
  map = [map dictionaryByRemovingObjectForKey:@10];

  XCTAssertTrue([map isEmpty], @"Properly empty");
}

- (void)testEmptyGet {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  XCTAssertNil([map objectForKey:@"something"], @"Properly nil");
}

- (void)testEmptyCount {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  XCTAssertTrue([map count] == 0, @"Properly zero count");
}

- (void)testEmptyRemoval {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryByRemovingObjectForKey:@"something"];
  XCTAssertTrue(map.count == 0, @"Properly zero count");
}

- (void)testReverseTraversal {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@1 forKey:@1];
  map = [map dictionaryBySettingObject:@5 forKey:@5];
  map = [map dictionaryBySettingObject:@3 forKey:@3];
  map = [map dictionaryBySettingObject:@2 forKey:@2];
  map = [map dictionaryBySettingObject:@4 forKey:@4];

  __block int next = 5;
  [map enumerateKeysAndObjectsReverse:YES
                           usingBlock:^(id key, id value, BOOL *stop) {
                             XCTAssertEqualObjects(key, @(next), @"Properly equal");
                             next = next - 1;
                           }];
}

- (void)testInsertionAndRemovalOfAHundredItems {
  NSUInteger n = 100;
  NSMutableArray *toInsert = [NSMutableArray arrayWithCapacity:n];
  NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity:n];

  for (NSUInteger i = 0; i < n; i++) {
    [toInsert addObject:@(i)];
    [toRemove addObject:@(i)];
  }

  [self shuffleArray:toInsert];
  [self shuffleArray:toRemove];

  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (NSUInteger i = 0; i < n; i++) {
    map = [map dictionaryBySettingObject:toInsert[i] forKey:toInsert[i]];
  }
  XCTAssertTrue(map.count == n, @"Check if all N objects are in the map");

  // check the order is correct
  __block int next = 0;
  [map enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    XCTAssertEqualObjects(key, @(next), @"Correct key");
    XCTAssertEqualObjects(value, @(next), @"Correct value");
    next = next + 1;
  }];
  XCTAssertEqual(next, n, @"Check we traversed all of the items");

  // remove them

  for (NSUInteger i = 0; i < n; i++) {
    map = [map dictionaryByRemovingObjectForKey:toRemove[i]];
  }

  XCTAssertEqual(map.count, 0, @"Check we removed all of the items");
}

- (void)shuffleArray:(NSMutableArray *)array {
  NSUInteger count = array.count;
  for (NSUInteger i = 0; i < count; i++) {
    NSUInteger nElements = count - i;
    NSUInteger n = (arc4random() % nElements) + i;
    [array exchangeObjectAtIndex:i withObjectAtIndex:n];
  }
}

- (void)testBalanceProblem {
  NSArray *toInsert = @[ @1, @7, @8, @5, @2, @6, @4, @0, @3 ];

  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (NSUInteger i = 0; i < toInsert.count; i++) {
    map = [map dictionaryBySettingObject:toInsert[i] forKey:toInsert[i]];
  }
  XCTAssertTrue(map.count == toInsert.count, @"Check if all N objects are in the map");

  // check the order is correct
  __block int next = 0;
  [map enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    XCTAssertEqualObjects(key, @(next), @"Correct key");
    XCTAssertEqualObjects(value, @(next), @"Correct value");
    next = next + 1;
  }];
  XCTAssertEqual((int)next, (int)toInsert.count, @"Check we traversed all of the items");
}

- (void)testPredecessorKey {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@1 forKey:@1];
  map = [map dictionaryBySettingObject:@50 forKey:@50];
  map = [map dictionaryBySettingObject:@3 forKey:@3];
  map = [map dictionaryBySettingObject:@4 forKey:@4];
  map = [map dictionaryBySettingObject:@7 forKey:@7];
  map = [map dictionaryBySettingObject:@9 forKey:@9];

  XCTAssertNil([map predecessorKey:@1], @"First object doesn't have a predecessor");
  XCTAssertEqualObjects([map predecessorKey:@3], @1, @"@1");
  XCTAssertEqualObjects([map predecessorKey:@4], @3, @"@3");
  XCTAssertEqualObjects([map predecessorKey:@7], @4, @"@4");
  XCTAssertEqualObjects([map predecessorKey:@9], @7, @"@7");
  XCTAssertEqualObjects([map predecessorKey:@50], @9, @"@9");
  XCTAssertThrows([map predecessorKey:@777], @"Expect exception about nonexistent key");
}

// This is a macro instead of a method so that the failures show on the proper lines.
#define ASSERT_ENUMERATOR(enumerator, start, end, step)                                   \
  do {                                                                                    \
    NSEnumerator *e = (enumerator);                                                       \
    id next = nil;                                                                        \
    for (NSUInteger i = (start); i != (end); i += (step)) {                               \
      next = [e nextObject];                                                              \
      XCTAssertNotNil(next, @"expected %lu. got nil.", (unsigned long)i);                 \
      XCTAssertEqualObjects(next, @(i), "expected %lu. got %@.", (unsigned long)i, next); \
    }                                                                                     \
    next = [e nextObject];                                                                \
    XCTAssertNil(next, @"expected nil. got %@.", next);                                   \
  } while (0)

- (void)testEnumerator {
  NSUInteger n = 100;
  NSMutableArray *toInsert = [NSMutableArray arrayWithCapacity:n];
  NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity:n];

  for (int i = 0; i < n; i++) {
    [toInsert addObject:@(i)];
    [toRemove addObject:@(i)];
  }

  [self shuffleArray:toInsert];
  [self shuffleArray:toRemove];

  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:self.defaultComparator];

  // add them to the dictionary
  for (NSUInteger i = 0; i < n; i++) {
    map = [map dictionaryBySettingObject:toInsert[i] forKey:toInsert[i]];
  }
  XCTAssertTrue(map.count == n, @"Check if all N objects are in the map");

  ASSERT_ENUMERATOR([map keyEnumerator], 0, 100, 1);
}

- (void)testReverseEnumerator {
  NSUInteger n = 20;
  NSMutableArray *toInsert = [NSMutableArray arrayWithCapacity:n];

  for (int i = 0; i < n; i++) {
    [toInsert addObject:@(i)];
  }

  [self shuffleArray:toInsert];

  FSTImmutableSortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // Add them to the dictionary.
  for (NSUInteger i = 0; i < n; i++) {
    map = [map dictionaryBySettingObject:toInsert[i] forKey:toInsert[i]];
  }
  XCTAssertTrue(map.count == n, @"Check if all N objects are in the map");
  XCTAssertTrue([map isKindOfClass:FSTArraySortedDictionary.class],
                @"Make sure we still have a array backed dictionary");

  ASSERT_ENUMERATOR([map reverseKeyEnumerator], n - 1, -1, -1);
}

- (void)testEnumeratorFrom {
  // Create a dictionary with the even numbers in [2, 42).
  NSUInteger n = 20;
  NSMutableArray *toInsert = [NSMutableArray arrayWithCapacity:n];
  for (int i = 0; i < n; i++) {
    [toInsert addObject:@(i * 2 + 2)];
  }
  [self shuffleArray:toInsert];

  FSTImmutableSortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // Add them to the dictionary.
  for (NSUInteger i = 0; i < n; i++) {
    map = [map dictionaryBySettingObject:toInsert[i] forKey:toInsert[i]];
  }
  XCTAssertTrue(map.count == n, @"Check if all N objects are in the map");
  XCTAssertTrue([map isKindOfClass:FSTArraySortedDictionary.class],
                @"Make sure we still have a array backed dictionary");

  // Test from before keys.
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@0], 2, n * 2 + 2, 2);

  // Test from after keys.
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@100], 0, 0, 2);

  // Test from key in map.
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@10], 10, n * 2 + 2, 2);

  // Test from in between keys.
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@11], 12, n * 2 + 2, 2);
}

- (void)testEnumeratorFromTo {
  // Create a dictionary with the even numbers in [2, 42).
  NSUInteger n = 20;
  NSMutableArray *toInsert = [NSMutableArray arrayWithCapacity:n];
  for (int i = 0; i < n; i++) {
    [toInsert addObject:@(i * 2 + 2)];
  }
  [self shuffleArray:toInsert];

  FSTImmutableSortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // Add them to the dictionary.
  for (NSUInteger i = 0; i < n; i++) {
    map = [map dictionaryBySettingObject:toInsert[i] forKey:toInsert[i]];
  }
  XCTAssertTrue(map.count == n, @"Check if all N objects are in the map");
  XCTAssertTrue([map isKindOfClass:FSTArraySortedDictionary.class],
                @"Make sure we still have an array backed dictionary");

  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@0 to:@1], 2, 2, 2);            // before to before
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@0 to:@100], 2, n * 2 + 2, 2);  // before to after
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@0 to:@6], 2, 6, 2);            // before to key in map
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@0 to:@7], 2, 8, 2);      // before to in between keys
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@100 to:@0], 2, 2, 2);    // after to before
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@100 to:@110], 2, 2, 2);  // after to after
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@100 to:@6], 2, 2, 2);    // after to key in map
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@100 to:@7], 2, 2, 2);    // after to in between
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@6 to:@0], 6, 6, 2);      // key in map to before
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@6 to:@100], 6, n * 2 + 2, 2);  // key in map to after
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@6 to:@10], 6, 10, 2);  // key in map to key in map
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@6 to:@11], 6, 12, 2);  // key in map to in between
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@7 to:@0], 8, 8, 2);    // in between to before
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@7 to:@100], 8, n * 2 + 2, 2);  // in between to after
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@7 to:@10], 8, 10, 2);  // in between to key in map
  ASSERT_ENUMERATOR([map keyEnumeratorFrom:@7 to:@13], 8, 14, 2);  // in between to in between
}

- (void)testReverseEnumeratorFrom {
  NSUInteger n = 20;
  NSMutableArray *toInsert = [NSMutableArray arrayWithCapacity:n];

  for (int i = 0; i < n; i++) {
    [toInsert addObject:@(i * 2 + 2)];
  }

  [self shuffleArray:toInsert];

  FSTImmutableSortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];

  // add them to the dictionary
  for (NSUInteger i = 0; i < n; i++) {
    map = [map dictionaryBySettingObject:toInsert[i] forKey:toInsert[i]];
  }
  XCTAssertTrue(map.count == n, @"Check if all N objects are in the map");
  XCTAssertTrue([map isKindOfClass:FSTArraySortedDictionary.class],
                @"Make sure we still have a array backed dictionary");

  // Test from before keys.
  ASSERT_ENUMERATOR([map reverseKeyEnumeratorFrom:@0], 0, 0, -2);

  // Test from after keys.
  ASSERT_ENUMERATOR([map reverseKeyEnumeratorFrom:@100], n * 2, 0, -2);

  // Test from key in map.
  ASSERT_ENUMERATOR([map reverseKeyEnumeratorFrom:@10], 10, 0, -2);

  // Test from in between keys.
  ASSERT_ENUMERATOR([map reverseKeyEnumeratorFrom:@11], 10, 0, -2);
}

#undef ASSERT_ENUMERATOR

- (void)testIndexOf {
  FSTArraySortedDictionary *map =
      [[FSTArraySortedDictionary alloc] initWithComparator:[self defaultComparator]];
  map = [map dictionaryBySettingObject:@1 forKey:@1];
  map = [map dictionaryBySettingObject:@50 forKey:@50];
  map = [map dictionaryBySettingObject:@3 forKey:@3];
  map = [map dictionaryBySettingObject:@4 forKey:@4];
  map = [map dictionaryBySettingObject:@7 forKey:@7];
  map = [map dictionaryBySettingObject:@9 forKey:@9];

  XCTAssertEqual([map indexOfKey:@0], NSNotFound);
  XCTAssertEqual([map indexOfKey:@1], 0);
  XCTAssertEqual([map indexOfKey:@2], NSNotFound);
  XCTAssertEqual([map indexOfKey:@3], 1);
  XCTAssertEqual([map indexOfKey:@4], 2);
  XCTAssertEqual([map indexOfKey:@5], NSNotFound);
  XCTAssertEqual([map indexOfKey:@6], NSNotFound);
  XCTAssertEqual([map indexOfKey:@7], 3);
  XCTAssertEqual([map indexOfKey:@8], NSNotFound);
  XCTAssertEqual([map indexOfKey:@9], 4);
  XCTAssertEqual([map indexOfKey:@50], 5);
}

@end
