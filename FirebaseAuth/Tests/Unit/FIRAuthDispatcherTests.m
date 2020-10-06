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

#import "FirebaseAuth/Sources/Auth/FIRAuthDispatcher.h"

/** @var kMaxDifferenceBetweenTimeIntervals
    @brief The maximum difference between time intervals (in seconds), after which they will be
    considered different.
 */
static const NSTimeInterval kMaxDifferenceBetweenTimeIntervals = 0.3;

/** @var kTestDelay
    @brief Fake time delay before tasks are dispatched.
 */
NSTimeInterval kTestDelay = 0.1;

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static const NSTimeInterval kExpectationTimeout = 2;

id<OS_dispatch_queue> testWorkQueue;

/** @class FIRAuthDispatcherTests
    @brief Tests for @c FIRAuthDispatcher.
 */
@interface FIRAuthDispatcherTests : XCTestCase
@end
@implementation FIRAuthDispatcherTests

- (void)setUp {
  [super setUp];
  testWorkQueue = dispatch_queue_create("test.work.queue", NULL);
}

/** @fn testSharedInstance
    @brief Tests @c sharedInstance returns the same object.
 */
- (void)testSharedInstance {
  FIRAuthDispatcher *instance1 = [FIRAuthDispatcher sharedInstance];
  FIRAuthDispatcher *instance2 = [FIRAuthDispatcher sharedInstance];
  XCTAssertEqual(instance1, instance2);
}

/** @fn testDispatchAfterDelay
    @brief Tests @c dispatchAfterDelay indeed dispatches the specified task after the provided
        delay.
 */
- (void)testDispatchAfterDelay {
  FIRAuthDispatcher *dispatcher = [FIRAuthDispatcher sharedInstance];
  XCTestExpectation *expectation = [self expectationWithDescription:@"dispatchAfterCallback"];
  NSDate *dateBeforeDispatch = [NSDate date];
  dispatcher.dispatchAfterImplementation = nil;
  [dispatcher dispatchAfterDelay:kTestDelay
                           queue:testWorkQueue
                            task:^{
                              NSTimeInterval timeSinceDispatch =
                                  fabs([dateBeforeDispatch timeIntervalSinceNow]) - kTestDelay;
                              XCTAssert(timeSinceDispatch < kMaxDifferenceBetweenTimeIntervals);
                              [expectation fulfill];
                            }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  dispatcher = nil;
}

/** @fn testSetDispatchAfterImplementation
    @brief Tests taht @c dispatchAfterImplementation indeed configures a custom implementation for
        @c dispatchAfterDelay.
 */
- (void)testSetDispatchAfterImplementation {
  FIRAuthDispatcher *dispatcher = [FIRAuthDispatcher sharedInstance];
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"setDispatchTokenCallback"];
  [dispatcher setDispatchAfterImplementation:^(
                  NSTimeInterval delay, id<OS_dispatch_queue> _Nonnull queue, void (^task)(void)) {
    XCTAssertEqual(kTestDelay, delay);
    XCTAssertEqual(testWorkQueue, queue);
    [expectation1 fulfill];
  }];
  [dispatcher dispatchAfterDelay:kTestDelay
                           queue:testWorkQueue
                            task:^{
                              // Fail to ensure this code is never executed.
                              XCTFail();
                            }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  dispatcher.dispatchAfterImplementation = nil;
}

@end
