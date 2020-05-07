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

#include "Firestore/core/src/util/task.h"

#include <chrono>  // NOLINT(build/c++11)

#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

namespace chr = std::chrono;
using testing::Not;
using testutil::Expectation;

struct TaskState {
  int op_executed = 0;
  int op_destroyed = 0;
  int task_destroyed = 0;
};

class DestructionDetector {
 public:
  explicit DestructionDetector(int* count) : count_(count) {
  }

  // C++ makes copies of the detector when it is captured by value. Ensure only
  // the last copy (the one seated in the closure) is counted.
  DestructionDetector(const DestructionDetector& other) : count_(other.count_) {
    other.copied_from_ = true;
  }

  ~DestructionDetector() {
    if (!copied_from_) {
      *count_ += 1;
    }
  }

 private:
  int* count_ = nullptr;
  mutable bool copied_from_ = false;
};

class TrackingTask : public Task {
 public:
  TrackingTask(Executor* executor,
               TaskState* state,
               Executor::Operation&& operation)
      : Task(executor, std::move(operation)), state_(state) {
  }

  ~TrackingTask() override {
    state_->task_destroyed += 1;
  }

 private:
  TaskState* state_;
};

Task* NewTask(Executor* executor, TaskState* state) {
  DestructionDetector detector(&state->op_destroyed);

  Task* result = new TrackingTask(
      executor, state, [detector, state] { state->op_executed += 1; });
  EXPECT_EQ(state->op_executed, 0);
  EXPECT_EQ(state->op_destroyed, 0);
  EXPECT_EQ(state->task_destroyed, 0);
  return result;
}

Task* NewTask(TaskState* state) {
  return NewTask(nullptr, state);
}

}  // namespace

class TaskTest : public testing::Test, public testutil::AsyncTest {
 public:
  TaskTest() = default;
};

TEST_F(TaskTest, ExecuteReleases) {
  TaskState state;
  auto task = NewTask(&state);
  task->Execute();
  ASSERT_EQ(state.op_executed, 1);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 1);
}

TEST_F(TaskTest, ReleaseReleases) {
  TaskState state;
  auto task = NewTask(&state);
  task->Release();
  ASSERT_EQ(state.op_executed, 0);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 1);
}

TEST_F(TaskTest, CancelDoesNotRelease) {
  TaskState state;
  auto task = NewTask(&state);
  task->Cancel();
  ASSERT_EQ(state.op_executed, 0);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 0);

  task->Release();
  ASSERT_EQ(state.op_executed, 0);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 1);
}

TEST_F(TaskTest, CancelPreventsExecution) {
  TaskState state;
  auto task = NewTask(&state);
  task->Cancel();
  ASSERT_EQ(state.op_executed, 0);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 0);

  task->Execute();
  ASSERT_EQ(state.op_executed, 0);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 1);
}

TEST_F(TaskTest, CancelBlocksOnRunningTasks) {
  auto executor = testutil::ExecutorForTesting();
  std::string steps;

  Expectation running;
  Expectation task_can_complete;
  auto task = new Task(executor.get(), [&] {
    steps += "1";
    running.Fulfill();

    Await(task_can_complete);
    steps += "3";
  });

  // Start the task on a separate thread; this will block until the Task
  // completes.
  Async([&] { task->Execute(); });

  // Cancel on yet another thread because this also will block
  Expectation cancel_started;
  Expectation cancel_finished;
  Async([&] {
    Await(running);
    steps += "2";
    cancel_started.Fulfill();
    task->Cancel();
    steps += "4";
    cancel_finished.Fulfill();
  });

  Await(cancel_started);
  task_can_complete.Fulfill();

  Await(cancel_finished);

  // If cancel doesn't await completion then this will be 1243.
  ASSERT_EQ(steps, "1234");

  task->Release();
}

TEST_F(TaskTest, OwnedExecuteThenRelease) {
  auto executor = testutil::ExecutorForTesting();
  TaskState state;
  auto task = NewTask(executor.get(), &state);

  task->Execute();
  ASSERT_EQ(state.op_executed, 1);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 0);

  task->Release();
  ASSERT_EQ(state.task_destroyed, 1);
}

TEST_F(TaskTest, OwnedReleaseThenRelease) {
  auto executor = testutil::ExecutorForTesting();
  TaskState state;
  auto task = NewTask(executor.get(), &state);

  task->Release();
  ASSERT_EQ(state.op_executed, 0);
  ASSERT_EQ(state.op_destroyed, 0);
  ASSERT_EQ(state.task_destroyed, 0);

  task->Execute();
  ASSERT_EQ(state.op_executed, 1);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 1);
}

TEST_F(TaskTest, OwnedExecuteThenExecute) {
  // This perverse case arises when higher-level tests are executing against
  // a libdispatch-based Executor and they manually run scheduled tasks. In this
  // case the test itself will execute the task and then libdispatch will also
  // execute the task. Only the first `Execute` should execute the operation and
  // the second `Execute` should just `Release`.
  auto executor = testutil::ExecutorForTesting();
  TaskState state;
  auto task = NewTask(executor.get(), &state);

  task->Execute();
  ASSERT_EQ(state.op_executed, 1);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 0);

  task->Execute();
  ASSERT_EQ(state.op_executed, 1);
  ASSERT_EQ(state.op_destroyed, 1);
  ASSERT_EQ(state.task_destroyed, 1);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
