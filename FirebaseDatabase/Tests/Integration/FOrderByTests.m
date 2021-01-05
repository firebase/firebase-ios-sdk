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

#import "FirebaseDatabase/Tests/Integration/FOrderByTests.h"

@interface FOrderByTests ()
@end

@implementation FOrderByTests

- (void)testCanDefineAndUseAnIndex {
  __block FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSArray *users = @[
    @{@"name" : @"Andrew", @"nuggets" : @35}, @{@"name" : @"Rob", @"nuggets" : @40},
    @{@"name" : @"Greg", @"nuggets" : @38}
  ];

  __block int setCount = 0;
  [users enumerateObjectsUsingBlock:^(NSDictionary *user, NSUInteger idx, BOOL *stop) {
    [[ref childByAutoId] setValue:user
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                setCount++;
              }];
  }];

  [self waitUntil:^BOOL {
    return setCount == users.count;
  }];

  __block NSMutableArray *byNuggets = [[NSMutableArray alloc] init];
  [[ref queryOrderedByChild:@"nuggets"] observeEventType:FIRDataEventTypeChildAdded
                                               withBlock:^(FIRDataSnapshot *snapshot) {
                                                 NSDictionary *user = snapshot.value;
                                                 [byNuggets addObject:user[@"name"]];
                                               }];

  [self waitUntil:^BOOL {
    return byNuggets.count == users.count;
  }];

  NSArray *expected = @[ @"Andrew", @"Greg", @"Rob" ];
  XCTAssertEqualObjects(byNuggets, expected, @"Correct by-nugget ordering.");
}

- (void)testCanDefineAndUseDeepIndex {
  __block FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSArray *users = @[
    @{@"name" : @"Andrew", @"deep" : @{@"nuggets" : @35}},
    @{@"name" : @"Rob", @"deep" : @{@"nuggets" : @40}},
    @{@"name" : @"Greg", @"deep" : @{@"nuggets" : @38}}
  ];

  __block int setCount = 0;
  [users enumerateObjectsUsingBlock:^(NSDictionary *user, NSUInteger idx, BOOL *stop) {
    [[ref childByAutoId] setValue:user
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                setCount++;
              }];
  }];

  [self waitUntil:^BOOL {
    return setCount == users.count;
  }];

  __block NSMutableArray *byNuggets = [[NSMutableArray alloc] init];
  [[ref queryOrderedByChild:@"deep/nuggets"] observeEventType:FIRDataEventTypeChildAdded
                                                    withBlock:^(FIRDataSnapshot *snapshot) {
                                                      NSDictionary *user = snapshot.value;
                                                      [byNuggets addObject:user[@"name"]];
                                                    }];

  [self waitUntil:^BOOL {
    return byNuggets.count == users.count;
  }];

  NSArray *expected = @[ @"Andrew", @"Greg", @"Rob" ];
  XCTAssertEqualObjects(byNuggets, expected, @"Correct by-nugget ordering.");
}

- (void)testCanUsaAFallbackThenDefineTheSpecifiedIndex {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = tuple.one, *writer = tuple.two;

  NSDictionary *foo1 = @{
    @"a" : @{@"order" : @2, @"foo" : @1},
    @"b" : @{@"order" : @0},
    @"c" : @{@"order" : @1, @"foo" : @NO},
    @"d" : @{@"order" : @3, @"foo" : @"hello"}
  };

  NSDictionary *foo_e = @{@"order" : @1.5, @"foo" : @YES};
  NSDictionary *foo_f = @{@"order" : @4, @"foo" : @{@"bar" : @"baz"}};

  [self waitForCompletionOf:writer setValue:foo1];

  NSMutableArray *snaps = [[NSMutableArray alloc] init];
  [[[reader queryOrderedByChild:@"order"] queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               [snaps addObject:snapshot.value];
             }];
  WAIT_FOR(snaps.count == 1);

  NSDictionary *expected =
      @{@"d" : @{@"order" : @3, @"foo" : @"hello"}, @"a" : @{@"order" : @2, @"foo" : @1}};
  XCTAssertEqualObjects(snaps[0], expected, @"Got correct result");

  [self waitForCompletionOf:[writer child:@"e"] setValue:foo_e];

  [self waitForRoundTrip:reader];
  NSLog(@"snaps: %@", snaps);
  NSLog(@"snaps.count: %ld", (unsigned long)snaps.count);
  XCTAssertEqual(snaps.count, (NSUInteger)1, @"Should still have one event.");

  [self waitForCompletionOf:[writer child:@"f"] setValue:foo_f];

  [self waitForRoundTrip:reader];
  XCTAssertEqual(snaps.count, (NSUInteger)2, @"Should have gotten another event.");
  expected = @{@"f" : foo_f, @"d" : @{@"order" : @3, @"foo" : @"hello"}};
  XCTAssertEqualObjects(snaps[1], expected, @"Correct event.");
}

- (void)testSnapshotsAreIteratedInOrder {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSDictionary *initial = @{
    @"alex" : @{@"nuggets" : @60},
    @"rob" : @{@"nuggets" : @56},
    @"vassili" : @{@"nuggets" : @55.5},
    @"tony" : @{@"nuggets" : @52},
    @"greg" : @{@"nuggets" : @52}
  };

  NSArray *expectedOrder = @[ @"greg", @"tony", @"vassili", @"rob", @"alex" ];
  NSArray *expectedPrevNames = @[ [NSNull null], @"greg", @"tony", @"vassili", @"rob" ];

  NSMutableArray *valueOrder = [[NSMutableArray alloc] init];
  NSMutableArray *addedOrder = [[NSMutableArray alloc] init];
  NSMutableArray *addedPrevNames = [[NSMutableArray alloc] init];

  FIRDatabaseQuery *orderedRef = [ref queryOrderedByChild:@"nuggets"];

  [orderedRef observeEventType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       for (FIRDataSnapshot *child in snapshot.children) {
                         [valueOrder addObject:child.key];
                       }
                     }];

  [orderedRef observeEventType:FIRDataEventTypeChildAdded
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
        [addedOrder addObject:snapshot.key];
        [addedPrevNames addObject:prevName ? prevName : [NSNull null]];
      }];

  [ref setValue:initial];
  WAIT_FOR(addedOrder.count == expectedOrder.count && valueOrder.count == expectedOrder.count);

  XCTAssertEqualObjects(addedOrder, expectedOrder, @"child_added events in correct order.");
  XCTAssertEqualObjects(addedPrevNames, expectedPrevNames,
                        @"Got correct prevnames for child_added events.");
  XCTAssertEqualObjects(valueOrder, expectedOrder,
                        @"enumerated snapshot children in correct order.");
}

- (void)testSnapshotsAreIteratedInOrderForValueIndex {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSDictionary *initial =
      @{@"alex" : @60, @"rob" : @56, @"vassili" : @55.5, @"tony" : @52, @"greg" : @52};

  NSArray *expectedOrder = @[ @"greg", @"tony", @"vassili", @"rob", @"alex" ];
  NSArray *expectedPrevNames = @[ [NSNull null], @"greg", @"tony", @"vassili", @"rob" ];

  NSMutableArray *valueOrder = [[NSMutableArray alloc] init];
  NSMutableArray *addedOrder = [[NSMutableArray alloc] init];
  NSMutableArray *addedPrevNames = [[NSMutableArray alloc] init];

  FIRDatabaseQuery *orderedRef = [ref queryOrderedByValue];

  [orderedRef observeEventType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       for (FIRDataSnapshot *child in snapshot.children) {
                         [valueOrder addObject:child.key];
                       }
                     }];

  [orderedRef observeEventType:FIRDataEventTypeChildAdded
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
        [addedOrder addObject:snapshot.key];
        [addedPrevNames addObject:prevName ? prevName : [NSNull null]];
      }];

  [ref setValue:initial];
  WAIT_FOR(addedOrder.count == expectedOrder.count && valueOrder.count == expectedOrder.count);

  XCTAssertEqualObjects(addedOrder, expectedOrder, @"child_added events in correct order.");
  XCTAssertEqualObjects(addedPrevNames, expectedPrevNames,
                        @"Got correct prevnames for child_added events.");
  XCTAssertEqualObjects(valueOrder, expectedOrder,
                        @"enumerated snapshot children in correct order.");
}

- (void)testFiresChildMovedEvents {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSDictionary *initial = @{
    @"alex" : @{@"nuggets" : @60},
    @"rob" : @{@"nuggets" : @56},
    @"vassili" : @{@"nuggets" : @55.5},
    @"tony" : @{@"nuggets" : @52},
    @"greg" : @{@"nuggets" : @52}
  };

  FIRDatabaseQuery *orderedRef = [ref queryOrderedByChild:@"nuggets"];

  __block BOOL moved = NO;
  [orderedRef observeEventType:FIRDataEventTypeChildMoved
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
        moved = YES;
        XCTAssertEqualObjects(snapshot.key, @"greg", @"");
        XCTAssertEqualObjects(prevName, @"rob", @"");
        XCTAssertEqualObjects(
            snapshot.value,
            @{@"nuggets" : @57}, @"");
      }];

  [ref setValue:initial];
  [[ref child:@"greg/nuggets"] setValue:@57];
  WAIT_FOR(moved);
}

- (void)testDefineMultipleIndexesAtALocation {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = tuple.one, *writer = tuple.two;

  NSDictionary *foo1 = @{
    @"a" : @{@"order" : @2, @"foo" : @2},
    @"b" : @{@"order" : @0},
    @"c" : @{@"order" : @1, @"foo" : @NO},
    @"d" : @{@"order" : @3, @"foo" : @"hello"}
  };

  [self waitForCompletionOf:writer setValue:foo1];

  FIRDatabaseQuery *fooOrder = [reader queryOrderedByChild:@"foo"];
  FIRDatabaseQuery *orderOrder = [reader queryOrderedByChild:@"order"];
  NSMutableArray *fooSnaps = [[NSMutableArray alloc] init];
  NSMutableArray *orderSnaps = [[NSMutableArray alloc] init];

  [[[fooOrder queryStartingAtValue:nil] queryEndingAtValue:@1]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               [fooSnaps addObject:snapshot.value];
             }];

  [[orderOrder queryLimitedToLast:2] observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot *snapshot) {
                                              [orderSnaps addObject:snapshot.value];
                                            }];

  WAIT_FOR(fooSnaps.count == 1 && orderSnaps.count == 1);

  NSDictionary *expected = @{@"b" : @{@"order" : @0}, @"c" : @{@"order" : @1, @"foo" : @NO}};
  XCTAssertEqualObjects(fooSnaps[0], expected, @"");

  expected = @{
    @"d" : @{@"order" : @3, @"foo" : @"hello"},
    @"a" : @{@"order" : @2, @"foo" : @2},
  };
  XCTAssertEqualObjects(orderSnaps[0], expected, @"");

  [[writer child:@"a"] setValue:@{@"order" : @-1, @"foo" : @1}];

  WAIT_FOR(fooSnaps.count == 2 && orderSnaps.count == 2);

  expected = @{
    @"a" : @{@"order" : @-1, @"foo" : @1},
    @"b" : @{@"order" : @0},
    @"c" : @{@"order" : @1, @"foo" : @NO}
  };
  XCTAssertEqualObjects(fooSnaps[1], expected, @"");

  expected = @{@"d" : @{@"order" : @3, @"foo" : @"hello"}, @"c" : @{@"order" : @1, @"foo" : @NO}};
  XCTAssertEqualObjects(orderSnaps[1], expected, @"");
}

- (void)testCallbackRemovalWorks {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block int reads = 0;
  FIRDatabaseHandle fooHandle, bazHandle;
  fooHandle = [[ref queryOrderedByChild:@"foo"] observeEventType:FIRDataEventTypeValue
                                                       withBlock:^(FIRDataSnapshot *snapshot) {
                                                         reads++;
                                                       }];

  [[ref queryOrderedByChild:@"bar"] observeEventType:FIRDataEventTypeValue
                                           withBlock:^(FIRDataSnapshot *snapshot) {
                                             reads++;
                                           }];

  bazHandle = [[ref queryOrderedByChild:@"baz"] observeEventType:FIRDataEventTypeValue
                                                       withBlock:^(FIRDataSnapshot *snapshot) {
                                                         reads++;
                                                       }];

  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                reads++;
              }];

  [self waitForCompletionOf:ref setValue:@1];

  XCTAssertEqual(reads, 4, @"");

  [ref removeObserverWithHandle:fooHandle];
  [self waitForCompletionOf:ref setValue:@2];
  XCTAssertEqual(reads, 7, @"");

  // should be a no-op, resulting in 3 more reads.
  [[ref queryOrderedByChild:@"foo"] removeObserverWithHandle:bazHandle];
  [self waitForCompletionOf:ref setValue:@3];
  XCTAssertEqual(reads, 10, @"");

  [[ref queryOrderedByChild:@"bar"] removeAllObservers];
  [self waitForCompletionOf:ref setValue:@4];
  XCTAssertEqual(reads, 12, @"");

  // Now, remove everything.
  [ref removeAllObservers];
  [self waitForCompletionOf:ref setValue:@5];
  XCTAssertEqual(reads, 12, @"");
}

- (void)testChildAddedEventsAreInTheCorrectOrder {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSDictionary *initial = @{@"a" : @{@"value" : @5}, @"c" : @{@"value" : @3}};

  NSMutableArray *added = [[NSMutableArray alloc] init];
  [[ref queryOrderedByChild:@"value"] observeEventType:FIRDataEventTypeChildAdded
                                             withBlock:^(FIRDataSnapshot *snapshot) {
                                               [added addObject:snapshot.key];
                                             }];
  [ref setValue:initial];

  WAIT_FOR(added.count == 2);
  NSArray *expected = @[ @"c", @"a" ];
  XCTAssertEqualObjects(added, expected, @"");

  [ref updateChildValues:@{@"b" : @{@"value" : @4}, @"d" : @{@"value" : @2}}];

  WAIT_FOR(added.count == 4);
  expected = @[ @"c", @"a", @"d", @"b" ];
  XCTAssertEqualObjects(added, expected, @"");
}

- (void)testCanUseKeyIndex {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSDictionary *data = @{
    @"a" : @{@".priority" : @10, @".value" : @"a"},
    @"b" : @{@".priority" : @5, @".value" : @"b"},
    @"c" : @{@".priority" : @20, @".value" : @"c"},
    @"d" : @{@".priority" : @7, @".value" : @"d"},
    @"e" : @{@".priority" : @30, @".value" : @"e"},
    @"f" : @{@".priority" : @8, @".value" : @"f"}
  };

  [self waitForCompletionOf:ref setValue:data];

  __block BOOL valueDone = NO;
  [[[ref queryOrderedByKey] queryStartingAtValue:@"c"]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       NSMutableArray *keys = [[NSMutableArray alloc] init];
                       for (FIRDataSnapshot *child in snapshot.children) {
                         [keys addObject:child.key];
                       }
                       NSArray *expected = @[ @"c", @"d", @"e", @"f" ];
                       XCTAssertEqualObjects(keys, expected, @"");
                       valueDone = YES;
                     }];
  WAIT_FOR(valueDone);

  NSMutableArray *keys = [[NSMutableArray alloc] init];
  [[[ref queryOrderedByKey] queryLimitedToLast:5]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               for (FIRDataSnapshot *child in snapshot.children) {
                 [keys addObject:child.key];
               }
             }];

  WAIT_FOR(keys.count == 5);
  NSArray *expected = @[ @"b", @"c", @"d", @"e", @"f" ];
  XCTAssertEqualObjects(keys, expected, @"");
}

- (void)testQueriesWorkOnLeafNodes {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  [self waitForCompletionOf:ref setValue:@"leaf-node"];

  __block BOOL valueDone = NO;
  [[[ref queryOrderedByChild:@"foo"] queryLimitedToLast:1]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       XCTAssertEqual(snapshot.value, [NSNull null]);
                       valueDone = YES;
                     }];
  WAIT_FOR(valueDone);
}

- (void)testUpdatesForUnindexedQuery {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block BOOL done = NO;
  NSDictionary *value = @{
    @"one" : @{@"index" : @1, @"value" : @"one"},
    @"two" : @{@"index" : @2, @"value" : @"two"},
    @"three" : @{@"index" : @3, @"value" : @"three"}
  };
  [writer setValue:value
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];
  WAIT_FOR(done);

  done = NO;

  NSMutableArray *snapshots = [NSMutableArray array];

  [[[reader queryOrderedByChild:@"index"] queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               [snapshots addObject:snapshot.value];
               done = YES;
             }];

  WAIT_FOR(done);

  NSDictionary *expected = @{
    @"two" : @{@"index" : @2, @"value" : @"two"},
    @"three" : @{@"index" : @3, @"value" : @"three"}
  };

  XCTAssertEqual(snapshots.count, (NSUInteger)1);
  XCTAssertEqualObjects(snapshots[0], expected);

  done = NO;
  [[writer child:@"one/index"] setValue:@4];

  WAIT_FOR(done);

  expected = @{
    @"one" : @{@"index" : @4, @"value" : @"one"},
    @"three" : @{@"index" : @3, @"value" : @"three"}
  };
  XCTAssertEqual(snapshots.count, (NSUInteger)2);
  XCTAssertEqualObjects(snapshots[1], expected);
}

- (void)testServerRespectsKeyIndex {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  NSDictionary *initial = @{@"a" : @1, @"b" : @2, @"c" : @3};

  // If the server doesn't respect the index, it will send down limited data, but with no offset, so
  // the expected and actual data don't match
  FIRDatabaseQuery *query =
      [[[reader queryOrderedByKey] queryStartingAtValue:@"b"] queryLimitedToFirst:2];

  NSArray *expectedChildren = @[ @"b", @"c" ];

  [self waitForCompletionOf:writer setValue:initial];

  NSMutableArray *children = [[NSMutableArray alloc] init];

  __block BOOL done = NO;
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot) {
                  for (FIRDataSnapshot *child in snapshot.children) {
                    [children addObject:child.key];
                  }
                  done = YES;
                }];

  WAIT_FOR(done);

  XCTAssertEqualObjects(expectedChildren, children, @"Got correct children");
}

- (void)testServerRespectsValueIndex {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  NSDictionary *initial = @{@"a" : @1, @"c" : @2, @"b" : @3};

  // If the server doesn't respect the index, it will send down limited data, but with no offset, so
  // the expected and actual data don't match
  FIRDatabaseQuery *query =
      [[[reader queryOrderedByValue] queryStartingAtValue:@2] queryLimitedToFirst:2];

  NSArray *expectedChildren = @[ @"c", @"b" ];

  [self waitForCompletionOf:writer setValue:initial];

  NSMutableArray *children = [[NSMutableArray alloc] init];

  __block BOOL done = NO;
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot) {
                  for (FIRDataSnapshot *child in snapshot.children) {
                    [children addObject:child.key];
                  }
                  done = YES;
                }];

  WAIT_FOR(done);

  XCTAssertEqualObjects(expectedChildren, children, @"Got correct children");
}

- (void)testDeepUpdatesWorkWithQueries {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  NSDictionary *initial = @{
    @"a" : @{@"data" : @"foo", @"idx" : @YES},
    @"b" : @{@"data" : @"bar", @"idx" : @YES},
    @"c" : @{@"data" : @"baz", @"idx" : @NO}
  };
  [self waitForCompletionOf:writer setValue:initial];

  FIRDatabaseQuery *query = [[reader queryOrderedByChild:@"idx"] queryEqualToValue:@YES];

  NSDictionary *expected =
      @{@"a" : @{@"data" : @"foo", @"idx" : @YES}, @"b" : @{@"data" : @"bar", @"idx" : @YES}};

  [self waitForExportValueOf:query toBe:expected];

  NSDictionary *update = @{@"a/idx" : @NO, @"b/data" : @"blah", @"c/idx" : @YES};
  [self waitForCompletionOf:writer updateChildValues:update];

  expected =
      @{@"b" : @{@"data" : @"blah", @"idx" : @YES}, @"c" : @{@"data" : @"baz", @"idx" : @YES}};
  [self waitForExportValueOf:query toBe:expected];
}

- (void)testServerRespectsDeepIndex {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  NSDictionary *initial = @{
    @"a" : @{@"deep" : @{@"index" : @1}},
    @"c" : @{@"deep" : @{@"index" : @2}},
    @"b" : @{@"deep" : @{@"index" : @3}}
  };

  // If the server doesn't respect the index, it will send down limited data, but with no offset, so
  // the expected and actual data don't match
  FIRDatabaseQuery *query =
      [[[reader queryOrderedByChild:@"deep/index"] queryStartingAtValue:@2] queryLimitedToFirst:2];

  NSArray *expectedChildren = @[ @"c", @"b" ];

  [self waitForCompletionOf:writer setValue:initial];

  NSMutableArray *children = [[NSMutableArray alloc] init];

  __block BOOL done = NO;
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot) {
                  for (FIRDataSnapshot *child in snapshot.children) {
                    [children addObject:child.key];
                  }
                  done = YES;
                }];

  WAIT_FOR(done);

  XCTAssertEqualObjects(expectedChildren, children, @"Got correct children");
}

- (void)testStartAtEndAtWorksWithValueIndex {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSDictionary *initial =
      @{@"alex" : @60, @"rob" : @56, @"vassili" : @55.5, @"tony" : @52, @"greg" : @52};

  NSArray *expectedOrder = @[ @"tony", @"vassili", @"rob" ];
  NSArray *expectedPrevNames = @[ [NSNull null], @"tony", @"vassili" ];

  NSMutableArray *valueOrder = [[NSMutableArray alloc] init];
  NSMutableArray *addedOrder = [[NSMutableArray alloc] init];
  NSMutableArray *addedPrevNames = [[NSMutableArray alloc] init];

  FIRDatabaseQuery *orderedRef =
      [[[ref queryOrderedByValue] queryStartingAtValue:@52
                                              childKey:@"tony"] queryEndingAtValue:@59];

  [orderedRef observeEventType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       for (FIRDataSnapshot *child in snapshot.children) {
                         [valueOrder addObject:child.key];
                       }
                     }];

  [orderedRef observeEventType:FIRDataEventTypeChildAdded
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
        [addedOrder addObject:snapshot.key];
        [addedPrevNames addObject:prevName ? prevName : [NSNull null]];
      }];

  [ref setValue:initial];
  WAIT_FOR(addedOrder.count == expectedOrder.count && valueOrder.count == expectedOrder.count);

  XCTAssertEqualObjects(addedOrder, expectedOrder, @"child_added events in correct order.");
  XCTAssertEqualObjects(addedPrevNames, expectedPrevNames,
                        @"Got correct prevnames for child_added events.");
  XCTAssertEqualObjects(valueOrder, expectedOrder,
                        @"enumerated snapshot children in correct order.");
}

- (void)testRemovingDefaultListenerRemovesNonDefaultListenWithLoadsAllData {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSDictionary *initialData = @{@"key" : @"value"};
  [self waitForCompletionOf:ref setValue:initialData];

  [[ref queryOrderedByKey] observeEventType:FIRDataEventTypeValue
                                  withBlock:^(FIRDataSnapshot *snapshot){
                                  }];
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot){
              }];

  // Should remove both listener and should remove the listen sent to the server
  [ref removeAllObservers];

  __block id result = nil;
  // This used to crash because a listener for [ref queryOrderedByKey] existed already
  [[ref queryOrderedByKey] observeSingleEventOfType:FIRDataEventTypeValue
                                          withBlock:^(FIRDataSnapshot *snapshot) {
                                            result = snapshot.value;
                                          }];

  WAIT_FOR(result);
  XCTAssertEqualObjects(result, initialData);
}

@end
