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

#include "Firestore/core/src/firebase/firestore/util/async_queue_libdispatch.h"

#include <chrono>
#include <future>
#include <string>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

const auto underlying_queue =
    dispatch_queue_create("AsyncQueueTests", DISPATCH_QUEUE_SERIAL);

// In these generic tests the specific timer ids don't matter.
const TimerId kTimerId1 = TimerId::ListenStreamConnectionBackoff;
const TimerId kTimerId2 = TimerId::ListenStreamIdle;
const TimerId kTimerId3 = TimerId::WriteStreamConnectionBackoff;

AsyncQueue Queue() {
  return AsyncQueue{underlying_queue};
}

const auto kTimeout = std::chrono::seconds(1);

using SignalT = std::packaged_task<void()>;

SignalT CreateSignal() {
  return SignalT{[] {}};
}

// Googletest doesn't contain built-in functionality to block until an async
// operation completes, and there is no timeout by default. Work around both by
// resolving a packaged_task in the async operation and blocking on the
// associated future (with timeout).
bool WaitForTestToFinish(SignalT* const signal) {
  return signal->get_future().wait_for(kTimeout) == std::future_status::ready;
}

}  // namespace

TEST(AsyncQueue, Enqueue) {
  auto signal_finished = CreateSignal();

  auto queue = Queue();
  queue.Enqueue([&] { signal_finished(); });

  EXPECT_TRUE(WaitForTestToFinish(&signal_finished));
}

TEST(AsyncQueue, EnqueueDisallowsEnqueuedTasksToUseEnqueue) {
  auto signal_finished = CreateSignal();

  auto queue = Queue();
  queue.Enqueue([&] {  // clang-format off
    EXPECT_ANY_THROW(queue.Enqueue([&] { signal_finished(); }););
    // clang-format on
  });

  WaitForTestToFinish(&signal_finished);
}

TEST(AsyncQueue, EnqueueAllowsEnqueuedTasksToUseEnqueueUsingSameQueue) {
  auto signal_finished = CreateSignal();

  auto queue = Queue();
  queue.Enqueue([&] {  // clang-format off
    queue.EnqueueAllowingSameQueue([&] { signal_finished(); });
    // clang-format on
  });

  EXPECT_TRUE(WaitForTestToFinish(&signal_finished));
}

TEST(AsyncQueue, SameQueueIsAllowedForUnownedActions) {
  auto signal_finished = CreateSignal();
  auto queue = Queue();

  struct Context {
    AsyncQueue& queue;
    SignalT& signal_finished;
  } context{queue, signal_finished};
  dispatch_async_f(underlying_queue, &context, [](void* const raw_context) {
    auto unwrap = static_cast<const Context*>(raw_context);
    unwrap->queue.Enqueue([unwrap] { unwrap->signal_finished(); });
  });

  EXPECT_TRUE(WaitForTestToFinish(&signal_finished));
}

TEST(AsyncQueue, RunSync) {
  bool finished = false;

  auto queue = Queue();
  queue.RunSync([&] { finished = true; });

  EXPECT_TRUE(finished);
}

TEST(AsyncQueue, RunSyncDisallowsEnqueuedTasksToUseEnqueue) {
  auto queue = Queue();
  queue.RunSync([&] {  // clang-format off
    EXPECT_ANY_THROW(queue.RunSync([] {}););
    // clang-format on
  });
}

TEST(AsyncQueue, EnterCheckedOperationDisallowsNesting) {
  auto queue = Queue();
  queue.RunSync(
      [&] { EXPECT_ANY_THROW(queue.EnterCheckedOperation([] {});); });
}

TEST(AsyncQueue, VerifyIsCurrentQueueRequiresCurrentQueue) {
  ASSERT_NE(underlying_queue, dispatch_get_main_queue());
  EXPECT_ANY_THROW(Queue().VerifyIsCurrentQueue());
}

TEST(AsyncQueue, VerifyIsCurrentQueueRequiresOperationInProgress) {
  auto queue = Queue();
  dispatch_sync_f(underlying_queue, &queue, [](void* const raw_queue) {
    EXPECT_ANY_THROW(
        static_cast<AsyncQueue*>(raw_queue)->VerifyIsCurrentQueue());
  });
}

TEST(AsyncQueue, VerifyIsCurrentQueueWorksWithOperationInProgress) {
  auto queue = Queue();
  queue.RunSync([&] { EXPECT_NO_THROW(queue.VerifyIsCurrentQueue()); });
}

TEST(AsyncQueue, CanScheduleOperationsInTheFuture) {
  auto signal_finished = CreateSignal();
  std::string steps;

  auto queue = Queue();
  queue.Enqueue([&steps] { steps += '1'; });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(5), kTimerId1,
                          [&steps, &signal_finished] {
                            steps += '4';
                            signal_finished();
                          });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(1), kTimerId2,
                          [&steps] { steps += '3'; });
  queue.Enqueue([&steps] { steps += '2'; });

  EXPECT_TRUE(WaitForTestToFinish(&signal_finished));
  EXPECT_EQ(steps, "1234");
}

TEST(AsyncQueue, CanCancelDelayedCallbacks) {
  auto signal_finished = CreateSignal();
  std::string steps;

  auto queue = Queue();
  queue.Enqueue([&] {
    // Queue everything from the queue to ensure nothing completes before we
    // cancel.

    queue.EnqueueAllowingSameQueue([&steps] { steps += '1'; });

    DelayedOperation delayed_operation = queue.EnqueueAfterDelay(
        AsyncQueue::Milliseconds(1), kTimerId1, [&steps] { steps += '2'; });

    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(5), kTimerId2,
                            [&steps, &signal_finished] {
                              steps += '3';
                              signal_finished();
                            });

    EXPECT_TRUE(queue.ContainsDelayedOperation(kTimerId1));
    delayed_operation.Cancel();
    // Note: the operation will only be removed from the queue after it's run,
    // not immediately once it's canceled.
  });

  EXPECT_TRUE(WaitForTestToFinish(&signal_finished));
  EXPECT_EQ(steps, "13");
}

TEST(AsyncQueue, DelayedOperationIsValidAfterTheOperationHasRun) {
  auto signal_finished = CreateSignal();

  auto queue = Queue();
  DelayedOperation delayed_operation = queue.EnqueueAfterDelay(
      AsyncQueue::Milliseconds(1), kTimerId1, [&] { signal_finished(); });
  EXPECT_TRUE(queue.ContainsDelayedOperation(kTimerId1));

  EXPECT_TRUE(WaitForTestToFinish(&signal_finished));
  EXPECT_FALSE(queue.ContainsDelayedOperation(kTimerId1));
  EXPECT_NO_THROW(delayed_operation.Cancel());
}

TEST(AsyncQueue, CanManuallyDrainAllDelayedCallbacksForTesting) {
  std::string steps;

  auto queue = Queue();
  queue.Enqueue([&steps] { steps += '1'; });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(20000), kTimerId1,
                          [&steps] { steps += '4'; });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(10000), kTimerId2,
                          [&steps] { steps += '3'; });
  queue.Enqueue([&steps] { steps += '2'; });

  queue.RunDelayedOperationsUntil(TimerId::All);
  EXPECT_EQ(steps, "1234");
}

TEST(AsyncQueue, CanManuallyDrainSpecificDelayedCallbacksForTesting) {
  std::string steps;

  auto queue = Queue();
  queue.Enqueue([&] { steps += '1'; });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(20000), kTimerId1,
                          [&steps] { steps += '5'; });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(10000), kTimerId2,
                          [&steps] { steps += '3'; });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(15000), kTimerId3,
                          [&steps] { steps += '4'; });
  queue.Enqueue([&] { steps += '2'; });

  queue.RunDelayedOperationsUntil(kTimerId3);
  EXPECT_EQ(steps, "1234");
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
