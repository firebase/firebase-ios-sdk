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

#import "FirebaseDatabase/Tests/Integration/FOrder.h"
#import "FirebaseDatabase/Sources/Api/Private/FTypedefs_Private.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseReference.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleFirebase.h"
#import "FirebaseDatabase/Tests/Helpers/FEventTester.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"
#import "FirebaseDatabase/Tests/Helpers/FTupleEventTypeString.h"

@implementation FOrder

- (void)testPushEnumerateAndCheckCorrectOrder {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  for (int i = 0; i < 10; i++) {
    [[node childByAutoId] setValue:[NSNumber numberWithInt:i]];
  }

  [super
      snapWaiter:node
       withBlock:^(FIRDataSnapshot *snapshot) {
         int expected = 0;
         for (FIRDataSnapshot *child in snapshot.children) {
           XCTAssertEqualObjects([NSNumber numberWithInt:expected], [child value],
                                 @"Expects values match.");
           expected = expected + 1;
         }
         XCTAssertTrue(expected == 10, @"Should get all of the children");
         XCTAssertTrue(expected == snapshot.childrenCount, @"Snapshot should report correct count");
       }];
}

- (void)testPushEnumerateManyPathsWriteAndCheckOrder {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  NSMutableArray *paths = [[NSMutableArray alloc] init];

  for (int i = 0; i < 20; i++) {
    [paths addObject:[node childByAutoId]];
  }

  for (int i = 0; i < 20; i++) {
    [(FIRDatabaseReference *)[paths objectAtIndex:i] setValue:[NSNumber numberWithInt:i]];
  }

  [super snapWaiter:node
          withBlock:^(FIRDataSnapshot *snap) {
            int expected = 0;
            for (FIRDataSnapshot *child in snap.children) {
              XCTAssertEqualObjects([NSNumber numberWithInt:expected], [child value],
                                    @"Expects values match.");
              expected = expected + 1;
            }
            XCTAssertTrue(expected == 20, @"Should get all of the children");
            XCTAssertTrue(expected == snap.childrenCount, @"Snapshot should report correct count");
          }];
}

- (void)testPushDataReconnectReadBackAndVerifyOrder {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePair];

  __block int expected = 0;
  __block int nodesSet = 0;
  FIRDatabaseReference *node = tuple.one;
  for (int i = 0; i < 10; i++) {
    [[node childByAutoId] setValue:[NSNumber numberWithInt:i]
               withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
                 nodesSet++;
               }];
  }

  [self waitUntil:^BOOL {
    return nodesSet == 10;
  }];

  __block BOOL done = NO;
  [super snapWaiter:node
          withBlock:^(FIRDataSnapshot *snap) {
            expected = 0;
            //[snap forEach:^BOOL(FIRDataSnapshot *child) {
            for (FIRDataSnapshot *child in snap.children) {
              XCTAssertEqualObjects([NSNumber numberWithInt:expected], [child value],
                                    @"Expected child value");
              expected = expected + 1;
              // return NO;
            }
            done = YES;
          }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  XCTAssertTrue(nodesSet == 10, @"All of the nodes have been set");

  [super
      snapWaiter:tuple.two
       withBlock:^(FIRDataSnapshot *snap) {
         expected = 0;
         for (FIRDataSnapshot *child in snap.children) {
           XCTAssertEqualObjects([NSNumber numberWithInt:expected], [child value],
                                 @"Expected child value");
           expected = expected + 1;
         }
         done = YES;
         XCTAssertTrue(expected == 10, @"Saw the expected number of children %d == 10", expected);
       }];
}

- (void)testPushDataWithPrioritiesReconnectReadBackAndVerifyOrder {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePair];

  __block int expected = 0;
  __block int nodesSet = 0;
  FIRDatabaseReference *node = tuple.one;
  for (int i = 0; i < 10; i++) {
    [[node childByAutoId] setValue:[NSNumber numberWithInt:i]
                       andPriority:[NSNumber numberWithInt:(10 - i)]
               withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                 nodesSet = nodesSet + 1;
               }];
  }

  [super snapWaiter:node
          withBlock:^(FIRDataSnapshot *snap) {
            expected = 9;

            for (FIRDataSnapshot *child in snap.children) {
              XCTAssertEqualObjects([child value], [NSNumber numberWithInt:expected],
                                    @"Expected child value as per priority");
              expected = expected - 1;
            }
            XCTAssertTrue(expected == -1, @"Saw the expected number of children");
          }];

  [self waitUntil:^BOOL {
    return nodesSet == 10;
  }];

  XCTAssertTrue(nodesSet == 10, @"All of the nodes have been set");

  [super snapWaiter:tuple.two
          withBlock:^(FIRDataSnapshot *snap) {
            expected = 9;
            for (FIRDataSnapshot *child in snap.children) {
              XCTAssertEqualObjects([child value], [NSNumber numberWithInt:expected],
                                    @"Expected child value as per priority");
              expected = expected - 1;
            }
            XCTAssertTrue(expected == -1, @"Saw the expected number of children");
          }];
}

- (void)testPushDataWithExponentialPrioritiesReconnectReadBackAndVerifyOrder {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePair];

  __block int expected = 0;
  __block int nodesSet = 0;
  FIRDatabaseReference *node = tuple.one;
  for (int i = 0; i < 10; i++) {
    [[node childByAutoId] setValue:[NSNumber numberWithInt:i]
                       andPriority:[NSNumber numberWithDouble:(111111111111111111111111111111.0 /
                                                               pow(10, i))]
               withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                 nodesSet = nodesSet + 1;
               }];
  }

  [super snapWaiter:node
          withBlock:^(FIRDataSnapshot *snap) {
            expected = 9;

            for (FIRDataSnapshot *child in snap.children) {
              XCTAssertEqualObjects([child value], [NSNumber numberWithInt:expected],
                                    @"Expected child value as per priority");
              expected = expected - 1;
            }
            XCTAssertTrue(expected == -1, @"Saw the expected number of children");
          }];

  WAIT_FOR(nodesSet == 10);

  [super snapWaiter:tuple.two
          withBlock:^(FIRDataSnapshot *snap) {
            expected = 9;
            for (FIRDataSnapshot *child in snap.children) {
              XCTAssertEqualObjects([child value], [NSNumber numberWithInt:expected],
                                    @"Expected child value as per priority");
              expected = expected - 1;
            }
            XCTAssertTrue(expected == -1, @"Saw the expected number of children");
          }];
}

- (void)testThatNodesWithoutValuesAreNotEnumerated {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  [node child:@"foo"];
  [[node child:@"bar"] setValue:@"test"];

  __block int items = 0;
  [super snapWaiter:node
          withBlock:^(FIRDataSnapshot *snap) {
            for (FIRDataSnapshot *child in snap.children) {
              items = items + 1;
              XCTAssertEqualObjects([child key], @"bar",
                                    @"Saw the child which had a value set and not the empty one");
            }

            XCTAssertTrue(items == 1, @"Saw only the one that was actually set.");
          }];
}

- (void)testChildMovedEventWhenPriorityChanges {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  FEventTester *et = [[FEventTester alloc] initFrom:self];

  NSArray *expect = @[
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"b"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"c"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildMoved
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [et addLookingFor:expect];

  [et waitForInitialization];

  [[node child:@"a"] setValue:@"first" andPriority:@1];
  [[node child:@"b"] setValue:@"second" andPriority:@2];
  [[node child:@"c"] setValue:@"third" andPriority:@3];

  [[node child:@"a"] setPriority:@15];

  [et wait];
}

- (void)testCanResetPriorityToNull {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  [[node child:@"a"] setValue:@"a" andPriority:@1];
  [[node child:@"b"] setValue:@"b" andPriority:@2];

  FEventTester *et = [[FEventTester alloc] initFrom:self];
  NSArray *expect = @[
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"b"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [et addLookingFor:expect];

  [et wait];

  expect = @[
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildMoved
                                         withString:@"b"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"b"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [et addLookingFor:expect];

  [[node child:@"b"] setPriority:nil];

  [et wait];

  __block BOOL ready = NO;
  [[node child:@"b"]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       XCTAssertTrue([snapshot priority] == [NSNull null], @"Should be null");
                       ready = YES;
                     }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testInsertingANodeUnderALeafPreservesItsPriority {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap;
  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *s) {
                 snap = s;
               }];

  [node setValue:@"a" andPriority:@10];
  [[node child:@"deeper"] setValue:@"deeper"];

  [self waitUntil:^BOOL {
    id result = [snap value];
    NSDictionary *expected = @{@"deeper" : @"deeper"};
    return snap != nil && [result isKindOfClass:[NSDictionary class]] &&
           [result isEqualToDictionary:expected];
  }];

  XCTAssertEqualObjects([snap priority], @10, @"Proper value");
}

- (void)testVerifyOrderOfMixedNumbersStringNoPriorities {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePair];

  NSArray *nodeAndPriorities = @[
    @"alpha42",     @"zed",        @"noPriorityC", [NSNull null], @"num41",       @500,
    @"noPriorityB", [NSNull null], @"num80",       @4000.1,       @"num50",       @4000,
    @"num10",       @24,           @"alpha41",     @"zed",        @"alpha20",     @"horse",
    @"num20",       @123,          @"num70",       @4000.01,      @"noPriorityA", [NSNull null],
    @"alpha30",     @"tree",       @"num30",       @300,          @"num60",       @4000.001,
    @"alpha10",     @"0horse",     @"num42",       @500,          @"alpha40",     @"zed",
    @"num40",       @500
  ];

  __block int setsCompleted = 0;

  for (int i = 0; i < [nodeAndPriorities count]; i++) {
    FIRDatabaseReference *n = [tuple.one child:[nodeAndPriorities objectAtIndex:i++]];
    [n setValue:@1
                andPriority:[nodeAndPriorities objectAtIndex:i]
        withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
          setsCompleted = setsCompleted + 1;
        }];
  }

  NSString *expected =
      @"noPriorityA, noPriorityB, noPriorityC, num10, num20, num30, num40, num41, num42, num50, "
      @"num60, num70, num80, alpha10, alpha20, alpha30, alpha40, alpha41, alpha42, ";

  [super snapWaiter:tuple.one
          withBlock:^(FIRDataSnapshot *snap) {
            NSMutableString *output = [[NSMutableString alloc] init];
            for (FIRDataSnapshot *n in snap.children) {
              [output appendFormat:@"%@, ", [n key]];
            }

            XCTAssertTrue([expected isEqualToString:output], @"Proper order");
          }];

  WAIT_FOR(setsCompleted == [nodeAndPriorities count] / 2);

  [super snapWaiter:tuple.two
          withBlock:^(FIRDataSnapshot *snap) {
            NSMutableString *output = [[NSMutableString alloc] init];
            for (FIRDataSnapshot *n in snap.children) {
              [output appendFormat:@"%@, ", [n key]];
            }

            XCTAssertTrue([expected isEqualToString:output], @"Proper order");
          }];
}

- (void)testVerifyOrderOfIntegerNames {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSArray *keys = @[ @"foo", @"bar", @"03", @"0", @"100", @"20", @"5", @"3", @"003", @"9" ];

  __block int setsCompleted = 0;

  for (int i = 0; i < [keys count]; i++) {
    FIRDatabaseReference *n = [ref child:[keys objectAtIndex:i]];
    [n setValue:@1
        withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
          setsCompleted = setsCompleted + 1;
        }];
  }

  NSString *expected = @"0, 3, 03, 003, 5, 9, 20, 100, bar, foo, ";

  [super snapWaiter:ref
          withBlock:^(FIRDataSnapshot *snap) {
            NSMutableString *output = [[NSMutableString alloc] init];
            for (FIRDataSnapshot *n in snap.children) {
              [output appendFormat:@"%@, ", [n key]];
            }

            XCTAssertTrue([expected isEqualToString:output], @"Proper order");
          }];
}

- (void)testPrevNameIsCorrectOnChildAddedEvent {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  [node setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}];

  NSMutableString *added = [[NSMutableString alloc] init];

  __block int count = 0;
  [node observeEventType:FIRDataEventTypeChildAdded
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snap, NSString *prevName) {
        [added appendFormat:@"%@ %@, ", [snap key], prevName];
        count++;
      }];

  [self waitUntil:^BOOL {
    return count == 3;
  }];

  XCTAssertTrue([added isEqualToString:@"a (null), b a, c b, "], @"Proper order and prevname");
}

- (void)testPrevNameIsCorrectWhenAddingNewNodes {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  [node setValue:@{@"b" : @2, @"c" : @3, @"d" : @4}];

  NSMutableString *added = [[NSMutableString alloc] init];

  __block int count = 0;
  [node observeEventType:FIRDataEventTypeChildAdded
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snap, NSString *prevName) {
        [added appendFormat:@"%@ %@, ", [snap key], prevName];
        count++;
      }];

  [self waitUntil:^BOOL {
    return count == 3;
  }];

  XCTAssertTrue([added isEqualToString:@"b (null), c b, d c, "], @"Proper order and prevname");

  [added setString:@""];
  [[node child:@"a"] setValue:@1];
  [self waitUntil:^BOOL {
    return count == 4;
  }];

  XCTAssertTrue([added isEqualToString:@"a (null), "], @"Proper insertion of new node");

  [added setString:@""];
  [[node child:@"e"] setValue:@5];
  [self waitUntil:^BOOL {
    return count == 5;
  }];
  XCTAssertTrue([added isEqualToString:@"e d, "], @"Proper insertion of new node");
}

- (void)testPrevNameIsCorrectWhenAddingNewNodesWithJSON {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  [node setValue:@{@"b" : @2, @"c" : @3, @"d" : @4}];

  NSMutableString *added = [[NSMutableString alloc] init];
  __block int count = 0;
  [node observeEventType:FIRDataEventTypeChildAdded
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snap, NSString *prevName) {
        [added appendFormat:@"%@ %@, ", [snap key], prevName];
        count++;
      }];

  [self waitUntil:^BOOL {
    return count == 3;
  }];

  XCTAssertTrue([added isEqualToString:@"b (null), c b, d c, "], @"Proper order and prevname");

  [added setString:@""];
  [node setValue:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}];
  [self waitUntil:^BOOL {
    return count == 4;
  }];

  XCTAssertTrue([added isEqualToString:@"a (null), "], @"Proper insertion of new node");

  [added setString:@""];
  [node setValue:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4, @"e" : @5}];
  [self waitUntil:^BOOL {
    return count == 5;
  }];

  XCTAssertTrue([added isEqualToString:@"e d, "], @"Proper insertion of new node");
}

- (void)testPrevNameIsCorrectWhenMovingNodes {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  NSMutableString *moved = [[NSMutableString alloc] init];

  __block int count = 0;
  [node observeEventType:FIRDataEventTypeChildMoved
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
        [moved appendFormat:@"%@ %@, ", snapshot.key, prevName];
        count++;
      }];

  [[node child:@"a"] setValue:@"a" andPriority:@1];
  [[node child:@"b"] setValue:@"a" andPriority:@2];
  [[node child:@"c"] setValue:@"a" andPriority:@3];
  [[node child:@"d"] setValue:@"a" andPriority:@4];

  [[node child:@"d"] setPriority:@0];
  [self waitUntil:^BOOL {
    return count == 1;
  }];

  XCTAssertTrue([moved isEqualToString:@"d (null), "], @"Got first move");

  [moved setString:@""];
  [[node child:@"a"] setPriority:@4];
  [self waitUntil:^BOOL {
    return count == 2;
  }];

  XCTAssertTrue([moved isEqualToString:@"a c, "], @"Got second move");

  [moved setString:@""];
  [[node child:@"c"] setPriority:@0.5];
  [self waitUntil:^BOOL {
    return count == 3;
  }];

  XCTAssertTrue([moved isEqualToString:@"c d, "], @"Got third move");
}

- (void)testPrevNameIsCorrectWhenSettingWholeJsonDict {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  NSMutableString *moved = [[NSMutableString alloc] init];

  __block int count = 0;
  [node observeEventType:FIRDataEventTypeChildMoved
      andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
        [moved appendFormat:@"%@ %@, ", snapshot.key, prevName];
        count++;
      }];

  [node setValue:@{
    @"a" : @{@".value" : @"a", @".priority" : @1},
    @"b" : @{@".value" : @"b", @".priority" : @2},
    @"c" : @{@".value" : @"c", @".priority" : @3},
    @"d" : @{@".value" : @"d", @".priority" : @4}
  }];

  [node setValue:@{
    @"d" : @{@".value" : @"d", @".priority" : @0},
    @"a" : @{@".value" : @"a", @".priority" : @1},
    @"b" : @{@".value" : @"b", @".priority" : @2},
    @"c" : @{@".value" : @"c", @".priority" : @3}
  }];
  [self waitUntil:^BOOL {
    return count == 1;
  }];

  XCTAssertTrue([moved isEqualToString:@"d (null), "], @"Got move");

  [moved setString:@""];

  [node setValue:@{
    @"d" : @{@".value" : @"d", @".priority" : @0},
    @"b" : @{@".value" : @"b", @".priority" : @2},
    @"c" : @{@".value" : @"c", @".priority" : @3},
    @"a" : @{@".value" : @"a", @".priority" : @4}
  }];

  [self waitUntil:^BOOL {
    return count == 2;
  }];

  XCTAssertTrue([moved isEqualToString:@"a c, "], @"Got move");

  [moved setString:@""];

  [node setValue:@{
    @"d" : @{@".value" : @"d", @".priority" : @0},
    @"c" : @{@".value" : @"c", @".priority" : @0.5},
    @"b" : @{@".value" : @"b", @".priority" : @2},
    @"a" : @{@".value" : @"a", @".priority" : @4}
  }];

  [self waitUntil:^BOOL {
    return count == 3;
  }];

  XCTAssertTrue([moved isEqualToString:@"c d, "], @"Got move");
}

- (void)testCase595NoChildMovedEventWhenDeletingPrioritizedGrandchild {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block int moves = 0;
  [node observeEventType:FIRDataEventTypeChildMoved
               withBlock:^(FIRDataSnapshot *snapshot) {
                 moves++;
               }];

  __block BOOL ready = NO;
  [[node child:@"test/foo"] setValue:@42 andPriority:@"5"];
  [[node child:@"test/foo2"] setValue:@42 andPriority:@"10"];
  [[node child:@"test/foo"] removeValue];
  [[node child:@"test/foo"]
      removeValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue(moves == 0, @"Nothing should have moved");
}

- (void)testCanSetAValueWithPriZero {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap = nil;
  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *s) {
                 snap = s;
               }];

  [node setValue:@"test" andPriority:@0];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertEqualObjects([snap value], @"test", @"Proper value");
  XCTAssertEqualObjects([snap priority], @0, @"Proper value");
}

- (void)testCanSetObjectWithPriZero {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap = nil;
  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *s) {
                 snap = s;
               }];

  [node setValue:@{@"x" : @"test", @"y" : @7} andPriority:@0];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertEqualObjects([[snap value] objectForKey:@"x"], @"test", @"Proper value");
  XCTAssertEqualObjects([[snap value] objectForKey:@"y"], @7, @"Proper value");
  XCTAssertEqualObjects([snap priority], @0, @"Proper value");
}

@end
