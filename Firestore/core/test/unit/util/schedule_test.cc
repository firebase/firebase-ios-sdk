/*
 * Copyright 2020 Google LLC
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

#include "Firestore/core/src/util/schedule.h"

#include <chrono>  // NOLINT(build/c++11)
#include <cstdlib>
#include <string>

#include "Firestore/core/src/util/task.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "Firestore/core/test/unit/testutil/time_testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace chr = std::chrono;

using testutil::kTimeout;
using testutil::Now;

class ScheduleTest : public ::testing::Test, public testutil::AsyncTest {
 public:
  ScheduleTest() : start_time{Now()} {
  }

  Schedule schedule;
  Schedule::TimePoint start_time;

  void Push(int value, Schedule::TimePoint target_time) {
    auto task = Task::Create(nullptr, target_time, value, 0u, [] {});
    schedule.Push(task);
  }

  int PopIfDue() {
    return Value(schedule.PopIfDue());
  }

  int PopBlocking() {
    return Value(schedule.PopBlocking());
  }

  int Value(Task* task) {
    if (task) {
      int result = task->tag();
      task->Release();
      return result;
    } else {
      return -1;
    }
  }
};

// Schedule tests

#define ASSERT_NONE_DUE() ASSERT_EQ(schedule.PopIfDue(), nullptr)
#define EXPECT_NONE_DUE() EXPECT_EQ(schedule.PopIfDue(), nullptr)

TEST_F(ScheduleTest, PopIfDue_Immediate) {
  EXPECT_NONE_DUE();

  // Push values in a deliberately non-sorted order.
  Push(3, start_time);
  Push(1, start_time);
  Push(2, start_time);
  EXPECT_FALSE(schedule.empty());
  EXPECT_EQ(schedule.size(), 3u);

  EXPECT_EQ(PopIfDue(), 3);
  EXPECT_EQ(PopIfDue(), 1);
  EXPECT_EQ(PopIfDue(), 2);
  EXPECT_NONE_DUE();
  EXPECT_TRUE(schedule.empty());
  EXPECT_EQ(schedule.size(), 0u);
}

TEST_F(ScheduleTest, PopIfDue_Delayed) {
  Push(1, start_time + chr::milliseconds(5));
  Push(2, start_time + chr::milliseconds(3));
  Push(3, start_time + chr::milliseconds(1));

  SleepFor(5);

  EXPECT_EQ(PopIfDue(), 3);
  EXPECT_EQ(PopIfDue(), 2);
  EXPECT_EQ(PopIfDue(), 1);
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, PopBlocking) {
  Push(1, start_time + chr::milliseconds(3));
  EXPECT_NONE_DUE();

  EXPECT_EQ(PopBlocking(), 1);
  EXPECT_GE(Now(), start_time + chr::milliseconds(3));
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, RemoveIf) {
  Push(1, start_time);
  Push(2, Now() + chr::minutes(1));

  auto maybe_removed =
      schedule.RemoveIf([](const Task& t) { return t.tag() == 1; });
  EXPECT_EQ(Value(maybe_removed), 1);

  // Non-existent value.
  maybe_removed = schedule.RemoveIf([](const Task& t) { return t.tag() == 1; });
  EXPECT_EQ(maybe_removed, nullptr);

  maybe_removed = schedule.RemoveIf([](const Task& t) { return t.tag() == 2; });
  EXPECT_EQ(Value(maybe_removed), 2);
  EXPECT_TRUE(schedule.empty());
}

TEST_F(ScheduleTest, Ordering) {
  Push(11, start_time + chr::milliseconds(5));
  Push(1, start_time);
  Push(2, start_time);
  Push(9, start_time + chr::milliseconds(2));
  Push(3, start_time);
  Push(10, start_time + chr::milliseconds(3));
  Push(12, start_time + chr::milliseconds(5));
  Push(4, start_time);
  Push(5, start_time);
  Push(6, start_time);
  Push(8, start_time + chr::milliseconds(1));
  Push(7, start_time);

  std::vector<int> values;
  while (!schedule.empty()) {
    values.push_back(PopBlocking());
  }
  const std::vector<int> expected = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
  EXPECT_EQ(values, expected);
}

TEST_F(ScheduleTest, AddingEntryUnblocksEmptyQueue) {
  const auto future = Async([&] {
    ASSERT_NONE_DUE();
    EXPECT_EQ(PopBlocking(), 1);
  });

  SleepFor(5);
  Push(1, start_time);
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingUnblocksOnNewPastDueEntries) {
  const auto far_away = start_time + chr::seconds(10);
  Push(5, far_away);

  const auto future = Async([&] {
    ASSERT_NONE_DUE();
    EXPECT_EQ(PopBlocking(), 3);
  });

  SleepFor(5);
  Push(3, start_time);
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingAdjustsWaitTimeOnNewSoonerEntries) {
  const auto far_away = start_time + chr::seconds(10);
  Push(5, far_away);

  const auto future = Async([&] {
    ASSERT_NONE_DUE();
    EXPECT_EQ(PopBlocking(), 3);
    // Make sure schedule hasn't been waiting longer than necessary.
    EXPECT_LT(Now(), far_away);
  });

  SleepFor(5);
  Push(3, start_time + chr::milliseconds(100));
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingCanReadjustTimeIfSeveralElementsAreAdded) {
  const auto far_away = start_time + chr::seconds(5);
  const auto very_far_away = start_time + chr::seconds(10);
  Push(3, very_far_away);

  const auto future = Async([&] {
    ASSERT_NONE_DUE();
    EXPECT_EQ(PopBlocking(), 1);
    EXPECT_LT(Now(), far_away);
  });

  SleepFor(5);
  Push(2, far_away);
  SleepFor(1);
  Push(1, start_time + chr::milliseconds(100));
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingNoticesRemovals) {
  const auto future = Async([&] {
    Push(1, start_time + chr::milliseconds(50));
    Push(2, start_time + chr::milliseconds(100));
    ASSERT_NONE_DUE();
    EXPECT_EQ(PopBlocking(), 2);
  });

  while (schedule.empty()) {
    SleepFor(1);
  }
  const auto maybe_removed =
      schedule.RemoveIf([](const Task& t) { return t.tag() == 1; });
  EXPECT_EQ(Value(maybe_removed), 1);
  Await(future);
}

TEST_F(ScheduleTest, PopBlockingIsNotAffectedByIrrelevantRemovals) {
  const auto future = Async([&] {
    Push(1, start_time + chr::milliseconds(50));
    Push(2, start_time + chr::seconds(10));
    ASSERT_NONE_DUE();
    EXPECT_EQ(PopBlocking(), 1);
  });

  // Wait (with timeout) for both values to appear in the schedule.
  while (schedule.size() != 2) {
    if (Now() - start_time >= kTimeout) {
      FAIL() << "Timed out.";
    }
    SleepFor(1);
  }
  const auto maybe_removed =
      schedule.RemoveIf([](const Task& t) { return t.tag() == 2; });
  EXPECT_EQ(Value(maybe_removed), 2);
  Await(future);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
