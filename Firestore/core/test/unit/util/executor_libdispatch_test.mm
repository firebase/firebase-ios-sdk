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

#include <memory>

#include "Firestore/core/src/util/executor_libdispatch.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

using testutil::Expectation;

std::unique_ptr<Executor> ExecutorFactory(int threads = 1) {
  auto attr = threads == 1 ? DISPATCH_QUEUE_SERIAL : DISPATCH_QUEUE_CONCURRENT;
  return absl::make_unique<ExecutorLibdispatch>(
      dispatch_queue_create("ExecutorLibdispatchTests", attr));
}

namespace chr = std::chrono;

}  // namespace

INSTANTIATE_TEST_SUITE_P(ExecutorTestLibdispatch,
                         ExecutorTest,
                         ::testing::Values(ExecutorFactory));

namespace internal {
class ExecutorLibdispatchOnlyTests : public ::testing::Test,
                                     public testutil::AsyncTest {
 public:
  ExecutorLibdispatchOnlyTests() : executor{ExecutorFactory()} {
  }

  std::unique_ptr<Executor> executor;
};

TEST_F(ExecutorLibdispatchOnlyTests, NameReturnsLabelOfTheQueue) {
  Expectation ran;
  EXPECT_EQ(executor->Name(), "ExecutorLibdispatchTests");
  executor->Execute([&] {
    EXPECT_EQ(executor->CurrentExecutorName(), "ExecutorLibdispatchTests");
    ran.Fulfill();
  });
  Await(ran);
}

TEST_F(ExecutorLibdispatchOnlyTests,
       ExecuteBlockingOnTheCurrentQueueIsNotAllowed) {
  Expectation ran;
  EXPECT_NO_THROW(executor->ExecuteBlocking([] {}));
  executor->Execute([&] {
    EXPECT_ANY_THROW(executor->ExecuteBlocking([] {}));
    ran.Fulfill();
  });
  Await(ran);
}

TEST_F(ExecutorLibdispatchOnlyTests, ScheduledOperationOutlivesExecutor) {
  namespace chr = std::chrono;
  const auto far_away = chr::milliseconds(10);
  executor->Schedule(far_away, Executor::Tag{1}, [] {});
  executor.reset();
  // Try to wait until libdispatch invokes the scheduled operation. This is
  // flaky but unlikely to not work in practice. The test is successful if
  // there is no crash/data race under TSan.
  std::this_thread::sleep_for(chr::milliseconds(50));
}

TEST_F(ExecutorLibdispatchOnlyTests,
       ScheduledOperationOutlivesExecutor_DestroyedOnOwnQueue) {
  const auto far_away = chr::milliseconds(10);
  executor->Schedule(far_away, Executor::Tag{1}, [] {});

  // Invoke destructor on the executor's own queue to make sure there is no
  // deadlock.
  std::function<void()> reset = [this] { executor.reset(); };
  auto queue =
      static_cast<ExecutorLibdispatch*>(executor.get())->dispatch_queue();
  dispatch_sync_f(queue, &reset, [](void* const raw_reset) {
    const auto unwrap = static_cast<std::function<void()>*>(raw_reset);
    (*unwrap)();
  });
  // Try to wait until libdispatch invokes the scheduled operation. This is
  // flaky but unlikely to not work in practice. The test is successful if
  // there is no crash/data race under TSan.
  std::this_thread::sleep_for(chr::milliseconds(50));
}

}  // namespace internal
}  // namespace util
}  // namespace firestore
}  // namespace firebase
