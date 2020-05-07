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

#include "Firestore/core/test/unit/util/executor_test.h"

#include <chrono>              // NOLINT(build/c++11)
#include <condition_variable>  // NOLINT(build/c++11)
#include <cstdlib>
#include <future>  // NOLINT(build/c++11)
#include <string>
#include <thread>  // NOLINT(build/c++11)

#include "Firestore/core/src/util/executor.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

namespace chr = std::chrono;

using testutil::Expectation;

DelayedOperation Schedule(Executor* const executor,
                          const Executor::Milliseconds delay,
                          Executor::Operation&& operation) {
  const Executor::Tag no_tag = -1;
  return executor->Schedule(delay, no_tag, std::move(operation));
}

}  // namespace

TEST_P(ExecutorTest, Execute) {
  Expectation ran;
  executor->Execute(ran.AsCallback());
  Await(ran);
}

TEST_P(ExecutorTest, ExecuteBlocking) {
  bool finished = false;
  executor->ExecuteBlocking([&] { finished = true; });
  EXPECT_TRUE(finished);
}

TEST_P(ExecutorTest, DestructorDoesNotBlockIfThereArePendingTasks) {
  const auto future = Async([&] {
    auto another_executor = GetParam()(/* threads */ 1);
    Schedule(another_executor.get(), chr::minutes(5), [] {});
    Schedule(another_executor.get(), chr::minutes(10), [] {});
    // Destructor shouldn't block waiting for the 5/10-minute-away operations.
  });

  Await(future);
}

// TODO(varconst): this test is inherently flaky because it can't be guaranteed
// that the enqueued asynchronous operation didn't finish before the code has
// a chance to even enqueue the next operation. Delays are chosen so that the
// test is unlikely to fail in practice. Need to revisit this.
TEST_P(ExecutorTest, CanScheduleOperationsInTheFuture) {
  std::string steps;
  Expectation ran;
  executor->Execute([&steps] { steps += '1'; });
  Schedule(executor.get(), Executor::Milliseconds(20), [&] {
    steps += '4';
    ran.Fulfill();
  });
  Schedule(executor.get(), Executor::Milliseconds(10),
           [&steps] { steps += '3'; });
  executor->Execute([&steps] { steps += '2'; });

  Await(ran);
  EXPECT_EQ(steps, "1234");
}

TEST_P(ExecutorTest, CanCancelDelayedOperations) {
  std::string steps;

  Expectation ran;
  executor->Execute([&] {
    executor->Execute([&steps] { steps += '1'; });

    DelayedOperation delayed_operation = Schedule(
        executor.get(), Executor::Milliseconds(1), [&steps] { steps += '2'; });

    Schedule(executor.get(), Executor::Milliseconds(5), [&] {
      steps += '3';
      ran.Fulfill();
    });

    delayed_operation.Cancel();
  });

  Await(ran);
  EXPECT_EQ(steps, "13");
}

TEST_P(ExecutorTest, DelayedOperationIsValidAfterTheOperationHasRun) {
  Expectation ran;

  DelayedOperation delayed_operation =
      Schedule(executor.get(), Executor::Milliseconds(1), ran.AsCallback());

  Await(ran);
  EXPECT_NO_THROW(delayed_operation.Cancel());
}

TEST_P(ExecutorTest, CancelingEmptyDelayedOperationIsValid) {
  DelayedOperation delayed_operation;
  EXPECT_NO_THROW(delayed_operation.Cancel());
}

TEST_P(ExecutorTest, DoubleCancelingDelayedOperationIsValid) {
  std::string steps;

  Expectation ran;
  executor->Execute([&] {
    DelayedOperation delayed_operation = Schedule(
        executor.get(), Executor::Milliseconds(1), [&steps] { steps += '1'; });
    Schedule(executor.get(), Executor::Milliseconds(5), [&] {
      steps += '2';
      ran.Fulfill();
    });

    delayed_operation.Cancel();
    delayed_operation.Cancel();
  });

  Await(ran);
  EXPECT_EQ(steps, "2");
}

TEST_P(ExecutorTest, IsCurrentExecutor) {
  EXPECT_FALSE(executor->IsCurrentExecutor());
  EXPECT_NE(executor->Name(), executor->CurrentExecutorName());

  executor->ExecuteBlocking([&] {
    EXPECT_TRUE(executor->IsCurrentExecutor());
    EXPECT_EQ(executor->Name(), executor->CurrentExecutorName());
  });

  executor->Execute([&] {
    EXPECT_TRUE(executor->IsCurrentExecutor());
    EXPECT_EQ(executor->Name(), executor->CurrentExecutorName());
  });

  Expectation ran;
  Schedule(executor.get(), Executor::Milliseconds(1), [&] {
    EXPECT_TRUE(executor->IsCurrentExecutor());
    EXPECT_EQ(executor->Name(), executor->CurrentExecutorName());
    ran.Fulfill();
  });

  Await(ran);
}

TEST_P(ExecutorTest, OperationsCanBeRemovedFromScheduleBeforeTheyRun) {
  const Executor::Tag tag_foo = 1;
  const Executor::Tag tag_bar = 2;

  // Make sure the schedule is empty.
  EXPECT_FALSE(executor->IsScheduled(tag_foo));
  EXPECT_FALSE(executor->IsScheduled(tag_bar));
  EXPECT_FALSE(executor->PopFromSchedule().has_value());

  // Add two operations to the schedule with different tags.

  // The exact delay doesn't matter as long as it's too far away to be executed
  // during the test.
  const auto far_away = chr::seconds(1);
  executor->Schedule(far_away, tag_foo, [] {});
  // Scheduled operations can be distinguished by their tag.
  EXPECT_TRUE(executor->IsScheduled(tag_foo));
  EXPECT_FALSE(executor->IsScheduled(tag_bar));

  // This operation will be scheduled after the previous one (operations
  // scheduled with the same delay are FIFO ordered).
  executor->Schedule(far_away, tag_bar, [] {});
  EXPECT_TRUE(executor->IsScheduled(tag_foo));
  EXPECT_TRUE(executor->IsScheduled(tag_bar));

  // Now pop the operations one by one without waiting for them to be executed,
  // check that operations are popped in the order they are scheduled and
  // preserve tags. Schedule should become empty as a result.

  auto maybe_operation = executor->PopFromSchedule();
  ASSERT_TRUE(maybe_operation.has_value());
  EXPECT_EQ(maybe_operation->tag, tag_foo);
  EXPECT_FALSE(executor->IsScheduled(tag_foo));
  EXPECT_TRUE(executor->IsScheduled(tag_bar));

  maybe_operation = executor->PopFromSchedule();
  ASSERT_TRUE(maybe_operation.has_value());
  EXPECT_EQ(maybe_operation->tag, tag_bar);
  EXPECT_FALSE(executor->IsScheduled(tag_bar));

  // Schedule should now be empty.
  EXPECT_FALSE(executor->PopFromSchedule().has_value());
}

TEST_P(ExecutorTest, DuplicateTagsOnOperationsAreAllowed) {
  const Executor::Tag tag_foo = 1;
  std::string steps;

  // Add two operations with the same tag to the schedule to verify that
  // duplicate tags are allowed.

  const auto far_away = chr::seconds(1);
  executor->Schedule(far_away, tag_foo, [&steps] { steps += '1'; });
  executor->Schedule(far_away, tag_foo, [&steps] { steps += '2'; });
  EXPECT_TRUE(executor->IsScheduled(tag_foo));

  auto maybe_operation = executor->PopFromSchedule();
  ASSERT_TRUE(maybe_operation.has_value());
  EXPECT_EQ(maybe_operation->tag, tag_foo);
  // There's still another operation with the same tag in the schedule.
  EXPECT_TRUE(executor->IsScheduled(tag_foo));

  maybe_operation->operation();

  maybe_operation = executor->PopFromSchedule();
  ASSERT_TRUE(maybe_operation.has_value());
  EXPECT_EQ(maybe_operation->tag, tag_foo);
  EXPECT_FALSE(executor->IsScheduled(tag_foo));

  maybe_operation->operation();
  // Despite having the same tag, the operations should have been ordered
  // according to their scheduled time and preserved their identity.
  EXPECT_EQ(steps, "12");
}

TEST_P(ExecutorTest, ConcurrentExecutorsWork) {
  /**
   * A mix of a countdown latch and a barrier. All threads that bump the
   * countdown block until the count becomes zero.
   */
  class BlockingCountdown {
   public:
    explicit BlockingCountdown(int threads) : threads_count_(threads) {
    }

    int count() const {
      std::lock_guard<std::mutex> lock(mutex_);
      return threads_count_;
    }

    /** Awaits the completion of all threads. */
    void Await() {
      std::unique_lock<std::mutex> lock(mutex_);
      is_zero_.wait(lock, [this] { return threads_count_ == 0; });
    }

    /**
     * Bumps the counter down by one and waits for the counter to become zero.
     */
    void Bump() {
      std::unique_lock<std::mutex> lock(mutex_);

      --threads_count_;

      // Block until all threads have come through here to ensure that the
      // executor is actually executing tasks concurrently.
      is_zero_.wait(lock, [this] { return threads_count_ == 0; });
      is_zero_.notify_all();
    }

   private:
    mutable std::mutex mutex_;
    std::condition_variable is_zero_;
    int threads_count_ = 0;
  };

  const int threads_count = 5;
  executor = GetParam()(threads_count);
  auto countdown = std::make_shared<BlockingCountdown>(threads_count);

  for (int i = 0; i < threads_count; i++) {
    executor->Execute([countdown] { countdown->Bump(); });
  }

  countdown->Await();
  ASSERT_EQ(0, countdown->count());
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
