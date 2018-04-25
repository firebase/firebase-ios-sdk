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

#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace chr = std::chrono;
using internal::Executor;

namespace {

DelayedOperation Schedule(Executor* const executor,
                          const Executor::Milliseconds delay,
                          Executor::Operation&& operation) {
  const Executor::Tag no_tag = -1;
  return executor->Schedule(
      delay, Executor::TaggedOperation{no_tag, std::move(operation)});
}

}  // namespace

TEST_P(ExecutorTest, Execute) {
  executor->Execute([&] { signal_finished(); });
  EXPECT_TRUE(WaitForTestToFinish());
}

TEST_P(ExecutorTest, DestructorDoesNotBlockIfThereArePendingTasks) {
  const auto future = std::async(std::launch::async, [&] {
    auto another_executor = GetParam()();
    Schedule(another_executor.get(), chr::minutes(5), [] {});
    Schedule(another_executor.get(), chr::minutes(10), [] {});
    // Destructor shouldn't block waiting for the 5/10-minute-away operations.
  });

  ABORT_ON_TIMEOUT(future);
}

TEST_P(ExecutorTest, CanScheduleOperationsInTheFuture) {
  std::string steps;

  executor->Execute([&steps] { steps += '1'; });
  Schedule(executor.get(), Executor::Milliseconds(5), [&] {
    steps += '4';
    signal_finished();
  });
  Schedule(executor.get(), Executor::Milliseconds(1),
           [&steps] { steps += '3'; });
  executor->Execute([&steps] { steps += '2'; });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_EQ(steps, "1234");
}

TEST_P(ExecutorTest, CanCancelDelayedOperations) {
  std::string steps;

  executor->Execute([&] {
    executor->Execute([&steps] { steps += '1'; });

    DelayedOperation delayed_operation = Schedule(
        executor.get(), Executor::Milliseconds(1), [&steps] { steps += '2'; });

    Schedule(executor.get(), Executor::Milliseconds(5), [&] {
      steps += '3';
      signal_finished();
    });

    delayed_operation.Cancel();
  });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_EQ(steps, "13");
}

TEST_P(ExecutorTest, DelayedOperationIsValidAfterTheOperationHasRun) {
  DelayedOperation delayed_operation = Schedule(
      executor.get(), Executor::Milliseconds(1), [&] { signal_finished(); });

  EXPECT_TRUE(WaitForTestToFinish());
  EXPECT_NO_THROW(delayed_operation.Cancel());
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
