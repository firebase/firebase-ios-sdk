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

#include "Firestore/core/test/firebase/firestore/util/executor_test.h"

#include <chrono>  // NOLINT(build/c++11)
#include <cstdlib>
#include <future>  // NOLINT(build/c++11)
#include <string>
#include <thread>  // NOLINT(build/c++11)

#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "Firestore/core/test/firebase/firestore/testutil/async_testing.h"
#include "Firestore/core/test/firebase/firestore/testutil/time_testing.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace chr = std::chrono;

using async::Schedule;
using testutil::kTimeout;
using testutil::Now;

class ScheduleTest : public ::testing::Test, public testutil::AsyncTest {
 public:
  ScheduleTest() : start_time{Now()} {
  }

  using ScheduleT = Schedule<int>;

  ScheduleT schedule;
  ScheduleT::TimePoint start_time;
};

// Schedule tests

TEST_F(ScheduleTest, PopIfDue_Immediate) {
  EXPECT_FALSE(schedule.PopIfDue().has_value());

  // Push values in a deliberately non-sorted order.
  schedule.Push(3, start_time);
  schedule.Push(1, start_time);
  schedule.Push(2, start_time);
  EXPECT_FALSE(schedule.empty());
  EXPECT_EQ(schedule.size(), 3u);

  EXPECT_EQ(schedule.PopIfDue().value(), 3);
  EXPECT_EQ(schedule.PopIfDue().value(), 1);
  EXPECT_EQ(schedule.PopIfDue().value(), 2);
  EXPECT_FALSE(schedule.PopIfDue().has_value());
  EXPECT_TRUE(schedule.empty());
  EXPECT_EQ(schedule.size(), 0u);
}

TEST_F(ScheduleTest, PopIfDue_Delayed) {
  schedule.Push(1, start_time + chr::milliseconds(5));
  schedule.Push(2, start_time + chr::milliseconds(3));
  schedule.Push(3, start_time + chr::milliseconds(1));

  std::this_thread::sleep_for(chr::milliseconds(5));

  EXPECT_EQ(schedule.PopIfDue().value(), 3);
  EXPECT_EQ(schedule.PopIfDue().value(), 2);
  EXPECT_EQ(schedule.PopIfDue().value(), 1);
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, PopBlocking) {
  schedule.Push(1, start_time + chr::milliseconds(3));
  EXPECT_FALSE(schedule.PopIfDue().has_value());

  EXPECT_EQ(schedule.PopBlocking(), 1);
  EXPECT_GE(Now(), start_time + chr::milliseconds(3));
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, RemoveIf) {
  schedule.Push(1, start_time);
  schedule.Push(2, Now() + chr::minutes(1));

  auto maybe_removed = schedule.RemoveIf([](const int v) { return v == 1; });
  EXPECT_TRUE(maybe_removed.has_value());
  EXPECT_EQ(maybe_removed.value(), 1);

  // Non-existent value.
  maybe_removed = schedule.RemoveIf([](const int v) { return v == 1; });
  EXPECT_FALSE(maybe_removed.has_value());

  maybe_removed = schedule.RemoveIf([](const int v) { return v == 2; });
  EXPECT_TRUE(maybe_removed.has_value());
  EXPECT_EQ(maybe_removed.value(), 2);
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
  while (!schedule.empty()) {
    values.push_back(schedule.PopBlocking());
  }
  const std::vector<int> expected = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
  EXPECT_EQ(values, expected);
}

TEST_F(ScheduleTest, AddingEntryUnblocksEmptyQueue) {
  const auto future = Async([&] {
    ASSERT_FALSE(schedule.PopIfDue().has_value());
    EXPECT_EQ(schedule.PopBlocking(), 1);
  });

  std::this_thread::sleep_for(chr::milliseconds(5));
  schedule.Push(1, start_time);
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingUnblocksOnNewPastDueEntries) {
  const auto far_away = start_time + chr::seconds(10);
  schedule.Push(5, far_away);

  const auto future = Async([&] {
    ASSERT_FALSE(schedule.PopIfDue().has_value());
    EXPECT_EQ(schedule.PopBlocking(), 3);
  });

  std::this_thread::sleep_for(chr::milliseconds(5));
  schedule.Push(3, start_time);
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingAdjustsWaitTimeOnNewSoonerEntries) {
  const auto far_away = start_time + chr::seconds(10);
  schedule.Push(5, far_away);

  const auto future = Async([&] {
    ASSERT_FALSE(schedule.PopIfDue().has_value());
    EXPECT_EQ(schedule.PopBlocking(), 3);
    // Make sure schedule hasn't been waiting longer than necessary.
    EXPECT_LT(Now(), far_away);
  });

  std::this_thread::sleep_for(chr::milliseconds(5));
  schedule.Push(3, start_time + chr::milliseconds(100));
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingCanReadjustTimeIfSeveralElementsAreAdded) {
  const auto far_away = start_time + chr::seconds(5);
  const auto very_far_away = start_time + chr::seconds(10);
  schedule.Push(3, very_far_away);

  const auto future = Async([&] {
    ASSERT_FALSE(schedule.PopIfDue().has_value());
    EXPECT_EQ(schedule.PopBlocking(), 1);
    EXPECT_LT(Now(), far_away);
  });

  SleepFor(5);
  schedule.Push(2, far_away);
  SleepFor(1);
  schedule.Push(1, start_time + chr::milliseconds(100));
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingNoticesRemovals) {
  const auto future = Async([&] {
    schedule.Push(1, start_time + chr::milliseconds(50));
    schedule.Push(2, start_time + chr::milliseconds(100));
    ASSERT_FALSE(schedule.PopIfDue().has_value());
    EXPECT_EQ(schedule.PopBlocking(), 2);
  });

  while (schedule.empty()) {
    SleepFor(1);
  }
  const auto maybe_removed =
      schedule.RemoveIf([](const int v) { return v == 1; });
  EXPECT_EQ(maybe_removed.value(), 1);
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingIsNotAffectedByIrrelevantRemovals) {
  const auto future = Async([&] {
    schedule.Push(1, start_time + chr::milliseconds(50));
    schedule.Push(2, start_time + chr::seconds(10));
    ASSERT_FALSE(schedule.PopIfDue().has_value());
    EXPECT_EQ(schedule.PopBlocking(), 1);
  });

  // Wait (with timeout) for both values to appear in the schedule.
  while (schedule.size() != 2) {
    if (Now() - start_time >= kTimeout) {
      FAIL() << "Timed out.";
    }
    std::this_thread::sleep_for(chr::milliseconds(1));
  }
  const auto maybe_removed =
      schedule.RemoveIf([](const int v) { return v == 2; });
  ASSERT_TRUE(maybe_removed.has_value());
  EXPECT_EQ(maybe_removed.value(), 2);
  Await(future);
}

// ExecutorStd tests

namespace {

inline std::unique_ptr<Executor> ExecutorFactory(int threads) {
  return absl::make_unique<ExecutorStd>(threads);
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(ExecutorTestStd,
                         ExecutorTest,
                         ::testing::Values(ExecutorFactory));

}  // namespace util
}  // namespace firestore
}  // namespace firebase
