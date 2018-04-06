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

#include <stdlib.h>
#include <chrono>
#include <future>
#include <string>
#include <thread>

#include <iostream>

#include <gtest/gtest.h>

namespace firebase {
namespace firestore {
namespace util {

namespace {

namespace chr = std::chrono;

chr::time_point<std::chrono::system_clock, chr::milliseconds> now() {
  return chr::time_point_cast<chr::milliseconds>(chr::system_clock::now());
}

const auto kTimeout = std::chrono::seconds(5);

struct TimeoutMixin {
  TimeoutMixin() : signal_finished{[] {}} {
  }

  // Googletest doesn't contain built-in functionality to block until an async
  // operation completes, and there is no timeout by default. Work around both
  // by resolving a packaged_task in the async operation and blocking on the
  // associated future (with timeout).
  bool WaitForTestToFinish() {
    return signal_finished.get_future().wait_for(kTimeout) ==
           std::future_status::ready;
  }

  std::packaged_task<void()> signal_finished;
};

class ScheduleTest : public TimeoutMixin, public ::testing::Test {
 public:
  ScheduleTest() : start_time{now()} {
  }

  using ScheduleT = Schedule<int>;

  int TryPop() {
    int read = -1;
    schedule.PopIfDue(&read);
    return read;
  }

  ScheduleT schedule;
  ScheduleT::TimePoint start_time;
  int out = 0;
};

}  // namespace

// Schedule tests

TEST_F(ScheduleTest, PopIfDue_Immediate) {
  EXPECT_FALSE(schedule.PopIfDue(nullptr));

  schedule.Push(3, start_time);
  schedule.Push(1, start_time);
  schedule.Push(2, start_time);
  EXPECT_FALSE(schedule.empty());

  EXPECT_EQ(TryPop(), 3);
  EXPECT_EQ(TryPop(), 1);
  EXPECT_EQ(TryPop(), 2);
  EXPECT_FALSE(schedule.PopIfDue(nullptr));
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, PopIfDue_Delayed) {
  schedule.Push(1, start_time + chr::milliseconds(5));
  schedule.Push(2, start_time + chr::milliseconds(3));
  schedule.Push(3, start_time + chr::milliseconds(1));

  EXPECT_FALSE(schedule.PopIfDue(&out));
  std::this_thread::sleep_for(chr::milliseconds(5));

  EXPECT_EQ(TryPop(), 3);
  EXPECT_EQ(TryPop(), 2);
  EXPECT_EQ(TryPop(), 1);
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, PopBlocking) {
  schedule.Push(1, start_time + chr::milliseconds(3));
  EXPECT_FALSE(schedule.PopIfDue(&out));

  schedule.PopBlocking(&out);
  EXPECT_EQ(out, 1);
  EXPECT_GE(now(), start_time + chr::milliseconds(3));
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, RemoveIf) {
  schedule.Push(1, start_time);
  schedule.Push(2, now() + chr::minutes(1));
  EXPECT_TRUE(schedule.RemoveIf(&out, [](const int v) { return v == 1; }));
  EXPECT_EQ(out, 1);
  EXPECT_TRUE(schedule.RemoveIf(&out, [](const int v) { return v == 2; }));
  EXPECT_EQ(out, 2);
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, Ordering) {
  schedule.Push(11, start_time + chr::milliseconds(5));
  schedule.Push(1, start_time);
  schedule.Push(2, start_time);
  schedule.Push(9, start_time + chr::milliseconds(2));
  schedule.Push(3, start_time);
  schedule.Push(10, start_time + chr::milliseconds(3));
  schedule.Push(12, start_time + chr::milliseconds(5));
  schedule.Push(4, start_time);
  schedule.Push(5, start_time);
  schedule.Push(6, start_time);
  schedule.Push(8, start_time + chr::milliseconds(1));
  schedule.Push(7, start_time);

  std::vector<int> values;
  const auto append = [&] {
    values.push_back(0);
    schedule.PopBlocking(&values.back());
  };
  while (!schedule.empty()) {
    append();
  }
  const std::vector<int> expected = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
  EXPECT_EQ(values, expected);
}

TEST_F(ScheduleTest, AddingEntryUnblocksEmptyQueue) {
  const auto future = std::async(std::launch::async, [&] {
    ASSERT_FALSE(schedule.PopIfDue(&out));
    schedule.PopBlocking(&out);
    EXPECT_EQ(out, 1);
    signal_finished();
  });

  std::this_thread::sleep_for(chr::milliseconds(5));
  schedule.Push(1, start_time);
  // Unfortunately, the future returned from std::async blocks in its destructor
  // until the async call is finished. If PopBlocking is buggy and hangs
  // forever, the future's destructor will also hang forever. To avoid all tests
  // freezing, the only thing to do is to abort (which skips destructors).
  if (!WaitForTestToFinish()) {
    ADD_FAILURE();
    std::abort();
  }
}

TEST_F(ScheduleTest, PopBlockingUnblocksOnNewImmediateEntries) {
  schedule.Push(5, start_time + chr::seconds(10));

  const auto future = std::async(std::launch::async, [&] {
      std::this_thread::sleep_for(chr::milliseconds(1));
      schedule.Push(3, start_time);
      if (!WaitForTestToFinish()) {
        ADD_FAILURE();
        std::abort();
      }
  });

  ASSERT_FALSE(schedule.PopIfDue(&out));
  schedule.PopBlocking(&out);
  EXPECT_EQ(out, 3);
  signal_finished();
}

TEST_F(ScheduleTest, PopBlockingAdjustsWaitTimeOnNewSoonerEntries) {
  const auto far_away = start_time + chr::seconds(10);
  schedule.Push(5, far_away);

  const auto future = std::async(std::launch::async, [&] {
      std::this_thread::sleep_for(chr::milliseconds(1));
      schedule.Push(3, start_time + chr::milliseconds(100));
      if (!WaitForTestToFinish()) {
        ADD_FAILURE();
        std::abort();
      }
  });

  ASSERT_FALSE(schedule.PopIfDue(&out));
  schedule.PopBlocking(&out);
  EXPECT_EQ(out, 3);
  EXPECT_LE(now(), far_away);
  signal_finished();
}

// AsyncQueue tests

namespace {

class AsyncQueueTest : public TimeoutMixin, public ::testing::Test {
 public:
  AsyncQueue queue;
};

}  // namespace

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

}  // namespace firestore
}  // namespace firebase
}  // namespace firebase
