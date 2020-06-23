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

#import "FirebaseDatabase/Tests/Integration/FIRDatabaseQueryTests.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Tests/Helpers/FTestExpectations.h"

@implementation FIRDatabaseQueryTests

- (void)testCanCreateBasicQueries {
  // Just make sure none of these throw anything

  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  [ref queryLimitedToFirst:10];
  [ref queryLimitedToLast:10];

  [[ref queryOrderedByKey] queryStartingAtValue:@"foo"];
  [[ref queryOrderedByKey] queryEndingAtValue:@"foo"];
  [[ref queryOrderedByKey] queryEqualToValue:@"foo"];

  [[ref queryOrderedByChild:@"index"] queryStartingAtValue:@YES];
  [[ref queryOrderedByChild:@"index"] queryStartingAtValue:@1];
  [[ref queryOrderedByChild:@"index"] queryStartingAtValue:@"foo"];
  [[ref queryOrderedByChild:@"index"] queryStartingAtValue:nil];
  [[ref queryOrderedByChild:@"index"] queryEndingAtValue:@YES];
  [[ref queryOrderedByChild:@"index"] queryEndingAtValue:@1];
  [[ref queryOrderedByChild:@"index"] queryEndingAtValue:@"foo"];
  [[ref queryOrderedByChild:@"index"] queryEndingAtValue:nil];
  [[ref queryOrderedByChild:@"index"] queryEqualToValue:@YES];
  [[ref queryOrderedByChild:@"index"] queryEqualToValue:@1];
  [[ref queryOrderedByChild:@"index"] queryEqualToValue:@"foo"];
  [[ref queryOrderedByChild:@"index"] queryEqualToValue:nil];

  [[ref queryOrderedByPriority] queryStartingAtValue:@1];
  [[ref queryOrderedByPriority] queryStartingAtValue:@"foo"];
  [[ref queryOrderedByPriority] queryStartingAtValue:nil];
  [[ref queryOrderedByPriority] queryEndingAtValue:@1];
  [[ref queryOrderedByPriority] queryEndingAtValue:@"foo"];
  [[ref queryOrderedByPriority] queryEndingAtValue:nil];
  [[ref queryOrderedByPriority] queryEqualToValue:@1];
  [[ref queryOrderedByPriority] queryEqualToValue:@"foo"];
  [[ref queryOrderedByPriority] queryEqualToValue:nil];
}

- (void)testInvalidQueryParams {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  XCTAssertThrows([[ref queryLimitedToFirst:100] queryLimitedToFirst:100]);
  XCTAssertThrows([[ref queryLimitedToFirst:100] queryLimitedToLast:100]);
  XCTAssertThrows([[ref queryLimitedToLast:100] queryLimitedToFirst:100]);
  XCTAssertThrows([[ref queryLimitedToLast:100] queryLimitedToLast:100]);
  XCTAssertThrows([[ref queryOrderedByPriority] queryOrderedByPriority]);
  XCTAssertThrows([[ref queryOrderedByPriority] queryOrderedByKey]);
  XCTAssertThrows([[ref queryOrderedByPriority] queryOrderedByChild:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByPriority] queryOrderedByValue]);
  XCTAssertThrows([[ref queryOrderedByKey] queryOrderedByPriority]);
  XCTAssertThrows([[ref queryOrderedByKey] queryOrderedByKey]);
  XCTAssertThrows([[ref queryOrderedByKey] queryOrderedByChild:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByKey] queryOrderedByValue]);
  XCTAssertThrows([[ref queryOrderedByChild:@"foo"] queryOrderedByPriority]);
  XCTAssertThrows([[ref queryOrderedByChild:@"foo"] queryOrderedByKey]);
  XCTAssertThrows([[ref queryOrderedByChild:@"foo"] queryOrderedByChild:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByChild:@"foo"] queryOrderedByValue]);
  XCTAssertThrows([[ref queryOrderedByValue] queryOrderedByPriority]);
  XCTAssertThrows([[ref queryOrderedByValue] queryOrderedByKey]);
  XCTAssertThrows([[ref queryOrderedByValue] queryOrderedByChild:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByValue] queryOrderedByValue]);
  XCTAssertThrows([[ref queryStartingAtValue:@"foo"] queryStartingAtValue:@"foo"]);
  XCTAssertThrows([[ref queryStartingAtValue:@"foo"] queryEqualToValue:@"foo"]);
  XCTAssertThrows([[ref queryEndingAtValue:@"foo"] queryEndingAtValue:@"foo"]);
  XCTAssertThrows([[ref queryEndingAtValue:@"foo"] queryEqualToValue:@"foo"]);
  XCTAssertThrows([[ref queryEqualToValue:@"foo"] queryStartingAtValue:@"foo"]);
  XCTAssertThrows([[ref queryEqualToValue:@"foo"] queryEndingAtValue:@"foo"]);
  XCTAssertThrows([[ref queryEqualToValue:@"foo"] queryEqualToValue:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByKey] queryStartingAtValue:@"foo" childKey:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByKey] queryEndingAtValue:@"foo" childKey:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByKey] queryEqualToValue:@"foo" childKey:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByKey] queryStartingAtValue:@1 childKey:@"foo"]);
  XCTAssertThrows([[ref queryOrderedByKey] queryStartingAtValue:@YES]);
  XCTAssertThrows([[ref queryOrderedByKey] queryEndingAtValue:@1]);
  XCTAssertThrows([[ref queryOrderedByKey] queryEndingAtValue:@YES]);
  XCTAssertThrows([[ref queryOrderedByKey] queryStartingAtValue:nil]);
  XCTAssertThrows([[ref queryOrderedByKey] queryEndingAtValue:nil]);
  XCTAssertThrows([[ref queryOrderedByKey] queryEqualToValue:nil]);
  XCTAssertThrows([[ref queryStartingAtValue:@"foo" childKey:@"foo"] queryOrderedByKey]);
  XCTAssertThrows([[ref queryEndingAtValue:@"foo" childKey:@"foo"] queryOrderedByKey]);
  XCTAssertThrows([[ref queryEqualToValue:@"foo" childKey:@"foo"] queryOrderedByKey]);
  XCTAssertThrows([[ref queryStartingAtValue:@1] queryOrderedByKey]);
  XCTAssertThrows([[ref queryStartingAtValue:@YES] queryOrderedByKey]);
  XCTAssertThrows([[ref queryEndingAtValue:@1] queryOrderedByKey]);
  XCTAssertThrows([[ref queryEndingAtValue:@YES] queryOrderedByKey]);
  XCTAssertThrows([ref queryStartingAtValue:@[]]);
  XCTAssertThrows([ref queryStartingAtValue:@{}]);
  XCTAssertThrows([ref queryEndingAtValue:@[]]);
  XCTAssertThrows([ref queryEndingAtValue:@{}]);
  XCTAssertThrows([ref queryEqualToValue:@[]]);
  XCTAssertThrows([ref queryEqualToValue:@{}]);

  XCTAssertThrows([[ref queryOrderedByKey] queryOrderedByPriority],
                  @"Cannot call orderBy multiple times");
  XCTAssertThrows([[ref queryOrderedByChild:@"foo"] queryOrderedByPriority],
                  @"Cannot call orderBy multiple times");
  XCTAssertThrows([[ref queryOrderedByKey] queryOrderedByKey],
                  @"Cannot call orderBy multiple times");
  XCTAssertThrows([[ref queryOrderedByChild:@"foo"] queryOrderedByKey],
                  @"Cannot call orderBy multiple times");
  XCTAssertThrows([[ref queryOrderedByKey] queryOrderedByChild:@"foo"],
                  @"Cannot call orderBy multiple times");
  XCTAssertThrows([[ref queryOrderedByChild:@"foo"] queryOrderedByChild:@"foo"],
                  @"Cannot call orderBy multiple times");

  XCTAssertThrows([[ref queryOrderedByKey] queryStartingAtValue:@"a" childKey:@"b"],
                  @"Cannot specify starting child name when ordering by key.");
  XCTAssertThrows([[ref queryOrderedByKey] queryEndingAtValue:@"a" childKey:@"b"],
                  @"Cannot specify ending child name when ordering by key.");
  XCTAssertThrows([[ref queryOrderedByKey] queryEqualToValue:@"a" childKey:@"b"],
                  @"Cannot specify equalTo child name when ordering by key.");

  XCTAssertThrows([[ref queryOrderedByPriority] queryStartingAtValue:@YES],
                  @"Can't pass booleans as start/end when using priority index.");
  XCTAssertThrows([[ref queryOrderedByPriority] queryEndingAtValue:@NO],
                  @"Can't pass booleans as start/end when using priority index.");
  XCTAssertThrows([[ref queryOrderedByPriority] queryEqualToValue:@YES],
                  @"Can't pass booleans as start/end when using priority index.");
}

- (void)testLimitRanges {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  XCTAssertThrows([ref queryLimitedToLast:0], @"Can't pass zero as limit");
  XCTAssertThrows([ref queryLimitedToFirst:0], @"Can't pass zero as limit");
  XCTAssertThrows([ref queryLimitedToLast:0], @"Can't pass zero as limit");
  uint64_t MAX_ALLOWED_VALUE = (uint64_t)(1l << 31) - 1;
  [ref queryLimitedToFirst:(NSUInteger)MAX_ALLOWED_VALUE];
  [ref queryLimitedToLast:(NSUInteger)MAX_ALLOWED_VALUE];
  XCTAssertThrows([ref queryLimitedToFirst:(NSUInteger)(MAX_ALLOWED_VALUE + 1)],
                  @"Can't pass limits that don't fit into 32 bit signed integer range");
  XCTAssertThrows([ref queryLimitedToLast:(NSUInteger)(MAX_ALLOWED_VALUE + 1)],
                  @"Can't pass limits that don't fit into 32 bit signed integer range");
}

- (void)testInvalidKeys {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  NSArray* badKeys = @[
    @".test", @"test.", @"fo$o", @"[what", @"ever]", @"ha#sh", @"/thing", @"th/ing", @"thing/"
  ];

  for (NSString* badKey in badKeys) {
    XCTAssertThrows([[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:badKey],
                    @"Setting bad key");
    XCTAssertThrows([[ref queryOrderedByPriority] queryEndingAtValue:nil childKey:badKey],
                    @"Setting bad key");
  }
}

- (void)testOffCanBeCalledOnDefault {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL called = NO;
  FIRDatabaseQuery* query = [ref queryLimitedToLast:5];
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  if (called) {
                    XCTFail(@"Should not be called twice");
                  } else {
                    called = YES;
                  }
                }];

  [ref setValue:@{@"a" : @5, @"b" : @6}];

  [self waitUntil:^BOOL {
    return called;
  }];

  called = NO;

  [ref removeAllObservers];

  __block BOOL complete = NO;
  [ref setValue:@{@"a" : @6, @"b" : @7}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        complete = YES;
      }];

  [self waitUntil:^BOOL {
    return complete;
  }];

  XCTAssertFalse(called, @"Should not have been called again");
}

- (void)testOffCanBeCalledOnHandle {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL called = NO;
  FIRDatabaseQuery* query = [ref queryLimitedToLast:5];
  FIRDatabaseHandle handle = [query observeEventType:FIRDataEventTypeValue
                                           withBlock:^(FIRDataSnapshot* snapshot) {
                                             if (called) {
                                               XCTFail(@"Should not be called twice");
                                             } else {
                                               called = YES;
                                             }
                                           }];

  [ref setValue:@{@"a" : @5, @"b" : @6}];

  [self waitUntil:^BOOL {
    return called;
  }];

  called = NO;

  [ref removeObserverWithHandle:handle];

  __block BOOL complete = NO;
  [ref setValue:@{@"a" : @6, @"b" : @7}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        complete = YES;
      }];

  [self waitUntil:^BOOL {
    return complete;
  }];

  XCTAssertFalse(called, @"Should not have been called again");
}

- (void)testOffCanBeCalledOnSpecificQuery {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL called = NO;
  FIRDatabaseQuery* query = [ref queryLimitedToLast:5];
  FIRDatabaseHandle handle = [query observeEventType:FIRDataEventTypeValue
                                           withBlock:^(FIRDataSnapshot* snapshot) {
                                             if (called) {
                                               XCTFail(@"Should not be called twice");
                                             } else {
                                               called = YES;
                                             }
                                           }];

  [ref setValue:@{@"a" : @5, @"b" : @6}];

  [self waitUntil:^BOOL {
    return called;
  }];

  called = NO;

  [query removeObserverWithHandle:handle];

  __block BOOL complete = NO;
  [ref setValue:@{@"a" : @6, @"b" : @7}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        complete = YES;
      }];

  [self waitUntil:^BOOL {
    return complete;
  }];

  XCTAssertFalse(called, @"Should not have been called again");
}

- (void)testOffCanBeCalledOnMultipleQueries {
  FIRDatabaseQuery* query = [[FTestHelpers getRandomNode] queryLimitedToFirst:10];
  FIRDatabaseHandle handle1 = [query observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot* snapshot){
                                            }];
  FIRDatabaseHandle handle2 = [query observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot* snapshot){
                                            }];
  [query removeObserverWithHandle:handle1];
  [query removeObserverWithHandle:handle2];
}

- (void)testOffCanBeCalledWithoutHandle {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL called1 = NO;
  __block BOOL called2 = NO;
  FIRDatabaseQuery* query = [ref queryLimitedToLast:5];
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot* snapshot) {
                called1 = YES;
              }];
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  called2 = YES;
                }];

  [ref setValue:@{@"a" : @5, @"b" : @6}];

  [self waitUntil:^BOOL {
    return called1 && called2;
  }];

  called1 = NO;
  called2 = NO;

  [ref removeAllObservers];

  __block BOOL complete = NO;
  [ref setValue:@{@"a" : @6, @"b" : @7}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        complete = YES;
      }];

  [self waitUntil:^BOOL {
    return complete;
  }];

  XCTAssertFalse(called1 || called2, @"Should not have called either callback");
}

- (void)testEnsureOnly5ItemsAreKept {
  __block FIRDataSnapshot* snap = nil;
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  FIRDatabaseQuery* query = [ref queryLimitedToLast:5];
  __block int count = 0;
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  snap = snapshot;
                  count++;
                }];

  [ref setValue:nil];
  for (int i = 0; i < 10; ++i) {
    [[ref childByAutoId] setValue:[NSNumber numberWithInt:i]];
  }

  [self waitUntil:^BOOL {
    // The initial set triggers the callback, so we need to wait for 11 events
    return count == 11;
  }];

  count = 5;
  for (FIRDataSnapshot* snapshot in snap.children) {
    NSNumber* num = [snapshot value];
    NSNumber* current = [NSNumber numberWithInt:count];
    XCTAssertTrue([num isEqualToNumber:current], @"Expect children in order");
    count++;
  }

  XCTAssertTrue(count == 10, @"Expected 5 children");
}

- (void)testOnlyLast5SentFromServer {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block int count = 0;

  [ref setValue:nil];

  for (int i = 0; i < 10; ++i) {
    [[ref childByAutoId] setValue:[NSNumber numberWithInt:i]
              withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
                count++;
              }];
  }

  [self waitUntil:^BOOL {
    return count == 10;
  }];

  FIRDatabaseQuery* query = [ref queryLimitedToLast:5];
  count = 5;
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  for (FIRDataSnapshot* child in snapshot.children) {
                    NSNumber* num = [child value];
                    NSNumber* current = [NSNumber numberWithInt:count];
                    XCTAssertTrue([num isEqualToNumber:current], @"Expect children to be in order");
                    count++;
                  }
                }];

  [self waitUntil:^BOOL {
    return count == 10;
  }];
}

- (void)testVariousLimits {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  [expectations addQuery:[ref queryLimitedToLast:1] withExpectation:@{@"c" : @3}];
  [expectations
             addQuery:[[[ref queryOrderedByPriority] queryEndingAtValue:nil] queryLimitedToLast:1]
      withExpectation:@{@"c" : @3}];
  [expectations
             addQuery:[[[ref queryOrderedByPriority] queryEndingAtValue:nil] queryLimitedToLast:2]
      withExpectation:@{@"b" : @2, @"c" : @3}];
  [expectations
             addQuery:[[[ref queryOrderedByPriority] queryEndingAtValue:nil] queryLimitedToLast:3]
      withExpectation:@{@"a" : @1, @"b" : @2, @"c" : @3}];
  [expectations
             addQuery:[[[ref queryOrderedByPriority] queryEndingAtValue:nil] queryLimitedToLast:4]
      withExpectation:@{@"a" : @1, @"b" : @2, @"c" : @3}];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [expectations validate];
}

- (void)testSetLimitsWithStartAt {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:nil]
                             queryLimitedToFirst:1]
         withExpectation:@{@"a" : @1}];
  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"c"]
                             queryLimitedToFirst:1]
         withExpectation:@{@"c" : @3}];
  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"b"]
                             queryLimitedToFirst:1]
         withExpectation:@{@"b" : @2}];
  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"b"]
                             queryLimitedToFirst:2]
         withExpectation:@{@"b" : @2, @"c" : @3}];
  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"b"]
                             queryLimitedToFirst:3]
         withExpectation:@{@"b" : @2, @"c" : @3}];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  [expectations validate];
}

- (void)testLimitsAndStartAtWithServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:nil]
                             queryLimitedToFirst:1]
         withExpectation:@{@"a" : @1}];

  /*params = [[FQueryParams alloc] init];
  params = [params setStartPriority:nil andName:@"c"];
  params = [params limitTo:1];
  [expectations addQuery:[ref queryWithParams:params] withExpectation:@{@"c": @3}];

  params = [[FQueryParams alloc] init];
  params = [params setStartPriority:nil andName:@"b"];
  params = [params limitTo:1];
  [expectations addQuery:[ref queryWithParams:params] withExpectation:@{@"b": @2}];

  params = [[FQueryParams alloc] init];
  params = [params setStartPriority:nil andName:@"b"];
  params = [params limitTo:2];
  [expectations addQuery:[ref queryWithParams:params] withExpectation:@{@"b": @2, @"c": @3}];

  params = [[FQueryParams alloc] init];
  params = [params setStartPriority:nil andName:@"b"];
  params = [params limitTo:3];
  [expectations addQuery:[ref queryWithParams:params] withExpectation:@{@"b": @2, @"c": @3}];*/

  [self waitUntil:^BOOL {
    return expectations.isReady;
  }];
  [expectations validate];
  [ref removeAllObservers];
}

- (void)testChildEventsAreFiredWhenLimitIsHit {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [[ref queryLimitedToLast:2] observeEventType:FIRDataEventTypeChildAdded
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       [added addObject:[snapshot key]];
                                     }];
  [[ref queryLimitedToLast:2] observeEventType:FIRDataEventTypeChildRemoved
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       [removed addObject:[snapshot key]];
                                     }];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"b", @"c" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have two items");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"d"] setValue:@4
         withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
           ready = YES;
         }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[ @"b" ];
  XCTAssertTrue([removed isEqualToArray:expected], @"Expected to remove b");
  expected = @[ @"d" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Expected to add d");
  [ref removeAllObservers];
}

- (void)testChildEventsAreFiredWhenLimitIsHitWithServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  FIRDatabaseQuery* query = [ref queryLimitedToLast:2];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  [self waitUntil:^BOOL {
    return [added count] == 2;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"b", @"c" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have two items");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"d"] setValue:@4
         withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
           ready = YES;
         }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[ @"b" ];
  XCTAssertTrue([removed isEqualToArray:expected], @"Expected to remove b");
  expected = @[ @"d" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Expected to add d");
  [ref removeAllObservers];
}

- (void)testChildEventsAreFiredWhenLimitIsHitWithStart {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"a"] queryLimitedToFirst:2];

  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"a", @"b" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have two items");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"aa"] setValue:@4
          withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
            ready = YES;
          }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[ @"b" ];
  XCTAssertTrue([removed isEqualToArray:expected], @"Expected to remove b");
  expected = @[ @"aa" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Expected to add aa");
  [ref removeAllObservers];
}

- (void)testChildEventsAreFiredWhenLimitIsHitWithStartAndServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"a"] queryLimitedToFirst:2];
  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  [self waitUntil:^BOOL {
    return [added count] == 2;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"a", @"b" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have two items");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"aa"] setValue:@4
          withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
            ready = YES;
          }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[ @"b" ];
  XCTAssertTrue([removed isEqualToArray:expected], @"Expected to remove b");
  expected = @[ @"aa" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Expected to add aa");
  [ref removeAllObservers];
}

- (void)testStartAndLimitWithIncompleteWindow {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"a"] queryLimitedToFirst:2];
  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  __block BOOL ready = NO;
  [ref setValue:@{@"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready && [added count] >= 1;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"c" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have one item");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"b"] setValue:@4
         withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
           ready = YES;
         }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([removed count] == 0, @"Expected to remove nothing");
  expected = @[ @"b" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Expected to add b");
  [ref removeAllObservers];
}

- (void)testStartAndLimitWithIncompleteWindowAndServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setValue:@{@"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"a"] queryLimitedToFirst:2];

  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  [self waitUntil:^BOOL {
    return [added count] == 1;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"c" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have one item");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"b"] setValue:@4
         withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
           ready = YES;
         }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([removed count] == 0, @"Expected to remove nothing");
  expected = @[ @"b" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Expected to add b");
  [ref removeAllObservers];
}

- (void)testChildEventsFiredWhenItemDeleted {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  FIRDatabaseQuery* query = [ref queryLimitedToLast:2];

  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready && [added count] >= 1;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"b", @"c" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have one item");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"b"] removeValueWithCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
    ready = YES;
  }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[ @"b" ];
  XCTAssertTrue([removed isEqualToArray:expected], @"Expected to remove b");
  expected = @[ @"a" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Expected to add a");
  [ref removeAllObservers];
}

- (void)testChildEventsAreFiredWhenItemDeletedAtServer {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNodeWithoutPersistence];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  FIRDatabaseQuery* query = [ref queryLimitedToLast:2];

  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  [self waitUntil:^BOOL {
    return [added count] == 2;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"b", @"c" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have two items");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"b"] removeValueWithCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
    ready = YES;
  }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertEqualObjects(removed, (@[ @"b" ]), @"Expected to remove b");
  XCTAssertEqualObjects(added, (@[ @"a" ]), @"Expected to add a");
  [ref removeAllObservers];
}

- (void)testRemoveFiredWhenItemDeleted {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  FIRDatabaseQuery* query = [ref queryLimitedToLast:2];
  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  __block BOOL ready = NO;
  [ref setValue:@{@"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready && [added count] >= 1;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"b", @"c" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have one item");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"b"] removeValueWithCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
    ready = YES;
  }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[ @"b" ];
  XCTAssertTrue([removed isEqualToArray:expected], @"Expected to remove b");
  XCTAssertTrue([added count] == 0, @"Expected to add nothing");
  [ref removeAllObservers];
}

- (void)testRemoveFiredWhenItemDeletedAtServer {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setValue:@{@"b" : @2, @"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  FIRDatabaseQuery* query = [ref queryLimitedToLast:2];

  NSMutableArray* added = [[NSMutableArray alloc] init];
  NSMutableArray* removed = [[NSMutableArray alloc] init];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [added addObject:[snapshot key]];
                }];
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  [removed addObject:[snapshot key]];
                }];

  [self waitUntil:^BOOL {
    return [added count] == 2;
  }];

  XCTAssertTrue([removed count] == 0, @"Nothing should be removed from our window");
  NSArray* expected = @[ @"b", @"c" ];
  XCTAssertTrue([added isEqualToArray:expected], @"Should have two items");

  [added removeAllObjects];
  ready = NO;
  [[ref child:@"b"] removeValueWithCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
    ready = YES;
  }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[ @"b" ];
  XCTAssertTrue([removed isEqualToArray:expected], @"Expected to remove b");
  XCTAssertTrue([added count] == 0, @"Expected to add nothing");
  [ref removeAllObservers];
}

- (void)testStartAtPriorityAndEndAtPriorityWork {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:@"w"]
                             queryEndingAtValue:@"y"]
         withExpectation:@{@"b" : @2, @"c" : @3, @"d" : @4}];
  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:@"w"]
                             queryEndingAtValue:@"w"]
         withExpectation:@{@"d" : @4}];

  __block id nullSnap = @"dummy";
  [[[[ref queryOrderedByPriority] queryStartingAtValue:@"a"] queryEndingAtValue:@"c"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               nullSnap = [snapshot value];
             }];

  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @"z"},
    @"b" : @{@".value" : @2, @".priority" : @"y"},
    @"c" : @{@".value" : @3, @".priority" : @"x"},
    @"d" : @{@".value" : @4, @".priority" : @"w"}
  }];

  WAIT_FOR(expectations.isReady && [nullSnap isEqual:[NSNull null]]);

  [expectations validate];
}

- (void)testStartAtPriorityAndEndAtPriorityWorkWithServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @"z"},
    @"b" : @{@".value" : @2, @".priority" : @"y"},
    @"c" : @{@".value" : @3, @".priority" : @"x"},
    @"d" : @{@".value" : @4, @".priority" : @"w"}
  }
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  WAIT_FOR(ready);

  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:@"w"]
                             queryEndingAtValue:@"y"]
         withExpectation:@{@"b" : @2, @"c" : @3, @"d" : @4}];
  [expectations addQuery:[[[ref queryOrderedByPriority] queryStartingAtValue:@"w"]
                             queryEndingAtValue:@"w"]
         withExpectation:@{@"d" : @4}];

  __block id nullSnap = @"dummy";
  [[[[ref queryOrderedByPriority] queryStartingAtValue:@"a"] queryEndingAtValue:@"c"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               nullSnap = [snapshot value];
             }];

  WAIT_FOR(expectations.isReady && [nullSnap isEqual:[NSNull null]]);

  [expectations validate];
}

- (void)testStartAtAndEndAtPriorityAndNameWork {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  FIRDatabaseQuery* query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1 childKey:@"a"]
      queryEndingAtValue:@2
                childKey:@"d"];
  [expectations addQuery:query withExpectation:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}];

  query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1
                                                     childKey:@"b"] queryEndingAtValue:@2
                                                                              childKey:@"c"];
  [expectations addQuery:query withExpectation:@{@"b" : @2, @"c" : @3}];

  query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1
                                                     childKey:@"c"] queryEndingAtValue:@2];
  [expectations addQuery:query withExpectation:@{@"c" : @3, @"d" : @4}];

  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @1},
    @"b" : @{@".value" : @2, @".priority" : @1},
    @"c" : @{@".value" : @3, @".priority" : @2},
    @"d" : @{@".value" : @4, @".priority" : @2}
  }];

  WAIT_FOR(expectations.isReady);

  [expectations validate];
}

- (void)testStartAtAndEndAtPriorityAndNameWorkWithServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block BOOL ready = NO;
  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @1},
    @"b" : @{@".value" : @2, @".priority" : @1},
    @"c" : @{@".value" : @3, @".priority" : @2},
    @"d" : @{@".value" : @4, @".priority" : @2}
  }
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  WAIT_FOR(ready);

  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  FIRDatabaseQuery* query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1 childKey:@"a"]
      queryEndingAtValue:@2
                childKey:@"d"];
  [expectations addQuery:query withExpectation:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}];

  query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1
                                                     childKey:@"b"] queryEndingAtValue:@2
                                                                              childKey:@"c"];
  [expectations addQuery:query withExpectation:@{@"b" : @2, @"c" : @3}];

  query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1
                                                     childKey:@"c"] queryEndingAtValue:@2];
  [expectations addQuery:query withExpectation:@{@"c" : @3, @"d" : @4}];

  WAIT_FOR(expectations.isReady);

  [expectations validate];
}

- (void)testStartAtAndEndAtPriorityAndNameWork2 {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  FIRDatabaseQuery* query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1 childKey:@"c"]
      queryEndingAtValue:@2
                childKey:@"b"];
  [expectations addQuery:query withExpectation:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}];

  query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1
                                                     childKey:@"d"] queryEndingAtValue:@2
                                                                              childKey:@"a"];
  [expectations addQuery:query withExpectation:@{@"d" : @4, @"a" : @1}];

  query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1
                                                     childKey:@"e"] queryEndingAtValue:@2];
  [expectations addQuery:query withExpectation:@{@"a" : @1, @"b" : @2}];

  [ref setValue:@{
    @"c" : @{@".value" : @3, @".priority" : @1},
    @"d" : @{@".value" : @4, @".priority" : @1},
    @"a" : @{@".value" : @1, @".priority" : @2},
    @"b" : @{@".value" : @2, @".priority" : @2}
  }];

  WAIT_FOR(expectations.isReady);

  [expectations validate];
}

- (void)testStartAtAndEndAtPriorityAndNameWorkWithServerData2 {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block BOOL ready = NO;
  [ref setValue:@{
    @"c" : @{@".value" : @3, @".priority" : @1},
    @"d" : @{@".value" : @4, @".priority" : @1},
    @"a" : @{@".value" : @1, @".priority" : @2},
    @"b" : @{@".value" : @2, @".priority" : @2}
  }
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  WAIT_FOR(ready);

  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  FIRDatabaseQuery* query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1 childKey:@"c"]
      queryEndingAtValue:@2
                childKey:@"b"];
  [expectations addQuery:query withExpectation:@{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4}];

  query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1
                                                     childKey:@"d"] queryEndingAtValue:@2
                                                                              childKey:@"a"];
  [expectations addQuery:query withExpectation:@{@"d" : @4, @"a" : @1}];

  query = [[[ref queryOrderedByPriority] queryStartingAtValue:@1
                                                     childKey:@"e"] queryEndingAtValue:@2];
  [expectations addQuery:query withExpectation:@{@"a" : @1, @"b" : @2}];

  WAIT_FOR(expectations.isReady);

  [expectations validate];
}

- (void)testEqualToPriorityWorks {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  [expectations addQuery:[[ref queryOrderedByPriority] queryEqualToValue:@"w"]
         withExpectation:@{@"d" : @4}];

  __block id nullSnap = @"dummy";
  [[[ref queryOrderedByPriority] queryEqualToValue:@"c"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               nullSnap = [snapshot value];
             }];

  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @"z"},
    @"b" : @{@".value" : @2, @".priority" : @"y"},
    @"c" : @{@".value" : @3, @".priority" : @"x"},
    @"d" : @{@".value" : @4, @".priority" : @"w"}
  }];

  WAIT_FOR(expectations.isReady && [nullSnap isEqual:[NSNull null]]);

  [expectations validate];
}

- (void)testEqualToPriorityWorksWithServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @"z"},
    @"b" : @{@".value" : @2, @".priority" : @"y"},
    @"c" : @{@".value" : @3, @".priority" : @"x"},
    @"d" : @{@".value" : @4, @".priority" : @"w"}
  }
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  WAIT_FOR(ready);

  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  [expectations addQuery:[[ref queryOrderedByPriority] queryEqualToValue:@"w"]
         withExpectation:@{@"d" : @4}];

  __block id nullSnap = @"dummy";
  [[[ref queryOrderedByPriority] queryEqualToValue:@"c"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               nullSnap = [snapshot value];
             }];

  WAIT_FOR(expectations.isReady && [nullSnap isEqual:[NSNull null]]);

  [expectations validate];
}

- (void)testEqualToPriorityAndNameWorks {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  FIRDatabaseQuery* query = [[ref queryOrderedByPriority] queryEqualToValue:@1 childKey:@"a"];
  [expectations addQuery:query withExpectation:@{@"a" : @1}];

  __block id nullSnap = @"dummy";
  [[[ref queryOrderedByPriority] queryEqualToValue:@"1" childKey:@"z"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               nullSnap = [snapshot value];
             }];

  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @1},
    @"b" : @{@".value" : @2, @".priority" : @1},
    @"c" : @{@".value" : @3, @".priority" : @2},
    @"d" : @{@".value" : @4, @".priority" : @2}
  }];

  WAIT_FOR(expectations.isReady && [nullSnap isEqual:[NSNull null]]);

  [expectations validate];
}

- (void)testEqualToPriorityAndNameWorksWithServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block BOOL ready = NO;
  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @1},
    @"b" : @{@".value" : @2, @".priority" : @1},
    @"c" : @{@".value" : @3, @".priority" : @2},
    @"d" : @{@".value" : @4, @".priority" : @2}
  }
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  WAIT_FOR(ready);

  FTestExpectations* expectations = [[FTestExpectations alloc] initFrom:self];

  FIRDatabaseQuery* query = [[ref queryOrderedByPriority] queryEqualToValue:@1 childKey:@"a"];
  [expectations addQuery:query withExpectation:@{@"a" : @1}];

  __block id nullSnap = @"dummy";
  [[[ref queryOrderedByPriority] queryEqualToValue:@"1" childKey:@"z"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               nullSnap = [snapshot value];
             }];

  WAIT_FOR(expectations.isReady && [nullSnap isEqual:[NSNull null]]);

  [expectations validate];
}

- (void)testPrevNameWorks {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  NSMutableArray* added = [[NSMutableArray alloc] init];

  [[ref queryLimitedToLast:2] observeEventType:FIRDataEventTypeChildAdded
                andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot* snapshot, NSString* prevName) {
                  [added addObject:snapshot.key];
                  if (prevName) {
                    [added addObject:prevName];
                  } else {
                    [added addObject:@"null"];
                  }
                }];

  [[ref child:@"a"] setValue:@1];
  [self waitUntil:^BOOL {
    NSArray* expected = @[ @"a", @"null" ];
    return [added isEqualToArray:expected];
  }];

  [added removeAllObjects];

  [[ref child:@"c"] setValue:@3];
  [self waitUntil:^BOOL {
    NSArray* expected = @[ @"c", @"a" ];
    return [added isEqualToArray:expected];
  }];

  [added removeAllObjects];

  [[ref child:@"b"] setValue:@2];
  [self waitUntil:^BOOL {
    NSArray* expected = @[ @"b", @"null" ];
    return [added isEqualToArray:expected];
  }];

  [added removeAllObjects];

  [[ref child:@"d"] setValue:@3];
  [self waitUntil:^BOOL {
    NSArray* expected = @[ @"d", @"c" ];
    return [added isEqualToArray:expected];
  }];
}

// Dropping some of the server data tests here, around prevName. They don't really test anything
// new, and mostly don't even test server data

- (void)testPrevNameWorksWithMoves {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  NSMutableArray* moved = [[NSMutableArray alloc] init];

  [[ref queryLimitedToLast:2] observeEventType:FIRDataEventTypeChildMoved
                andPreviousSiblingKeyWithBlock:^(FIRDataSnapshot* snapshot, NSString* prevName) {
                  [moved addObject:snapshot.key];
                  if (prevName) {
                    [moved addObject:prevName];
                  } else {
                    [moved addObject:@"null"];
                  }
                }];

  [ref setValue:@{
    @"a" : @{@".value" : @"a", @".priority" : @10},
    @"b" : @{@".value" : @"b", @".priority" : @20},
    @"c" : @{@".value" : @"c", @".priority" : @30},
    @"d" : @{@".value" : @"d", @".priority" : @40}
  }];

  __block BOOL ready = NO;
  [[ref child:@"c"] setPriority:@50
            withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
              ready = YES;
            }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSArray* expected = @[ @"c", @"d" ];
  XCTAssertTrue([moved isEqualToArray:expected], @"Expected changed node and prevChild");

  [moved removeAllObjects];
  ready = NO;
  [[ref child:@"c"] setPriority:@35
            withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
              ready = YES;
            }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[ @"c", @"null" ];
  XCTAssertTrue([moved isEqualToArray:expected], @"Expected changed node and prevChild");

  [moved removeAllObjects];
  ready = NO;
  [[ref child:@"b"] setPriority:@33
            withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
              ready = YES;
            }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  expected = @[];
  XCTAssertTrue([moved isEqualToArray:expected],
                @"Expected changed node and prevChild to be empty");
}

- (void)testLocalEvents {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  NSMutableArray* events = [[NSMutableArray alloc] init];
  [[ref queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeChildAdded
             withBlock:^(FIRDataSnapshot* snapshot) {
               NSString* eventString = [NSString stringWithFormat:@"%@ added", [snapshot value]];
               [events addObject:eventString];
             }];

  [[ref queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeChildRemoved
             withBlock:^(FIRDataSnapshot* snapshot) {
               NSString* eventString = [NSString stringWithFormat:@"%@ removed", [snapshot value]];
               [events addObject:eventString];
             }];

  __block BOOL ready = NO;
  for (int i = 0; i < 5; ++i) {
    [[ref childByAutoId] setValue:[NSNumber numberWithInt:i]
              withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
                if (i == 4) {
                  ready = YES;
                }
              }];
  }

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSArray* expected = @[
    @"0 added", @"1 added", @"0 removed", @"2 added", @"1 removed", @"3 added", @"2 removed",
    @"4 added"
  ];
  XCTAssertTrue([events isEqualToArray:expected], @"Expecting window to stay at two nodes");
}

- (void)testRemoteEvents {
  FTupleFirebase* pair = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writer = pair.one;
  FIRDatabaseReference* reader = pair.two;

  NSMutableArray* events = [[NSMutableArray alloc] init];

  [[reader queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeChildAdded
             withBlock:^(FIRDataSnapshot* snapshot) {
               NSString* eventString = [NSString stringWithFormat:@"%@ added", [snapshot value]];
               [events addObject:eventString];
             }];

  [[reader queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeChildRemoved
             withBlock:^(FIRDataSnapshot* snapshot) {
               NSString* oldEventString = [NSString stringWithFormat:@"%@ added", [snapshot value]];
               [events removeObject:oldEventString];
             }];

  for (int i = 0; i < 5; ++i) {
    [[writer childByAutoId] setValue:[NSNumber numberWithInt:i]];
  }

  NSArray* expected = @[ @"3 added", @"4 added" ];
  [self waitUntil:^BOOL {
    return [events isEqualToArray:expected];
  }];
}

- (void)testLimitOnEmptyNodeFiresValue {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  [[ref queryLimitedToLast:1] observeEventType:FIRDataEventTypeValue
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       ready = YES;
                                     }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testFilteringToNullPriorities {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  // Note: cannot set nil in a dictionary, just leave out priority
  [ref setValue:@{
    @"a" : @0,
    @"b" : @1,
    @"c" : @{@".priority" : @2, @".value" : @2},
    @"d" : @{@".priority" : @3, @".value" : @3},
    @"e" : @{@".priority" : @"hi", @".value" : @4}
  }];

  __block BOOL ready = NO;
  [[[[ref queryOrderedByPriority] queryStartingAtValue:nil] queryEndingAtValue:nil]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               NSDictionary* expected = @{@"a" : @0, @"b" : @1};
               NSDictionary* val = [snapshot value];
               XCTAssertTrue([val isEqualToDictionary:expected],
                             @"Expected only null priority keys");
               ready = YES;
             }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testNullPrioritiesIncludedInEndAt {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  // Note: cannot set nil in a dictionary, just leave out priority
  [ref setValue:@{
    @"a" : @0,
    @"b" : @1,
    @"c" : @{@".priority" : @2, @".value" : @2},
    @"d" : @{@".priority" : @3, @".value" : @3},
    @"e" : @{@".priority" : @"hi", @".value" : @4}
  }];

  __block BOOL ready = NO;
  [[[ref queryOrderedByPriority] queryEndingAtValue:@2]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               NSDictionary* expected = @{@"a" : @0, @"b" : @1, @"c" : @2};
               NSDictionary* val = [snapshot value];
               XCTAssertTrue([val isEqualToDictionary:expected], @"Expected up to priority 2");
               ready = YES;
             }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (NSSet*)dumpListensForRef:(FIRDatabaseReference*)ref {
  NSMutableSet* dumpPieces = [[NSMutableSet alloc] init];
  NSDictionary* listens = [ref.repo dumpListens];

  FPath* nodePath = ref.path;
  [listens enumerateKeysAndObjectsUsingBlock:^(FQuerySpec* spec, id obj, BOOL* stop) {
    if ([nodePath contains:spec.path]) {
      FPath* relative = [FPath relativePathFrom:nodePath to:spec.path];
      [dumpPieces addObject:[[FQuerySpec alloc] initWithPath:relative params:spec.params]];
    }
  }];

  return dumpPieces;
}

- (NSSet*)expectDefaultListenerAtPath:(FPath*)path {
  return [self expectParams:[FQueryParams defaultInstance] atPath:path];
}

- (NSSet*)expectParamssetValue:(NSSet*)paramsSet atPath:(FPath*)path {
  NSMutableSet* all = [NSMutableSet set];
  [paramsSet enumerateObjectsUsingBlock:^(FQueryParams* params, BOOL* stop) {
    [all addObject:[[FQuerySpec alloc] initWithPath:path params:params]];
  }];
  return all;
}

- (NSSet*)expectParams:(FQueryParams*)params atPath:(FPath*)path {
  return [self expectParamssetValue:[NSSet setWithObject:params] atPath:path];
}

- (void)testDedupesListensOnChild {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block NSSet* listens = [self dumpListensForRef:ref];
  XCTAssertTrue(listens.count == 0, @"No Listens yet");

  [[ref child:@"a"] observeEventType:FIRDataEventTypeValue
                           withBlock:^(FIRDataSnapshot* snapshot){
                           }];
  __block BOOL ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [NSSet setWithObject:[FQuerySpec defaultQueryAtPath:PATH(@"a")]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected child listener");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot* snapshot){
              }];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [NSSet setWithObject:[FQuerySpec defaultQueryAtPath:PATH(@"")]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected parent listener");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [ref removeAllObservers];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [NSSet setWithObject:[FQuerySpec defaultQueryAtPath:PATH(@"a")]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Child listener should be back");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [[ref child:@"a"] removeAllObservers];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    XCTAssertTrue(listens.count == 0, @"No more listeners");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testDedupeListensOnGrandchild {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block NSSet* listens;
  __block BOOL ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    XCTAssertTrue(listens.count == 0, @"No Listens yet");
    ready = YES;
  });
  WAIT_FOR(ready);

  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot* snapshot){
              }];

  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [self expectDefaultListenerAtPath:[FPath empty]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected one listener");
    ready = YES;
  });
  WAIT_FOR(ready);

  [[ref child:@"a/aa"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot* snapshot){
                              }];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [self expectDefaultListenerAtPath:[FPath empty]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected parent listener to override");
    ready = YES;
  });
  WAIT_FOR(ready);

  [ref removeAllObservers];
  [[ref child:@"a/aa"] removeAllObservers];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    XCTAssertTrue(listens.count == 0, @"No more listeners");
    ready = YES;
  });
  WAIT_FOR(ready);
}

- (void)testListenOnGrandparentOfTwoChildren {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block NSSet* listens = [self dumpListensForRef:ref];
  XCTAssertTrue(listens.count == 0, @"No Listens yet");

  [[ref child:@"a/aa"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot* snapshot){
                              }];
  __block BOOL ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [self expectDefaultListenerAtPath:[FPath pathWithString:@"/a/aa"]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected grandchild");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [[ref child:@"a/bb"] observeEventType:FIRDataEventTypeValue
                              withBlock:^(FIRDataSnapshot* snapshot){
                              }];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expecteda = [self expectDefaultListenerAtPath:[FPath pathWithString:@"/a/aa"]];
    NSSet* expectedb = [self expectDefaultListenerAtPath:[FPath pathWithString:@"/a/bb"]];
    NSMutableSet* expected = [NSMutableSet setWithSet:expecteda];
    [expected unionSet:expectedb];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected two grandchildren");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot* snapshot){
              }];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [self expectDefaultListenerAtPath:[FPath empty]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected parent listener to override");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [ref removeAllObservers];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expecteda = [self expectDefaultListenerAtPath:[FPath pathWithString:@"/a/aa"]];
    NSSet* expectedb = [self expectDefaultListenerAtPath:[FPath pathWithString:@"/a/bb"]];
    NSMutableSet* expected = [NSMutableSet setWithSet:expecteda];
    [expected unionSet:expectedb];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected grandchild listeners to return");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [[ref child:@"a/aa"] removeAllObservers];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [self expectDefaultListenerAtPath:[FPath pathWithString:@"/a/bb"]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Expected one listener");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [[ref child:@"a/bb"] removeAllObservers];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    XCTAssertTrue(listens.count == 0, @"No more listeners");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testDedupingMultipleListenQueries {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block NSSet* listens = [self dumpListensForRef:ref];
  XCTAssertTrue(listens.count == 0, @"No Listens yet");

  __block BOOL ready = NO;
  FIRDatabaseQuery* aLim1 = [[ref child:@"a"] queryLimitedToLast:1];
  FIRDatabaseHandle handle1 = [aLim1 observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot* snapshot){
                                            }];
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    FQueryParams* expectedParams = [[FQueryParams alloc] init];
    expectedParams = [expectedParams limitTo:1];
    NSSet* expected = [self expectParams:expectedParams atPath:[FPath pathWithString:@"/a"]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Single query");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  FIRDatabaseQuery* rootLim1 = [ref queryLimitedToLast:1];
  FIRDatabaseHandle handle2 = [rootLim1 observeEventType:FIRDataEventTypeValue
                                               withBlock:^(FIRDataSnapshot* snapshot){
                                               }];
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    FQueryParams* expectedParams = [[FQueryParams alloc] init];
    expectedParams = [expectedParams limitTo:1];
    NSSet* rootExpected = [self expectParams:expectedParams atPath:[FPath empty]];
    NSSet* childExpected = [self expectParams:expectedParams atPath:[FPath pathWithString:@"/a"]];
    NSMutableSet* expected = [NSMutableSet setWithSet:rootExpected];
    [expected unionSet:childExpected];
    XCTAssertTrue([expected isEqualToSet:listens], @"Two queries");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  FIRDatabaseQuery* aLim5 = [[ref child:@"a"] queryLimitedToLast:5];
  FIRDatabaseHandle handle3 = [aLim5 observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot* snapshot){
                                            }];
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    FQueryParams* expectedParams1 = [[FQueryParams alloc] init];
    expectedParams1 = [expectedParams1 limitTo:1];
    NSSet* rootExpected = [self expectParams:expectedParams1 atPath:[FPath empty]];

    FQueryParams* expectedParams2 = [[FQueryParams alloc] init];
    expectedParams2 = [expectedParams2 limitTo:5];
    NSSet* childExpected =
        [self expectParamssetValue:[NSSet setWithObjects:expectedParams1, expectedParams2, nil]
                            atPath:[FPath pathWithString:@"/a"]];
    NSMutableSet* expected = [NSMutableSet setWithSet:childExpected];
    [expected unionSet:rootExpected];
    XCTAssertTrue([expected isEqualToSet:listens], @"Three queries");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [ref removeObserverWithHandle:handle2];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    FQueryParams* expectedParams1 = [[FQueryParams alloc] init];
    expectedParams1 = [expectedParams1 limitTo:1];
    FQueryParams* expectedParams2 = [[FQueryParams alloc] init];
    expectedParams2 = [expectedParams2 limitTo:5];
    NSSet* expected =
        [self expectParamssetValue:[NSSet setWithObjects:expectedParams1, expectedParams2, nil]
                            atPath:[FPath pathWithString:@"/a"]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Two queries");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [aLim1 removeObserverWithHandle:handle1];
  [aLim5 removeObserverWithHandle:handle3];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    XCTAssertTrue(listens.count == 0, @"No more listeners");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testListenOnParentOfQueriedChildren {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  __block NSSet* listens = [self dumpListensForRef:ref];
  XCTAssertTrue(listens.count == 0, @"No Listens yet");

  __block BOOL ready = NO;
  FIRDatabaseQuery* aLim1 = [[ref child:@"a"] queryLimitedToLast:1];
  FIRDatabaseHandle handle1 = [aLim1 observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot* snapshot){
                                            }];
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    FQueryParams* expectedParams = [[FQueryParams alloc] init];
    expectedParams = [expectedParams limitTo:1];
    NSSet* expected = [self expectParams:expectedParams atPath:[FPath pathWithString:@"/a"]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Single query");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  FIRDatabaseQuery* bLim1 = [[ref child:@"b"] queryLimitedToLast:1];
  FIRDatabaseHandle handle2 = [bLim1 observeEventType:FIRDataEventTypeValue
                                            withBlock:^(FIRDataSnapshot* snapshot){
                                            }];
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    FQueryParams* expectedParams = [[FQueryParams alloc] init];
    expectedParams = [expectedParams limitTo:1];
    NSSet* expecteda = [self expectParams:expectedParams atPath:[FPath pathWithString:@"/a"]];
    NSSet* expectedb = [self expectParams:expectedParams atPath:[FPath pathWithString:@"/b"]];
    NSMutableSet* expected = [NSMutableSet setWithSet:expecteda];
    [expected unionSet:expectedb];
    XCTAssertTrue([expected isEqualToSet:listens], @"Two queries");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  FIRDatabaseHandle handle3 = [ref observeEventType:FIRDataEventTypeValue
                                          withBlock:^(FIRDataSnapshot* snapshot){
                                          }];
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [self expectDefaultListenerAtPath:[FPath empty]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Parent should override");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  // remove in slightly random order
  [aLim1 removeObserverWithHandle:handle1];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    NSSet* expected = [self expectDefaultListenerAtPath:[FPath empty]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Parent should override");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  [ref removeObserverWithHandle:handle3];
  ready = NO;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    FQueryParams* expectedParams = [[FQueryParams alloc] init];
    expectedParams = [expectedParams limitTo:1];
    NSSet* expected = [self expectParams:expectedParams atPath:[FPath pathWithString:@"/b"]];
    XCTAssertTrue([expected isEqualToSet:listens], @"Single query");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  [bLim1 removeObserverWithHandle:handle2];
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    listens = [self dumpListensForRef:ref];
    XCTAssertTrue(listens.count == 0, @"No more listeners");
    ready = YES;
  });

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testLimitWithMixOfNullAndNonNullPriorities {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  NSMutableArray* children = [[NSMutableArray alloc] init];

  [[ref queryLimitedToLast:5] observeEventType:FIRDataEventTypeChildAdded
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       [children addObject:[snapshot key]];
                                     }];

  __block BOOL ready = NO;
  NSDictionary* toSet = @{
    @"Vikrum" : @{@".priority" : @1000, @"score" : @1000, @"name" : @"Vikrum"},
    @"Mike" : @{@".priority" : @500, @"score" : @500, @"name" : @"Mike"},
    @"Andrew" : @{@".priority" : @50, @"score" : @50, @"name" : @"Andrew"},
    @"James" : @{@".priority" : @7, @"score" : @7, @"name" : @"James"},
    @"Sally" : @{@".priority" : @-7, @"score" : @-7, @"name" : @"Sally"},
    @"Fred" : @{@"score" : @0, @"name" : @"Fred"}
  };

  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSArray* expected = @[ @"Sally", @"James", @"Andrew", @"Mike", @"Vikrum" ];
  XCTAssertTrue([children isEqualToArray:expected], @"Null priority should be left out");
}

- (void)testLimitWithMixOfNullAndNonNullPrioritiesOnServerData {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  NSDictionary* toSet = @{
    @"Vikrum" : @{@".priority" : @1000, @"score" : @1000, @"name" : @"Vikrum"},
    @"Mike" : @{@".priority" : @500, @"score" : @500, @"name" : @"Mike"},
    @"Andrew" : @{@".priority" : @50, @"score" : @50, @"name" : @"Andrew"},
    @"James" : @{@".priority" : @7, @"score" : @7, @"name" : @"James"},
    @"Sally" : @{@".priority" : @-7, @"score" : @-7, @"name" : @"Sally"},
    @"Fred" : @{@"score" : @0, @"name" : @"Fred"}
  };

  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  __block int count = 0;
  NSMutableArray* children = [[NSMutableArray alloc] init];

  [[ref queryLimitedToLast:5] observeEventType:FIRDataEventTypeChildAdded
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       [children addObject:[snapshot key]];
                                       count++;
                                     }];

  [self waitUntil:^BOOL {
    return count == 5;
  }];

  NSArray* expected = @[ @"Sally", @"James", @"Andrew", @"Mike", @"Vikrum" ];
  XCTAssertTrue([children isEqualToArray:expected], @"Null priority should be left out");
}

// Skipping context tests. Context is not implemented on iOS

/* DISABLING for now, since I'm not 100% sure what the right behavior is.
   Perhaps a merge at /foo should shadow server updates at /foo instead of
   just the modified children?  Not sure.
- (void) testHandleUpdateThatDeletesEntireWindow {
    Firebase* ref = [FTestHelpers getRandomNode];

    NSMutableArray* snaps = [[NSMutableArray alloc] init];

    [[ref queryLimitedToLast:2] observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot
*snapshot) { id val = [snapshot value]; if (val == nil) { [snaps addObject:[NSNull null]]; } else {
            [snaps addObject:val];
        }
    }];

    NSDictionary* toSet = @{
    @"a": @{@".priority": @1, @".value": @1},
    @"b": @{@".priority": @2, @".value": @2},
    @"c": @{@".priority": @3, @".value": @3}
    };

    [ref setValue:toSet];

    __block BOOL ready = NO;
    toSet = @{@"b": [NSNull null], @"c": [NSNull null]};
    [ref updateChildValues:toSet withCompletionBlock:^(NSError* err, Firebase* ref) {
        ready = YES;
    }];

    [self waitUntil:^BOOL{
        return ready;
    }];

    NSArray* expected = @[@{@"b": @2, @"c": @3}, [NSNull null], @{@"a": @1}];
    STAssertTrue([snaps isEqualToArray:expected], @"Expected %@ to equal %@", snaps, expected);
}
*/

- (void)testHandlesAnOutOfViewQueryOnAChild {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block NSDictionary* parent = nil;
  [[ref queryLimitedToLast:1] observeEventType:FIRDataEventTypeValue
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       parent = [snapshot value];
                                     }];

  __block NSNumber* child = nil;
  [[ref child:@"a"] observeEventType:FIRDataEventTypeValue
                           withBlock:^(FIRDataSnapshot* snapshot) {
                             child = [snapshot value];
                           }];

  __block BOOL ready = NO;
  NSDictionary* toSet = @{@"a" : @1, @"b" : @2};
  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSDictionary* parentExpected = @{@"b" : @2};
  NSNumber* childExpected = [NSNumber numberWithInt:1];
  XCTAssertTrue([parent isEqualToDictionary:parentExpected], @"Expected last element");
  XCTAssertTrue([child isEqualToNumber:childExpected], @"Expected value of a");

  ready = NO;
  [ref updateChildValues:@{@"c" : @3}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  parentExpected = @{@"c" : @3};
  XCTAssertTrue([parent isEqualToDictionary:parentExpected], @"Expected last element");
  XCTAssertTrue([child isEqualToNumber:childExpected], @"Expected value of a");
}

- (void)testHandlesAChildQueryGoingOutOfViewOfTheParent {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block NSDictionary* parent = nil;
  [[ref queryLimitedToLast:1] observeEventType:FIRDataEventTypeValue
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       parent = [snapshot value];
                                     }];

  __block NSNumber* child = nil;
  [[ref child:@"a"] observeEventType:FIRDataEventTypeValue
                           withBlock:^(FIRDataSnapshot* snapshot) {
                             child = [snapshot value];
                           }];

  __block BOOL ready = NO;
  NSDictionary* toSet = @{@"a" : @1};
  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  WAIT_FOR(ready);

  NSDictionary* parentExpected = @{@"a" : @1};
  NSNumber* childExpected = [NSNumber numberWithInt:1];
  XCTAssertTrue([parent isEqualToDictionary:parentExpected], @"Expected last element");
  XCTAssertTrue([child isEqualToNumber:childExpected], @"Expected value of a");

  ready = NO;
  [[ref child:@"b"] setValue:@2
         withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
           ready = YES;
         }];

  WAIT_FOR(ready);

  parentExpected = @{@"b" : @2};
  XCTAssertTrue([parent isEqualToDictionary:parentExpected], @"Expected last element");
  XCTAssertTrue([child isEqualToNumber:childExpected], @"Expected value of a");

  ready = NO;
  [[ref child:@"b"] removeValueWithCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
    ready = YES;
  }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  parentExpected = @{@"a" : @1};
  XCTAssertTrue([parent isEqualToDictionary:parentExpected], @"Expected last element");
  XCTAssertTrue([child isEqualToNumber:childExpected], @"Expected value of a");
}

- (void)testHandlesDivergingViews {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block NSDictionary* cVal = nil;
  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryEndingAtValue:nil childKey:@"c"] queryLimitedToLast:1];
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  cVal = [snapshot value];
                }];

  __block NSDictionary* dVal = nil;
  query = [[[ref queryOrderedByPriority] queryEndingAtValue:nil
                                                   childKey:@"d"] queryLimitedToLast:1];
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  dVal = [snapshot value];
                }];

  __block BOOL ready = NO;
  NSDictionary* toSet = @{@"a" : @1, @"b" : @2, @"c" : @3};
  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSDictionary* expected = @{@"c" : @3};
  XCTAssertTrue([cVal isEqualToDictionary:expected], @"should be c");
  XCTAssertTrue([dVal isEqualToDictionary:expected], @"should be c");

  ready = NO;
  [[ref child:@"d"] setValue:@4
         withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
           ready = YES;
         }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([cVal isEqualToDictionary:expected], @"should be c");
  expected = @{@"d" : @4};
  XCTAssertTrue([dVal isEqualToDictionary:expected], @"should be d");
}

- (void)testHandlesRemovingAQueriedElement {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block NSNumber* val = nil;
  [[ref queryLimitedToLast:1] observeEventType:FIRDataEventTypeChildAdded
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       id newVal = [snapshot value];
                                       if (newVal != nil) {
                                         val = [snapshot value];
                                       }
                                     }];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([val isEqualToNumber:@2], @"Expected last element in window");

  ready = NO;
  [[ref child:@"b"] removeValueWithCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
    ready = YES;
  }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([val isEqualToNumber:@1], @"Should now be the next element in the window");
}

- (void)testStartAtAndLimit1Works {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block NSNumber* val = nil;
  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryStartingAtValue:nil] queryLimitedToFirst:1];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  id newVal = [snapshot value];
                  if (newVal != nil) {
                    val = [snapshot value];
                  }
                }];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([val isEqualToNumber:@1], @"Expected first element in window");
}

// See case 1664
- (void)testStartAtAndLimit1AndRemoveFirstChild {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block NSNumber* val = nil;
  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryStartingAtValue:nil] queryLimitedToFirst:1];
  [query observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot* snapshot) {
                  id newVal = [snapshot value];
                  if (newVal != nil) {
                    val = [snapshot value];
                  }
                }];

  __block BOOL ready = NO;
  [ref setValue:@{@"a" : @1, @"b" : @2}
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([val isEqualToNumber:@1], @"Expected first element in window");

  ready = NO;
  [[ref child:@"a"] removeValueWithCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
    ready = YES;
  }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([val isEqualToNumber:@2], @"Expected next element in window");
}

// See case 1169
- (void)testStartAtWithTwoArgumentsWorks {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;
  NSMutableArray* children = [[NSMutableArray alloc] init];

  NSDictionary* toSet = @{
    @"Walker" : @{@"name" : @"Walker", @"score" : @20, @".priority" : @20},
    @"Michael" : @{@"name" : @"Michael", @"score" : @100, @".priority" : @100}
  };

  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryStartingAtValue:@20
                                                 childKey:@"Walker"] queryLimitedToFirst:2];
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  for (FIRDataSnapshot* child in snapshot.children) {
                    [children addObject:child.key];
                  }
                  ready = YES;
                }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSArray* expected = @[ @"Walker", @"Michael" ];
  XCTAssertTrue([children isEqualToArray:expected], @"Expected both children");
}

- (void)testHandlesMultipleQueriesOnSameNode {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;

  NSDictionary* toSet = @{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4, @"e" : @5, @"f" : @6};

  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  __block BOOL called = NO;
  [[ref queryLimitedToLast:2]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               // we got the initial data
               XCTAssertFalse(called,
                              @"This should only get called once, we don't update data after this");
               called = YES;
               ready = YES;
             }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  __block NSDictionary* snap = nil;
  // now do nested once calls
  [[ref queryLimitedToLast:1]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot* snapshot) {
                       [[ref queryLimitedToLast:1]
                           observeSingleEventOfType:FIRDataEventTypeValue
                                          withBlock:^(FIRDataSnapshot* snapshot) {
                                            snap = [snapshot value];
                                            ready = YES;
                                          }];
                     }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSDictionary* expected = @{@"f" : @6};
  XCTAssertTrue([snap isEqualToDictionary:expected], @"Expected the correct data");
}

- (void)testHandlesOnceCalledOnNodeWithDefaultListener {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;

  NSDictionary* toSet = @{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4, @"e" : @5, @"f" : @6};

  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;

  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot* snapshot) {
                // we got the initial data
                ready = YES;
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;

  __block NSNumber* snap = nil;
  [[ref queryLimitedToLast:1] observeSingleEventOfType:FIRDataEventTypeChildAdded
                                             withBlock:^(FIRDataSnapshot* snapshot) {
                                               snap = [snapshot value];
                                               ready = YES;
                                             }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  XCTAssertTrue([snap isEqualToNumber:@6], @"Got once response");
}

- (void)testHandlesOnceCalledOnNodeWithDefaultListenerAndNonCompleteLimit {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL ready = NO;

  NSDictionary* toSet = @{@"a" : @1, @"b" : @2, @"c" : @3};

  [ref setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  // do first listen
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot* snapshot) {
                ready = YES;
              }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;

  __block NSDictionary* snap = nil;
  [[ref queryLimitedToLast:5] observeSingleEventOfType:FIRDataEventTypeValue
                                             withBlock:^(FIRDataSnapshot* snapshot) {
                                               snap = [snapshot value];
                                               ready = YES;
                                             }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  NSDictionary* expected = @{@"a" : @1, @"b" : @2, @"c" : @3};
  XCTAssertTrue([snap isEqualToDictionary:expected], @"Got once response");
}

- (void)testRemoveTriggersRemoteEvents {
  FTupleFirebase* tuple = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writer = tuple.one;
  FIRDatabaseReference* reader = tuple.two;

  __block BOOL ready = NO;

  NSDictionary* toSet = @{@"a" : @"a", @"b" : @"b", @"c" : @"c", @"d" : @"d", @"e" : @"e"};

  [writer setValue:toSet
      withCompletionBlock:^(NSError* err, FIRDatabaseReference* ref) {
        ready = YES;
      }];

  [self waitUntil:^BOOL {
    return ready;
  }];

  ready = NO;
  __block int count = 0;

  [[reader queryLimitedToLast:5]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               count++;
               if (count == 1) {
                 NSDictionary* val = [snapshot value];
                 NSDictionary* expected =
                     @{@"a" : @"a", @"b" : @"b", @"c" : @"c", @"d" : @"d", @"e" : @"e"};
                 XCTAssertTrue([val isEqualToDictionary:expected],
                               @"First callback, expect all the data");
                 [[writer child:@"c"] removeValue];
               } else {
                 XCTAssertTrue(count == 2, @"Should only get called twice");
                 NSDictionary* val = [snapshot value];
                 NSDictionary* expected = @{@"a" : @"a", @"b" : @"b", @"d" : @"d", @"e" : @"e"};
                 XCTAssertTrue([val isEqualToDictionary:expected],
                               @"Second callback, expect all the remaining data");
                 ready = YES;
               }
             }];

  [self waitUntil:^BOOL {
    return ready;
  }];
}

- (void)testEndingAtNameReturnsCorrectChildren {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  NSDictionary* toSet = @{
    @"a" : @"a",
    @"b" : @"b",
    @"c" : @"c",
    @"d" : @"d",
    @"e" : @"e",
    @"f" : @"f",
    @"g" : @"g",
    @"h" : @"h"
  };

  [self waitForCompletionOf:ref setValue:toSet];

  __block NSDictionary* snap = nil;
  __block BOOL done = NO;
  FIRDatabaseQuery* query =
      [[[ref queryOrderedByPriority] queryEndingAtValue:nil childKey:@"f"] queryLimitedToLast:5];
  [query observeEventType:FIRDataEventTypeValue
                withBlock:^(FIRDataSnapshot* snapshot) {
                  snap = [snapshot value];
                  done = YES;
                }];

  [self waitUntil:^BOOL {
    return done;
  }];

  NSDictionary* expected = @{@"b" : @"b", @"c" : @"c", @"d" : @"d", @"e" : @"e", @"f" : @"f"};
  XCTAssertTrue([snap isEqualToDictionary:expected], @"Expected 5 elements, ending at f");
}

- (void)testListenForChildAddedWithLimitEnsureEventsFireProperly {
  FTupleFirebase* refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writer = refs.one;
  FIRDatabaseReference* reader = refs.two;

  __block BOOL done = NO;

  NSDictionary* toSet =
      @{@"a" : @1, @"b" : @"b", @"c" : @{@"deep" : @"path", @"of" : @{@"stuff" : @YES}}};
  [writer setValue:toSet
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];

  WAIT_FOR(done);

  __block int count = 0;
  [[reader queryLimitedToLast:3]
      observeEventType:FIRDataEventTypeChildAdded
             withBlock:^(FIRDataSnapshot* snapshot) {
               count++;
               if (count == 1) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"a"], @"Got first child");
                 XCTAssertTrue([snapshot.value isEqualToNumber:@1], @"Got correct value");
               } else if (count == 2) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"b"], @"Got second child");
                 XCTAssertTrue([snapshot.value isEqualToString:@"b"], @"got correct value");
               } else if (count == 3) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"c"], @"Got third child");
                 NSDictionary* expected = @{@"deep" : @"path", @"of" : @{@"stuff" : @YES}};
                 XCTAssertTrue([snapshot.value isEqualToDictionary:expected], @"Got deep object");
               } else {
                 XCTFail(@"wrong event count");
               }
             }];

  WAIT_FOR(count == 3);
}

#ifdef FLAKY_TEST
- (void)testListenForChildChangedWithLimitEnsureEventsFireProperly {
  FTupleFirebase* refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writer = refs.one;
  FIRDatabaseReference* reader = refs.two;

  __block BOOL done = NO;

  NSDictionary* toSet = @{@"a" : @"something", @"b" : @"we'll", @"c" : @"overwrite"};
  [writer setValue:toSet
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];

  WAIT_FOR(done);

  __block int count = 0;
  [reader
      observeEventType:FIRDataEventTypeChildChanged
             withBlock:^(FIRDataSnapshot* snapshot) {
               count++;
               if (count == 1) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"a"], @"Got first child");
                 XCTAssertTrue([snapshot.value isEqualToNumber:@1], @"Got correct value");
               } else if (count == 2) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"b"], @"Got second child");
                 XCTAssertTrue([snapshot.value isEqualToString:@"b"], @"got correct value");
               } else if (count == 3) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"c"], @"Got third child");
                 NSDictionary* expected = @{@"deep" : @"path", @"of" : @{@"stuff" : @YES}};
                 XCTAssertTrue([snapshot.value isEqualToDictionary:expected], @"Got deep object");
               } else {
                 XCTFail(@"wrong event count");
               }
             }];
  toSet = @{@"a" : @1, @"b" : @"b", @"c" : @{@"deep" : @"path", @"of" : @{@"stuff" : @YES}}};
  [writer setValue:toSet];

  WAIT_FOR(count == 3);
}
#endif

- (void)testListenForChildRemovedWithLimitEnsureEventsFireProperly {
  FTupleFirebase* refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writer = refs.one;
  FIRDatabaseReference* reader = refs.two;

  __block BOOL done = NO;

  NSDictionary* toSet =
      @{@"a" : @1, @"b" : @"b", @"c" : @{@"deep" : @"path", @"of" : @{@"stuff" : @YES}}};
  [writer setValue:toSet
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];

  WAIT_FOR(done);

  __block int count = 0;
  [reader
      observeEventType:FIRDataEventTypeChildRemoved
             withBlock:^(FIRDataSnapshot* snapshot) {
               count++;
               if (count == 1) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"a"], @"Got first child");
                 XCTAssertTrue([snapshot.value isEqualToNumber:@1], @"Got correct value");
               } else if (count == 2) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"b"], @"Got second child");
                 XCTAssertTrue([snapshot.value isEqualToString:@"b"], @"got correct value");
               } else if (count == 3) {
                 XCTAssertTrue([snapshot.key isEqualToString:@"c"], @"Got third child");
                 NSDictionary* expected = @{@"deep" : @"path", @"of" : @{@"stuff" : @YES}};
                 XCTAssertTrue([snapshot.value isEqualToDictionary:expected], @"Got deep object");
               } else {
                 XCTFail(@"wrong event count");
               }
             }];

  done = NO;
  [reader observeEventType:FIRDataEventTypeValue
                 withBlock:^(FIRDataSnapshot* snapshot) {
                   // Load the data first
                   done = snapshot.value != [NSNull null] &&
                          [snapshot.value isEqualToDictionary:toSet];
                 }];

  WAIT_FOR(done);

  // Now do the removes
  [[writer child:@"a"] removeValue];
  [[writer child:@"b"] removeValue];
  [[writer child:@"c"] removeValue];

  WAIT_FOR(count == 3);
}

- (void)testQueriesBehaveProperlyAfterOnceCall {
  FTupleFirebase* refs = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writer = refs.one;
  FIRDatabaseReference* reader = refs.two;

  __block BOOL done = NO;
  NSDictionary* toSet = @{@"a" : @1, @"b" : @2, @"c" : @3, @"d" : @4};
  [writer setValue:toSet
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];

  WAIT_FOR(done);

  done = NO;
  [reader observeSingleEventOfType:FIRDataEventTypeValue
                         withBlock:^(FIRDataSnapshot* snapshot) {
                           done = YES;
                         }];

  WAIT_FOR(done);

  // Ok, now do some queries
  __block int startCount = 0;
  __block int defaultCount = 0;
  [[[reader queryOrderedByPriority] queryStartingAtValue:nil childKey:@"d"]
      observeEventType:FIRDataEventTypeChildAdded
             withBlock:^(FIRDataSnapshot* snapshot) {
               startCount++;
             }];

  [reader observeEventType:FIRDataEventTypeChildAdded
                 withBlock:^(FIRDataSnapshot* snapshot) {
                   defaultCount++;
                 }];

  [reader observeEventType:FIRDataEventTypeChildRemoved
                 withBlock:^(FIRDataSnapshot* snapshot) {
                   XCTFail(@"Should not remove any children");
                 }];

  WAIT_FOR(startCount == 1 && defaultCount == 4);
}

- (void)testIntegerKeysBehaveNumerically1 {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  NSDictionary* toSet = @{
    @"1" : @YES,
    @"50" : @YES,
    @"550" : @YES,
    @"6" : @YES,
    @"600" : @YES,
    @"70" : @YES,
    @"8" : @YES,
    @"80" : @YES
  };
  __block BOOL done = NO;
  [ref setValue:toSet
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        [[[ref queryOrderedByPriority] queryStartingAtValue:nil childKey:@"80"]
            observeSingleEventOfType:FIRDataEventTypeValue
                           withBlock:^(FIRDataSnapshot* snapshot) {
                             NSDictionary* expected = @{@"80" : @YES, @"550" : @YES, @"600" : @YES};
                             XCTAssertTrue([snapshot.value isEqualToDictionary:expected],
                                           @"Got correct result.");
                             done = YES;
                           }];
      }];
  WAIT_FOR(done);
}

- (void)testIntegerKeysBehaveNumerically2 {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  NSDictionary* toSet = @{
    @"1" : @YES,
    @"50" : @YES,
    @"550" : @YES,
    @"6" : @YES,
    @"600" : @YES,
    @"70" : @YES,
    @"8" : @YES,
    @"80" : @YES
  };
  __block BOOL done = NO;
  [ref setValue:toSet
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        [[[ref queryOrderedByPriority] queryEndingAtValue:nil childKey:@"50"]
            observeSingleEventOfType:FIRDataEventTypeValue
                           withBlock:^(FIRDataSnapshot* snapshot) {
                             NSDictionary* expected =
                                 @{@"1" : @YES,
                                   @"6" : @YES,
                                   @"8" : @YES,
                                   @"50" : @YES};
                             XCTAssertTrue([snapshot.value isEqualToDictionary:expected],
                                           @"Got correct result.");
                             done = YES;
                           }];
      }];
  WAIT_FOR(done);
}

- (void)testIntegerKeysBehaveNumerically3 {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  NSDictionary* toSet = @{
    @"1" : @YES,
    @"50" : @YES,
    @"550" : @YES,
    @"6" : @YES,
    @"600" : @YES,
    @"70" : @YES,
    @"8" : @YES,
    @"80" : @YES
  };
  __block BOOL done = NO;
  [ref setValue:toSet
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        [[[[ref queryOrderedByPriority] queryStartingAtValue:nil
                                                    childKey:@"50"] queryEndingAtValue:nil
                                                                              childKey:@"80"]
            observeSingleEventOfType:FIRDataEventTypeValue
                           withBlock:^(FIRDataSnapshot* snapshot) {
                             NSDictionary* expected = @{@"50" : @YES, @"70" : @YES, @"80" : @YES};
                             XCTAssertTrue([snapshot.value isEqualToDictionary:expected],
                                           @"Got correct result.");
                             done = YES;
                           }];
      }];
  WAIT_FOR(done);
}

- (void)testItemsPulledIntoLimitCorrectly {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  NSMutableArray* snaps = [[NSMutableArray alloc] init];

  // Just so everything is cached locally.
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot* snapshot){

              }];

  [[ref queryLimitedToLast:2] observeEventType:FIRDataEventTypeValue
                                     withBlock:^(FIRDataSnapshot* snapshot) {
                                       id val = [snapshot value];
                                       [snaps addObject:val];
                                     }];

  [ref setValue:@{
    @"a" : @{@".value" : @1, @".priority" : @1},
    @"b" : @{@".value" : @2, @".priority" : @2},
    @"c" : @{@".value" : @3, @".priority" : @3}
  }];

  __block BOOL ready = NO;
  [[ref child:@"b"] setValue:[NSNull null]
         withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
           ready = YES;
         }];

  WAIT_FOR(ready);

  NSArray* expected = @[ @{@"b" : @2, @"c" : @3}, @{@"a" : @1, @"c" : @3} ];
  XCTAssertEqualObjects(snaps, expected, @"Incorrect snapshots.");
}

- (void)testChildChangedCausesChildRemovedEvent {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  [[ref child:@"l/a"] setValue:@"1" andPriority:@"a"];
  [[ref child:@"l/b"] setValue:@"2" andPriority:@"b"];
  FIRDatabaseQuery* query = [[[[ref child:@"l"] queryOrderedByPriority] queryStartingAtValue:@"b"]
      queryEndingAtValue:@"d"];
  __block BOOL removed = NO;
  [query observeEventType:FIRDataEventTypeChildRemoved
                withBlock:^(FIRDataSnapshot* snapshot) {
                  XCTAssertEqualObjects(snapshot.value, @"2", @"Incorrect snapshot");
                  removed = YES;
                }];

  [[ref child:@"l/b"] setValue:@"4" andPriority:@"a"];

  WAIT_FOR(removed);
}

- (void)testQueryHasRef {
  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
  FIRDatabaseQuery* query = [ref queryOrderedByKey];
  XCTAssertEqualObjects([query.ref path], [ref path], @"Should have same path");
}

- (void)testQuerySnapshotChildrenRespectDefaultOrdering {
  FTupleFirebase* pair = [FTestHelpers getRandomNodePair];
  FIRDatabaseReference* writer = pair.one;
  FIRDatabaseReference* reader = pair.two;
  __block BOOL done = NO;

  NSDictionary* list = @{
    @"a" : @{
      @"thisvaluefirst" : @{@".value" : @true, @".priority" : @1},
      @"name" : @{@".value" : @"Michael", @".priority" : @2},
      @"thisvaluelast" : @{@".value" : @true, @".priority" : @3},
    },
    @"b" : @{
      @"thisvaluefirst" : @{@".value" : @true},
      @"name" : @{@".value" : @"Rob", @".priority" : @2},
      @"thisvaluelast" : @{@".value" : @true, @".priority" : @3},
    },
    @"c" : @{
      @"thisvaluefirst" : @{@".value" : @true, @".priority" : @1},
      @"name" : @{@".value" : @"Jonny", @".priority" : @2},
      @"thisvaluelast" : @{@".value" : @true, @".priority" : @"somestring"},
    }
  };

  [writer setValue:list
      withCompletionBlock:^(NSError* error, FIRDatabaseReference* ref) {
        done = YES;
      }];
  WAIT_FOR(done);

  done = NO;
  [[reader queryOrderedByChild:@"name"]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot* snapshot) {
                       NSArray* expectedKeys = @[ @"thisvaluefirst", @"name", @"thisvaluelast" ];
                       NSArray* expectedNames = @[ @"Jonny", @"Michael", @"Rob" ];

                       // Validate that snap.child() resets order to default for child snaps
                       NSMutableArray* orderedKeys = [[NSMutableArray alloc] init];
                       for (FIRDataSnapshot* childSnap in [snapshot childSnapshotForPath:@"b"]
                                .children) {
                         [orderedKeys addObject:childSnap.key];
                       }
                       XCTAssertEqualObjects(expectedKeys, orderedKeys,
                                             @"Should have matching ordered lists of keys");

                       // Validate that snap.forEach() resets ordering to default for child snaps
                       NSMutableArray* orderedNames = [[NSMutableArray alloc] init];
                       for (FIRDataSnapshot* childSnap in snapshot.children) {
                         [orderedNames addObject:[childSnap childSnapshotForPath:@"name"].value];
                         [orderedKeys removeAllObjects];
                         for (FIRDataSnapshot* grandchildSnap in childSnap.children) {
                           [orderedKeys addObject:grandchildSnap.key];
                         }
                         XCTAssertEqualObjects(expectedKeys, orderedKeys,
                                               @"Should have matching ordered lists of keys");
                       }
                       XCTAssertEqualObjects(expectedNames, orderedNames,
                                             @"Should have matching ordered lists of names");

                       done = YES;
                     }];
  WAIT_FOR(done);
}

- (void)testAddingListensForTheSamePathDoesNotCheckFail {
  // This bug manifests itself if there's a hierarchy of query listener, default listener and
  // one-time listener underneath. In Java implementation, during one-time listener registration,
  // sync-tree traversal stopped as soon as it found a complete server cache (this is the case for
  // not indexed query view). The problem is that the same traversal was looking for a ancestor
  // default view, and the early exit prevented from finding the default listener above the one-time
  // listener. Event removal code path wasn't removing the listener because it stopped as soon as it
  // found the default view. This left the zombie one-time listener and check failed on the second
  // attempt to create a listener for the same path (asana#61028598952586).

  FIRDatabaseReference* ref = [FTestHelpers getRandomNode];

  __block BOOL done = NO;

  [[ref child:@"child"] setValue:@{@"name" : @"John"}];
  [[[ref queryOrderedByChild:@"name"] queryEqualToValue:@"John"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^(FIRDataSnapshot* snapshot) {
               done = YES;
             }];
  WAIT_FOR(done);

  done = NO;
  [[[ref child:@"child"] child:@"favoriteToy"]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot* snapshot) {
                       done = YES;
                     }];
  WAIT_FOR(done);

  done = NO;
  [[[ref child:@"child"] child:@"favoriteToy"]
      observeSingleEventOfType:FIRDataEventTypeValue
                     withBlock:^(FIRDataSnapshot* snapshot) {
                       done = YES;
                     }];
  WAIT_FOR(done);
}

@end
