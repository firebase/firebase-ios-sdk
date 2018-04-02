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
#include <utility>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {
const auto underlying_queue =
    dispatch_queue_create("AsyncQueueTests", DISPATCH_QUEUE_SERIAL);

AsyncQueue Queue() {
  return AsyncQueue{underlying_queue};
}
}  // namespace

TEST(AsyncQueue, SimpleUsage) {
  std::packaged_task<void()> signal_finished{[] {}};

  auto queue = Queue();
  queue.Enqueue([&] { signal_finished(); });

  const auto status =
      signal_finished.get_future().wait_for(std::chrono::seconds(1));
  EXPECT_EQ(status, std::future_status::ready);
}

TEST(AsyncQueue, EnqueuedTasksCannotSpawnEnqueuedTasks) {
  std::packaged_task<void()> signal_finished{[] {}};

  auto queue = Queue();
  queue.Enqueue([&] {  // clang-format off
    EXPECT_ANY_THROW(queue.Enqueue([&] { signal_finished(); }););
    // clang-format on
  });

  signal_finished.get_future().wait_for(std::chrono::seconds(1));
}

TEST(AsyncQueue, EnqueuedTasksCanCallEnqueueAllowingSameQueue) {
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
      unwrap->first->Enqueue([unwrap] {
          (*unwrap->second)();
          });
      });

  const auto status =
      signal_finished.get_future().wait_for(std::chrono::seconds(1));
  EXPECT_EQ(status, std::future_status::ready);
}

// 9 (void)testDispatchSyncBlocksSubmissionFromTasksOnTheQueue {
// 8 (void)testVerifyIsCurrentQueueActuallyRequiresCurrentQueue {
// 7 (void)testVerifyIsCurrentQueueRequiresOperationIsInProgress {
// 6 (void)testVerifyIsCurrentQueueWorksWithOperationIsInProgress {
// 5 (void)testEnterCheckedOperationDisallowsNesting {
// 4 (void)testCanScheduleCallbacksInTheFuture {
// 3 (void)testCanCancelDelayedCallbacks {
// 2 (void)testCanManuallyDrainAllDelayedCallbacksForTesting {
// 1 (void)testCanManuallyDrainSpecificDelayedCallbacksForTesting {

}  // namespace util
}  // namespace firestore
}  // namespace firebase
