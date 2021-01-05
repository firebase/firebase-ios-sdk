/*
 * Copyright 2018 Google LLC
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
#include "Firestore/core/src/util/task.h"
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
  static const Executor::Tag test_tag = 42;
  return executor->Schedule(delay, test_tag, std::move(operation));
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
    auto another_executor = GetParam()(/*threads=*/1);
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

TEST_P(ExecutorTest, CanCancelDelayedOperationsFromTheOperation) {
  std::string steps;
  DelayedOperation delayed_operation;

  Expectation ran;
  Expectation scheduled;

  // The test is designed to catch cases where a task might deadlock so run it
  // asynchronously.
  Async([&] {
    steps += "1";
    delayed_operation =
        Schedule(executor.get(), Executor::Milliseconds(1), [&] {
          Await(scheduled);
          steps += "3";

          // When checking if a task is scheduled from the currently executing
          // task, the result is true.
          ASSERT_FALSE(delayed_operation);

          delayed_operation.Cancel();

          steps += "4";
          ran.Fulfill();
        });

    steps += "2";
    scheduled.Fulfill();
  });

  Await(ran);
  EXPECT_EQ(steps, "1234");
}

TEST_P(ExecutorTest, DelayedOperationIsValidAfterTheOperationHasRun) {
  Expectation ran;

  DelayedOperation delayed_operation =
      Schedule(executor.get(), Executor::Milliseconds(1), ran.AsCallback());

  Await(ran);
  EXPECT_NO_THROW(delayed_operation.Cancel());
}

TEST_P(ExecutorTest, CancellingEmptyDelayedOperationIsValid) {
  DelayedOperation delayed_operation;
  EXPECT_NO_THROW(delayed_operation.Cancel());
}

TEST_P(ExecutorTest, DoubleCancellingDelayedOperationIsValid) {
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
  EXPECT_FALSE(executor->IsTagScheduled(tag_foo));
  EXPECT_FALSE(executor->IsTagScheduled(tag_bar));
  EXPECT_EQ(executor->PopFromSchedule(), nullptr);

  // Add two operations to the schedule with different tags.

  // The exact delay doesn't matter as long as it's too far away to be executed
  // during the test.
  const auto far_away = chr::seconds(1);
  executor->Schedule(far_away, tag_foo, [] {});
  // Scheduled operations can be distinguished by their tag.
  EXPECT_TRUE(executor->IsTagScheduled(tag_foo));
  EXPECT_FALSE(executor->IsTagScheduled(tag_bar));

  // This operation will be scheduled after the previous one (operations
  // scheduled with the same delay are FIFO ordered).
  executor->Schedule(far_away, tag_bar, [] {});
  EXPECT_TRUE(executor->IsTagScheduled(tag_foo));
  EXPECT_TRUE(executor->IsTagScheduled(tag_bar));

  // Now pop the operations one by one without waiting for them to be executed,
  // check that operations are popped in the order they are scheduled and
  // preserve tags. Schedule should become empty as a result.

  auto maybe_operation = executor->PopFromSchedule();
  ASSERT_NE(maybe_operation, nullptr);
  EXPECT_EQ(maybe_operation->tag(), tag_foo);
  EXPECT_FALSE(executor->IsTagScheduled(tag_foo));
  EXPECT_TRUE(executor->IsTagScheduled(tag_bar));
  maybe_operation->ExecuteAndRelease();

  maybe_operation = executor->PopFromSchedule();
  ASSERT_NE(maybe_operation, nullptr);
  EXPECT_EQ(maybe_operation->tag(), tag_bar);
  EXPECT_FALSE(executor->IsTagScheduled(tag_bar));
  maybe_operation->ExecuteAndRelease();

  // Schedule should now be empty.
  EXPECT_EQ(executor->PopFromSchedule(), nullptr);
}

TEST_P(ExecutorTest, DuplicateTagsOnOperationsAreAllowed) {
  const Executor::Tag tag_foo = 1;
  std::string steps;

  // Add two operations with the same tag to the schedule to verify that
  // duplicate tags are allowed.

  const auto far_away = chr::seconds(1);
  executor->Schedule(far_away, tag_foo, [&steps] { steps += '1'; });
  executor->Schedule(far_away, tag_foo, [&steps] { steps += '2'; });
  EXPECT_TRUE(executor->IsTagScheduled(tag_foo));

  auto maybe_operation = executor->PopFromSchedule();
  ASSERT_NE(maybe_operation, nullptr);
  EXPECT_EQ(maybe_operation->tag(), tag_foo);
  // There's still another operation with the same tag in the schedule.
  EXPECT_TRUE(executor->IsTagScheduled(tag_foo));

  maybe_operation->ExecuteAndRelease();

  maybe_operation = executor->PopFromSchedule();
  ASSERT_NE(maybe_operation, nullptr);
  EXPECT_EQ(maybe_operation->tag(), tag_foo);
  EXPECT_FALSE(executor->IsTagScheduled(tag_foo));

  maybe_operation->ExecuteAndRelease();
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

TEST_P(ExecutorTest, DestructorWaitsForExecutingTasks) {
  Expectation running;
  Expectation shutdown_started;

  std::string result;

  executor->Execute([&] {
    result += "1";
    running.Fulfill();

    Await(shutdown_started);
    result += "3";
  });

  Expectation shutdown_complete;
  Async([&] {
    Await(running);
    result += "2";

    shutdown_started.Fulfill();
    executor.reset();

    result += "4";
    shutdown_complete.Fulfill();
  });

  Await(shutdown_complete);
  ASSERT_EQ(result, "1234");
}

TEST_P(ExecutorTest, DisposeAvoidsDeadlockingWithCancellation) {
  Expectation running;
  Expectation shutdown_started;
  Expectation cancelled;

  std::string result;

  DelayedOperation operation;
  operation = executor->Schedule(Executor::Milliseconds(0), 42, [&] {
    result += "1";
    running.Fulfill();

    Await(shutdown_started);

    result += "3";
    operation.Cancel();

    result += "4";
    cancelled.Fulfill();
  });

  Expectation shutdown_complete;
  Async([&] {
    Await(running);
    result += "2";

    shutdown_started.Fulfill();
    executor->Dispose();
    result += "5";

    shutdown_complete.Fulfill();
  });

  Await(cancelled);
  Await(shutdown_complete);
  ASSERT_EQ(result, "12345");
}

TEST_P(ExecutorTest, DestructorAvoidsDeadlockWhenDeletingSelf) {
  Expectation complete;
  std::string result;

  executor->Execute([&] {
    result += "1";
    executor.reset();
    result += "2";

    complete.Fulfill();
  });

  Await(complete);
  ASSERT_EQ(result, "12");
}

TEST_P(ExecutorTest, DisposeBlocksTaskSubmission) {
  executor->Dispose();
  // Verify there's no crash for an idempotent invocation.
  executor->Dispose();

  Expectation ran;
  executor->Execute(ran.AsCallback());

  auto status = ran.get_future().wait_for(Executor::Milliseconds(50));
  ASSERT_EQ(status, std::future_status::timeout);
}

TEST_P(ExecutorTest, DisposeBlocksConcurrentTaskSubmission) {
  Expectation allow_destruction;
  Expectation blocking_task_running;

  // Run a task that blocks. These cause Dispose to block.
  executor->Execute([&] {
    blocking_task_running.Fulfill();
    Await(allow_destruction);
  });

  Await(blocking_task_running);

  // Run `Dispose`. This will block because there's a task pending.
  Expectation dispose_running;
  Expectation dispose_complete;
  Async([&] {
    dispose_running.Fulfill();
    executor->Dispose();
    dispose_complete.Fulfill();
  });

  // Run another `Execute`. This one either blocks waiting to submit or is
  // prevented from running by the disposed check. Either way, `ran` will not
  // be fulfilled.
  Await(dispose_running);
  Expectation execute_running;
  Expectation ran;
  Async([&] {
    execute_running.Fulfill();
    executor->Execute(ran.AsCallback());
  });

  Await(execute_running);
  auto status = ran.get_future().wait_for(Executor::Milliseconds(50));
  ASSERT_EQ(status, std::future_status::timeout);

  allow_destruction.Fulfill();
  Await(dispose_complete);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
