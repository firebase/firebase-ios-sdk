/*
 * Copyright 2026 Google LLC
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

#include "Firestore/core/src/remote/connectivity_monitor_apple.h"
#include "Firestore/core/src/util/async_queue.h"

using firebase::firestore::remote::ConnectivityMonitorApple;
using firebase::firestore::util::AsyncQueue;

@interface FSTConnectivityMonitorTests : XCTestCase
@end

@implementation FSTConnectivityMonitorTests

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
- (void)testForegroundNotificationInvokesCallback {
  auto executor = firebase::firestore::util::Executor::CreateSerial("test_queue");
  auto worker_queue = firebase::firestore::util::AsyncQueue::Create(std::move(executor));

  // Create the monitor
  auto monitor = std::make_unique<ConnectivityMonitorApple>(worker_queue);

  // Wait a small amount of time to let any initial NWPathMonitor events settle
  XCTestExpectation *settleExpectation = [self expectationWithDescription:@"Wait for settle"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [settleExpectation fulfill];
                 });
  [self waitForExpectationsWithTimeout:2.0 handler:nil];

  XCTAssertTrue(
      monitor->GetCurrentStatus().has_value(),
      @"Initial status was not set by NWPathMonitor! Tests cannot proceed reliably without it.");

  XCTAssertNotEqual(monitor->GetCurrentStatus().value(),
                    firebase::firestore::remote::ConnectivityMonitor::NetworkStatus::Unavailable,
                    @"Initial status is Unavailable! Test cannot proceed reliably because "
                    @"foreground notification skips invoking callbacks when unavailable.");

  bool callbackInvoked = false;
  XCTestExpectation *callbackExpectation = [self expectationWithDescription:@"Callback invoked"];

  monitor->AddCallback([&](firebase::firestore::remote::ConnectivityMonitor::NetworkStatus status) {
    (void)status;
    callbackInvoked = true;
    [callbackExpectation fulfill];
  });

  __block BOOL notificationReceived = false;
  id testObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:UIApplicationWillEnterForegroundNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                (void)note;
                notificationReceived = true;
              }];

  // Post notification to simulate entering foreground
  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationWillEnterForegroundNotification
                    object:nil];

  // Wait for the callback to be invoked on the worker queue
  [self waitForExpectationsWithTimeout:5.0 handler:nil];

  [[NSNotificationCenter defaultCenter] removeObserver:testObserver];

  XCTAssertTrue(
      notificationReceived,
      @"UIApplicationWillEnterForegroundNotification was not received by the test observer!");
  XCTAssertTrue(callbackInvoked);
}
#endif

@end
