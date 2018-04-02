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

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"

#include <chrono>
#include <future>
#include <string>
#include <utility>

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
}  // namespace

TEST(AsyncQueue, Enqueue) {
  std::packaged_task<void()> signal_finished{[] {}};

  auto queue = Queue();
  queue.Enqueue([&] { signal_finished(); });

  const auto status =
      signal_finished.get_future().wait_for(std::chrono::seconds(1));
  EXPECT_EQ(status, std::future_status::ready);
}

TEST(AsyncQueue, EnqueueDisallowsEnqueuedTasksToUseEnqueue) {
  std::packaged_task<void()> signal_finished{[] {}};

  auto queue = Queue();
  queue.Enqueue([&] {  // clang-format off
    EXPECT_ANY_THROW(queue.Enqueue([&] { signal_finished(); }););
    // clang-format on
  });

  signal_finished.get_future().wait_for(std::chrono::seconds(1));
}

TEST(AsyncQueue, EnqueueAllowsEnqueuedTasksToUseEnqueueUsingSameQueue) {
  std::packaged_task<void()> signal_finished{[] {}};

  auto queue = Queue();
  queue.Enqueue([&] {  // clang-format off
    queue.EnqueueAllowingSameQueue([&] { signal_finished(); });
    // clang-format on
  });

  const auto status =
      signal_finished.get_future().wait_for(std::chrono::seconds(1));
  EXPECT_EQ(status, std::future_status::ready);
}

TEST(AsyncQueue, SameQueueIsAllowedForUnownedActions) {
  std::packaged_task<void()> signal_finished{[] {}};
  auto queue = Queue();

  using WrapT = std::pair<AsyncQueue*, std::packaged_task<void()>*>;
  WrapT wrap{&queue, &signal_finished};
  dispatch_async_f(underlying_queue, &wrap, [](void* const raw_wrap) {
    auto unwrap = static_cast<const WrapT*>(raw_wrap);
    unwrap->first->Enqueue([unwrap] { (*unwrap->second)(); });
  });

  const auto status =
      signal_finished.get_future().wait_for(std::chrono::seconds(1));
  EXPECT_EQ(status, std::future_status::ready);
}

TEST(AsyncQueue, EnqueueSync) {
  std::packaged_task<void()> signal_finished{[] {}};

  auto queue = Queue();
  queue.EnqueueSync([&] { signal_finished(); });

  const auto status =
      signal_finished.get_future().wait_for(std::chrono::seconds(1));
  EXPECT_EQ(status, std::future_status::ready);
}

TEST(AsyncQueue, EnqueueSyncDisallowsEnqueuedTasksToUseEnqueue) {
  std::packaged_task<void()> signal_finished{[] {}};

  auto queue = Queue();
  queue.EnqueueSync([&] {  // clang-format off
    EXPECT_ANY_THROW(queue.EnqueueSync([&] { signal_finished(); }););
    // clang-format on
  });

  signal_finished.get_future().wait_for(std::chrono::seconds(1));
}

TEST(AsyncQueue, EnterCheckedOperationDisallowsNesting) {
  std::packaged_task<void()> signal_finished{[] {}};

  auto queue = Queue();
  queue.EnqueueSync([&] {
    EXPECT_ANY_THROW(queue.EnterCheckedOperation([&] { signal_finished(); }););
  });

  signal_finished.get_future().wait_for(std::chrono::seconds(1));
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
  queue.EnqueueSync([&] { EXPECT_NO_THROW(queue.VerifyIsCurrentQueue()); });
}

TEST(AsyncQueue, CanScheduleOperationsInTheFuture) {
  std::packaged_task<void()> signal_finished{[] {}};
  std::string steps;

  auto queue = Queue();
  queue.Enqueue([&steps] { steps += '1'; });
  queue.EnqueueWithDelay(AsyncQueue::Milliseconds(5), kTimerId1,
                         [&steps, &signal_finished] {
                           steps += '4';
                           signal_finished();
                         });
  queue.EnqueueWithDelay(AsyncQueue::Milliseconds(1), kTimerId2,
                         [&steps] { steps += '3'; });
  queue.Enqueue([&steps] { steps += '2'; });

  const auto status =
      signal_finished.get_future().wait_for(std::chrono::seconds(1));
  EXPECT_EQ(status, std::future_status::ready);
  EXPECT_EQ(steps, "1234");
}

TEST(AsyncQueue, CanCancelDelayedCallbacks) {
  std::packaged_task<void()> signal_finished{[] {}};
  std::string steps;

  auto queue = Queue();
  queue.Enqueue([&] {
    // Queue everything from the queue to ensure nothing completes before we
    // cancel.

    queue.EnqueueAllowingSameQueue([&steps] { steps += '1'; });

    DelayedOperation delayed_operation = queue.EnqueueWithDelay(
        AsyncQueue::Milliseconds(1), kTimerId1, [&steps] { steps += '2'; });

    queue.EnqueueWithDelay(AsyncQueue::Milliseconds(5), kTimerId2,
                           [&steps, &signal_finished] {
                             steps += '3';
                             signal_finished();
                           });

    EXPECT_TRUE(queue.ContainsOperationWithTimerId(kTimerId1));
    delayed_operation.Cancel();
    EXPECT_FALSE(queue.ContainsOperationWithTimerId(kTimerId1));
  });

  const auto status =
      signal_finished.get_future().wait_for(std::chrono::seconds(1));
  EXPECT_EQ(status, std::future_status::ready);
  EXPECT_EQ(steps, "13");
}

TEST(AsyncQueue, CanManuallyDrainAllDelayedCallbacksForTesting) {
  std::string steps;

  auto queue = Queue();
  queue.Enqueue([&steps] { steps += '1'; });
  queue.EnqueueWithDelay(AsyncQueue::Milliseconds(20000), kTimerId1,
                         [&steps] { steps += '4'; });
  queue.EnqueueWithDelay(AsyncQueue::Milliseconds(10000), kTimerId2,
                         [&steps] { steps += '3'; });
  queue.Enqueue([&steps] { steps += '2'; });

  queue.RunDelayedOperationsUntil(TimerId::All);
  EXPECT_EQ(steps, "1234");
}

TEST(AsyncQueue, CanManuallyDrainSpecificDelayedCallbacksForTesting) {
  std::string steps;

  auto queue = Queue();
  queue.Enqueue([&] { steps += '1'; });
  queue.EnqueueWithDelay(AsyncQueue::Milliseconds(20000), kTimerId1,
                         [&steps] { steps += '5'; });
  queue.EnqueueWithDelay(AsyncQueue::Milliseconds(10000), kTimerId2,
                         [&steps] { steps += '3'; });
  queue.EnqueueWithDelay(AsyncQueue::Milliseconds(15000), kTimerId3,
                         [&steps] { steps += '4'; });
  queue.Enqueue([&] { steps += '2'; });

  queue.RunDelayedOperationsUntil(kTimerId3);
  EXPECT_EQ(steps, "1234");
}


}  // namespace util
}  // namespace firestore
}  // namespace firebase
