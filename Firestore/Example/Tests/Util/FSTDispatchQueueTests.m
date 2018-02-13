/*
 * Copyright 2018 Google
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

#import "Firestore/Source/Util/FSTDispatchQueue.h"

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/XCTestCase+Await.h"

// We reuse these TimerIDs for generic testing.
static const FSTTimerID timerID1 = FSTTimerIDListenStreamConnection;
static const FSTTimerID timerID2 = FSTTimerIDListenStreamIdle;
static const FSTTimerID timerID3 = FSTTimerIDWriteStreamConnection;

@interface FSTDispatchQueueTests : XCTestCase
@end

@implementation FSTDispatchQueueTests {
  FSTDispatchQueue *_queue;
  NSMutableArray *_completedSteps;
  NSArray *_expectedSteps;
  XCTestExpectation *_expectation;
}

- (void)setUp {
  [super setUp];
  dispatch_queue_t dispatch_queue =
      dispatch_queue_create("FSTDispatchQueueTests", DISPATCH_QUEUE_SERIAL);
  _queue = [[FSTDispatchQueue alloc] initWithQueue:dispatch_queue];
  _completedSteps = [NSMutableArray array];
  _expectedSteps = nil;
}

/**
 * Helper to return a block that adds @(n) to _completedSteps when run and fulfils _expectation if
 * the _completedSteps match the _expectedSteps.
 */
- (void (^)())stepBlock:(int)n {
  return ^void() {
    [_completedSteps addObject:@(n)];
    if (_expectedSteps && [_completedSteps isEqualToArray:_expectedSteps]) {
      [_expectation fulfill];
    }
  };
}

- (void)testCanScheduleCallbacksInTheFuture {
  _expectation = [self expectationWithDescription:@"Expected steps"];
  _expectedSteps = @[ @1, @2, @3, @4 ];
  [_queue dispatchAsync:[self stepBlock:1]];
  [_queue dispatchAfterDelay:0.005 timerID:timerID1 block:[self stepBlock:4]];
  [_queue dispatchAfterDelay:0.001 timerID:timerID2 block:[self stepBlock:3]];
  [_queue dispatchAsync:[self stepBlock:2]];

  [self awaitExpectations];
}

- (void)testCanCancelDelayedCallbacks {
  _expectation = [self expectationWithDescription:@"Expected steps"];
  _expectedSteps = @[ @1, @3 ];
  // Queue everything from the queue to ensure nothing completes before we cancel.
  [_queue dispatchAsync:^{
    [_queue dispatchAsyncAllowingSameQueue:[self stepBlock:1]];
    FSTDelayedCallback *timer1 =
        [_queue dispatchAfterDelay:.001 timerID:timerID1 block:[self stepBlock:2]];
    [_queue dispatchAfterDelay:.005 timerID:timerID2 block:[self stepBlock:3]];

    XCTAssertTrue([_queue containsDelayedCallbackWithTimerID:timerID1]);
    [timer1 cancel];
    XCTAssertFalse([_queue containsDelayedCallbackWithTimerID:timerID1]);
  }];

  [self awaitExpectations];
}

- (void)testCanRunAllDelayedCallbacksEarly {
  [_queue dispatchAsync:[self stepBlock:1]];
  [_queue dispatchAfterDelay:20 timerID:timerID1 block:[self stepBlock:4]];
  [_queue dispatchAfterDelay:10 timerID:timerID2 block:[self stepBlock:3]];
  [_queue dispatchAsync:[self stepBlock:2]];

  [_queue runDelayedCallbacksUntil:FSTTimerIDAll];
  XCTAssertEqualObjects(_completedSteps, (@[ @1, @2, @3, @4 ]));
}

- (void)testCanRunSomeDelayedCallbacksEarly {
  [_queue dispatchAsync:[self stepBlock:1]];
  [_queue dispatchAfterDelay:20 timerID:timerID1 block:[self stepBlock:5]];
  [_queue dispatchAfterDelay:10 timerID:timerID2 block:[self stepBlock:3]];
  [_queue dispatchAfterDelay:15 timerID:timerID3 block:[self stepBlock:4]];
  [_queue dispatchAsync:[self stepBlock:2]];

  [_queue runDelayedCallbacksUntil:timerID3];
  XCTAssertEqualObjects(_completedSteps, (@[ @1, @2, @3, @4 ]));
}

@end
