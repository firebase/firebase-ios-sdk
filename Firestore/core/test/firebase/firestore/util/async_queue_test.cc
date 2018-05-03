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

#include "Firestore/core/test/firebase/firestore/util/async_queue_test.h"

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)
#include <string>

#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

// In these generic tests the specific timer ids don't matter.
const TimerId kTimerId1 = TimerId::ListenStreamConnectionBackoff;
const TimerId kTimerId2 = TimerId::ListenStreamIdle;
const TimerId kTimerId3 = TimerId::WriteStreamConnectionBackoff;

}  // namespace

TEST_P(AsyncQueueTest, Enqueue) {
  queue.Enqueue([&] { signal_finished(); });
  EXPECT_TRUE(WaitForTestToFinish());
}

TEST_P(AsyncQueueTest, EnqueueDisallowsNesting) {
  queue.Enqueue([&] {  // clang-format off
    // clang-format on
    EXPECT_ANY_THROW(queue.Enqueue([] {}));
    signal_finished();
  });

  EXPECT_TRUE(WaitForTestToFinish());
}

TEST_P(AsyncQueueTest, EnqueueRelaxedWorksFromWithinEnqueue) {
  queue.Enqueue([&] {  // clang-format off
    queue.EnqueueRelaxed([&] { signal_finished(); });
    // clang-format on
  });

  EXPECT_TRUE(WaitForTestToFinish());
}

TEST_P(AsyncQueueTest, EnqueueBlocking) {
  bool finished = false;
  queue.EnqueueBlocking([&] { finished = true; });
  EXPECT_TRUE(finished);
}

TEST_P(AsyncQueueTest, EnqueueBlockingDisallowsNesting) {
  queue.EnqueueBlocking([&] {  // clang-format off
    EXPECT_ANY_THROW(queue.EnqueueBlocking([] {}););
    // clang-format on
  });
}

TEST_P(AsyncQueueTest, ExecuteBlockingDisallowsNesting) {
  queue.EnqueueBlocking(
      [&] { EXPECT_ANY_THROW(queue.ExecuteBlocking([] {});); });
}

TEST_P(AsyncQueueTest, VerifyIsCurrentQueueWorksWithOperationInProgress) {
  queue.EnqueueBlocking([&] { EXPECT_NO_THROW(queue.VerifyIsCurrentQueue()); });
}

TEST_P(AsyncQueueTest, CanScheduleOperationsInTheFuture) {
  std::string steps;

  queue.Enqueue([&steps] { steps += '1'; });
  queue.Enqueue([&] {
    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(5), kTimerId1, [&] {
      steps += '4';
      signal_finished();
    });
    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(1), kTimerId2,
                            [&steps] { steps += '3'; });
    queue.EnqueueRelaxed([&steps] { steps += '2'; });
  });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_EQ(steps, "1234");
}

TEST_P(AsyncQueueTest, CanCancelDelayedOperations) {
  std::string steps;

  queue.Enqueue([&] {
    // Queue everything from the queue to ensure nothing completes before we
    // cancel.

    queue.EnqueueRelaxed([&steps] { steps += '1'; });

    DelayedOperation delayed_operation = queue.EnqueueAfterDelay(
        AsyncQueue::Milliseconds(1), kTimerId1, [&steps] { steps += '2'; });

    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(5), kTimerId2, [&] {
      steps += '3';
      signal_finished();
    });

    EXPECT_TRUE(queue.IsScheduled(kTimerId1));
    delayed_operation.Cancel();
    EXPECT_FALSE(queue.IsScheduled(kTimerId1));
  });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_EQ(steps, "13");
  EXPECT_FALSE(queue.IsScheduled(kTimerId1));
}

TEST_P(AsyncQueueTest, CanCallCancelOnDelayedOperationAfterTheOperationHasRun) {
  DelayedOperation delayed_operation;
  queue.Enqueue([&] {
    delayed_operation = queue.EnqueueAfterDelay(
        AsyncQueue::Milliseconds(10), kTimerId1, [&] { signal_finished(); });
    EXPECT_TRUE(queue.IsScheduled(kTimerId1));
  });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_FALSE(queue.IsScheduled(kTimerId1));
  EXPECT_NO_THROW(delayed_operation.Cancel());
}

TEST_P(AsyncQueueTest, CanManuallyDrainAllDelayedOperationsForTesting) {
  std::string steps;

  queue.Enqueue([&] {
    queue.EnqueueRelaxed([&steps] { steps += '1'; });
    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(20000), kTimerId1,
                            [&] { steps += '4'; });
    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(10000), kTimerId2,
                            [&steps] { steps += '3'; });
    queue.EnqueueRelaxed([&steps] { steps += '2'; });
    signal_finished();
  });

  EXPECT_TRUE(WaitForTestToFinish());
  queue.RunScheduledOperationsUntil(TimerId::All);
  EXPECT_EQ(steps, "1234");
}

TEST_P(AsyncQueueTest, CanManuallyDrainSpecificDelayedOperationsForTesting) {
  std::string steps;

  queue.Enqueue([&] {
    queue.EnqueueRelaxed([&] { steps += '1'; });
    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(20000), kTimerId1,
                            [&steps] { steps += '5'; });
    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(10000), kTimerId2,
                            [&steps] { steps += '3'; });
    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(15000), kTimerId3,
                            [&steps] { steps += '4'; });
    queue.EnqueueRelaxed([&] { steps += '2'; });
    signal_finished();
  });

  EXPECT_TRUE(WaitForTestToFinish());
  queue.RunScheduledOperationsUntil(kTimerId3);
  EXPECT_EQ(steps, "1234");
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
