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

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

AsyncQueue Queue() {
  return AsyncQueue{
      dispatch_queue_create("AsyncQueueTests", DISPATCH_QUEUE_SERIAL)};
}

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

TEST(AsyncQueue, EnqueuedTasksCanEnqueueAllowingSameQueue) {
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

// - (void)testDispatchAsyncAllowingSameQueueActuallyAllowsSameQueue
// - (void)testDispatchAsyncAllowsSameQueueForUnownedActions {
// - (void)testDispatchSyncBlocksSubmissionFromTasksOnTheQueue {
// - (void)testVerifyIsCurrentQueueActuallyRequiresCurrentQueue {
// - (void)testVerifyIsCurrentQueueRequiresOperationIsInProgress {
// - (void)testVerifyIsCurrentQueueWorksWithOperationIsInProgress {
// - (void)testEnterCheckedOperationDisallowsNesting {
// - (void)testCanScheduleCallbacksInTheFuture {
// - (void)testCanCancelDelayedCallbacks {
// - (void)testCanManuallyDrainAllDelayedCallbacksForTesting {
// - (void)testCanManuallyDrainSpecificDelayedCallbacksForTesting {

}  // namespace util
}  // namespace firestore
}  // namespace firebase
