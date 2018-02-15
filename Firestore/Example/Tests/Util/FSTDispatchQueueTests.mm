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

// In these generic tests the specific TimerIDs don't matter.
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
- (void (^)())blockForStep:(int)n {
  return ^void() {
    [self->_completedSteps addObject:@(n)];
    if (self->_expectedSteps && self->_completedSteps.count >= self->_expectedSteps.count) {
      XCTAssertEqualObjects(self->_completedSteps, self->_expectedSteps);
      [self->_expectation fulfill];
    }
  };
}

- (void)testCanScheduleCallbacksInTheFuture {
  _expectation = [self expectationWithDescription:@"Expected steps"];
  _expectedSteps = @[ @1, @2, @3, @4 ];
  [_queue dispatchAsync:[self blockForStep:1]];
  [_queue dispatchAfterDelay:0.005 timerID:timerID1 block:[self blockForStep:4]];
  [_queue dispatchAfterDelay:0.001 timerID:timerID2 block:[self blockForStep:3]];
  [_queue dispatchAsync:[self blockForStep:2]];

  [self awaitExpectations];
}

- (void)testCanCancelDelayedCallbacks {
  _expectation = [self expectationWithDescription:@"Expected steps"];
  _expectedSteps = @[ @1, @3 ];
  // Queue everything from the queue to ensure nothing completes before we cancel.
  [_queue dispatchAsync:^{
    [_queue dispatchAsyncAllowingSameQueue:[self blockForStep:1]];
    FSTDelayedCallback *step2Timer =
        [_queue dispatchAfterDelay:.001 timerID:timerID1 block:[self blockForStep:2]];
    [_queue dispatchAfterDelay:.005 timerID:timerID2 block:[self blockForStep:3]];

    XCTAssertTrue([_queue containsDelayedCallbackWithTimerID:timerID1]);
    [step2Timer cancel];
    XCTAssertFalse([_queue containsDelayedCallbackWithTimerID:timerID1]);
  }];

  [self awaitExpectations];
}

- (void)testCanManuallyDrainAllDelayedCallbacksForTesting {
  [_queue dispatchAsync:[self blockForStep:1]];
  [_queue dispatchAfterDelay:20 timerID:timerID1 block:[self blockForStep:4]];
  [_queue dispatchAfterDelay:10 timerID:timerID2 block:[self blockForStep:3]];
  [_queue dispatchAsync:[self blockForStep:2]];

  [_queue runDelayedCallbacksUntil:FSTTimerIDAll];
  XCTAssertEqualObjects(_completedSteps, (@[ @1, @2, @3, @4 ]));
}

- (void)testCanManuallyDrainSpecificDelayedCallbacksForTesting {
  [_queue dispatchAsync:[self blockForStep:1]];
  [_queue dispatchAfterDelay:20 timerID:timerID1 block:[self blockForStep:5]];
  [_queue dispatchAfterDelay:10 timerID:timerID2 block:[self blockForStep:3]];
  [_queue dispatchAfterDelay:15 timerID:timerID3 block:[self blockForStep:4]];
  [_queue dispatchAsync:[self blockForStep:2]];

  [_queue runDelayedCallbacksUntil:timerID3];
  XCTAssertEqualObjects(_completedSteps, (@[ @1, @2, @3, @4 ]));
}

@end
