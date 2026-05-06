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

#include <atomic>
#include <memory>

#include "Firestore/core/src/remote/connectivity_monitor_apple.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/executor.h"

using firebase::firestore::remote::ConnectivityMonitor;
using firebase::firestore::remote::ConnectivityMonitorApple;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::Executor;
using NetworkStatus = ConnectivityMonitor::NetworkStatus;

namespace {

// Helper: build a fresh AsyncQueue for an isolated test.
std::shared_ptr<AsyncQueue> MakeWorkerQueue(const char* name) {
  return AsyncQueue::Create(Executor::CreateSerial(name));
}

// Helper: build a monitor and wait until NWPathMonitor delivers its first
// status update. Returns a unique_ptr; caller must destroy it on the
// worker queue (see DestroyOnQueue).
//
// If the first update never arrives within `timeout_seconds`, fails the
// test via XCTFail through the provided test case pointer.
std::unique_ptr<ConnectivityMonitorApple> MakeMonitorAndWaitForInitialStatus(
    XCTestCase* test_case,
    const std::shared_ptr<AsyncQueue>& worker_queue,
    NSTimeInterval timeout_seconds = 2.0) {
  auto monitor = std::make_unique<ConnectivityMonitorApple>(worker_queue);

  // NWPathMonitor delivers its first pathUpdateHandler asynchronously.
  // Poll GetCurrentStatus() until it has a value or we time out.
  NSDate* timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout_seconds];
  while (!monitor->GetCurrentStatus().has_value() && [timeoutDate timeIntervalSinceNow] > 0) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
  }

  if (!monitor->GetCurrentStatus().has_value()) {
    XCTFail(@"Timed out waiting for initial status update from NWPathMonitor");
  }
  return monitor;
}

// Helper: destroy a monitor on its AsyncQueue, satisfying the lifecycle
// invariant documented in connectivity_monitor_apple.h.
void DestroyOnQueue(std::unique_ptr<ConnectivityMonitorApple>& monitor,
                    const std::shared_ptr<AsyncQueue>& worker_queue) {
  worker_queue->EnqueueBlocking([&monitor]() { monitor.reset(); });
}

}  // namespace

@interface FSTConnectivityMonitorTests : XCTestCase
@end

@implementation FSTConnectivityMonitorTests

#pragma mark - Lifecycle

- (void)testConstructAndDestruct {
  auto worker_queue = MakeWorkerQueue("test_construct_destruct");
  auto monitor = std::make_unique<ConnectivityMonitorApple>(worker_queue);
  DestroyOnQueue(monitor, worker_queue);
  // No assertions — this passes if construction and on-queue destruction
  // do not crash and the destructor's HARD_ASSERT does not fire.
}

- (void)testRapidConstructDestruct {
  // Stress: repeated construction/destruction should not leak resources
  // (NWPathMonitor handles, dispatch queues, observer registrations) and
  // should not crash if a pathUpdateHandler is in flight when destruction
  // begins.
  for (int i = 0; i < 50; ++i) {
    auto worker_queue = MakeWorkerQueue("test_rapid");
    auto monitor = std::make_unique<ConnectivityMonitorApple>(worker_queue);
    DestroyOnQueue(monitor, worker_queue);
  }
}

- (void)testGetCurrentStatusBeforeUpdate {
  // Immediately after construction, GetCurrentStatus may or may not
  // already have a value depending on how fast NWPathMonitor delivers
  // its first update. The contract is: it does not crash, and the
  // returned optional is always meaningful.
  auto worker_queue = MakeWorkerQueue("test_get_status_early");
  auto monitor = std::make_unique<ConnectivityMonitorApple>(worker_queue);

  auto status = monitor->GetCurrentStatus();
  // No assertion on the value — either nullopt or a real status is OK.
  // We are testing that the call itself is safe immediately after construct.
  (void)status;

  DestroyOnQueue(monitor, worker_queue);
}

- (void)testGetCurrentStatusAfterUpdate {
  auto worker_queue = MakeWorkerQueue("test_get_status_after");
  auto monitor = MakeMonitorAndWaitForInitialStatus(self, worker_queue);

  auto status = monitor->GetCurrentStatus();
  XCTAssertTrue(status.has_value(), @"After waiting for initial update, status must be set");

  DestroyOnQueue(monitor, worker_queue);
}

- (void)testAddCallbackDoesNotCrash {
  auto worker_queue = MakeWorkerQueue("test_add_callback");
  auto monitor = MakeMonitorAndWaitForInitialStatus(self, worker_queue);

  std::atomic<int> invocation_count{0};
  monitor->AddCallback(
      [&invocation_count](NetworkStatus /*status*/) { invocation_count.fetch_add(1); });

  // We don't assert on invocation_count: status changes are not deterministic
  // in a unit test environment. We only assert that AddCallback itself is safe
  // and does not crash.

  DestroyOnQueue(monitor, worker_queue);
}

#pragma mark - Foreground notification (iOS / tvOS / visionOS)

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

- (void)testForegroundNotificationInvokesCallback {
  auto worker_queue = MakeWorkerQueue("test_foreground_invokes");
  auto monitor = MakeMonitorAndWaitForInitialStatus(self, worker_queue);

  // Skip the test if the simulator has no network — the foreground handler
  // intentionally short-circuits when status is Unavailable, so the
  // assertion below would not be meaningful.
  if (monitor->GetCurrentStatus().value() == NetworkStatus::Unavailable) {
    DestroyOnQueue(monitor, worker_queue);
    XCTSkip(@"Skipping: simulator reports Unavailable; "
            @"foreground handler short-circuits in this state");
    return;
  }

  XCTestExpectation* callbackExpectation =
      [self expectationWithDescription:@"Callback invoked after foreground"];
  std::atomic<bool> callback_invoked{false};
  monitor->AddCallback([&](NetworkStatus /*status*/) {
    if (!callback_invoked.exchange(true)) {
      [callbackExpectation fulfill];
    }
  });

  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationWillEnterForegroundNotification
                    object:nil];

  [self waitForExpectations:@[ callbackExpectation ] timeout:5.0];
  XCTAssertTrue(callback_invoked.load());

  DestroyOnQueue(monitor, worker_queue);
}

- (void)testForegroundNotificationAfterDestructionDoesNotCrash {
  // Verifies that the destructor properly removes the
  // NSNotificationCenter observer. If it didn't, posting a notification
  // after destruction would call a block holding a dangling `this`.
  auto worker_queue = MakeWorkerQueue("test_foreground_after_destruct");
  auto monitor = MakeMonitorAndWaitForInitialStatus(self, worker_queue);

  DestroyOnQueue(monitor, worker_queue);

  // Post the notification several times after destruction. If the observer
  // were not removed, this would dispatch into a destroyed object and crash.
  for (int i = 0; i < 5; ++i) {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:UIApplicationWillEnterForegroundNotification
                      object:nil];
  }

  // Give any (incorrectly) dispatched handler a chance to run and crash
  // before we declare success.
  XCTestExpectation* drained =
      [self expectationWithDescription:@"Settle after post-destruct notifications"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [drained fulfill];
                 });
  [self waitForExpectations:@[ drained ] timeout:2.0];
}

- (void)testForegroundNotificationWithoutCallbacksDoesNotCrash {
  // The foreground handler iterates registered callbacks. With zero
  // callbacks registered, it must still complete without crashing.
  auto worker_queue = MakeWorkerQueue("test_foreground_no_callbacks");
  auto monitor = MakeMonitorAndWaitForInitialStatus(self, worker_queue);

  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationWillEnterForegroundNotification
                    object:nil];

  // Let the worker queue drain any work the foreground handler enqueued.
  worker_queue->EnqueueBlocking([]() {});

  DestroyOnQueue(monitor, worker_queue);
}

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

@end
