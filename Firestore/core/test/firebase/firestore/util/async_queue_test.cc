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

#include <chrono>  // NOLINT(build/c++11)
#include <cstdlib>
#include <future>  // NOLINT(build/c++11)
#include <string>
#include <thread>  // NOLINT(build/c++11)

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

namespace chr = std::chrono;

chr::time_point<std::chrono::system_clock, chr::milliseconds> now() {
  return chr::time_point_cast<AsyncQueue::Milliseconds>(
      chr::system_clock::now());
}

const auto kTimeout = std::chrono::seconds(5);

// Waits for the future to become ready and returns whether it timed out.
bool WaitForFuture(const std::future<void>& future,
                   const chr::milliseconds timeout = kTimeout) {
  return future.wait_for(timeout) == std::future_status::ready;
}

// Unfortunately, the future returned from std::async blocks in its destructor
// until the async call is finished. If the function called from std::async is
// buggy and hangs forever, the future's destructor will also hang forever. To
// avoid all tests freezing, the only thing to do is to abort (which skips
// destructors).
void Abort() {
  ADD_FAILURE();
  std::abort();
}

// Calls std::abort if the future times out.
void AbortOnTimeout(const std::future<void>& future) {
  if (!WaitForFuture(future, kTimeout)) {
    Abort();
  }
}

// The macro calls AbortOnTimeout, but preserves stack trace.
#define ABORT_ON_TIMEOUT(future)                            \
  do {                                                      \
    SCOPED_TRACE("Async operation timed out, aborting..."); \
    AbortOnTimeout(future);                                 \
  } while (0)

class ScheduleTest : public ::testing::Test {
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

  // Push values in a deliberately non-sorted order.
  schedule.Push(3, start_time);
  schedule.Push(1, start_time);
  schedule.Push(2, start_time);
  EXPECT_FALSE(schedule.empty());
  EXPECT_EQ(schedule.size(), 3u);

  EXPECT_EQ(TryPop(), 3);
  EXPECT_EQ(TryPop(), 1);
  EXPECT_EQ(TryPop(), 2);
  EXPECT_FALSE(schedule.PopIfDue(nullptr));
  EXPECT_TRUE(schedule.empty());
  EXPECT_EQ(schedule.size(), 0u);
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
  });

  std::this_thread::sleep_for(chr::milliseconds(5));
  schedule.Push(1, start_time);
  ABORT_ON_TIMEOUT(future);
}

TEST_F(ScheduleTest, PopBlockingUnblocksOnNewPastDueEntries) {
  const auto far_away = start_time + chr::seconds(10);
  schedule.Push(5, far_away);

  const auto future = std::async(std::launch::async, [&] {
    ASSERT_FALSE(schedule.PopIfDue(&out));
    schedule.PopBlocking(&out);
    EXPECT_EQ(out, 3);
  });

  std::this_thread::sleep_for(chr::milliseconds(5));
  schedule.Push(3, start_time);
  ABORT_ON_TIMEOUT(future);
}

TEST_F(ScheduleTest, PopBlockingAdjustsWaitTimeOnNewSoonerEntries) {
  const auto far_away = start_time + chr::seconds(10);
  schedule.Push(5, far_away);

  const auto future = std::async(std::launch::async, [&] {
    ASSERT_FALSE(schedule.PopIfDue(&out));
    schedule.PopBlocking(&out);
    EXPECT_EQ(out, 3);
    // Make sure schedule hasn't been waiting longer than necessary.
    EXPECT_LE(now(), far_away);
  });

  std::this_thread::sleep_for(chr::milliseconds(5));
  schedule.Push(3, start_time + chr::milliseconds(100));
  ABORT_ON_TIMEOUT(future);
}

TEST_F(ScheduleTest, PopBlockingCanReadjustTimeIfSeveralElementsAreAdded) {
  const auto far_away = start_time + chr::seconds(5);
  const auto very_far_away = start_time + chr::seconds(10);
  schedule.Push(3, very_far_away);

  const auto future = std::async(std::launch::async, [&] {
    ASSERT_FALSE(schedule.PopIfDue(&out));
    schedule.PopBlocking(&out);
    EXPECT_EQ(out, 1);
    EXPECT_LE(now(), far_away);
  });

  std::this_thread::sleep_for(chr::milliseconds(5));
  schedule.Push(2, far_away);
  std::this_thread::sleep_for(chr::milliseconds(1));
  schedule.Push(1, start_time + chr::milliseconds(100));
  ABORT_ON_TIMEOUT(future);
}

TEST_F(ScheduleTest, PopBlockingNoticesRemovals) {
  const auto future = std::async(std::launch::async, [&] {
    schedule.Push(1, start_time + chr::milliseconds(50));
    schedule.Push(2, start_time + chr::milliseconds(100));
    ASSERT_FALSE(schedule.PopIfDue(&out));
    schedule.PopBlocking(&out);
    EXPECT_EQ(out, 2);
  });

  while (schedule.empty()) {
    std::this_thread::sleep_for(chr::milliseconds(1));
  }
  const bool removed =
      schedule.RemoveIf(nullptr, [](const int v) { return v == 1; });
  EXPECT_TRUE(removed);
  ABORT_ON_TIMEOUT(future);
}

TEST_F(ScheduleTest, PopBlockingIsNotAffectedByIrrelevantRemovals) {
  const auto future = std::async(std::launch::async, [&] {
    schedule.Push(1, start_time + chr::milliseconds(50));
    schedule.Push(2, start_time + chr::seconds(10));
    ASSERT_FALSE(schedule.PopIfDue(&out));
    schedule.PopBlocking(&out);
    EXPECT_EQ(out, 1);
  });

  while (schedule.empty()) {
    std::this_thread::sleep_for(chr::milliseconds(1));
  }
  const bool removed =
      schedule.RemoveIf(nullptr, [](const int v) { return v == 2; });
  EXPECT_TRUE(removed);
  ABORT_ON_TIMEOUT(future);
}

// AsyncQueue tests

namespace {

class AsyncQueueTest : public ::testing::Test {
 public:
  AsyncQueueTest() : signal_finished{[] {}} {
  }

  // Googletest doesn't contain built-in functionality to block until an async
  // operation completes, and there is no timeout by default. Work around both
  // by resolving a packaged_task in the async operation and blocking on the
  // associated future (with timeout).
  bool WaitForTestToFinish(const chr::milliseconds timeout = kTimeout) {
    return WaitForFuture(signal_finished.get_future(), timeout);
  }

  // Used in async tests to notify the main thread that an opration has
  // finished.
  std::packaged_task<void()> signal_finished;
  AsyncQueue queue;
};

}  // namespace

TEST_F(AsyncQueueTest, Enqueue) {
  queue.Enqueue([&] { signal_finished(); });
  EXPECT_TRUE(WaitForTestToFinish());
}

TEST_F(AsyncQueueTest, DestructorDoesNotBlockIfThereArePendingTasks) {
  const auto future = std::async(std::launch::async, [&] {
    AsyncQueue another_queue;
    another_queue.EnqueueAfterDelay(chr::minutes(5), [] {});
    another_queue.EnqueueAfterDelay(chr::minutes(10), [] {});
    // Destructor shouldn't block waiting for the 5/10-minute-away operations.
  });

  ABORT_ON_TIMEOUT(future);
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

TEST_F(AsyncQueueTest, CanCancelDelayedOperations) {
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
