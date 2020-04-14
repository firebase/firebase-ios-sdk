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

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Auth/FIRAuthGlobalWorkQueue.h"
#import "FirebaseAuth/Sources/Auth/FIRAuthSerialTaskQueue.h"

/** @var kTimeout
    @brief Time-out in seconds waiting for tasks to be executed.
 */
static const NSTimeInterval kTimeout = 1;

/** @class FIRAuthSerialTaskQueueTests
    @brief Tests for @c FIRAuthSerialTaskQueue .
 */
@interface FIRAuthSerialTaskQueueTests : XCTestCase
@end
@implementation FIRAuthSerialTaskQueueTests

- (void)testExecution {
  XCTestExpectation *expectation = [self expectationWithDescription:@"executed"];
  FIRAuthSerialTaskQueue *queue = [[FIRAuthSerialTaskQueue alloc] init];
  [queue enqueueTask:^(FIRAuthSerialTaskCompletionBlock completionArg) {
    completionArg();
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kTimeout handler:nil];
}

- (void)testCompletion {
  XCTestExpectation *expectation = [self expectationWithDescription:@"executed"];
  FIRAuthSerialTaskQueue *queue = [[FIRAuthSerialTaskQueue alloc] init];
  __block FIRAuthSerialTaskCompletionBlock completion = nil;
  [queue enqueueTask:^(FIRAuthSerialTaskCompletionBlock completionArg) {
    completion = completionArg;
    [expectation fulfill];
  }];
  __block XCTestExpectation *nextExpectation = nil;
  __block BOOL executed = NO;
  [queue enqueueTask:^(FIRAuthSerialTaskCompletionBlock completionArg) {
    executed = YES;
    completionArg();
    [nextExpectation fulfill];
  }];
  // The second task should not be executed until the first is completed.
  [self waitForExpectationsWithTimeout:kTimeout handler:nil];
  XCTAssertNotNil(completion);
  XCTAssertFalse(executed);
  nextExpectation = [self expectationWithDescription:@"executed next"];
  completion();
  [self waitForExpectationsWithTimeout:kTimeout handler:nil];
  XCTAssertTrue(executed);
}

- (void)testTargetQueue {
  XCTestExpectation *expectation = [self expectationWithDescription:@"executed"];
  FIRAuthSerialTaskQueue *queue = [[FIRAuthSerialTaskQueue alloc] init];
  __block BOOL executed = NO;
  dispatch_suspend(FIRAuthGlobalWorkQueue());
  [queue enqueueTask:^(FIRAuthSerialTaskCompletionBlock completionArg) {
    executed = YES;
    completionArg();
    [expectation fulfill];
  }];
  // The task should not executed until the global work queue is resumed.
  usleep(kTimeout * USEC_PER_SEC);
  XCTAssertFalse(executed);
  dispatch_resume(FIRAuthGlobalWorkQueue());
  [self waitForExpectationsWithTimeout:kTimeout handler:nil];
}

- (void)testTaskQueueNoAffectTargetQueue {
  FIRAuthSerialTaskQueue *queue = [[FIRAuthSerialTaskQueue alloc] init];
  __block FIRAuthSerialTaskCompletionBlock completion = nil;
  [queue enqueueTask:^(FIRAuthSerialTaskCompletionBlock completionArg) {
    completion = completionArg;
  }];
  __block XCTestExpectation *nextExpectation = nil;
  __block BOOL executed = NO;
  [queue enqueueTask:^(FIRAuthSerialTaskCompletionBlock completionArg) {
    executed = YES;
    completionArg();
    [nextExpectation fulfill];
  }];
  XCTestExpectation *expectation = [self expectationWithDescription:@"executed"];
  dispatch_async(FIRAuthGlobalWorkQueue(), ^{
    [expectation fulfill];
  });
  // The task queue waiting for completion should not affect the global work queue.
  [self waitForExpectationsWithTimeout:kTimeout handler:nil];
  XCTAssertNotNil(completion);
  XCTAssertFalse(executed);
  nextExpectation = [self expectationWithDescription:@"executed next"];
  completion();
  [self waitForExpectationsWithTimeout:kTimeout handler:nil];
  XCTAssertTrue(executed);
}

@end
