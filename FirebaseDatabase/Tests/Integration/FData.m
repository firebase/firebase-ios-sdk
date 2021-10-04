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

#import "FirebaseDatabase/Tests/Integration/FData.h"
#import <limits.h>
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Core/FRepo_Private.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRServerValue.h"
#import "FirebaseDatabase/Tests/Helpers/FEventTester.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"
#import "FirebaseDatabase/Tests/Helpers/FTupleEventTypeString.h"

@implementation FData

- (void)testGetNode {
  __unused FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  XCTAssertTrue(YES, @"Properly created node without throwing error");
}

- (void)testWriteData {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  [node setValue:@42];
  XCTAssertTrue(YES, @"Properly write to node without throwing error");
}

- (void)testWriteDataWithDebugLogging {
  [FIRDatabase setLoggingEnabled:YES];
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  [node setValue:@42];
  [FIRDatabase setLoggingEnabled:NO];
  XCTAssertTrue(YES, @"Properly write to node without throwing error");
}

- (void)testWriteAndReadData {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  [node setValue:@42];

  [self snapWaiter:node
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertEqualObjects(@42, [snapshot value], @"Properly saw correct value");
         }];
}

- (void)testProperParamChecking {
  // ios doesn't have an equivalent of this test
}

- (void)testNamespaceCaseInsensitivityWithinARepo {
  FIRDatabaseReference *ref1 =
      [[FTestHelpers defaultDatabase] referenceFromURL:[self.databaseURL uppercaseString]];
  FIRDatabaseReference *ref2 =
      [[FTestHelpers defaultDatabase] referenceFromURL:[self.databaseURL lowercaseString]];

  XCTAssertTrue([ref1.description isEqualToString:ref2.description], @"Descriptions should match");
}

- (void)testRootProperty {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  FIRDatabaseReference *root = node.root;
  XCTAssertTrue(root != nil, @"Should get a root");
  XCTAssertTrue([[root description] isEqualToString:self.databaseURL],
                @"Root is actually the root");
}

- (void)testValReturnsCompoundObjectWithChildren {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  [node setValue:@{@"foo" : @{@"bar" : @5}}];

  [self snapWaiter:node
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertEqualObjects([[[snapshot value] objectForKey:@"foo"] objectForKey:@"bar"], @5,
                                 @"Properly saw compound object");
         }];
}

- (void)testWriteDataAndWaitForServerConfirmation {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  [self waitForCompletionOf:node setValue:@42];
}

- (void)testWriteAValueAndRead {
  // dupe of FEvent testWriteLeafExpectValueChanged
}

- (void)testWriteABunchOfDataAndRead {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writeNode = tuple.one;
  FIRDatabaseReference *readNode = tuple.two;

  __block BOOL done = NO;

  [[[[writeNode child:@"a"] child:@"b"] child:@"c"] setValue:@1];
  [[[[writeNode child:@"a"] child:@"d"] child:@"e"] setValue:@2];
  [[[[writeNode child:@"a"] child:@"d"] child:@"f"] setValue:@3];
  [[writeNode child:@"g"] setValue:@4
               withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
                 done = YES;
               }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [super snapWaiter:readNode
          withBlock:^(FIRDataSnapshot *s) {
            XCTAssertEqualObjects([[[[s childSnapshotForPath:@"a"] childSnapshotForPath:@"b"]
                                      childSnapshotForPath:@"c"] value],
                                  @1, @"Proper child value");
            XCTAssertEqualObjects([[[[s childSnapshotForPath:@"a"] childSnapshotForPath:@"d"]
                                      childSnapshotForPath:@"e"] value],
                                  @2, @"Proper child value");
            XCTAssertEqualObjects([[[[s childSnapshotForPath:@"a"] childSnapshotForPath:@"d"]
                                      childSnapshotForPath:@"f"] value],
                                  @3, @"Proper child value");
            XCTAssertEqualObjects([[s childSnapshotForPath:@"g"] value], @4, @"Proper child value");
          }];
}

- (void)testWriteABunchOfDataWithLeadingZeroesAndRead {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writeNode = tuple.one;
  FIRDatabaseReference *readNode = tuple.two;

  [self waitForCompletionOf:[writeNode child:@"1"] setValue:@1];
  [self waitForCompletionOf:[writeNode child:@"01"] setValue:@2];
  [self waitForCompletionOf:[writeNode child:@"001"] setValue:@3];
  [self waitForCompletionOf:[writeNode child:@"0001"] setValue:@4];

  [super
      snapWaiter:readNode
       withBlock:^(FIRDataSnapshot *s) {
         XCTAssertEqualObjects([[s childSnapshotForPath:@"1"] value], @1, @"Proper child value");
         XCTAssertEqualObjects([[s childSnapshotForPath:@"01"] value], @2, @"Proper child value");
         XCTAssertEqualObjects([[s childSnapshotForPath:@"001"] value], @3, @"Proper child value");
         XCTAssertEqualObjects([[s childSnapshotForPath:@"0001"] value], @4, @"Proper child value");
       }];
}

- (void)testLeadingZeroesTurnIntoDictionary {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  [self waitForCompletionOf:[ref child:@"1"] setValue:@1];
  [self waitForCompletionOf:[ref child:@"01"] setValue:@2];

  __block BOOL done = NO;
  __block FIRDataSnapshot *snap = nil;

  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                snap = snapshot;
                done = YES;
              }];

  WAIT_FOR(done);

  XCTAssertTrue([snap.value isKindOfClass:[NSDictionary class]], @"Should be dictionary");
  XCTAssertEqualObjects([snap.value objectForKey:@"1"], @1, @"Proper child value");
  XCTAssertEqualObjects([snap.value objectForKey:@"01"], @2, @"Proper child value");
}

- (void)testLeadingZerosDontCollapseLocally {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  __block FIRDataSnapshot *snap = nil;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                snap = snapshot;
                done = (snapshot.childrenCount == 2);
              }];

  [[ref child:@"3"] setValue:@YES];
  [[ref child:@"03"] setValue:@NO];

  WAIT_FOR(done);

  XCTAssertEqualObjects([[snap childSnapshotForPath:@"3"] value], @YES, @"Proper child value");
  XCTAssertEqualObjects([[snap childSnapshotForPath:@"03"] value], @NO, @"Proper child value");
}

- (void)testSnapshotRef {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                [snapshot.ref observeSingleEventOfType:FIRDataEventTypeValue
                                             withBlock:^(FIRDataSnapshot *snapshot) {
                                               done = YES;
                                             }];
              }];
  WAIT_FOR(done);
}

- (void)testWriteLeafNodeOverwriteAtParentVerifyExpectedEvents {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  FIRDatabaseReference *connected =
      [[[FTestHelpers defaultDatabase] reference] child:@".info/connected"];
  __block BOOL ready = NO;
  [connected observeEventType:FIRDataEventTypeValue
                    withBlock:^(FIRDataSnapshot *snapshot) {
                      NSNumber *val = [snapshot value];
                      ready = [val boolValue];
                    }];

  WAIT_FOR(ready);

  NSArray *lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],  // 4
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"aa"],  // 0
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],  // 4
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"aa"],  // 2
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],  // 4
  ];

  [[node repo]
      interrupt];  // Going offline ensures that local events get queued up before server events
  FEventTester *et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:lookingFor];

  [[node child:@"a/aa"] setValue:@1];
  [[node child:@"a"] setValue:@{@"aa" : @2}];

  [[node repo] resume];
  [et wait];
}

- (void)testWriteLeafNodeOverwriteAtParentMultipleTimesVerifyExpectedEvents {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  NSArray *lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/bb"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
  ];

  [[node repo]
      interrupt];  // Going offline ensures that local events get queued up before server events
  FEventTester *et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:lookingFor];

  [[node child:@"a/aa"] setValue:@1];
  [[node child:@"a"] setValue:@{@"aa" : @2}];
  [[node child:@"a"] setValue:@{@"aa" : @3}];
  [[node child:@"a"] setValue:@{@"aa" : @3}];

  [[node repo] resume];
  [et wait];
}

#ifdef FLAKY_TEST
This test flakes frequently on the emulator on travis and almost always on GHA with

    testWriteLeafNodeRemoveLeafVerifyExpectedEvents,
    failed
    : caught "NSInternalInconsistencyException",
      "Unable to report test assertion failure '(([target isEqualTo:recvd]) is true) failed: throwing
      "Unable to report test assertion failure '(([target isEqualTo:recvd]) is true) failed - Expected
              http :          // localhost:9000/-M8IJYWb68MuqQKKz2IY/a aa (0) to match
                      http :  // localhost:9000/-M8IJYWb68MuqQKKz2IY/a (null) (4)' from
                              /
                              Users / runner / runners / 2.262.1 / work / firebase -
          ios - sdk / firebase - ios -
          sdk / Example / Database / Tests / Helpers /
              FEventTester
                  .m : 123 because it was raised inside test case -[FEventTester(null)] which has no
                      associated XCTestRun object.This may happen when test cases are
                          constructed and invoked independently of standard XCTest infrastructure,
      or when the test has already finished
                      ." - Expected http://localhost:9000/-M8IJYWb68MuqQKKz2IY/a aa (0) to match "
                       "http://localhost:9000/-M8IJYWb68MuqQKKz2IY/a (null) (4)' from "
                       "/Users/runner/runners/2.262.1/work/firebase-ios-sdk/firebase-ios-sdk/"
                       "Example/Database/Tests/Helpers/FEventTester.m:123 because it was raised "
                       "inside test case -[FEventTester (null)] which has no associated XCTestRun "
                       "object. This may happen when test cases are constructed and invoked "
                       "independently of standard XCTest infrastructure, or when the test has "
                       "already finished." /
                  Users / runner / runners / 2.262.1 / work / firebase -
              ios - sdk / firebase - ios -
              sdk / Example / Database / Tests / Helpers / FEventTester.m : 123
``` FTupleEventTypeString *recvd = [self.actualPathsAndEvents objectAtIndex:i];
XCTAssertTrue([target isEqualTo:recvd], @"Expected %@ to match %@", target, recvd);

- (void)testWriteParentNodeOverwriteAtLeafVerifyExpectedEvents {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  NSArray *lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
  ];

  [[node repo]
      interrupt];  // Going offline ensures that local events get queued up before server events
  FEventTester *et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:lookingFor];

  [[node child:@"a"] setValue:@{@"aa" : @2}];
  [[node child:@"a/aa"] setValue:@1];

  [[node repo] resume];
  [et wait];
}

- (void)testWriteLeafNodeRemoveParentNodeVerifyExpectedEvents {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  NSArray *lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a"]
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:writer
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:writer
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
  ];
  FEventTester *et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:lookingFor];

  [[writer child:@"a/aa"] setValue:@42];
  // the local events
  [et wait];

  // the reader should get all of the events intermingled
  FEventTester *readerEvents = [[FEventTester alloc] initFrom:self];
  lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [readerEvents addLookingFor:lookingFor];

  [readerEvents wait];

  lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeChildRemoved
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeChildRemoved
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];
  [readerEvents addLookingFor:lookingFor];

  lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a"]
                                          withEvent:FIRDataEventTypeChildRemoved
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:writer
                                          withEvent:FIRDataEventTypeChildRemoved
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:writer
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [et addLookingFor:lookingFor];

  [[writer child:@"a"] removeValue];

  [et wait];
  [readerEvents wait];

  [et unregister];
  [readerEvents unregister];

  // Ensure we can write a new value
  __block NSNumber *readVal = @0.0;
  __block NSNumber *writeVal = @0.0;

  [[reader child:@"a/aa"] observeEventType:FIRDataEventTypeValue
                                 withBlock:^(FIRDataSnapshot *snapshot) {
                                   id val = [snapshot value];
                                   if (val != [NSNull null]) {
                                     readVal = val;
                                   }
                                 }];

  [[writer child:@"a/aa"] observeEventType:FIRDataEventTypeValue
                                 withBlock:^(FIRDataSnapshot *snapshot) {
                                   id val = [snapshot value];
                                   if (val != [NSNull null]) {
                                     writeVal = val;
                                   }
                                 }];

  [[writer child:@"a/aa"] setValue:@3.1415];

  [self waitUntil:^BOOL {
    return fabs([readVal doubleValue] - 3.1415) < 0.001 &&
           fabs([writeVal doubleValue] - 3.1415) < 0.001;
    // return [readVal isEqualToNumber:@3.1415] && [writeVal isEqualToNumber:@3.1415];
  }];
}

- (void)testWriteLeafNodeRemoveLeafVerifyExpectedEvents {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  NSArray *lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a"]
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:writer
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:writer
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
  ];
  FEventTester *et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:lookingFor];
  [[writer child:@"a/aa"] setValue:@42];

  // the local events
  [et wait];

  // the reader should get all of the events intermingled
  FEventTester *readerEvents = [[FEventTester alloc] initFrom:self];
  lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeChildAdded
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [readerEvents addLookingFor:lookingFor];

  [readerEvents wait];

  lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeChildRemoved
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeChildRemoved
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];
  [readerEvents addLookingFor:lookingFor];

  lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a"]
                                          withEvent:FIRDataEventTypeChildRemoved
                                         withString:@"aa"],
    [[FTupleEventTypeString alloc] initWithFirebase:[writer child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:writer
                                          withEvent:FIRDataEventTypeChildRemoved
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:writer
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [et addLookingFor:lookingFor];

  // remove just the leaf
  [[writer child:@"a/aa"] removeValue];

  [et wait];
  [readerEvents wait];

  [et unregister];
  [readerEvents unregister];

  // Ensure we can write a new value
  __block NSNumber *readVal = @0.0;
  __block NSNumber *writeVal = @0.0;

  [[reader child:@"a/aa"] observeEventType:FIRDataEventTypeValue
                                 withBlock:^(FIRDataSnapshot *snapshot) {
                                   id val = [snapshot value];
                                   if (val != [NSNull null]) {
                                     readVal = val;
                                   }
                                 }];

  [[writer child:@"a/aa"] observeEventType:FIRDataEventTypeValue
                                 withBlock:^(FIRDataSnapshot *snapshot) {
                                   id val = [snapshot value];
                                   if (val != [NSNull null]) {
                                     writeVal = val;
                                   }
                                 }];

  [[writer child:@"a/aa"] setValue:@3.1415];

  [self waitUntil:^BOOL {
    // NSLog(@"readVal: %@, writeVal: %@, vs %@", readVal, writeVal, @3.1415);
    // return [readVal isEqualToNumber:@3.1415] && [writeVal isEqualToNumber:@3.1415];
    return fabs([readVal doubleValue] - 3.1415) < 0.001 &&
           fabs([writeVal doubleValue] - 3.1415) < 0.001;
  }];
}
#endif

- (void)testWriteMultipleLeafNodesRemoveOnlyOneVerifyExpectedEvents {
  // XXX impl
}

- (void)testVerifyNodeNamesCantStartWithADot {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  XCTAssertThrows([ref child:@".foo"], @"not a valid .prefix");
  XCTAssertThrows([ref child:@"foo/.foo"], @"not a valid path");
  // Should not throw
  [[ref parent] child:@".info"];
}

- (void)testVerifyWritingToDotLengthAndDotKeysThrows {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  XCTAssertThrows([[ref child:@".keys"] setValue:@42], @"not a valid .prefix");
  XCTAssertThrows([[ref child:@".length"] setValue:@42], @"not a valid path");
}

- (void)testNumericKeysGetTurnedIntoArrays {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  [[ref child:@"0"] setValue:@"alpha"];
  [[ref child:@"1"] setValue:@"bravo"];
  [[ref child:@"2"] setValue:@"charlie"];
  [[ref child:@"3"] setValue:@"delta"];
  [[ref child:@"4"] setValue:@"echo"];

  __block BOOL ready = NO;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                id val = [snapshot value];
                XCTAssertTrue([val isKindOfClass:[NSArray class]], @"Expected an array");
                NSArray *expected = @[ @"alpha", @"bravo", @"charlie", @"delta", @"echo" ];
                XCTAssertTrue([expected isEqualToArray:val], @"Did not get the correct array");
                ready = YES;
              }];

  [self waitUntil:^{
    return ready;
  }];
}

// This was an issue on 64-bit.
- (void)testLargeNumericKeysDontGetTurnedIntoArrays {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  [[ref child:@"100003354884401"] setValue:@"alpha"];

  __block BOOL ready = NO;
  [ref observeSingleEventOfType:FIRDataEventTypeValue
                      withBlock:^(FIRDataSnapshot *snapshot) {
                        id val = [snapshot value];
                        XCTAssertTrue([val isKindOfClass:[NSDictionary class]],
                                      @"Expected a dictionary.");
                        ready = YES;
                      }];

  [self waitUntil:^{
    return ready;
  }];
}

- (void)testWriteCompoundObjectAndGetItBack {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  NSDictionary *data = @{
    @"a" : @{@"aa" : @5, @"ab" : @3},
    @"b" : @{@"ba" : @"hey there!", @"bb" : @{@"bba" : @NO}},
    @"c" : @[ @0, @{@"c_1" : @4}, @"hey", @YES, @NO, @"dude" ]
  };

  __block FIRDataSnapshot *snap = nil;
  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 snap = snapshot;
               }];

  __block BOOL done = NO;
  [node setValue:data
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [self snapWaiter:node
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertTrue([[[[snapshot value] objectForKey:@"c"] objectAtIndex:3] boolValue],
                         @"Got proper boolean");
         }];
}

- (void)testCanPassValueToPush {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  FIRDatabaseReference *pushA = [node childByAutoId];
  [pushA setValue:@5];

  [self snapWaiter:pushA
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertEqualObjects(@5, [snapshot value], @"Got proper value");
         }];

  FIRDatabaseReference *pushB = [node childByAutoId];
  [pushB setValue:@{@"a" : @5, @"b" : @6}];

  [self snapWaiter:pushB
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertEqualObjects(@5, [[snapshot value] objectForKey:@"a"], @"Got proper value");
           XCTAssertEqualObjects(@6, [[snapshot value] objectForKey:@"b"], @"Got proper value");
         }];
}

// Dropped test that tested callbacks to push. Support was removed.

- (void)testRemoveCallbackHit {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];
  __block BOOL setDone = NO;
  __block BOOL removeDone = NO;
  __block BOOL readDone = NO;

  [node setValue:@42
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        setDone = YES;
      }];

  [self waitUntil:^BOOL {
    return setDone;
  }];

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 id val = [snapshot value];
                 if (val == [NSNull null]) {
                   readDone = YES;
                 }
               }];

  [node removeValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
    XCTAssertTrue(error == nil, @"Should not be an error removing");
    removeDone = YES;
  }];

  [self waitUntil:^BOOL {
    return readDone && removeDone;
  }];
}

- (void)testRemoveCallbackIsHitForNodesThatAreAlreadyRemoved {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block int removes = 0;

  [node removeValueWithCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
    removes = removes + 1;
  }];

  [node removeValueWithCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
    removes = removes + 1;
  }];

  [self waitUntil:^BOOL {
    return removes == 2;
  }];
}

- (void)testUsingNumbersAsKeysDoesntCreateHugeSparseArrays {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  [[ref child:@"3024"] setValue:@5];

  __block BOOL ready = NO;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                id val = [snapshot value];
                XCTAssertTrue(![val isKindOfClass:[NSArray class]], @"Should not be an array");
                ready = YES;
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testOnceWithACallbackHitsServer {
  FTupleFirebase *tuple = [FTestHelpers getRandomNodeTriple];
  FIRDatabaseReference *writeNode = tuple.one;
  FIRDatabaseReference *readNode = tuple.two;
  FIRDatabaseReference *readNodeB = tuple.three;

  __block BOOL initialReadDone = NO;

  [readNode observeSingleEventOfType:FIRDataEventTypeValue
                           withBlock:^(FIRDataSnapshot *snapshot) {
                             XCTAssertTrue([[snapshot value] isEqual:[NSNull null]],
                                           @"First callback is null");
                             initialReadDone = YES;
                           }];

  [self waitUntil:^BOOL {
    return initialReadDone;
  }];

  __block BOOL writeDone = NO;

  [writeNode setValue:@42
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        writeDone = YES;
      }];

  [self waitUntil:^BOOL {
    return writeDone;
  }];

  __block BOOL readDone = NO;

  [readNodeB observeSingleEventOfType:FIRDataEventTypeValue
                            withBlock:^(FIRDataSnapshot *snapshot) {
                              XCTAssertEqualObjects(@42, [snapshot value], @"Proper second read");
                              readDone = YES;
                            }];

  [self waitUntil:^BOOL {
    return readDone;
  }];
}

// Removed test of forEach aborting iteration. Support dropped, use for .. in syntax

- (void)testSetAndThenListenForValueEventsAreCorrect {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL setDone = NO;

  [node setValue:@"moo"
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        setDone = YES;
      }];

  __block int calls = 0;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 calls = calls + 1;
                 XCTAssertTrue(calls == 1, @"Only called once");
                 XCTAssertEqualObjects([snapshot value], @"moo", @"Proper snapshot value");
               }];

  [self waitUntil:^BOOL {
    return setDone && calls == 1;
  }];

  [node removeAllObservers];
}

- (void)testHasChildrenWorksCorrectly {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  [node setValue:@{@"one" : @42, @"two" : @{@"a" : @5}, @"three" : @{@"a" : @5, @"b" : @6}}];

  __block BOOL removedTwo = NO;
  __block BOOL done = NO;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 if (!removedTwo) {
                   XCTAssertFalse([[snapshot childSnapshotForPath:@"one"] hasChildren], @"nope");
                   XCTAssertTrue([[snapshot childSnapshotForPath:@"two"] hasChildren], @"nope");
                   XCTAssertTrue([[snapshot childSnapshotForPath:@"three"] hasChildren], @"nope");
                   XCTAssertFalse([[snapshot childSnapshotForPath:@"four"] hasChildren], @"nope");

                   removedTwo = YES;
                   [[node child:@"two"] removeValue];
                 } else {
                   XCTAssertFalse([[snapshot childSnapshotForPath:@"two"] hasChildren],
                                  @"Second time around");
                   done = YES;
                 }
               }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testNumChildrenWorksCorrectly {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  [node setValue:@{@"one" : @42, @"two" : @{@"a" : @5}, @"three" : @{@"a" : @5, @"b" : @6}}];

  __block BOOL removedTwo = NO;
  __block BOOL done = NO;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 if (!removedTwo) {
                   XCTAssertTrue([snapshot childrenCount] == 3, @"Total children");
                   XCTAssertTrue([[snapshot childSnapshotForPath:@"one"] childrenCount] == 0,
                                 @"Two's children");
                   XCTAssertTrue([[snapshot childSnapshotForPath:@"two"] childrenCount] == 1,
                                 @"Two's children");
                   XCTAssertTrue([[snapshot childSnapshotForPath:@"three"] childrenCount] == 2,
                                 @"Two's children");
                   XCTAssertTrue([[snapshot childSnapshotForPath:@"four"] childrenCount] == 0,
                                 @"Two's children");

                   removedTwo = YES;
                   [[node child:@"two"] removeValue];
                 } else {
                   XCTAssertTrue([snapshot childrenCount] == 2, @"Total children");
                   XCTAssertTrue([[snapshot childSnapshotForPath:@"two"] childrenCount] == 0,
                                 @"Two's children");
                   done = YES;
                 }
               }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

#ifdef FLAKY_TEST
- (void)testSettingANodeWithChildrenToAPrimitiveAndBack {
  // Can't tolerate stale data; so disable persistence.
  FTupleFirebase *tuple = [FTestHelpers getRandomNodePairWithoutPersistence];
  FIRDatabaseReference *writeNode = tuple.one;
  FIRDatabaseReference *readNode = tuple.two;

  __block BOOL done = NO;

  NSDictionary *compound = @{@"a" : @5, @"b" : @6};
  NSNumber *number = @76;

  [writeNode setValue:compound];

  [self snapWaiter:writeNode
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertTrue([snapshot hasChildren], @"Has children");
           XCTAssertEqualObjects(@5, [[snapshot childSnapshotForPath:@"a"] value], @"First child");
           XCTAssertEqualObjects(@6, [[snapshot childSnapshotForPath:@"b"] value], @"First child");
           done = YES;
         }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  [self snapWaiter:readNode
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertTrue([snapshot hasChildren], @"has children");
           XCTAssertEqualObjects(@5, [[snapshot childSnapshotForPath:@"a"] value], @"First child");
           XCTAssertEqualObjects(@6, [[snapshot childSnapshotForPath:@"b"] value], @"First child");
           done = YES;
         }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  [writeNode setValue:number
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  [self snapWaiter:readNode
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertFalse([snapshot hasChildren], @"No more children");
           XCTAssertEqualObjects(number, [snapshot value], @"Proper non compound value");
           done = YES;
         }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  [writeNode setValue:compound
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  [self snapWaiter:readNode
         withBlock:^(FIRDataSnapshot *snapshot) {
           XCTAssertTrue([snapshot hasChildren], @"Has children");
           XCTAssertEqualObjects(@5, [[snapshot childSnapshotForPath:@"a"] value], @"First child");
           XCTAssertEqualObjects(@6, [[snapshot childSnapshotForPath:@"b"] value], @"First child");
           done = YES;
         }];

  [self waitUntil:^BOOL {
    return done;
  }];

  XCTAssertTrue(done, @"Properly finished");
}
#endif

- (void)testWriteLeafRemoveLeafAddChildToRemovedNode {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block BOOL ready = NO;
  [writer setValue:@5];
  [writer removeValue];
  [[writer child:@"abc"] setValue:@5
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                ready = YES;
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  __block NSDictionary *readVal = nil;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   readVal = [snapshot value];
                 }];

  [self waitUntil:^BOOL {
    return readVal != nil;
  }];

  NSNumber *five = [readVal objectForKey:@"abc"];
  XCTAssertTrue([five isEqualToNumber:@5], @"Should get 5");
}

- (void)testListenForValueAndThenWriteOnANodeWithExistingData {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  [self waitForCompletionOf:writer setValue:@{@"a" : @5, @"b" : @2}];

  __block int calls = 0;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   calls++;
                   if (calls == 1) {
                     NSDictionary *val = [snapshot value];
                     NSDictionary *expected = @{@"a" : @10, @"b" : @2};
                     XCTAssertTrue([val isEqualToDictionary:expected], @"Got the correct value");
                   } else {
                     XCTFail(@"Should only be called once");
                   }
                 }];

  [[reader child:@"a"] setValue:@10];
  [self waitUntil:^BOOL {
    return calls == 1;
  }];
  [reader removeAllObservers];
}

- (void)testSetPriorityOnNonexistentNodeFails {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setPriority:@5
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        XCTAssertTrue(error != nil, @"This should not succeed");
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testSetPriorityOnExistentNodeSucceeds {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setValue:@"hello!"];
  [ref setPriority:@5
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        XCTAssertTrue(error == nil, @"This should succeed");
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testSetWithPrioritySetsValueAndPriority {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  [self waitForCompletionOf:writer setValue:@"hello" andPriority:@5];

  __block FIRDataSnapshot *writeSnap = nil;
  __block FIRDataSnapshot *readSnap = nil;
  [writer observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   writeSnap = snapshot;
                 }];
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   readSnap = snapshot;
                 }];

  [self waitUntil:^BOOL {
    return readSnap != nil && writeSnap != nil;
  }];

  XCTAssertTrue([@"hello" isEqualToString:[readSnap value]], @"Got the value on the reader");
  XCTAssertTrue([@"hello" isEqualToString:[writeSnap value]], @"Got the value on the writer");
  XCTAssertTrue([@5 isEqualToNumber:[readSnap priority]], @"Got the priority on the reader");
  XCTAssertTrue([@5 isEqualToNumber:[writeSnap priority]], @"Got the priority on the writer");
}

- (void)testEffectsOfSetPriorityIsImmediatelyEvident {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSMutableArray *values = [[NSMutableArray alloc] init];
  NSMutableArray *priorities = [[NSMutableArray alloc] init];

  [ref observeSingleEventOfType:FIRDataEventTypeValue
                      withBlock:^(FIRDataSnapshot *snapshot) {
                        [values addObject:[snapshot value]];
                        [priorities addObject:[snapshot priority]];
                      }];
  [ref setValue:@5];
  [ref setPriority:@10];
  __block BOOL ready = NO;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                [values addObject:[snapshot value]];
                [priorities addObject:[snapshot priority]];
                ready = YES;
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSArray *expectedValues = @[ @5, @5 ];
  NSArray *expectedPriorites = @[ [NSNull null], @10 ];
  XCTAssertTrue([values isEqualToArray:expectedValues],
                @"Expected both listeners to get 5, got %@ instead", values);
  XCTAssertTrue([priorities isEqualToArray:expectedPriorites],
                @"The first listener should have missed the priority, got %@ instead", priorities);
}

- (void)testSetOverwritesPriorityOfTopLevelNodeAndSubnodes {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block BOOL ready = NO;
  [writer setValue:@{@"a" : @5}];
  [writer setPriority:@10];
  [[writer child:@"a"] setPriority:@18];
  [writer setValue:@{@"a" : @7}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   id pri = [snapshot priority];
                   XCTAssertTrue([NSNull null] == pri, @"Expected null priority");
                   FIRDataSnapshot *child = [snapshot childSnapshotForPath:@"a"];
                   XCTAssertTrue([NSNull null] == [child priority],
                                 @"Child priority should be null too");
                   ready = YES;
                 }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testSetPriorityOfLeafSavesCorrectly {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block BOOL ready = NO;
  [writer setValue:@"testleaf"
              andPriority:@992
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   id pri = [snapshot priority];
                   XCTAssertTrue([@992 isEqualToNumber:pri], @"Expected non-null priority");
                   ready = YES;
                 }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testSetPriorityOfObjectSavesCorrectly {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block BOOL ready = NO;
  [writer setValue:@{@"a" : @5}
              andPriority:@991
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   id pri = [snapshot priority];
                   XCTAssertTrue([@991 isEqualToNumber:pri], @"Expected non-null priority");
                   ready = YES;
                 }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testSetWithPriorityFollowedBySetClearsPriority {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block BOOL ready = NO;
  [writer setValue:@{@"a" : @5}
              andPriority:@991
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [reader setValue:@{@"a" : @19}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   id pri = [snapshot priority];
                   XCTAssertTrue([NSNull null] == pri, @"Expected null priority");
                   ready = YES;
                 }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testGetPriorityReturnsCorrectType {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block FIRDataSnapshot *snap = nil;

  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                snap = snapshot;
              }];

  [ref setValue:@"a"];
  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([snap priority] == [NSNull null], @"Expect null priority");
  snap = nil;

  [ref setValue:@"b" andPriority:@5];
  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap priority] isEqualToNumber:@5], @"Expect priority");
  snap = nil;

  [ref setValue:@"c" andPriority:@"6"];
  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap priority] isEqualToString:@"6"], @"Expect priority");
  snap = nil;

  [ref setValue:@"d" andPriority:@7];
  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap priority] isEqualToNumber:@7], @"Expect priority");
  snap = nil;

  [ref setValue:@{@".value" : @"e", @".priority" : @8}];
  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap priority] isEqualToNumber:@8], @"Expect priority");
  snap = nil;

  [ref setValue:@{@".value" : @"f", @".priority" : @"8"}];
  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap priority] isEqualToString:@"8"], @"Expect priority");
  snap = nil;

  [ref setValue:@{@".value" : @"e", @".priority" : [NSNull null]}];
  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([snap priority] == [NSNull null], @"Expect priority");
  snap = nil;
}

- (void)testExportValIncludesPriorities {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  NSDictionary *contents =
      @{@"foo" : @{@"bar" : @{@".value" : @5, @".priority" : @7}, @".priority" : @"hi"}};
  __block FIRDataSnapshot *snap = nil;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                snap = snapshot;
              }];
  [ref setValue:contents];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([contents isEqualToDictionary:[snap valueInExportFormat]],
                @"Expected priorities in snapshot");
}

- (void)testPriorityIsOverwrittenByServer {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block int event = 0;
  __block BOOL done = NO;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   NSLog(@"%@ Snapshot", snapshot);
                   id pri = [snapshot priority];
                   if (event == 0) {
                     XCTAssertTrue([@100 isEqualToNumber:pri],
                                   @"Expect local priority. Got %@ instead.", pri);
                   } else if (event == 1) {
                     XCTAssertTrue(pri == [NSNull null], @"Expect remote priority. Got %@ instead.",
                                   pri);
                   } else {
                     XCTFail(@"Extra event");
                   }
                   event++;
                   if (event == 2) {
                     done = YES;
                   }
                 }];

  [writer
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               id pri = [snapshot priority];
               if ([[pri class] isSubclassOfClass:[NSNumber class]] && [@100 isEqualToNumber:pri]) {
                 [writer setValue:@"whatever"];
               }
             }];

  [reader setValue:@"hi" andPriority:@100];
  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testLargeNumericPrioritiesWork {
  NSNumber *bigPriority = @1356721306842;
  __block BOOL ready = NO;
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  [self waitForCompletionOf:writer setValue:@5 andPriority:bigPriority];

  __block NSNumber *serverPriority = @0;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   serverPriority = [snapshot priority];
                   ready = YES;
                 }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([bigPriority isEqualToNumber:serverPriority], @"Expect big priority back");
}

- (void)testToString {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  FIRDatabaseReference *parent = [ref parent];

  XCTAssertEqualObjects([parent description], self.databaseURL);
  FIRDatabaseReference *child = [parent child:@"a/b/c"];
  NSString *expected = [NSString stringWithFormat:@"%@/a/b/c", self.databaseURL];
  XCTAssertEqualObjects([child description], expected);
}

- (void)testURLEncodingOfDescriptionAndURLDecodingOfNewFirebase {
  __block BOOL ready = NO;
  NSString *test1 =
      [NSString stringWithFormat:@"%@/a%%b&c@d/space: /non-ascii_character:ø", self.databaseURL];
  NSString *expected1 = [NSString
      stringWithFormat:@"%@/a%%25b%%26c%%40d/space%%3A%%20/non-ascii_character%%3A%%C3%%B8",
                       self.databaseURL];
  FIRDatabaseReference *ref = [[FTestHelpers defaultDatabase] referenceFromURL:test1];
  NSString *result = [ref description];
  XCTAssertTrue([result isEqualToString:expected1], @"Encodes properly");

  int rnd = arc4random_uniform(100000000);
  NSString *path = [NSString stringWithFormat:@"%i", rnd];
  [[ref child:path] setValue:@"testdata"
         withCompletionBlock:^(NSError *error, FIRDatabaseReference *childRef) {
           FIRDatabaseReference *other =
               [[FTestHelpers defaultDatabase] referenceFromURL:[ref description]];
           [[other child:path] observeEventType:FIRDataEventTypeValue
                                      withBlock:^(FIRDataSnapshot *snapshot) {
                                        NSString *val = snapshot.value;
                                        XCTAssertTrue([val isEqualToString:@"testdata"],
                                                      @"Expected to get testdata back");
                                        ready = YES;
                                      }];
         }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testNameAtRootAndNonRootLocations {
  FIRDatabaseReference *ref = [[FTestHelpers defaultDatabase] referenceFromURL:self.databaseURL];
  XCTAssertTrue(ref.key == nil, @"Root key should be nil");
  FIRDatabaseReference *child = [ref child:@"a"];
  XCTAssertTrue([child.key isEqualToString:@"a"], @"Should be 'a'");
  FIRDatabaseReference *deeperChild = [child child:@"b/c"];
  XCTAssertTrue([deeperChild.key isEqualToString:@"c"], @"Should be 'c'");
}

- (void)testNameAndRefOnSnapshotsForRootAndNonRootLocations {
  FIRDatabaseReference *ref = [[FTestHelpers defaultDatabase] reference];

  __block BOOL ready = NO;
  [ref removeValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
    ready = YES;
  }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [ref
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               XCTAssertTrue(snapshot.key == nil, @"Root snap should not have a key");
               NSString *snapString = [snapshot.ref description];
               XCTAssertTrue([snapString isEqualToString:snapString], @"Refs should be equivalent");
               FIRDataSnapshot *childSnap = [snapshot childSnapshotForPath:@"a"];
               XCTAssertTrue([childSnap.key isEqualToString:@"a"], @"Properly keys children");
               FIRDatabaseReference *childRef = [ref child:@"a"];
               NSString *refString = [childRef description];
               snapString = [childSnap.ref description];
               XCTAssertTrue([refString isEqualToString:snapString], @"Refs should be equivalent");
               childSnap = [childSnap childSnapshotForPath:@"b/c"];
               childRef = [childRef child:@"b/c"];
               XCTAssertTrue([childSnap.key isEqualToString:@"c"], @"properly keys children");
               refString = [childRef description];
               snapString = [childSnap.ref description];
               XCTAssertTrue([refString isEqualToString:snapString], @"Refs should be equivalent");
               ready = YES;
             }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  // generate value event at root
  [ref setValue:@"foo"];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testParentForRootAndNonRootLocations {
  FIRDatabaseReference *ref = [[FIRDatabase database] reference];

  XCTAssertTrue(ref.parent == nil, @"Parent of root should be nil");

  FIRDatabaseReference *child = [ref child:@"a"];
  XCTAssertTrue([[child.parent description] isEqualToString:[ref description]],
                @"Should be equivalent locations");
  child = [ref child:@"a/b/c"];
  XCTAssertTrue([[child.parent.parent.parent description] isEqualToString:[ref description]],
                @"Should be equivalent locations");
}

- (void)testSettingNumericKeysConvertsToStrings {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSDictionary *toSet = @{@4 : @"hi", @5 : @"test"};

  XCTAssertThrows([ref setValue:toSet], @"Keys must be strings");
}

- (void)testSetChildAndListenAtRootRegressionTest {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block BOOL ready = NO;
  [writer removeValue];
  [[writer child:@"foo"] setValue:@"hi"
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                [reader observeEventType:FIRDataEventTypeValue
                               withBlock:^(FIRDataSnapshot *snapshot) {
                                 NSDictionary *val = [snapshot value];
                                 NSDictionary *expected = @{@"foo" : @"hi"};
                                 XCTAssertTrue([val isEqualToDictionary:expected], @"Got child");
                                 ready = YES;
                               }];
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testAccessingInvalidPathsThrows {
  NSArray *badPaths = @[ @".test", @"test.", @"fo$o", @"[what", @"ever]", @"ha#sh" ];

  for (NSString *key in badPaths) {
    NSString *url = [NSString stringWithFormat:@"%@/%@", self.databaseURL, key];
    XCTAssertThrows(
        ^{
          FIRDatabaseReference *ref = [[FIRDatabase database] referenceFromURL:url];
          XCTFail(@"Should not get here with ref: %@", ref);
        }(),
        @"should throw");
    url = [NSString stringWithFormat:@"%@/TESTS/%@", self.databaseURL, key];
    XCTAssertThrows(
        ^{
          FIRDatabaseReference *ref = [[FIRDatabase database] referenceFromURL:url];
          XCTFail(@"Should not get here with ref: %@", ref);
        }(),
        @"should throw");
  }

  __block BOOL ready = NO;
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                for (NSString *key in badPaths) {
                  XCTAssertThrows([snapshot childSnapshotForPath:key], @"should throw");
                  XCTAssertThrows([snapshot hasChild:key], @"should throw");
                }
                ready = YES;
              }];
  [ref setValue:nil];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testSettingObjectsAtInvalidKeysThrow {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  NSArray *badPaths = @[
    @".test", @"test.", @"fo$o", @"[what", @"ever]", @"ha#sh", @"/thing", @"th/ing", @"thing/"
  ];
  NSMutableArray *badObjs = [[NSMutableArray alloc] init];
  for (NSString *key in badPaths) {
    [badObjs addObject:@{key : @"test"}];
    [badObjs addObject:@{@"deeper" : @{key : @"test"}}];
  }

  for (NSDictionary *badObj in badObjs) {
    XCTAssertThrows([ref setValue:badObj], @"Should throw");
    XCTAssertThrows([ref setValue:badObj andPriority:@5], @"Should throw");
    XCTAssertThrows([ref onDisconnectSetValue:badObj], @"Should throw");
    XCTAssertThrows([ref onDisconnectSetValue:badObj andPriority:@5], @"Should throw");
    // XXX transaction
  }
}

- (void)testSettingInvalidObjectsThrow {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  XCTAssertThrows([ref setValue:[NSDate date]], @"Should throw");

  NSDictionary *data = @{@"invalid" : @"data", @".sv" : @"timestamp"};
  XCTAssertThrows([ref setValue:data], @"Should throw");

  data = @{@".value" : @{}};
  XCTAssertThrows([ref setValue:data], @"Should throw");
}

- (void)testInvalidUpdateThrow {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  NSArray *badUpdates = @[
    @{@"/" : @"t", @"a" : @"t"}, @{@"a" : @"t", @"a/b" : @"t"}, @{@"/a" : @"t", @"a/b" : @"t"},
    @{@"/a/b" : @"t", @"a" : @"t"}, @{@"/a/b/.priority" : @"t", @"/a/b" : @"t"},
    @{@"/a/b/.sv" : @"timestamp"}, @{@"/a/b/.value" : @"t"}, @{@"/a/b/.priority" : @{@"x" : @"y"}}
  ];

  for (NSDictionary *update in badUpdates) {
    XCTAssertThrows([ref updateChildValues:update], @"Should throw");
    XCTAssertThrows([ref onDisconnectUpdateChildValues:update], @"Should throw");
  }
}

- (void)testSettingNull {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  XCTAssertNoThrow([ref setValue:nil], @"Should not throw");
  XCTAssertNoThrow([ref setValue:[NSNull null]], @"Should not throw");
}

- (void)testSettingNaN {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  XCTAssertThrows([ref setValue:[NSDecimalNumber notANumber]], @"Should throw");
}

- (void)testSettingInvalidPriority {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  XCTAssertThrows([ref setValue:@"3" andPriority:[NSDecimalNumber notANumber]], @"Should throw");
  XCTAssertThrows([ref setValue:@"4" andPriority:@{}], @"Should throw");
  XCTAssertThrows([ref setValue:@"5" andPriority:@[]], @"Should throw");
}

- (void)testRemoveFromOnMobileGraffitiBugAtAngelHack {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL done = NO;

  [node observeEventType:FIRDataEventTypeChildAdded
               withBlock:^(FIRDataSnapshot *snapshot) {
                 [[node child:[snapshot key]]
                     removeValueWithCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
                       done = YES;
                     }];
               }];

  [[node childByAutoId] setValue:@"moo"];

  [self waitUntil:^BOOL {
    return done;
  }];

  XCTAssertTrue(done, @"Properly finished");
}

- (void)testSetANodeWithAQuotedKey {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  __block FIRDataSnapshot *snap;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 snap = snapshot;
               }];

  [node setValue:@{@"\"herp\"" : @1234}
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        done = YES;
        XCTAssertEqualObjects(@1234, [[snap childSnapshotForPath:@"\"herp\""] value],
                              @"Got it back");
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  XCTAssertTrue(done, @"Properly finished");
}

- (void)testSetANodeWithASingleQuoteKey {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  __block FIRDataSnapshot *snap;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 snap = snapshot;
               }];

  [node setValue:@{@"\"" : @1234}
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        done = YES;
        XCTAssertEqualObjects(@1234, [[snap childSnapshotForPath:@"\""] value], @"Got it back");
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  XCTAssertTrue(done, @"Properly finished");
}

- (void)testEmptyChildGetValueEventBeforeParent {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  NSArray *lookingFor = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa/aaa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a/aa"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
  ];

  FEventTester *et = [[FEventTester alloc] initFrom:self];
  [et addLookingFor:lookingFor];

  [node setValue:@{@"b" : @5}];

  [et wait];
}

// iOS behavior is different from what the recursive set test looks for. We don't raise events
// synchronously

- (void)testOnAfterSetWaitsForLatestData {
  // We test here that we don't cache sets, but they would be persisted so make sure we are running
  // without persistence
  FTupleFirebase *refs = [FTestHelpers getRandomNodePairWithoutPersistence];
  FIRDatabaseReference *node1 = refs.one;
  FIRDatabaseReference *node2 = refs.two;

  __block BOOL ready = NO;
  [node1 setValue:@5
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        [node2 setValue:@42
            withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
              ready = YES;
            }];
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;

  [node1 observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot) {
                  NSNumber *val = [snapshot value];
                  XCTAssertTrue([val isEqualToNumber:@42], @"Should not have cached earlier set");
                  ready = YES;
                }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testOnceWaitsForLatestData {
  // Can't tolerate stale data; so disable persistence.
  FTupleFirebase *refs = [FTestHelpers getRandomNodePairWithoutPersistence];
  FIRDatabaseReference *node1 = refs.one;
  FIRDatabaseReference *node2 = refs.two;

  __block BOOL ready = NO;

  [node1 observeSingleEventOfType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          id val = [snapshot value];
                          XCTAssertTrue([NSNull null] == val, @"First value should be null");

                          [node2 setValue:@5
                              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                                [node1 observeSingleEventOfType:FIRDataEventTypeValue
                                                      withBlock:^(FIRDataSnapshot *snapshot) {
                                                        NSNumber *val = [snapshot value];
                                                        XCTAssertTrue(
                                                            [val isKindOfClass:[NSNumber class]] &&
                                                                [val isEqualToNumber:@5],
                                                            @"Should get first value");
                                                        ready = YES;
                                                      }];
                              }];
                        }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [node2 setValue:@42
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        [node1 observeSingleEventOfType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot *snapshot) {
                                NSNumber *val = [snapshot value];
                                XCTAssertTrue([val isEqualToNumber:@42], @"Got second number");
                                ready = YES;
                              }];
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testMemoryFreeingOnUnlistenDoesNotCorruptData {
  // Can't tolerate stale data; so disable persistence.
  FTupleFirebase *refs = [FTestHelpers getRandomNodePairWithoutPersistence];
  FIRDatabaseReference *node2 = [[refs.one root] childByAutoId];

  __block BOOL hasRun = NO;
  __block BOOL ready = NO;
  FIRDatabaseHandle handle1 =
      [refs.one observeEventType:FIRDataEventTypeValue
                       withBlock:^(FIRDataSnapshot *snapshot) {
                         if (!hasRun) {
                           hasRun = YES;
                           id val = [snapshot value];
                           XCTAssertTrue([NSNull null] == val, @"First time should be null");
                           [refs.one setValue:@"test"
                               withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                                 ready = YES;
                               }];
                         }
                       }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [refs.one removeObserverWithHandle:handle1];

  ready = NO;
  [node2 setValue:@"hello"
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        [refs.one
            observeSingleEventOfType:FIRDataEventTypeValue
                           withBlock:^(FIRDataSnapshot *snapshot) {
                             NSString *val = [snapshot value];
                             XCTAssertTrue([val isEqualToString:@"test"],
                                           @"Get back the value we set above");
                             [refs.two
                                 observeSingleEventOfType:FIRDataEventTypeValue
                                                withBlock:^(FIRDataSnapshot *snapshot) {
                                                  NSString *val = [snapshot value];
                                                  XCTAssertTrue([val isEqualToString:@"test"],
                                                                @"Get back the value we set above");
                                                  ready = YES;
                                                }];
                           }];
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  // write {x: 1, y : {t: 2, u: 3}}
  // Listen at /. Then listen at /x/t
  // unlisten at /y/t. Off at /. Once at /. Ensure data is still all there.
  // Once at /y. Ensure data is still all there.
  refs = [FTestHelpers getRandomNodePairWithoutPersistence];

  ready = NO;
  __block FIRDatabaseHandle deeplisten = NSNotFound;
  __block FIRDatabaseHandle slashlisten = NSNotFound;
  __weak FIRDatabaseReference *refOne = refs.one;
  [refs.one setValue:@{@"x" : @1, @"y" : @{@"t" : @2, @"u" : @3}}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        slashlisten = [refOne
            observeEventType:FIRDataEventTypeValue
                   withBlock:^(FIRDataSnapshot *snapshot) {
                     deeplisten = [[refOne child:@"y/t"]
                         observeEventType:FIRDataEventTypeValue
                                withBlock:^(FIRDataSnapshot *snapshot) {
                                  [[refOne child:@"y/t"] removeObserverWithHandle:deeplisten];
                                  [refOne removeObserverWithHandle:slashlisten];
                                  ready = YES;
                                }];
                   }];
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [[refs.one child:@"x"] setValue:@"test"
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                [refs.one observeSingleEventOfType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot) {
                                           NSDictionary *val = [snapshot value];
                                           NSDictionary *expected =
                                               @{@"x" : @"test",
                                                 @"y" : @{@"t" : @2, @"u" : @3}};
                                           XCTAssertTrue([val isEqualToDictionary:expected],
                                                         @"Got the final value");
                                           ready = YES;
                                         }];
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testUpdateRaisesCorrectLocalEvents {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap = nil;
  [node observeSingleEventOfType:FIRDataEventTypeValue
                       withBlock:^(FIRDataSnapshot *snapshot) {
                         snap = snapshot;
                       }];

  __block BOOL ready = NO;
  [node setValue:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  FEventTester *et = [[FEventTester alloc] initFrom:self];
  NSArray *expectations = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node child:@"d"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"d"],
    [[FTupleEventTypeString alloc] initWithFirebase:node
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [et addLookingFor:expectations];

  [et waitForInitialization];

  [node updateChildValues:@{@"a" : @4, @"d" : @1}];

  [et wait];
}

- (void)testUpdateRaisesCorrectRemoteEvents {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block BOOL ready = NO;
  [writer setValue:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  FEventTester *et = [[FEventTester alloc] initFrom:self];
  NSArray *expectations = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[reader child:@"d"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"a"],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeChildChanged
                                         withString:@"d"],
    [[FTupleEventTypeString alloc] initWithFirebase:reader
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [et addLookingFor:expectations];

  [et waitForInitialization];

  [writer updateChildValues:@{@"a" : @4, @"d" : @1}];

  [et wait];

  ready = NO;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   NSDictionary *result = [snapshot value];
                   NSDictionary *expected = @{@"a" : @4, @"b" : @2, @"c" : @3, @"d" : @1};
                   XCTAssertTrue([result isEqualToDictionary:expected], @"Got expected results");
                   ready = YES;
                 }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testUpdateChangesAreStoredCorrectlyByTheServer {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  [self waitForCompletionOf:writer setValue:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}];

  [self waitForCompletionOf:writer updateChildValues:@{@"a" : @42}];

  [self snapWaiter:reader
         withBlock:^(FIRDataSnapshot *snapshot) {
           NSDictionary *result = [snapshot value];
           NSDictionary *expected = @{@"a" : @42, @"b" : @2, @"c" : @3, @"d" : @4};
           XCTAssertTrue([result isEqualToDictionary:expected], @"Expected updated value");
         }];
}

- (void)testUpdateDoesntAffectPriorityLocally {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap = nil;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                snap = snapshot;
              }];

  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3} andPriority:@"testpri"];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap priority] isEqualToString:@"testpri"], @"Got initial priority");
  snap = nil;

  [ref updateChildValues:@{@"a" : @4}];
  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap priority] isEqualToString:@"testpri"], @"Got initial priority");
}

- (void)testUpdateDoesntAffectPriorityRemotely {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block BOOL ready = NO;
  [writer setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
              andPriority:@"testpri"
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [reader observeSingleEventOfType:FIRDataEventTypeValue
                         withBlock:^(FIRDataSnapshot *snapshot) {
                           NSString *result = [snapshot priority];
                           XCTAssertTrue([result isEqualToString:@"testpri"],
                                         @"Expected initial priority");
                           ready = YES;
                         }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [writer updateChildValues:@{@"a" : @4}
        withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
          ready = YES;
        }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [reader observeSingleEventOfType:FIRDataEventTypeValue
                         withBlock:^(FIRDataSnapshot *snapshot) {
                           NSString *result = [snapshot priority];
                           XCTAssertTrue([result isEqualToString:@"testpri"],
                                         @"Expected initial priority");
                           ready = YES;
                         }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testUpdateReplacesChildrenAndIsNotRecursive {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block FIRDataSnapshot *localSnap = nil;
  __block BOOL ready = NO;

  [writer observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   localSnap = snapshot;
                 }];

  [writer setValue:@{@"a" : @{@"aa" : @1, @"ab" : @2}}];
  [writer updateChildValues:@{@"a" : @{@"aa" : @1}}
        withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
          ready = YES;
        }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;

  [reader observeSingleEventOfType:FIRDataEventTypeValue
                         withBlock:^(FIRDataSnapshot *snapshot) {
                           NSDictionary *result = [snapshot value];
                           NSDictionary *expected = @{@"a" : @{@"aa" : @1}};
                           XCTAssertTrue([result isEqualToDictionary:expected],
                                         @"Should get new value");
                           ready = YES;
                         }];

  [self waitUntil:^BOOL {
    NSDictionary *result = [localSnap value];
    NSDictionary *expected = @{@"a" : @{@"aa" : @1}};
    return ready && [result isEqualToDictionary:expected];
  }];
}

- (void)testDeepUpdatesWork {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block FIRDataSnapshot *localSnap = nil;
  __block BOOL ready = NO;

  [writer observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   localSnap = snapshot;
                 }];

  [writer setValue:@{@"a" : @{@"aa" : @1, @"ab" : @2}}];
  [writer updateChildValues:@{
    @"a/aa" : @10,
    @".priority" : @3.0,
    @"a/ab" : @{@".priority" : @2.0, @".value" : @20}
  }
        withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
          ready = YES;
        }];

  [self waitUntil:^BOOL {
    return ready;
  }];
  ready = NO;

  [reader observeSingleEventOfType:FIRDataEventTypeValue
                         withBlock:^(FIRDataSnapshot *snapshot) {
                           NSDictionary *result = [snapshot value];
                           NSDictionary *expected = @{@"a" : @{@"aa" : @10, @"ab" : @20}};
                           XCTAssertTrue([result isEqualToDictionary:expected],
                                         @"Should get new value");
                           ready = YES;
                         }];

  [self waitUntil:^BOOL {
    NSDictionary *result = [localSnap value];
    NSDictionary *expected = @{@"a" : @{@"aa" : @10, @"ab" : @20}};
    return ready && [result isEqualToDictionary:expected];
  }];
}

// Type signature means we don't need a test for updating scalars. They wouldn't compile

- (void)testEmptyUpdateWorks {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref updateChildValues:@{}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        XCTAssertTrue(error == nil, @"Should not be an error");
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

// XXX update stress test

- (void)testUpdateFiresCorrectEventWhenAChildIsDeleted {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block FIRDataSnapshot *localSnap = nil;
  __block FIRDataSnapshot *remoteSnap = nil;

  [self waitForCompletionOf:writer setValue:@{@"a" : @12, @"b" : @6}];
  [writer observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   localSnap = snapshot;
                 }];

  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   remoteSnap = snapshot;
                 }];

  [self waitUntil:^BOOL {
    return localSnap != nil && remoteSnap != nil;
  }];

  localSnap = nil;
  remoteSnap = nil;

  [writer updateChildValues:@{@"a" : [NSNull null]}];

  [self waitUntil:^BOOL {
    return localSnap != nil && remoteSnap != nil;
  }];

  NSDictionary *expected = @{@"b" : @6};
  XCTAssertTrue([[remoteSnap value] isEqualToDictionary:expected], @"Removed child");
  XCTAssertTrue([[localSnap value] isEqualToDictionary:expected], @"Removed child");
}

- (void)testUpdateFiresCorrectEventOnNewChildren {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block FIRDataSnapshot *localSnap = nil;
  __block FIRDataSnapshot *remoteSnap = nil;

  [[writer child:@"a"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot *snapshot) {
                                localSnap = snapshot;
                              }];

  [[reader child:@"a"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot *snapshot) {
                                remoteSnap = snapshot;
                              }];

  [self waitUntil:^BOOL {
    return localSnap != nil && remoteSnap != nil;
  }];

  localSnap = nil;
  remoteSnap = nil;

  [writer updateChildValues:@{@"a" : @42}];

  [self waitUntil:^BOOL {
    return localSnap != nil && remoteSnap != nil;
  }];

  XCTAssertTrue([[remoteSnap value] isEqualToNumber:@42], @"Added child");
  XCTAssertTrue([[localSnap value] isEqualToNumber:@42], @"Added child");
}

- (void)testUpdateFiresCorrectEventOnDeletedChildren {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block FIRDataSnapshot *localSnap = nil;
  __block FIRDataSnapshot *remoteSnap = nil;
  [self waitForCompletionOf:writer setValue:@{@"a" : @12}];
  [[writer child:@"a"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot *snapshot) {
                                localSnap = snapshot;
                              }];

  [[reader child:@"a"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot *snapshot) {
                                remoteSnap = snapshot;
                              }];

  [self waitUntil:^BOOL {
    return localSnap != nil && remoteSnap != nil;
  }];

  localSnap = nil;
  remoteSnap = nil;

  [writer updateChildValues:@{@"a" : [NSNull null]}];

  [self waitUntil:^BOOL {
    return localSnap != nil && remoteSnap != nil;
  }];

  XCTAssertTrue([remoteSnap value] == [NSNull null], @"Removed child");
  XCTAssertTrue([localSnap value] == [NSNull null], @"Removed child");
}

- (void)testUpdateFiresCorrectEventOnChangedChildren {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  [self waitForCompletionOf:writer setValue:@{@"a" : @12}];

  __block FIRDataSnapshot *localSnap = nil;
  __block FIRDataSnapshot *remoteSnap = nil;

  [[writer child:@"a"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot *snapshot) {
                                localSnap = snapshot;
                              }];

  [[reader child:@"a"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot *snapshot) {
                                remoteSnap = snapshot;
                              }];

  [self waitUntil:^BOOL {
    return localSnap != nil && remoteSnap != nil;
  }];

  localSnap = nil;
  remoteSnap = nil;

  [self waitForCompletionOf:writer updateChildValues:@{@"a" : @11}];

  [self waitUntil:^BOOL {
    return localSnap != nil && remoteSnap != nil;
  }];

  XCTAssertTrue([[remoteSnap value] isEqualToNumber:@11], @"Changed child");
  XCTAssertTrue([[localSnap value] isEqualToNumber:@11], @"Changed child");
}

- (void)testUpdateOfPriorityWorks {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;
  FIRDatabaseReference *writer = refs.two;

  __block BOOL ready = NO;
  [writer setValue:@{@"a" : @5, @".priority" : @"pri1"}];
  [writer updateChildValues:@{
    @"a" : @6,
    @".priority" : @"pri2",
    @"b" : @{@".priority" : @"pri3", @"c" : @10}
  }
        withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
          NSLog(@"error? %@", error);
          ready = YES;
        }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;

  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   XCTAssertEqualObjects([[snapshot childSnapshotForPath:@"a"] value], @6,
                                         @"Should match write values");
                   XCTAssertTrue([[snapshot priority] isEqualToString:@"pri2"],
                                 @"Should get updated priority");
                   XCTAssertTrue(
                       [[[snapshot childSnapshotForPath:@"b"] priority] isEqualToString:@"pri3"],
                       @"Should get updated priority");
                   XCTAssertEqualObjects([[snapshot childSnapshotForPath:@"b/c"] value], @10,
                                         @"Should match write values");
                   ready = YES;
                 }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testSetWithCircularReferenceFails {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  NSMutableDictionary *toSet = [[NSMutableDictionary alloc] init];
  NSDictionary *lol = @{@"foo" : @"bar", @"circular" : toSet};
  [toSet setObject:lol forKey:@"lol"];

  XCTAssertThrows([ref setValue:toSet], @"Should not be able to set circular dictionary");
}

- (void)testLargeNumbers {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  long long jsMaxInt = 9007199254740992;
  long jsMaxIntPlusOne = (long)jsMaxInt + 1;
  NSNumber *toSet = [NSNumber numberWithLong:jsMaxIntPlusOne];
  [ref setValue:toSet];

  __block FIRDataSnapshot *snap = nil;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                snap = snapshot;
              }];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  NSNumber *result = [snap value];
  XCTAssertTrue([result isEqualToNumber:toSet], @"Should get back same number");

  toSet = [NSNumber numberWithLong:LONG_MAX];
  snap = nil;

  [ref setValue:toSet];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  result = [snap value];
  XCTAssertTrue([result isEqualToNumber:toSet], @"Should get back same number");

  snap = nil;
  toSet = [NSNumber numberWithDouble:DBL_MAX];
  [ref setValue:toSet];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  result = [snap value];
  XCTAssertTrue([result isEqualToNumber:toSet], @"Should get back same number");
}

#ifdef FLAKY_TEST
- (void)testParentDeleteShadowsChildListeners {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *deleter = refs.two;

  NSString *childName = [writer childByAutoId].key;

  __block BOOL called = NO;
  [[deleter child:childName]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               XCTAssertFalse(called, @"Should only be hit once");
               called = YES;
               XCTAssertTrue(snapshot.value == [NSNull null], @"Value should be null");
             }];

  WAIT_FOR(called);

  __block BOOL done = NO;
  [[writer child:childName] setValue:@"foo"];
  [deleter removeValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
    done = YES;
  }];

  WAIT_FOR(done);
  [deleter removeAllObservers];
}
#endif

- (void)testParentDeleteShadowsChildListenersWithNonDefaultQuery {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *deleter = refs.two;

  NSString *childName = [writer childByAutoId].key;

  __block BOOL queryCalled = NO;
  __block BOOL deepChildCalled = NO;
  [[[[deleter child:childName] queryOrderedByPriority] queryStartingAtValue:nil childKey:@"b"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               XCTAssertFalse(queryCalled, @"Should only be hit once");
               queryCalled = YES;
               XCTAssertTrue(snapshot.value == [NSNull null], @"Value should be null");
             }];

  [[[deleter child:childName] child:@"a"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               XCTAssertFalse(deepChildCalled, @"Should only be hit once");
               deepChildCalled = YES;
               XCTAssertTrue(snapshot.value == [NSNull null], @"Value should be null");
             }];

  WAIT_FOR(deepChildCalled && queryCalled);

  __block BOOL done = NO;
  [[writer child:childName] setValue:@"foo"];
  [deleter removeValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
    done = YES;
  }];

  WAIT_FOR(done);
}

- (void)testLocalServerTimestampEventuallyButNotImmediatelyMatchServer {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;
  __block int done = 0;

  NSMutableArray *readSnaps = [[NSMutableArray alloc] init];
  NSMutableArray *writeSnaps = [[NSMutableArray alloc] init];

  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   if ([snapshot value] != [NSNull null]) {
                     [readSnaps addObject:snapshot];
                     if (readSnaps.count == 1) {
                       done += 1;
                     }
                   }
                 }];

  [writer observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   if ([snapshot value] != [NSNull null]) {
                     [writeSnaps addObject:snapshot];
                     if (writeSnaps.count == 2) {
                       done += 1;
                     }
                   }
                 }];

  [writer setValue:[FIRServerValue timestamp] andPriority:[FIRServerValue timestamp]];

  [self waitUntil:^BOOL {
    return done == 2;
  }];

  XCTAssertEqual((unsigned long)[readSnaps count], (unsigned long)1,
                 @"Should have received one snapshot on reader");
  XCTAssertEqual((unsigned long)[writeSnaps count], (unsigned long)2,
                 @"Should have received two snapshots on writer");

  FIRDataSnapshot *firstReadSnap = [readSnaps objectAtIndex:0];
  FIRDataSnapshot *firstWriteSnap = [writeSnaps objectAtIndex:0];
  FIRDataSnapshot *secondWriteSnap = [writeSnaps objectAtIndex:1];

  NSNumber *now = [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];
  XCTAssertTrue([now doubleValue] - [firstWriteSnap.value doubleValue] < 3000,
                @"Should have received a local event with a value close to timestamp");
  XCTAssertTrue([now doubleValue] - [firstWriteSnap.priority doubleValue] < 3000,
                @"Should have received a local event with a priority close to timestamp");
  XCTAssertTrue([now doubleValue] - [secondWriteSnap.value doubleValue] < 3000,
                @"Should have received a server event with a value close to timestamp");
  XCTAssertTrue([now doubleValue] - [secondWriteSnap.priority doubleValue] < 3000,
                @"Should have received a server event with a priority close to timestamp");

  XCTAssertFalse([firstWriteSnap value] == [secondWriteSnap value],
                 @"Initial and future writer values should be different");
  XCTAssertFalse([firstWriteSnap priority] == [secondWriteSnap priority],
                 @"Initial and future writer priorities should be different");
  XCTAssertEqualObjects(firstReadSnap.value, secondWriteSnap.value,
                        @"Eventual reader and writer values should be equal");
  XCTAssertEqualObjects(firstReadSnap.priority, secondWriteSnap.priority,
                        @"Eventual reader and writer priorities should be equal");
}

- (void)testServerTimestampSetWithPriorityRemoteEvents {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  NSDictionary *data = @{
    @"a" : [FIRServerValue timestamp],
    @"b" : @{@".value" : [FIRServerValue timestamp], @".priority" : [FIRServerValue timestamp]}
  };

  __block BOOL done = NO;
  [writer setValue:data
              andPriority:[FIRServerValue timestamp]
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [self
      snapWaiter:reader
       withBlock:^(FIRDataSnapshot *snapshot) {
         NSDictionary *value = [snapshot value];
         NSNumber *now =
             [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];
         NSNumber *timestamp = [snapshot priority];
         XCTAssertTrue([[snapshot priority] isKindOfClass:[NSNumber class]],
                       @"Should get back number");
         XCTAssertTrue([now doubleValue] - [timestamp doubleValue] < 2000,
                       @"Number should be no more than 2 seconds ago");
         XCTAssertEqualObjects([snapshot priority], [value objectForKey:@"a"],
                               @"Should get back matching ServerValue.TIMESTAMP");
         XCTAssertEqualObjects([snapshot priority], [value objectForKey:@"b"],
                               @"Should get back matching ServerValue.TIMESTAMP");
         XCTAssertEqualObjects([snapshot priority], [[snapshot childSnapshotForPath:@"b"] priority],
                               @"Should get back matching ServerValue.TIMESTAMP");
       }];
}

- (void)testServerTimestampSetPriorityRemoteEvents {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block FIRDataSnapshot *snap = nil;
  [reader observeEventType:FIRDataEventTypeChildMoved
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   snap = snapshot;
                 }];

  [self waitForCompletionOf:[writer child:@"a"] setValue:@1 andPriority:nil];
  [self waitForCompletionOf:[writer child:@"b"] setValue:@1 andPriority:@1];
  [self waitForValueOf:[reader child:@"a"] toBe:@1];

  __block BOOL done = NO;
  [[writer child:@"a"] setPriority:[FIRServerValue timestamp]
               withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                 done = YES;
               }];

  [self waitUntil:^BOOL {
    return done && snap != nil;
  }];

  NSNumber *now = [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];
  NSNumber *timestamp = [snap priority];
  XCTAssertTrue([[snap priority] isKindOfClass:[NSNumber class]], @"Should get back number");
  XCTAssertTrue([now doubleValue] - [timestamp doubleValue] < 2000,
                @"Number should be no more than 2 seconds ago");
}

- (void)testServerTimestampUpdateRemoteEvents {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block FIRDataSnapshot *snap = nil;
  __block BOOL done = NO;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   snap = snapshot;
                   if (snap && [[snap childSnapshotForPath:@"a/b/d"] value] != [NSNull null]) {
                     done = YES;
                   }
                 }];

  [[writer child:@"a/b/c"] setValue:@1];
  [[writer child:@"a"] updateChildValues:@{@"b" : @{@"c" : [FIRServerValue timestamp], @"d" : @1}}];

  [self waitUntil:^BOOL {
    return done;
  }];

  NSNumber *now = [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];
  NSNumber *timestamp = [[snap childSnapshotForPath:@"a/b/c"] value];
  XCTAssertTrue([[[snap childSnapshotForPath:@"a/b/c"] value] isKindOfClass:[NSNumber class]],
                @"Should get back number");
  XCTAssertTrue([now doubleValue] - [timestamp doubleValue] < 2000,
                @"Number should be no more than 2 seconds ago");
}

- (void)testServerTimestampSetWithPriorityLocalEvents {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  NSDictionary *data = @{
    @"a" : [FIRServerValue timestamp],
    @"b" : @{@".value" : [FIRServerValue timestamp], @".priority" : [FIRServerValue timestamp]}
  };

  __block FIRDataSnapshot *snap = nil;
  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 snap = snapshot;
               }];

  __block BOOL done = NO;
  [node setValue:data
              andPriority:[FIRServerValue timestamp]
      withCompletionBlock:^(NSError *err, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [self
      snapWaiter:node
       withBlock:^(FIRDataSnapshot *snapshot) {
         NSDictionary *value = [snapshot value];
         NSNumber *now =
             [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];
         NSNumber *timestamp = [snapshot priority];
         XCTAssertTrue([[snapshot priority] isKindOfClass:[NSNumber class]],
                       @"Should get back number");
         XCTAssertTrue([now doubleValue] - [timestamp doubleValue] < 2000,
                       @"Number should be no more than 2 seconds ago");
         XCTAssertEqualObjects([snapshot priority], [value objectForKey:@"a"],
                               @"Should get back matching ServerValue.TIMESTAMP");
         XCTAssertEqualObjects([snapshot priority], [value objectForKey:@"b"],
                               @"Should get back matching ServerValue.TIMESTAMP");
         XCTAssertEqualObjects([snapshot priority], [[snapshot childSnapshotForPath:@"b"] priority],
                               @"Should get back matching ServerValue.TIMESTAMP");
       }];
}

- (void)testServerTimestampSetPriorityLocalEvents {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap = nil;
  [node observeEventType:FIRDataEventTypeChildMoved
               withBlock:^(FIRDataSnapshot *snapshot) {
                 snap = snapshot;
               }];

  __block BOOL done = NO;

  [[node child:@"a"] setValue:@1 andPriority:nil];
  [[node child:@"b"] setValue:@1 andPriority:@1];
  [[node child:@"a"] setPriority:[FIRServerValue timestamp]
             withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
               done = YES;
             }];

  [self waitUntil:^BOOL {
    return done;
  }];

  NSNumber *now = [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];
  NSNumber *timestamp = [snap priority];
  XCTAssertTrue([[snap priority] isKindOfClass:[NSNumber class]], @"Should get back number");
  XCTAssertTrue([now doubleValue] - [timestamp doubleValue] < 2000,
                @"Number should be no more than 2 seconds ago");
}

- (void)testServerTimestampUpdateLocalEvents {
  FIRDatabaseReference *node1 = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap1 = nil;
  [node1 observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot) {
                  snap1 = snapshot;
                }];

  __block FIRDataSnapshot *snap2 = nil;
  [node1 observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot *snapshot) {
                  snap2 = snapshot;
                }];

  [node1 runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    [currentData setValue:[FIRServerValue timestamp]];
    return [FIRTransactionResult successWithValue:currentData];
  }];

  [self waitUntil:^BOOL {
    return snap1 != nil && snap2 != nil && [snap1 value] != nil && [snap2 value] != nil;
  }];

  NSNumber *now = [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];

  NSNumber *timestamp1 = [snap1 value];
  XCTAssertTrue([[snap1 value] isKindOfClass:[NSNumber class]], @"Should get back number");
  XCTAssertTrue([now doubleValue] - [timestamp1 doubleValue] < 2000,
                @"Number should be no more than 2 seconds ago");

  NSNumber *timestamp2 = [snap2 value];
  XCTAssertTrue([[snap2 value] isKindOfClass:[NSNumber class]], @"Should get back number");
  XCTAssertTrue([now doubleValue] - [timestamp2 doubleValue] < 2000,
                @"Number should be no more than 2 seconds ago");
}

- (void)testServerTimestampTransactionLocalEvents {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap = nil;
  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 snap = snapshot;
               }];

  [[node child:@"a/b/c"] setValue:@1];
  [[node child:@"a"] updateChildValues:@{@"b" : @{@"c" : [FIRServerValue timestamp], @"d" : @1}}];

  [self waitUntil:^BOOL {
    return snap != nil && [[snap childSnapshotForPath:@"a/b/d"] value] != nil;
  }];

  NSNumber *now = [NSNumber numberWithDouble:round([[NSDate date] timeIntervalSince1970] * 1000)];
  NSNumber *timestamp = [[snap childSnapshotForPath:@"a/b/c"] value];
  XCTAssertTrue([[[snap childSnapshotForPath:@"a/b/c"] value] isKindOfClass:[NSNumber class]],
                @"Should get back number");
  XCTAssertTrue([now doubleValue] - [timestamp doubleValue] < 2000,
                @"Number should be no more than 2 seconds ago");
}

- (void)testServerIncrementOverwritesExistingDataOnline {
  [self checkServerIncrementOverwritesExistingDataWhileOnline:true];
}

- (void)testServerIncrementOverwritesExistingDataOffline {
  [self checkServerIncrementOverwritesExistingDataWhileOnline:false];
}

- (void)checkServerIncrementOverwritesExistingDataWhileOnline:(BOOL)online {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block NSMutableArray *found = [NSMutableArray new];
  NSMutableArray *expected = [NSMutableArray new];
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snap) {
                [found addObject:snap.value];
              }];

  // Going offline ensures that local events get queued up before server events
  if (!online) {
    [ref.repo interrupt];
  }

  // null + incr
  [ref setValue:[FIRServerValue increment:@1]];
  [expected addObject:@1];

  // number + incr
  [ref setValue:@5];
  [ref setValue:[FIRServerValue increment:@1]];
  [expected addObject:@5];
  [expected addObject:@6];

  // string + incr
  [ref setValue:@"hello"];
  [ref setValue:[FIRServerValue increment:@1]];
  [expected addObject:@"hello"];
  [expected addObject:@1];

  // object + incr
  [ref setValue:@{@"hello" : @"world"}];
  [ref setValue:[FIRServerValue increment:@1]];
  [expected addObject:@{@"hello" : @"world"}];
  [expected addObject:@1];

  [self waitUntil:^BOOL {
    return found.count == expected.count;
  }];
  XCTAssertEqualObjects(expected, found);

  if (!online) {
    [ref.repo resume];
  }
}

- (void)testServerIncrementPriorityOnline {
  [self checkServerIncrementPriorityWhileOnline:true];
}

- (void)testServerIncrementPriorityOffline {
  [self checkServerIncrementPriorityWhileOnline:false];
}

- (void)checkServerIncrementPriorityWhileOnline:(BOOL)online {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  if (!online) {
    [ref.repo interrupt];
  }
  __block NSMutableArray *found = [NSMutableArray new];
  NSMutableArray *expected = [NSMutableArray new];
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snap) {
                [found addObject:snap.priority];
              }];

  // Going offline ensures that local events get queued up before server events
  // Also necessary because increment may not be live yet in the server.
  if (!online) {
    [ref.repo interrupt];
  }

  // null + incr
  [ref setValue:@0 andPriority:[FIRServerValue increment:@1]];
  [expected addObject:@1];
  [ref setValue:@0 andPriority:[FIRServerValue increment:@1.5]];
  [expected addObject:@2.5];

  [self waitUntil:^BOOL {
    return found.count == expected.count;
  }];
  XCTAssertEqualObjects(expected, found);

  if (!online) {
    [ref.repo resume];
  }
}

- (void)testServerIncrementOverflowAndTypeCoercion {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block NSMutableArray *found = [NSMutableArray new];
  __block NSMutableArray *foundTypes = [NSMutableArray new];
  NSMutableArray *expected = [NSMutableArray new];
  NSMutableArray *expectedTypes = [NSMutableArray new];
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snap) {
                [found addObject:snap.value];
                [foundTypes addObject:@([(NSNumber *)snap.value objCType])];
              }];

  // Going offline ensures that local events get queued up before server events
  // Also necessary because increment may not be live yet in the server.
  [ref.repo interrupt];

  // long + double = double
  [ref setValue:@1];
  [ref setValue:[FIRServerValue increment:@1.0]];
  [expected addObject:@1];
  [expected addObject:@2.0];
  [expectedTypes addObject:@(@encode(int))];
  [expectedTypes addObject:@(@encode(double))];

  // double + long = double
  [ref setValue:@1.5];
  [ref setValue:[FIRServerValue increment:@1]];
  [expected addObject:@1.5];
  [expected addObject:@2.5];
  [expectedTypes addObject:@(@encode(double))];
  [expectedTypes addObject:@(@encode(double))];

  // long overflow = double
  [ref setValue:@(1)];
  [ref setValue:[FIRServerValue increment:@(LONG_MAX)]];
  [expected addObject:@(1)];
  [expected addObject:@(LONG_MAX + 1.0)];
  [expectedTypes addObject:@(@encode(int))];
  [expectedTypes addObject:@(@encode(double))];

  // unsigned long long overflow = double
  [ref setValue:@1];
  [ref setValue:[FIRServerValue increment:@((unsigned long long)ULLONG_MAX)]];
  [expected addObject:@1];
  [expected addObject:@((double)ULLONG_MAX + 1)];
  [expectedTypes addObject:@(@encode(int))];
  [expectedTypes addObject:@(@encode(double))];

  // long underflow = double
  [ref setValue:@(-1)];
  [ref setValue:[FIRServerValue increment:@(LONG_MIN)]];
  [expected addObject:@(-1)];
  [expected addObject:@(LONG_MIN - 1.0)];
  [expectedTypes addObject:@(@encode(int))];
  [expectedTypes addObject:@(@encode(double))];

  [self waitUntil:^BOOL {
    return found.count == expected.count && foundTypes.count == expectedTypes.count;
  }];
  XCTAssertEqualObjects(expectedTypes, foundTypes);
  XCTAssertEqualObjects(expected, found);
  [ref.repo resume];
}

- (void)testUpdateAfterChildSet {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  __weak FIRDatabaseReference *weakRef = node;
  [node setValue:@{@"a" : @"a"}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        [weakRef observeEventType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          if (snapshot.childrenCount == 3 && [snapshot hasChild:@"a"] &&
                              [snapshot hasChild:@"b"] && [snapshot hasChild:@"c"]) {
                            done = YES;
                          }
                        }];

        [[weakRef child:@"b"] setValue:@"b"];

        [weakRef updateChildValues:@{@"c" : @"c"}];
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testDeltaSyncNoDataUpdatesAfterReconnect {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  FIRDatabaseConfig *cfg = [FTestHelpers configForName:@"test-config"];
  FIRDatabaseReference *ref2 = [[FTestHelpers databaseForConfig:cfg] referenceWithPath:ref.key];
  __block id data = @{@"a" : @1, @"b" : @2, @"c" : @{@".priority" : @3, @".value" : @3}, @"d" : @4};
  [self waitForCompletionOf:ref setValue:data];

  __block BOOL gotData = NO;
  [ref2 observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 XCTAssertFalse(gotData, @"event triggered twice.");
                 gotData = YES;
                 XCTAssertEqualObjects(snapshot.valueInExportFormat, data, @"Got wrong data.");
               }];

  [self waitUntil:^BOOL {
    return gotData;
  }];

  __block BOOL done = NO;
  XCTAssertEqual(ref2.repo.dataUpdateCount, 1L, @"Should have gotten one update.");

  // Bounce connection
  [FRepoManager interrupt:cfg];
  [FRepoManager resume:cfg];

  [[[ref2 root] child:@".info/connected"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               if ([snapshot.value boolValue]) {
                 // We're connected.  Do one more round-trip to make sure all state restoration is
                 // done
                 [[[ref2 root] child:@"foobar/empty/blah"]
                                setValue:nil
                     withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                       XCTAssertEqual(ref2.repo.dataUpdateCount, 1L,
                                      @"Should have gotten one update.");
                       done = YES;
                     }];
               }
             }];

  [self waitUntil:^BOOL {
    return done;
  }];

  // cleanup
  [FRepoManager interrupt:cfg];
  [FRepoManager disposeRepos:cfg];
}

- (void)testServerTimestampEventualConsistencyBetweenLocalAndRemote {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *writer = refs.one;
  FIRDatabaseReference *reader = refs.two;

  __block FIRDataSnapshot *writerSnap = nil;
  __block FIRDataSnapshot *readerSnap = nil;

  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   readerSnap = snapshot;
                 }];

  [writer observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot *snapshot) {
                   writerSnap = snapshot;
                 }];

  [writer setValue:[FIRServerValue timestamp] andPriority:[FIRServerValue timestamp]];

  [self waitUntil:^BOOL {
    if (readerSnap && writerSnap && [[readerSnap value] isKindOfClass:[NSNumber class]] &&
        [[writerSnap value] isKindOfClass:[NSNumber class]]) {
      if ([[readerSnap value] doubleValue] == [[writerSnap value] doubleValue]) {
        return YES;
      }
    }
    return NO;
  }];
}

// Listens at a location and then creates a bunch of children, waiting for them all to complete.
- (void)testChildAddedPerf1 {
  if (!runPerfTests) return;

  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  [ref observeEventType:FIRDataEventTypeChildAdded
              withBlock:^(FIRDataSnapshot *snapshot){

              }];

  NSDate *start = [NSDate date];
  int COUNT = 1000;
  __block BOOL done = NO;
  __block NSDate *finished = nil;
  for (int i = 0; i < COUNT; i++) {
    [[ref childByAutoId] setValue:@"01234567890123456789012345678901234567890123456789"
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                if (i == (COUNT - 1)) {
                  finished = [NSDate date];
                  done = YES;
                }
              }];
  }
  [self
      waitUntil:^BOOL {
        return done;
      }
        timeout:300];
  NSTimeInterval elapsed = [finished timeIntervalSinceDate:start];
  NSLog(@"Elapsed: %f", elapsed);
}

// Listens at a location, then adds a bunch of grandchildren under a single child.
- (void)testDeepChildAddedPerf1 {
  if (!runPerfTests) return;

  FIRDatabaseReference *ref = [FTestHelpers getRandomNode], *childRef = [ref child:@"child"];

  [ref observeEventType:FIRDataEventTypeChildAdded
              withBlock:^(FIRDataSnapshot *snapshot){

              }];

  NSDate *start = [NSDate date];
  int COUNT = 1000;
  __block BOOL done = NO;
  __block NSDate *finished = nil;
  for (int i = 0; i < COUNT; i++) {
    [[childRef childByAutoId] setValue:@"01234567890123456789012345678901234567890123456789"
                   withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                     if (i == (COUNT - 1)) {
                       finished = [NSDate date];
                       done = YES;
                     }
                   }];
  }
  [self
      waitUntil:^BOOL {
        return done;
      }
        timeout:300];

  NSTimeInterval elapsed = [finished timeIntervalSinceDate:start];
  NSLog(@"Elapsed: %f", elapsed);
}

// Listens at a location, then adds a bunch of grandchildren under a single child, but does it with
// merges. NOTE[2015-07-14]: This test is still pretty slow, because [FWriteTree removeWriteId] ends
// up rebuilding the tree after every ack.
- (void)testDeepChildAddedPerfViaMerge1 {
  if (!runPerfTests) return;

  FIRDatabaseReference *ref = [FTestHelpers getRandomNode], *childRef = [ref child:@"child"];

  [ref observeEventType:FIRDataEventTypeChildAdded
              withBlock:^(FIRDataSnapshot *snapshot){

              }];

  NSDate *start = [NSDate date];
  int COUNT = 250;
  __block BOOL done = NO;
  __block NSDate *finished = nil;
  for (int i = 0; i < COUNT; i++) {
    NSString *childName = [childRef childByAutoId].key;
    [childRef updateChildValues:@{childName : @"01234567890123456789012345678901234567890123456789"}
            withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
              if (i == (COUNT - 1)) {
                finished = [NSDate date];
                done = YES;
              }
            }];
  }
  [self
      waitUntil:^BOOL {
        return done;
      }
        timeout:300];

  NSTimeInterval elapsed = [finished timeIntervalSinceDate:start];
  NSLog(@"Elapsed: %f", elapsed);
}

@end
