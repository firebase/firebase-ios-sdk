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
static const FSTTimerID timerID1 = FSTTimerIDListenStreamConnectionBackoff;
static const FSTTimerID timerID2 = FSTTimerIDListenStreamIdle;
static const FSTTimerID timerID3 = FSTTimerIDWriteStreamConnectionBackoff;

@interface FSTDispatchQueueTests : XCTestCase
@end

@implementation FSTDispatchQueueTests {
  dispatch_queue_t _underlyingQueue;
  FSTDispatchQueue *_queue;
  NSMutableArray *_completedSteps;
  NSArray *_expectedSteps;
  XCTestExpectation *_expectation;
}

- (void)setUp {
  [super setUp];
  _underlyingQueue = dispatch_queue_create("FSTDispatchQueueTests", DISPATCH_QUEUE_SERIAL);
  _queue = [[FSTDispatchQueue alloc] initWithQueue:_underlyingQueue];
  _completedSteps = [NSMutableArray array];
  _expectedSteps = nil;
}

- (void)testDispatchAsyncBlocksSubmissionFromTasksOnTheQueue {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
  __block NSException *caught = nil;
  __block NSString *problem = nil;

  [_queue dispatchAsync:^{
    @try {
      [self->_queue dispatchAsync:^{
      }];
      problem = @"Should have disallowed submission into the queue while running";
      [expectation fulfill];
    } @catch (NSException *ex) {
      caught = ex;
      [expectation fulfill];
    }
  }];

  [self awaitExpectations];
  XCTAssertNil(problem);
  XCTAssertNotNil(caught);

  XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
  XCTAssertTrue([caught.reason
      hasPrefix:
          @"FIRESTORE INTERNAL ASSERTION FAILED: "
          @"Enqueue methods cannot be called when we are already running on target executor"]);
}

- (void)testDispatchAsyncAllowingSameQueueActuallyAllowsSameQueue {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
  __block NSException *caught = nil;

  [_queue dispatchAsync:^{
    @try {
      [self->_queue dispatchAsyncAllowingSameQueue:^{
        [expectation fulfill];
      }];
    } @catch (NSException *ex) {
      caught = ex;
      [expectation fulfill];
    }
  }];

  [self awaitExpectations];
  XCTAssertNil(caught);
}

- (void)testDispatchAsyncAllowsSameQueueForUnownedActions {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
  __block NSException *caught = nil;

  // Simulate the case of an action that runs on our queue because e.g. it's run by a user-owned
  // deinitializer that happened to be last held in one of our API methods.
  dispatch_async(_underlyingQueue, ^{
    @try {
      [self->_queue dispatchAsync:^{
        [expectation fulfill];
      }];
    } @catch (NSException *ex) {
      caught = ex;
      [expectation fulfill];
    }
  });

  [self awaitExpectations];
  XCTAssertNil(caught);
}

- (void)testDispatchSyncBlocksSubmissionFromTasksOnTheQueue {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
  __block NSException *caught = nil;
  __block NSString *problem = nil;

  [_queue dispatchSync:^{
    @try {
      [self->_queue dispatchSync:^{
      }];
      problem = @"Should have disallowed submission into the queue while running";
      [expectation fulfill];
    } @catch (NSException *ex) {
      caught = ex;
      [expectation fulfill];
    }
  }];

  [self awaitExpectations];
  XCTAssertNil(problem);
  XCTAssertNotNil(caught);

  XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
  XCTAssertTrue([caught.reason
      hasPrefix:
          @"FIRESTORE INTERNAL ASSERTION FAILED: "
          @"Enqueue methods cannot be called when we are already running on target executor"]);
}

- (void)testVerifyIsCurrentQueueActuallyRequiresCurrentQueue {
  XCTAssertNotEqualObjects(_underlyingQueue, dispatch_get_main_queue());

  __block NSException *caught = nil;
  @try {
    // Run on the main queue not the FSTDispatchQueue's queue
    [_queue verifyIsCurrentQueue];
  } @catch (NSException *ex) {
    caught = ex;
  }
  XCTAssertNotNil(caught);
  XCTAssertTrue([caught.reason hasPrefix:@"FIRESTORE INTERNAL ASSERTION FAILED: "
                                         @"Expected to be called by the executor "
                                         @"associated with this queue"]);
}

- (void)testVerifyIsCurrentQueueRequiresOperationIsInProgress {
  __block NSException *caught = nil;
  dispatch_sync(_underlyingQueue, ^{
    @try {
      [self->_queue verifyIsCurrentQueue];
    } @catch (NSException *ex) {
      caught = ex;
    }
  });
  XCTAssertNotNil(caught);
  XCTAssertTrue(
      [caught.reason hasPrefix:@"FIRESTORE INTERNAL ASSERTION FAILED: "
                               @"VerifyIsCurrentQueue called when no operation is executing"]);
}

- (void)testVerifyIsCurrentQueueWorksWithOperationIsInProgress {
  __block NSException *caught = nil;
  [_queue dispatchSync:^{
    @try {
      [self->_queue verifyIsCurrentQueue];
    } @catch (NSException *ex) {
      caught = ex;
    }
  }];
  XCTAssertNil(caught);
}

- (void)testEnterCheckedOperationDisallowsNesting {
  __block NSException *caught = nil;
  __block NSString *problem = nil;
  [_queue dispatchSync:^{
    @try {
      [self->_queue enterCheckedOperation:^{
      }];
      problem = @"Should not have been able to enter nested enterCheckedOperation";
    } @catch (NSException *ex) {
      caught = ex;
    }
  }];
  XCTAssertNil(problem);
  XCTAssertNotNil(caught);
  XCTAssertTrue(
      [caught.reason hasPrefix:@"FIRESTORE INTERNAL ASSERTION FAILED: "
                               @"ExecuteBlocking may not be called before the previous operation "
                               @"finishes executing"]);
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
  [_queue dispatchAsync:^{
    [_queue dispatchAfterDelay:0.005 timerID:timerID1 block:[self blockForStep:4]];
    [_queue dispatchAfterDelay:0.001 timerID:timerID2 block:[self blockForStep:3]];
  }];
  [_queue dispatchAsync:[self blockForStep:2]];

  [self awaitExpectations];
}

- (void)testCanCancelDelayedCallbacks {
  _expectation = [self expectationWithDescription:@"Expected steps"];
  _expectedSteps = @[ @1, @3 ];
  // Queue everything from the queue to ensure nothing completes before we cancel.
  [_queue dispatchAsync:^{
    [self->_queue dispatchAsyncAllowingSameQueue:[self blockForStep:1]];
    FSTDelayedCallback *step2Timer =
        [self->_queue dispatchAfterDelay:.001 timerID:timerID1 block:[self blockForStep:2]];
    [self->_queue dispatchAfterDelay:.005 timerID:timerID2 block:[self blockForStep:3]];

    XCTAssertTrue([self->_queue containsDelayedCallbackWithTimerID:timerID1]);
    [step2Timer cancel];
    XCTAssertFalse([self->_queue containsDelayedCallbackWithTimerID:timerID1]);
  }];

  [self awaitExpectations];
}

- (void)testCanManuallyDrainAllDelayedCallbacksForTesting {
  [_queue dispatchAsync:[self blockForStep:1]];
  [_queue dispatchAsync:^{
    [_queue dispatchAfterDelay:20 timerID:timerID1 block:[self blockForStep:4]];
    [_queue dispatchAfterDelay:10 timerID:timerID2 block:[self blockForStep:3]];
  }];
  [_queue dispatchAsync:[self blockForStep:2]];

  [_queue runDelayedCallbacksUntil:FSTTimerIDAll];
  XCTAssertEqualObjects(_completedSteps, (@[ @1, @2, @3, @4 ]));
}

- (void)testCanManuallyDrainSpecificDelayedCallbacksForTesting {
  [_queue dispatchAsync:[self blockForStep:1]];
  [_queue dispatchAsync:^{
    [_queue dispatchAfterDelay:20 timerID:timerID1 block:[self blockForStep:5]];
    [_queue dispatchAfterDelay:10 timerID:timerID2 block:[self blockForStep:3]];
    [_queue dispatchAfterDelay:15 timerID:timerID3 block:[self blockForStep:4]];
  }];
  [_queue dispatchAsync:[self blockForStep:2]];

  [_queue runDelayedCallbacksUntil:timerID3];
  XCTAssertEqualObjects(_completedSteps, (@[ @1, @2, @3, @4 ]));
}

@end
