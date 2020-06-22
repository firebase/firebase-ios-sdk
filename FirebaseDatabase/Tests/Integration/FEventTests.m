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

#import "FirebaseDatabase/Tests/Integration/FEventTests.h"
#import "FirebaseDatabase/Tests/Helpers/FEventTester.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"
#import "FirebaseDatabase/Tests/Helpers/FTupleEventTypeString.h"

@implementation FEventTests

- (void)testInvalidEventType {
  FIRDatabaseReference* f = [FTestHelpers getRandomNode];
  XCTAssertThrows([f observeEventType:-4
                            withBlock:^(FIRDataSnapshot* s){
                            }],
                  @"Invalid event type properly throws an error");
}

- (void)testWriteLeafExpectValueChanged {
  FTupleFirebase* tuple = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writeNode = tuple.one;
  FIRDatabaseReference* readNode = tuple.two;

  __block BOOL done = NO;
  [writeNode setValue:@1234
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  [self waitUntil:^BOOL {
    return done;
  }];

  [super snapWaiter:readNode
          withBlock:^(FIRDataSnapshot* s) {
            XCTAssertEqualObjects([s value], @1234, @"Proper value in snapshot");
          }];
}

- (void)testWRiteLeafNodeThenExpectValueEvent {
  FIRDatabaseReference* writeNode = [FTestHelpers getRandomNode];
  [writeNode setValue:@42];

  [super snapWaiter:writeNode
          withBlock:^(FIRDataSnapshot* s) {
            XCTAssertEqualObjects([s value], @42, @"Proper value in snapshot");
          }];
}

- (void)testWriteLeafNodeThenExpectChildAddedEventThenValueEvent {
  FIRDatabaseReference* writeNode = [FTestHelpers getRandomNode];

  [[writeNode child:@"foo"] setValue:@878787];

  NSArray* lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:writeNode
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"foo"],
    [[FTupleEventTypeString alloc] initWithFirebase:writeNode
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
  ];

  FEventTester* et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:lookingFor];
  [et wait];

  [super snapWaiter:writeNode
          withBlock:^(FIRDataSnapshot* s) {
            XCTAssertEqualObjects([[s childSnapshotForPath:@"foo"] value], @878787,
                                  @"Got proper value");
          }];
}

- (void)testSetMultipleEventListenersOnSameNode {
  FTupleFirebase* tuple = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writeNode = tuple.one;
  FIRDatabaseReference* readNode = tuple.two;

  [writeNode setValue:@42];

  // two write nodes
  FEventTester* et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:@[ [[FTupleEventTypeString alloc] initWithFirebase:writeNode
                                                             withEvent:FIRDataEventTypeValue
                                                            withString:nil] ]];
  [et wait];

  et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:@[ [[FTupleEventTypeString alloc] initWithFirebase:writeNode
                                                             withEvent:FIRDataEventTypeValue
                                                            withString:nil] ]];
  [et wait];

  // two read nodes
  et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:@[ [[FTupleEventTypeString alloc] initWithFirebase:readNode
                                                             withEvent:FIRDataEventTypeValue
                                                            withString:nil] ]];
  [et wait];

  et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:@[ [[FTupleEventTypeString alloc] initWithFirebase:readNode
                                                             withEvent:FIRDataEventTypeValue
                                                            withString:nil] ]];
  [et wait];
}

- (void)testUnsubscribeEventsAndConfirmThatEventsNoLongerFire {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];
  __block int numValueCB = 0;

  FIRDatabaseHandle handle = [node observeEventType:FIRDataEventTypeValue
                                          withBlock:^(FIRDataSnapshot* s) {
                                            numValueCB = numValueCB + 1;
                                          }];

  // Set
  for (int i = 0; i < 3; i++) {
    [node setValue:[NSNumber numberWithInt:i]];
  }

  // bye
  [node removeObserverWithHandle:handle];

  // set again
  for (int i = 10; i < 15; i++) {
    [node setValue:[NSNumber numberWithInt:i]];
  }

  for (int i = 20; i < 25; i++) {
    [node setValue:[NSNumber numberWithInt:i]];
  }

  // Should just be 3
  [self waitUntil:^BOOL {
    return numValueCB == 3;
  }];
}

- (void)testCanWriteACompoundObjectAndGetMoreGranularEventsForIndividualChanges {
  FTupleFirebase* tuple = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writeNode = tuple.one;
  FIRDatabaseReference* readNode = tuple.two;

  __block BOOL done = NO;
  [writeNode setValue:@{@"a" : @10, @"b" : @20}
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  NSArray* lookingForW = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[writeNode child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[writeNode child:@"b"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
  ];

  NSArray* lookingForR = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[readNode child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[readNode child:@"b"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
  ];

  FEventTester* etW = [[FEventTester alloc] initFrom:self];
  [etW addLookingFor:lookingForW];
  [etW wait];

  FEventTester* etR = [[FEventTester alloc] initFrom:self];
  [etR addLookingFor:lookingForR];
  [etR wait];

  // Modify compound but just change one of them

  lookingForW = @[ [[FTupleEventTypeString alloc] initWithFirebase:[writeNode child:@"b"]
                                                         withEvent:FIRDataEventTypeValue
                                                        withString:nil] ];
  lookingForR = @[ [[FTupleEventTypeString alloc] initWithFirebase:[readNode child:@"b"]
                                                         withEvent:FIRDataEventTypeValue
                                                        withString:nil] ];

  [etW addLookingFor:lookingForW];
  [etR addLookingFor:lookingForR];

  [writeNode setValue:@{@"a" : @10, @"b" : @30}];

  [etW wait];
  [etR wait];
}

- (void)testValueEventIsFiredForEmptyNode {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];

  __block BOOL valueFired = NO;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot* s) {
                 XCTAssertTrue([[s value] isEqual:[NSNull null]], @"Value is properly nil");
                 valueFired = YES;
               }];

  [self waitUntil:^BOOL {
    return valueFired;
  }];
}

- (void)testCorrectEventsRaisedWhenLeafTurnsIntoInternalNode {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];
  NSMutableString* eventString = [[NSMutableString alloc] init];

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot* s) {
                 if ([s hasChildren]) {
                   [eventString appendString:@", got children"];
                 } else {
                   [eventString appendFormat:@", value %@", [s value]];
                 }
               }];

  [node observeEventType:FIRDataEventTypeChildAdded
               withBlock:^(FIRDataSnapshot* s) {
                 [eventString appendFormat:@", child_added %@", [s key]];
               }];

  [node setValue:@42];
  [node setValue:@{@"a" : @2}];
  [node setValue:@84];
  __block BOOL done = NO;
  [node setValue:nil
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  [self waitUntil:^BOOL {
    return done;
  }];

  XCTAssertEqualObjects(@", value 42, child_added a, got children, value 84, value <null>",
                        eventString, @"Proper order seen");
}

- (void)testRegisteringCallbackMultipleTimesAndUnregistering {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];
  __block int changes = 0;

  fbt_void_datasnapshot cb = ^(FIRDataSnapshot* snapshot) {
    changes = changes + 1;
  };

  FIRDatabaseHandle handle1 = [node observeEventType:FIRDataEventTypeValue withBlock:cb];
  FIRDatabaseHandle handle2 = [node observeEventType:FIRDataEventTypeValue withBlock:cb];
  FIRDatabaseHandle handle3 = [node observeEventType:FIRDataEventTypeValue withBlock:cb];

  __block BOOL done = NO;

  [node setValue:@42
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  [self waitUntil:^BOOL {
    return done;
  }];
  done = NO;

  XCTAssertTrue(changes == 3, @"Saw 3 callback events %d", changes);

  [node removeObserverWithHandle:handle1];
  [node setValue:@84
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  [self waitUntil:^BOOL {
    return done;
  }];
  done = NO;

  XCTAssertTrue(changes == 5, @"Saw 5 callback events %d", changes);

  [node removeObserverWithHandle:handle2];
  [node setValue:@168
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  [self waitUntil:^BOOL {
    return done;
  }];
  done = NO;

  XCTAssertTrue(changes == 6, @"Saw 6 callback events %d", changes);

  [node removeObserverWithHandle:handle3];
  [node setValue:@376
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  [self waitUntil:^BOOL {
    return done;
  }];
  done = NO;

  XCTAssertTrue(changes == 6, @"Saw 6 callback events %d", changes);

  NSLog(@"callbacks: %d", changes);
}

- (void)testUnregisteringTheSameCallbackTooManyTimesDoesNothing {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];

  fbt_void_datasnapshot cb = ^(FIRDataSnapshot* snapshot) {
  };

  FIRDatabaseHandle handle1 = [node observeEventType:FIRDataEventTypeValue withBlock:cb];
  [node removeObserverWithHandle:handle1];
  [node removeObserverWithHandle:handle1];

  XCTAssertTrue(YES, @"Properly reached end of test without throwing errors.");
}

- (void)testOnceValueFiresExactlyOnce {
  FIRDatabaseReference* path = [FTestHelpers getRandomNode];
  __block BOOL firstCall = YES;

  [path observeSingleEventOfType:FIRDataEventTypeValue
                       withBlock:^(FIRDataSnapshot* snapshot) {
                         XCTAssertTrue(firstCall, @"Properly saw first call");
                         firstCall = NO;
                         XCTAssertEqualObjects(@42, [snapshot value], @"Properly saw node value");
                       }];

  [path setValue:@42];
  [path setValue:@84];

  __block BOOL done = NO;

  [path setValue:nil
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testOnceChildAddedFiresExaclyOnce {
  __block int badCount = 0;

  // for(int i = 0; i < 100; i++) {

  FIRDatabaseReference* path = [FTestHelpers getRandomNode];
  __block BOOL firstCall = YES;

  __block BOOL done = NO;

  [path observeSingleEventOfType:FIRDataEventTypeChildAdded
                       withBlock:^(FIRDataSnapshot* snapshot) {
                         XCTAssertTrue(firstCall, @"Properly saw first call");
                         firstCall = NO;
                         XCTAssertEqualObjects(@42, [snapshot value], @"Properly saw node value");
                         XCTAssertEqualObjects(@"foo", [snapshot key],
                                               @"Properly saw the first node");
                         if (![[snapshot value] isEqual:@42]) {
                           exit(-1);
                           badCount = badCount + 1;
                         }

                         done = YES;
                       }];

  [[path child:@"foo"] setValue:@42];
  [[path child:@"bar"] setValue:@84];  // XXX FIXME sometimes this event fires first
  [[path child:@"foo"] setValue:@168];

  //    [path setValue:nil withCompletionBlock:^(BOOL status) { done = YES; }];
  [self waitUntil:^BOOL {
    return done;
  }];

  //  }

  NSLog(@"BADCOUNT: %d", badCount);
}

- (void)testOnceValueFiresExacltyOnceEvenIfThereIsASetInsideCallback {
  FIRDatabaseReference* path = [FTestHelpers getRandomNode];
  __block BOOL firstCall = YES;
  __block BOOL done = NO;

  [path observeSingleEventOfType:FIRDataEventTypeValue
                       withBlock:^(FIRDataSnapshot* snapshot) {
                         XCTAssertTrue(firstCall, @"Properly saw first call");
                         if (firstCall) {
                           firstCall = NO;
                           XCTAssertEqualObjects(@42, [snapshot value], @"Properly saw node value");
                           [path setValue:@43];
                           done = YES;
                         } else {
                           XCTFail(@"Callback got called more than once.");
                         }
                       }];

  [path setValue:@42];
  [path setValue:@84];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testOnceChildAddedFiresOnceEvenWithCompoundObject {
  FIRDatabaseReference* path = [FTestHelpers getRandomNode];
  __block BOOL firstCall = YES;

  [path observeSingleEventOfType:FIRDataEventTypeChildAdded
                       withBlock:^(FIRDataSnapshot* snapshot) {
                         XCTAssertTrue(firstCall, @"Properly saw first call");
                         firstCall = NO;
                         XCTAssertEqualObjects(@84, [snapshot value], @"Properly saw node value");
                         XCTAssertEqualObjects(@"bar", [snapshot key],
                                               @"Properly saw the first node");
                       }];

  [path setValue:@{@"foo" : @42, @"bar" : @84}];

  __block BOOL done = NO;

  [path setValue:nil
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testOnEmptyChildFires {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];
  __block BOOL done = NO;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot* snapshot){
               }];
  [[node child:@"test"] observeEventType:FIRDataEventTypeValue
                               withBlock:^(FIRDataSnapshot* snapshot) {
                                 XCTAssertTrue([[snapshot value] isEqual:[NSNull null]],
                                               @"Properly saw nil child node");
                                 done = YES;
                               }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testOnEmptyChildEvenAfterParentIsSynched {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];
  __block BOOL parentDone = NO;
  __block BOOL done = NO;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot* snapshot) {
                 parentDone = YES;
               }];

  [self waitUntil:^BOOL {
    return parentDone;
  }];

  [[node child:@"test"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               XCTAssertTrue([[snapshot value] isEqual:[NSNull null]], @"Child is properly nil");
               done = YES;
             }];

  // This test really isn't in the same spirit as the JS test; we can't currently make sure that the
  // test fires right away since the ON and callback are async

  [self waitUntil:^BOOL {
    return done;
  }];

  XCTAssertTrue(done, @"Done fired.");
}

- (void)testEventsAreRaisedChildRemovedChildAddedChildMoved {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];

  NSMutableArray* events = [[NSMutableArray alloc] init];

  [node observeEventType:FIRDataEventTypeChildAdded
               withBlock:^(FIRDataSnapshot* snap) {
                 [events addObject:[NSString stringWithFormat:@"added %@", [snap key]]];
               }];

  [node observeEventType:FIRDataEventTypeChildRemoved
               withBlock:^(FIRDataSnapshot* snap) {
                 [events addObject:[NSString stringWithFormat:@"removed %@", [snap key]]];
               }];

  [node observeEventType:FIRDataEventTypeChildMoved
               withBlock:^(FIRDataSnapshot* snap) {
                 [events addObject:[NSString stringWithFormat:@"moved %@", [snap key]]];
               }];

  __block BOOL done = NO;

  [node setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @0},
    @"b" : @{@".value" : @1, @".priority" : @1},
    @"c" : @{@".value" : @1, @".priority" : @2},
    @"d" : @{@".value" : @1, @".priority" : @3},
    @"e" : @{@".value" : @1, @".priority" : @4},
    @"f" : @{@".value" : @1, @".priority" : @5},
  }
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [events removeAllObjects];

  done = NO;

  [node setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @5},
    @"aa" : @{@".value" : @1, @".priority" : @0},
    @"b" : @{@".value" : @1, @".priority" : @1},
    @"bb" : @{@".value" : @1, @".priority" : @2},
    @"d" : @{@".value" : @1, @".priority" : @3},
    @"e" : @{@".value" : @1, @".priority" : @6},
  }
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  XCTAssertEqualObjects(@"removed c, removed f, added aa, added bb, moved a, moved e",
                        [events componentsJoinedByString:@", "], @"Got expected results");
}

- (void)testIntegerToDoubleConversions {
  FIRDatabaseReference* node = [FTestHelpers getRandomNode];

  NSMutableArray<NSString*>* events = [[NSMutableArray alloc] init];

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot* snap) {
                 [events addObject:[NSString stringWithFormat:@"value %@", [snap value]]];
               }];

  for (NSNumber* number in @[ @1, @1.0, @1, @1.1 ]) {
    [self waitForCompletionOf:node setValue:number];
  }

  XCTAssertEqualObjects(@"value 1, value 1.1", [events componentsJoinedByString:@", "],
                        @"Got expected results");
}

- (void)testEventsAreRaisedProperlyWithOnQueryLimits {
  // xxx impl query
}

@end
