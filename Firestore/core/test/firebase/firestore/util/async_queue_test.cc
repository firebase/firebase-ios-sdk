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
#include <thread>

#include <gtest/gtest.h>

namespace firebase {
namespace firestore {
namespace util {

namespace {

const auto kTimeout = std::chrono::seconds(5);

class AsyncQueueTest : public ::testing::Test {
 public:
  AsyncQueueTest() : signal_finished{[] {}} {
  }

  // Googletest doesn't contain built-in functionality to block until an async
  // operation completes, and there is no timeout by default. Work around both
  // by resolving a packaged_task in the async operation and blocking on the
  // associated future (with timeout).
  bool WaitForTestToFinish() {
    return signal_finished.get_future().wait_for(kTimeout) ==
           std::future_status::ready;
  }

  AsyncQueue queue;
  std::packaged_task<void()> signal_finished;
};

}  // namespace

// Schedule tests

TEST(ScheduleTest, Foo) {
  namespace chr = std::chrono;
  const auto now = [] {
    return chr::time_point_cast<Schedule<int>::Duration>(
        chr::system_clock::now());
  };

  Schedule<int> schedule;
  EXPECT_FALSE(schedule.PopIfDue(nullptr));
  schedule.Push(3, now());
  schedule.Push(1, now());
  schedule.Push(2, now());
  EXPECT_FALSE(schedule.empty());

  int out = 0;
  const auto pop = [&] {
    const bool result = schedule.PopIfDue(&out);
    EXPECT_TRUE(result);
    return out;
  };
  EXPECT_EQ(pop(), 3);
  EXPECT_EQ(pop(), 1);
  EXPECT_EQ(pop(), 2);
  EXPECT_FALSE(schedule.PopIfDue(nullptr));
  EXPECT_TRUE(schedule.empty());

  out = 0;
  auto time_point = now();
  schedule.Push(1, time_point + chr::milliseconds(5));
  schedule.Push(2, time_point + chr::milliseconds(3));
  schedule.Push(3, time_point + chr::milliseconds(1));
  EXPECT_FALSE(schedule.PopIfDue(&out));
  std::this_thread::sleep_for(chr::milliseconds(5));
  EXPECT_EQ(pop(), 3);
  EXPECT_EQ(pop(), 2);
  EXPECT_EQ(pop(), 1);
  EXPECT_TRUE(schedule.empty());

  out = 0;
  time_point = now();
  schedule.Push(1, time_point + chr::milliseconds(3));
  EXPECT_FALSE(schedule.PopIfDue(&out));
  schedule.PopBlocking(&out);
  EXPECT_EQ(out, 1);
  EXPECT_GE(now(), time_point + chr::milliseconds(3));
  EXPECT_TRUE(schedule.empty());

  out = 0;
  schedule.Push(1, now());
  schedule.Push(2, now() + chr::minutes(1));
  EXPECT_TRUE(schedule.RemoveIf(&out, [](const int v) { return v == 1; }));
  EXPECT_EQ(out, 1);
  EXPECT_TRUE(schedule.RemoveIf(&out, [](const int v) { return v == 2; }));
  EXPECT_EQ(out, 2);
  EXPECT_TRUE(schedule.empty());

  std::vector<int> values;
  const auto append = [&] {
    values.push_back(0);
    schedule.PopBlocking(&values.back());
  };
  time_point = now();
  schedule.Push(11, time_point + chr::milliseconds(5));
  schedule.Push(1, time_point);
  schedule.Push(2, time_point);
  schedule.Push(9, time_point + chr::milliseconds(2));
  schedule.Push(3, time_point);
  schedule.Push(10, time_point + chr::milliseconds(3));
  schedule.Push(12, time_point + chr::milliseconds(5));
  schedule.Push(4, time_point);
  schedule.Push(5, time_point);
  schedule.Push(6, time_point);
  schedule.Push(8, time_point + chr::milliseconds(1));
  schedule.Push(7, time_point);
  while (!schedule.empty()) {
    append();
  }
  const std::vector<int> expected = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
  EXPECT_EQ(values, expected);

  out = 0;
  std::async(std::launch::async, [&] {
    schedule.Push(1, now());
  });
  schedule.PopBlocking(&out);
  EXPECT_EQ(out, 1);

  out = 0;
  schedule.Push(5, now() + chr::seconds(10));
  std::async(std::launch::async, [&] {
    schedule.Push(3, now());
  });
  schedule.PopBlocking(&out);
  EXPECT_EQ(out, 3);
}

// AsyncQueue tests

TEST_F(AsyncQueueTest, Enqueue) {
  queue.Enqueue([&] { signal_finished(); });
  EXPECT_TRUE(WaitForTestToFinish());
}

TEST_F(AsyncQueueTest, CanScheduleOperationsInTheFuture) {
  std::string steps;

  queue.Enqueue([&steps] { steps += '1'; });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(5), [&] {
    steps += '4';
    signal_finished();
  });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(1),
                          [&steps] { steps += '3'; });
  queue.Enqueue([&steps] { steps += '2'; });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_EQ(steps, "1234");
}

TEST_F(AsyncQueueTest, CanCancelDelayedCallbacks) {
  std::string steps;

  queue.Enqueue([&] {
    // Queue everything from the queue to ensure nothing completes before we
    // cancel.

    queue.Enqueue([&steps] { steps += '1'; });

    DelayedOperation delayed_operation = queue.EnqueueAfterDelay(
        AsyncQueue::Milliseconds(1), [&steps] { steps += '2'; });

    queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(5), [&] {
      steps += '3';
      signal_finished();
    });

    delayed_operation.Cancel();
  });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_EQ(steps, "13");
}

TEST_F(AsyncQueueTest, DelayedOperationIsValidAfterTheOperationHasRun) {
  DelayedOperation delayed_operation = queue.EnqueueAfterDelay(
      AsyncQueue::Milliseconds(1), [&] { signal_finished(); });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_NO_THROW(delayed_operation.Cancel());
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
