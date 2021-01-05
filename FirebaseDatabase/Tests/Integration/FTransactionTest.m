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

#import "FirebaseDatabase/Tests/Integration/FTransactionTest.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Tests/Helpers/FEventTester.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"
#import "FirebaseDatabase/Tests/Helpers/FTupleEventTypeString.h"

// HACK used by testUnsentTransactionsAreNotCancelledOnDisconnect to return one bad token and then a
// nil token.
@interface FIROneBadTokenProvider : NSObject <FAuthTokenProvider> {
  BOOL firstFetch;
}
@end

@implementation FIROneBadTokenProvider
- (instancetype)init {
  self = [super init];
  if (self) {
    firstFetch = YES;
  }
  return self;
}

- (void)fetchTokenForcingRefresh:(BOOL)forceRefresh
                    withCallback:(fbt_void_nsstring_nserror)callback {
  // Simulate delay
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_MSEC)),
                 [FIRDatabaseQuery sharedQueue], ^{
                   if (self->firstFetch) {
                     self->firstFetch = NO;
                     callback(@"bad-token", nil);
                   } else {
                     callback(nil, nil);
                   }
                 });
}

- (void)listenForTokenChanges:(fbt_void_nsstring)listener {
}

@end
@implementation FTransactionTest

- (void)testNewValueIsImmediatelyVisible {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL runOnce = NO;
  [[node child:@"foo"] runTransactionBlock:^(FIRMutableData *currentValue) {
    runOnce = YES;
    [currentValue setValue:@42];
    return [FIRTransactionResult successWithValue:currentValue];
  }];

  [self waitUntil:^BOOL {
    return runOnce;
  }];

  __block BOOL ready = NO;
  [[node child:@"foo"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               if (!ready) {
                 NSNumber *val = [snapshot value];
                 XCTAssertTrue([val isEqualToNumber:@42], @"Got value set in transaction");
                 ready = YES;
               }
             }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testNonAbortedTransactionSetsCommittedToTrueInCallback {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  [[node child:@"foo"]
      runTransactionBlock:^(FIRMutableData *currentValue) {
        [currentValue setValue:@42];
        return [FIRTransactionResult successWithValue:currentValue];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(committed, @"Should not have aborted");
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testAbortedTransactionSetsCommittedToFalseInCallback {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  [[node child:@"foo"]
      runTransactionBlock:^(FIRMutableData *currentValue) {
        return [FIRTransactionResult abort];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertFalse(committed, @"Should have aborted");
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testBugTestSetDataReconnectDoTransactionThatAbortsOnceDataArrivesVerifyCorrectEvents {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *reader = refs.one;

  __block BOOL dataWritten = NO;
  [[reader child:@"foo"] setValue:@42
              withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                dataWritten = YES;
              }];

  [self waitUntil:^BOOL {
    return dataWritten;
  }];

  FIRDatabaseReference *writer = refs.two;
  __block int eventsReceived = 0;
  [[writer child:@"foo"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot *snapshot) {
               if (eventsReceived == 0) {
                 NSString *val = [snapshot value];
                 XCTAssertTrue([val isEqualToString:@"temp value"],
                               @"Got initial transaction value");
               } else if (eventsReceived == 1) {
                 NSNumber *val = [snapshot value];
                 XCTAssertTrue([val isEqualToNumber:@42], @"Got hidden original value");
               } else {
                 XCTFail(@"Too many events");
               }
               eventsReceived++;
             }];

  [[writer child:@"foo"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id current = [currentData value];
        if (current == [NSNull null]) {
          [currentData setValue:@"temp value"];
          return [FIRTransactionResult successWithValue:currentData];
        } else {
          return [FIRTransactionResult abort];
        }
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertFalse(committed, @"This transaction should never commit");
        XCTAssertTrue(error == nil, @"This transaction should not have an error");
      }];

  [self waitUntil:^BOOL {
    return eventsReceived == 2;
  }];
}

- (void)testUseTransactionToCreateANodeMakeSureExactlyOneEventIsReceived {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block int events = 0;
  __block BOOL done = NO;

  [[node child:@"a"] observeEventType:FIRDataEventTypeValue
                            withBlock:^(FIRDataSnapshot *snapshot) {
                              events++;
                              if (events > 1) {
                                XCTFail(@"Too many events");
                              }
                            }];

  [[node child:@"a"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@42];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done && events == 1;
  }];
}

- (void)testUseTransactionToUpdateTwoExistingChildNodesMakeSureEventsAreOnlyRaisedForChangedNode {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *node1 = [refs.one child:@"foo"];
  FIRDatabaseReference *node2 = [refs.two child:@"foo"];

  __block BOOL ready = NO;
  [[node1 child:@"a"] setValue:@42];
  [[node1 child:@"b"] setValue:@42
           withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
             ready = YES;
           }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  FEventTester *et = [[FEventTester alloc] initFrom:self];
  NSArray *expect = @[
    [[FTupleEventTypeString alloc] initWithFirebase:[node2 child:@"a"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil],
    [[FTupleEventTypeString alloc] initWithFirebase:[node2 child:@"b"]
                                          withEvent:FIRDataEventTypeValue
                                         withString:nil]
  ];

  [et addLookingFor:expect];
  [et wait];

  expect = @[ [[FTupleEventTypeString alloc] initWithFirebase:[node2 child:@"b"]
                                                    withEvent:FIRDataEventTypeValue
                                                   withString:nil] ];

  [et addLookingFor:expect];

  ready = NO;
  [node2
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        NSDictionary *toSet = @{@"a" : @42, @"b" : @87};
        [currentData setValue:toSet];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [et wait];
}

- (void)testTransactionOnlyCalledOnceWhenInitializingAnEmptyNode {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block BOOL updateCalled = NO;
  [node runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    id val = [currentData value];
    XCTAssertTrue(val == [NSNull null], @"Should be no value here to start with");
    if (updateCalled) {
      XCTFail(@"Should not be called again");
    }
    updateCalled = YES;
    [currentData setValue:@{@"a" : @5, @"b" : @6}];
    return [FIRTransactionResult successWithValue:currentData];
  }];

  [self waitUntil:^BOOL {
    return updateCalled;
  }];
}

- (void)testSecondTransactionGetsRunImmediatelyOnPreviousOutputAndOnlyRunsOnce {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *ref1 = refs.one;
  FIRDatabaseReference *ref2 = refs.two;

  __block BOOL firstRun = NO;
  __block BOOL firstDone = NO;
  __block BOOL secondRun = NO;
  __block BOOL secondDone = NO;

  [ref1
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        XCTAssertFalse(firstRun, @"Should not be run twice");
        firstRun = YES;
        [currentData setValue:@42];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(committed, @"Should not fail");
        firstDone = YES;
      }];

  [self waitUntil:^BOOL {
    return firstRun;
  }];

  [ref1
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        XCTAssertFalse(secondRun, @"Should only run once");
        secondRun = YES;
        NSNumber *val = [currentData value];
        XCTAssertTrue([val isEqualToNumber:@42], @"Should see result of last transaction");
        [currentData setValue:@84];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(committed, @"Should not fail");
        secondDone = YES;
      }];

  [self waitUntil:^BOOL {
    return secondRun;
  }];

  __block FIRDataSnapshot *snap = nil;
  [ref1 observeSingleEventOfType:FIRDataEventTypeValue
                       withBlock:^(FIRDataSnapshot *snapshot) {
                         snap = snapshot;
                       }];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap value] isEqualToNumber:@84], @"Should get updated value");

  [self waitUntil:^BOOL {
    return firstDone && secondDone;
  }];

  snap = nil;
  [ref2 observeSingleEventOfType:FIRDataEventTypeValue
                       withBlock:^(FIRDataSnapshot *snapshot) {
                         snap = snapshot;
                       }];

  [self waitUntil:^BOOL {
    return snap != nil;
  }];

  XCTAssertTrue([[snap value] isEqualToNumber:@84], @"Should get updated value");
}

// The js test, "Set() cancels pending transactions and re-runs affected transactions.", does not
// cleanly port to ios due to everything being asynchronous. Rather than attempt to mitigate the
// various race conditions inherent in a port, I'm adding tests to cover the specific behaviors
// wrapped up in that one test.

- (void)testSetCancelsPendingTransaction {
  FIRDatabaseReference *node = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *nodeSnap = nil;
  __block FIRDataSnapshot *nodeFooSnap = nil;

  [node observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 nodeSnap = snapshot;
               }];

  [[node child:@"foo"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot *snapshot) {
                                nodeFooSnap = snapshot;
                              }];

  __block BOOL firstDone = NO;
  __block BOOL secondDone = NO;
  __block BOOL firstRun = NO;

  [[node child:@"foo"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        XCTAssertFalse(firstRun, @"Should only run once");
        firstRun = YES;
        [currentData setValue:@42];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(committed, @"Should not fail");
        firstDone = YES;
      }];

  [self waitUntil:^BOOL {
    return nodeFooSnap != nil;
  }];

  XCTAssertTrue([[nodeFooSnap value] isEqualToNumber:@42], @"Got first value");

  [node
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@{@"foo" : @84, @"bar" : @1}];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertFalse(committed, @"This should not ever be committed");
        secondDone = YES;
      }];

  [self waitUntil:^BOOL {
    return nodeSnap != nil;
  }];

  [[node child:@"foo"] setValue:@0];
}

// It's difficult to force a transaction re-run on ios, since everything is async. There is also an
// outstanding case that prevents this test from being before a connection is established (#1981)
/*
- (void) testSetRerunsAffectedTransactions  {

    Firebase* node = [FTestHelpers getRandomNode];

    __block BOOL ready = NO;
    [[node.parent child:@".info/connected"] observeEventType:FIRDataEventTypeValue
withBlock:^(FIRDataSnapshot *snapshot) { ready = [[snapshot value] boolValue];
    }];
    [self waitUntil:^BOOL{
        return ready;
    }];

    __block FIRDataSnapshot* nodeSnap = nil;

    [node observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *snapshot) {
        nodeSnap = snapshot;
        NSLog(@"SNAP value: %@", [snapshot value]);
    }];

    __block BOOL firstDone = NO;
    __block BOOL secondDone = NO;
    __block BOOL firstRun = NO;
    __block int secondCount = 0;
    __block BOOL setDone = NO;

    [node runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        STAssertFalse(firstRun, @"Should only run once");
        firstRun = YES;
        [currentData setValue:@42];
        return [FIRTransactionResult successWithValue:currentData];
    } andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        STAssertTrue(committed, @"Should not fail");
        firstDone = YES;
    }];

    [[node child:@"bar"] runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        NSLog(@"RUNNING TRANSACTION");
        secondCount++;
        id val = [currentData value];
        if (secondCount == 1) {
            STAssertTrue(val == [NSNull null], @"Should not have a value");
            [currentData setValue:@"first"];
            return [FIRTransactionResult successWithValue:currentData];
        } else if (secondCount == 2) {
            NSLog(@"val: %@", val);
            STAssertTrue(val == [NSNull null], @"Should not have a value");
            [currentData setValue:@"second"];
            return [FIRTransactionResult successWithValue:currentData];
        } else {
            STFail(@"Called too many times");
            return [FIRTransactionResult abort];
        }
    } andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        STAssertTrue(committed, @"Should eventually be committed");
        secondDone = YES;
    }];

    [[node child:@"foo"] setValue:@0 andCompletionBlock:^(NSError *error) {
        setDone = YES;
    }];

    [self waitUntil:^BOOL{
        return setDone;
    }];

    NSDictionary* expected = @{@"bar": @"second", @"foo": @0};
    STAssertTrue([[nodeSnap value] isEqualToDictionary:expected], @"Got last value");

    STAssertTrue(secondCount == 2, @"Should have re-run second transaction");
}*/

- (void)testTransactionSetSetWorks {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  [ref
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        XCTAssertTrue(val == [NSNull null], @"Initial data should be null");
        [currentData setValue:@"hi!"];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(error == nil, @"Should not be an error");
        XCTAssertTrue(committed, @"Should commit");
        done = YES;
      }];

  [ref setValue:@"foo"];
  [ref setValue:@"bar"];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testPriorityIsNotPreservedWhenSettingData {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block FIRDataSnapshot *snap = nil;
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                snap = snapshot;
              }];

  [ref setValue:@"test" andPriority:@5];

  __block BOOL ready = NO;
  [ref
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@"new value"];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  id val = [snap value];
  id pri = [snap priority];
  XCTAssertTrue(pri == [NSNull null], @"Got priority");
  XCTAssertTrue([val isEqualToString:@"new value"], @"Get new value");
}

// Skipping test with nested transactions. Everything is async on ios, so new transactions just get
// placed in a queue

- (void)testResultSnapshotIsPassedToOnComplete {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *ref1 = refs.one;
  FIRDatabaseReference *ref2 = refs.two;

  __block BOOL done = NO;
  [ref1
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        if (val == [NSNull null]) {
          [currentData setValue:@"hello!"];
          return [FIRTransactionResult successWithValue:currentData];
        } else {
          return [FIRTransactionResult abort];
        }
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(committed, @"Should commit");
        XCTAssertTrue([[snapshot value] isEqualToString:@"hello!"], @"Got correct snapshot");
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
  // do it again for the aborted case

  done = NO;
  [ref1
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        if (val == [NSNull null]) {
          [currentData setValue:@"hello!"];
          return [FIRTransactionResult successWithValue:currentData];
        } else {
          return [FIRTransactionResult abort];
        }
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertFalse(committed, @"Should not commit");
        XCTAssertTrue([[snapshot value] isEqualToString:@"hello!"], @"Got correct snapshot");
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  // do it again on a fresh connection, for the aborted case
  done = NO;
  [ref2
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        if (val == [NSNull null]) {
          [currentData setValue:@"hello!"];
          return [FIRTransactionResult successWithValue:currentData];
        } else {
          return [FIRTransactionResult abort];
        }
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertFalse(committed, @"Should not commit");
        XCTAssertTrue([[snapshot value] isEqualToString:@"hello!"], @"Got correct snapshot");
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testTransactionAbortsAfter25Retries {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  [ref.repo setHijackHash:YES];

  __block int tries = 0;
  __block BOOL done = NO;
  [ref
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        XCTAssertTrue(tries < 25, @"Should not be more than 25 tries");
        tries++;
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(error != nil, @"Should fail, too many retries");
        XCTAssertFalse(committed, @"Should not commit");
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  [ref.repo setHijackHash:NO];
}

- (void)testSetShouldCancelSentTransactionsThatComeBackAsDatastale {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *ref1 = refs.one;
  FIRDatabaseReference *ref2 = refs.two;

  __block BOOL ready = NO;
  [ref1 setValue:@5
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [ref2
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        XCTAssertTrue(val == [NSNull null], @"No current value");
        [currentData setValue:@72];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(error != nil, @"Should abort");
        XCTAssertFalse(committed, @"Should not commit");
        ready = YES;
      }];

  [ref2 setValue:@32];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testUpdateShouldNotCancelUnrelatedTransactions {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block BOOL fooTransactionDone = NO;
  __block BOOL barTransactionDone = NO;

  [self waitForCompletionOf:[ref child:@"foo"] setValue:@"oldValue"];

  [ref.repo setHijackHash:YES];

  // This transaction should get cancelled as we update "foo" later on.
  [[ref child:@"foo"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@72];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(error != nil, @"Should abort");
        XCTAssertFalse(committed, @"Should not commit");
        fooTransactionDone = YES;
      }];

  // This transaction should not get cancelled since we don't update "bar".
  [[ref child:@"bar"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@72];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        // Note: In rare cases, this might get aborted since failed transactions (forced by
        // setHijackHash) are only retried 25 times. If we hit this limit before we stop hijacking
        // the hash below, this test will flake.
        XCTAssertTrue(error == nil, @"Should not abort");
        XCTAssertTrue(committed, @"Should commit");
        barTransactionDone = YES;
      }];

  NSDictionary *udpateData = @{
    @"foo" : @"newValue",
    @"boo" : @"newValue",
    @"doo/foo" : @"newValue",
    @"loo" : @{@"doo" : @{@"boo" : @"newValue"}}
  };

  [self waitForCompletionOf:ref updateChildValues:udpateData];
  XCTAssertTrue(fooTransactionDone, "Should have gotten cancelled before the update");
  XCTAssertFalse(barTransactionDone, "Should run after the update");
  [ref.repo setHijackHash:NO];

  WAIT_FOR(barTransactionDone);
}

- (void)testTransactionOnWackyUnicode {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *ref1 = refs.one;
  FIRDatabaseReference *ref2 = refs.two;

  __block BOOL ready = NO;
  [ref1 setValue:@"♜♞♝♛♚♝♞♜"
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [ref2
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        if (val != [NSNull null]) {
          XCTAssertTrue([val isEqualToString:@"♜♞♝♛♚♝♞♜"], @"Got crazy unicode");
        }
        [currentData setValue:@"♖♘♗♕♔♗♘♖"];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(error == nil, @"Should not abort");
        XCTAssertTrue(committed, @"Should commit");
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testImmediatelyAbortedTransactions {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  [ref runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    return [FIRTransactionResult abort];
  }];

  __block BOOL ready = NO;
  [ref
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        return [FIRTransactionResult abort];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(error == nil, @"No error occurred, we just aborted");
        XCTAssertFalse(committed, @"Should not commit");
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testAddingToAnArrayWithATransaction {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];

  __block BOOL done = NO;
  [ref setValue:@[ @"cat", @"horse" ]
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;

  [ref
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        if (val != [NSNull null]) {
          NSArray *arr = val;
          NSMutableArray *toSet = [arr mutableCopy];
          [toSet addObject:@"dog"];
          [currentData setValue:toSet];
          return [FIRTransactionResult successWithValue:currentData];
        } else {
          [currentData setValue:@[ @"dog" ]];
          return [FIRTransactionResult successWithValue:currentData];
        }
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(committed, @"Should commit");
        NSArray *val = [snapshot value];
        NSArray *expected = @[ @"cat", @"horse", @"dog" ];
        XCTAssertTrue([val isEqualToArray:expected], @"Got whole array");
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testMergedTransactionsHaveCorrectSnapshotInOnComplete {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *node1 = refs.one;
  FIRDatabaseReference *node2 = refs.two;

  __block BOOL done = NO;
  [node1 setValue:@{@"a" : @0}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];

  __block BOOL transaction1Done = NO;
  __block BOOL transaction2Done = NO;

  [node2
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        if (val != [NSNull null]) {
          XCTAssertTrue([@{@"a" : @0} isEqualToDictionary:val], @"Got initial data");
        }
        [currentData setValue:@{@"a" : @1}];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(committed, @"Should commit");
        XCTAssertTrue([snapshot.key isEqualToString:node2.key], @"Correct snapshot name");
        NSDictionary *val = [snapshot value];
        // Per new behavior, will include the accepted value of the transaction, if it was
        // successful.
        NSDictionary *expected = @{@"a" : @1};
        XCTAssertTrue([val isEqualToDictionary:expected], @"Got final result");
        transaction1Done = YES;
      }];

  [[node2 child:@"a"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id val = [currentData value];
        if (val != [NSNull null]) {
          XCTAssertTrue([@1 isEqualToNumber:val], @"Got initial data");
        }
        [currentData setValue:@2];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(committed, @"Should commit");
        XCTAssertTrue([snapshot.key isEqualToString:@"a"], @"Correct snapshot name");
        NSNumber *val = [snapshot value];
        NSNumber *expected = @2;
        XCTAssertTrue([val isEqualToNumber:expected], @"Got final result");
        transaction2Done = YES;
      }];

  [self waitUntil:^BOOL {
    return transaction1Done && transaction2Done;
  }];
}

// Skipping two tests on nested calls. Since iOS uses a work queue, nested calls don't actually
// happen synchronously, so they aren't problematic

- (void)testPendingTransactionsAreCancelledOnDisconnect {
  FIRDatabaseConfig *cfg = [FTestHelpers configForName:@"pending-transactions"];
  FIRDatabaseReference *ref = [[[FTestHelpers databaseForConfig:cfg] reference] childByAutoId];

  __block BOOL done = NO;
  [[ref child:@"a"] setValue:@"initial"
         withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
           done = YES;
         }];

  [self waitUntil:^BOOL {
    return done;
  }];

  done = NO;
  [[ref child:@"b"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@"new"];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertFalse(committed, @"Should not commit");
        XCTAssertTrue(error != nil, @"Should be an error");
        done = YES;
      }];

  [FRepoManager interrupt:cfg];

  [self waitUntil:^BOOL {
    return done;
  }];

  // cleanup
  [FRepoManager interrupt:cfg];
  [FRepoManager disposeRepos:cfg];
}

- (void)testTransactionWithoutLocalEvents1 {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  NSMutableArray *values = [[NSMutableArray alloc] init];
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                [values addObject:[snapshot value]];
              }];

  [self waitUntil:^BOOL {
    // get initial data
    return values.count > 0;
  }];

  __block BOOL done = NO;
  [ref
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@"hello!"];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(error == nil, @"Should not be an error");
        XCTAssertTrue(committed, @"Committed");
        XCTAssertTrue([[snapshot value] isEqualToString:@"hello!"], @"got correct snapshot");
        done = YES;
      }
      withLocalEvents:NO];

  NSArray *expected = @[ [NSNull null] ];
  XCTAssertTrue([values isEqualToArray:expected], @"Should not have gotten any values yet");

  [self waitUntil:^BOOL {
    return done;
  }];

  expected = @[ [NSNull null], @"hello!" ];
  XCTAssertTrue([values isEqualToArray:expected], @"Should have the new value now");
}

- (void)testTransactionWithoutLocalEvents2 {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *ref1 = refs.one;
  FIRDatabaseReference *ref2 = refs.two;
  int SETS = 4;

  [ref1.repo setHijackHash:YES];

  NSMutableArray *events = [[NSMutableArray alloc] init];
  [ref1 setValue:@0];
  [ref1 observeEventType:FIRDataEventTypeValue
               withBlock:^(FIRDataSnapshot *snapshot) {
                 [events addObject:[snapshot value]];
               }];

  [self waitUntil:^BOOL {
    return events.count > 0;
  }];

  NSArray *expected = @[ @0 ];
  XCTAssertTrue([events isEqualToArray:expected], @"Got initial set");

  __block int retries = 0;
  __block BOOL done = NO;
  [ref1
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        retries++;
        id val = [currentData value];
        NSNumber *num = @0;
        if (val != [NSNull null]) {
          num = val;
        }
        int eventCount = [num intValue];
        if (eventCount == SETS - 1) {
          [ref1.repo setHijackHash:NO];
        }

        [currentData setValue:@"txn result"];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertTrue(error == nil, @"Should not be an error");
        XCTAssertTrue(committed, @"Committed");
        XCTAssertTrue([[snapshot value] isEqualToString:@"txn result"], @"got correct snapshot");
        done = YES;
      }
      withLocalEvents:NO];

  // Meanwhile, do sets from the second connection
  for (int i = 0; i < SETS; ++i) {
    __block BOOL setDone = NO;
    [ref2 setValue:[NSNumber numberWithInt:i]
        withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
          setDone = YES;
        }];
    [self waitUntil:^BOOL {
      return setDone;
    }];
  }

  [self waitUntil:^BOOL {
    return done;
  }];

  XCTAssertTrue(retries > 0, @"Transaction should have retried");
  XCTAssertEqualObjects([events lastObject], @"txn result",
                        @"Final value matches expected value from txn");
}

// Skipping test of calling transaction from value callback. Since all api calls are async on iOS,
// nested calls are not a problem.

- (void)testTransactionRevertsDataWhenAddADeeperListen {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *ref1 = refs.one;
  FIRDatabaseReference *ref2 = refs.two;

  __block BOOL done = NO;
  [[ref1 child:@"y"] setValue:@"test"
          withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
            [ref2 runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
              if (currentData.value == [NSNull null]) {
                [[currentData childDataByAppendingPath:@"x"] setValue:@5];
                return [FIRTransactionResult successWithValue:currentData];
              } else {
                return [FIRTransactionResult abort];
              }
            }];

            [[ref2 child:@"y"] observeEventType:FIRDataEventTypeValue
                                      withBlock:^(FIRDataSnapshot *snapshot) {
                                        if ([snapshot.value isEqual:@"test"]) {
                                          done = YES;
                                        }
                                      }];
          }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testTransactionWithIntegerKeys {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block BOOL done = NO;
  NSDictionary *toSet = @{@"1" : @1, @"5" : @5, @"10" : @10, @"20" : @20};
  [ref setValue:toSet
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        [ref
            runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
              [currentData setValue:@42];
              return [FIRTransactionResult successWithValue:currentData];
            }
            andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
              XCTAssertNil(error, @"Error should be nil.");
              XCTAssertTrue(committed, @"Transaction should have committed.");
              done = YES;
            }];
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

// https://app.asana.com/0/5673976843758/9259161251948
- (void)testBubbleAppTransactionBug {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block BOOL done = NO;
  [[ref child:@"a"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@1];
        return [FIRTransactionResult successWithValue:currentData];
      }
       andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot){
       }];

  [[ref child:@"a"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        NSNumber *val = currentData.value;
        NSNumber *new = [ NSNumber numberWithInt : (val.intValue + 42) ];
        [currentData setValue:new];
        return [FIRTransactionResult successWithValue:currentData];
      }
       andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot){
       }];

  [[ref child:@"b"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@7];
        return [FIRTransactionResult successWithValue:currentData];
      }
       andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot){
       }];

  [ref
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        NSNumber *a = [currentData childDataByAppendingPath:@"a"].value;
        NSNumber *b = [currentData childDataByAppendingPath:@"b"].value;
        NSNumber *new = [ NSNumber numberWithInt : a.intValue + b.intValue ];
        [currentData setValue:new];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertNil(error, @"Error should be nil.");
        XCTAssertTrue(committed, @"Committed should be true.");
        XCTAssertEqualObjects(@50, snapshot.value, @"Result should be 50.");
        done = YES;
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

// If we have cached data, transactions shouldn't run on null.
- (void)testTransactionsAreRunInitiallyOnCurrentlyCachedData {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  id initialData = @{@"a" : @"a-val", @"b" : @"b-val"};
  __block BOOL done = NO;
  __weak FIRDatabaseReference *weakRef = ref;
  [ref setValue:initialData
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *r) {
        [weakRef observeEventType:FIRDataEventTypeValue
                        withBlock:^(FIRDataSnapshot *snapshot) {
                          [weakRef runTransactionBlock:^FIRTransactionResult *(
                                       FIRMutableData *currentData) {
                            XCTAssertEqualObjects(currentData.value, initialData,
                                                  @"Should be initial data.");
                            done = YES;
                            return [FIRTransactionResult abort];
                          }];
                        }];
      }];

  [self waitUntil:^BOOL {
    return done;
  }];
}

- (void)testMultipleLevels {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block BOOL done = NO;

  [ref runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    return [FIRTransactionResult successWithValue:currentData];
  }];

  [[ref child:@"a"] runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    return [FIRTransactionResult successWithValue:currentData];
  }];

  [[ref child:@"b"] runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    return [FIRTransactionResult successWithValue:currentData];
  }];

  [ref
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        done = YES;
      }];

  WAIT_FOR(done);
}

- (void)testLocalServerValuesEventuallyButNotImmediatelyMatchServerWithTxns {
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

  [writer
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:[FIRServerValue timestamp]];
        [currentData setPriority:[FIRServerValue timestamp]];
        return [FIRTransactionResult successWithValue:currentData];
      }
       andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot){
       }];

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
  XCTAssertTrue([now doubleValue] - [firstWriteSnap.value doubleValue] < 2000,
                @"Should have received a local event with a value close to timestamp");
  XCTAssertTrue([now doubleValue] - [firstWriteSnap.priority doubleValue] < 2000,
                @"Should have received a local event with a priority close to timestamp");
  XCTAssertTrue([now doubleValue] - [secondWriteSnap.value doubleValue] < 2000,
                @"Should have received a server event with a value close to timestamp");
  XCTAssertTrue([now doubleValue] - [secondWriteSnap.priority doubleValue] < 2000,
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

- (void)testTransactionWithQueryListen {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block BOOL done = NO;

  [ref setValue:@{@"a" : @1, @"b" : @2}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        [[ref queryLimitedToFirst:1]
                          observeEventType:FIRDataEventTypeChildAdded
            andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot *snapshot, NSString *prevName) {
            }
                           withCancelBlock:^(NSError *error){
                           }];

        [[ref child:@"a"]
            runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
              return [FIRTransactionResult successWithValue:currentData];
            }
            andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
              XCTAssertNil(error, @"This transaction should not have an error");
              XCTAssertTrue(committed, @"Should not have aborted");
              XCTAssertEqualObjects([snapshot value], @1,
                                    @"Transaction value should match initial set");
              done = YES;
            }];
      }];

  WAIT_FOR(done);
}

- (void)testTransactionDoesNotPickUpCachedDataFromPreviousOnce {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *me = refs.one;
  FIRDatabaseReference *other = refs.two;
  __block BOOL done = NO;

  [me setValue:@"not null"
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  WAIT_FOR(done);
  done = NO;

  [me observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot *snapshot) {
                       done = YES;
                     }];

  WAIT_FOR(done);
  done = NO;

  [other setValue:[NSNull null]
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  WAIT_FOR(done);
  done = NO;

  [me
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id current = [currentData value];
        if (current == [NSNull null]) {
          [currentData setValue:@"it was null!"];
        } else {
          [currentData setValue:@"it was not null!"];
        }
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertNil(error, @"This transaction should not have an error");
        XCTAssertTrue(committed, @"Should not have aborted");
        XCTAssertEqualObjects([snapshot value], @"it was null!",
                              @"Transaction value should match remote null set");
        done = YES;
      }];

  WAIT_FOR(done);
}

- (void)testTransactionDoesNotPickUpCachedDataFromPreviousTransaction {
  FTupleFirebase *refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference *me = refs.one;
  FIRDatabaseReference *other = refs.two;
  __block BOOL done = NO;

  [me
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@"not null"];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertNil(error, @"This transaction should not have an error");
        XCTAssertTrue(committed, @"Should not have aborted");
        done = YES;
      }];

  WAIT_FOR(done);
  done = NO;

  [other setValue:[NSNull null]
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        done = YES;
      }];

  WAIT_FOR(done);
  done = NO;

  [me
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        id current = [currentData value];
        if (current == [NSNull null]) {
          [currentData setValue:@"it was null!"];
        } else {
          [currentData setValue:@"it was not null!"];
        }
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertNil(error, @"This transaction should not have an error");
        XCTAssertTrue(committed, @"Should not have aborted");
        XCTAssertEqualObjects([snapshot value], @"it was null!",
                              @"Transaction value should match remote null set");
        done = YES;
      }];

  WAIT_FOR(done);
}

- (void)testTransactionOnQueriedLocationDoesntRunInitiallyOnNull {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block BOOL txnDone = NO;

  [self waitForCompletionOf:[ref childByAutoId] setValue:@{@"a" : @1, @"b" : @2}];

  [[ref queryLimitedToFirst:1]
      observeEventType:FIRDataEventTypeChildAdded
             withBlock:^(FIRDataSnapshot *snapshot) {
               [snapshot.ref
                   runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
                     id expected = @{@"a" : @1, @"b" : @2};
                     XCTAssertEqualObjects(currentData.value, expected, @"");
                     [currentData setValue:[NSNull null]];
                     return [FIRTransactionResult successWithValue:currentData];
                   }
                   andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
                     XCTAssertNil(error, @"");
                     XCTAssertTrue(committed, @"");
                     XCTAssertEqualObjects(snapshot.value, [NSNull null], @"");
                     txnDone = YES;
                   }];
             }];

  WAIT_FOR(txnDone);
}

- (void)testTransactionsRaiseCorrectChildChangedEventsOnQueries {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block BOOL txnDone = NO;
  NSMutableArray *snapshots = [[NSMutableArray alloc] init];

  [self waitForCompletionOf:ref setValue:@{@"foo" : @{@"value" : @1}}];

  FIRDatabaseQuery *query = [ref queryEndingAtValue:@(DBL_MIN)];

  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot *snapshot) {
                  [snapshots addObject:snapshot];
                }];

  [query observeEventType:FIRDataEventTypeChildChanged
                withBlock:^(FIRDataSnapshot *snapshot) {
                  [snapshots addObject:snapshot];
                }];

  [[ref child:@"foo"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [[currentData childDataByAppendingPath:@"value"] setValue:@2];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertNil(error, @"");
        XCTAssertTrue(committed, @"");
        txnDone = YES;
      }
      withLocalEvents:NO];

  WAIT_FOR(txnDone);

  XCTAssertTrue(snapshots.count == 2, @"");
  FIRDataSnapshot *addedSnapshot = snapshots[0];
  XCTAssertEqualObjects(addedSnapshot.key, @"foo", @"");
  XCTAssertEqualObjects(addedSnapshot.value, @{@"value" : @1}, @"");

  FIRDataSnapshot *changedSnapshot = snapshots[1];
  XCTAssertEqualObjects(changedSnapshot.key, @"foo", @"");
  XCTAssertEqualObjects(changedSnapshot.value, @{@"value" : @2}, @"");
}

- (void)testTransactionsUseLocalMerges {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  __block BOOL txnDone = NO;
  [ref updateChildValues:@{@"foo" : @"bar"}];

  [[ref child:@"foo"]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        XCTAssertEqualObjects(currentData.value, @"bar",
                              @"Transaction value matches local updates");
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertNil(error, @"");
        XCTAssertTrue(committed, @"");
        txnDone = YES;
      }];

  WAIT_FOR(txnDone);
}

// See https://app.asana.com/0/15566422264127/23303789496881
- (void)testOutOfOrderRemoveWritesAreHandledCorrectly {
  FIRDatabaseReference *ref = [FTestHelpers getRandomNode];
  [ref setValue:@{@"foo" : @"bar"}];
  [ref runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    [currentData setValue:@"transaction-1"];
    return [FIRTransactionResult successWithValue:currentData];
  }];
  [ref runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    [currentData setValue:@"transaction-2"];
    return [FIRTransactionResult successWithValue:currentData];
  }];
  __block BOOL done = NO;
  // This will trigger an abort of the transaction which should not cause the client to crash
  [ref updateChildValues:@{@"qux" : @"quu"}
      withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
        XCTAssertNil(error);
        done = YES;
      }];

  WAIT_FOR(done);
}

- (void)testUnsentTransactionsAreNotCancelledOnDisconnect {
  // Hack: To trigger us to disconnect before restoring state, we inject a bad auth token.
  // In real-world usage the much more common case is that we get redirected to a different
  // server, but that's harder to manufacture from a test.
  NSString *configName = @"testUnsentTransactionsAreNotCancelledOnDisconnect";
  FIRDatabaseConfig *config = [FTestHelpers configForName:configName];
  config.authTokenProvider = [[FIROneBadTokenProvider alloc] init];

  // Queue a transaction offline.
  FIRDatabaseReference *root = [[FTestHelpers databaseForConfig:config] reference];
  [root.database goOffline];
  __block BOOL done = NO;
  [[root childByAutoId]
      runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
        [currentData setValue:@0];
        return [FIRTransactionResult successWithValue:currentData];
      }
      andCompletionBlock:^(NSError *error, BOOL committed, FIRDataSnapshot *snapshot) {
        XCTAssertNil(error);
        XCTAssertTrue(committed);
        done = YES;
      }];

  [root.database goOnline];
  WAIT_FOR(done);
}

@end
