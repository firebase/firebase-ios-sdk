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

#include <memory>

#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

std::unique_ptr<internal::Executor> ExecutorFactory() {
  return absl::make_unique<internal::ExecutorLibdispatch>(
      dispatch_queue_create("ExecutorLibdispatchTests", DISPATCH_QUEUE_SERIAL));
}

}  // namespace

INSTANTIATE_TEST_CASE_P(ExecutorTestLibdispatch,
                        ExecutorTest,
                        ::testing::Values(ExecutorFactory));

namespace internal {
class ExecutorLibdispatchOnlyTests : public TestWithTimeoutMixin,
                                     public ::testing::Test {
 public:
  ExecutorLibdispatchOnlyTests() : executor{ExecutorFactory()} {
  }

  std::unique_ptr<Executor> executor;
};

TEST_F(ExecutorLibdispatchOnlyTests, NameReturnsLabelOfTheQueue) {
  EXPECT_EQ(executor->Name(), "ExecutorLibdispatchTests");
  executor->Execute([&] {
    EXPECT_EQ(executor->CurrentExecutorName(), "ExecutorLibdispatchTests");
    signal_finished();
  });
  EXPECT_TRUE(WaitForTestToFinish());
}

TEST_F(ExecutorLibdispatchOnlyTests,
       ExecuteBlockingOnTheCurrentQueueIsNotAllowed) {
  EXPECT_NO_THROW(executor->ExecuteBlocking([] {}));
  executor->Execute([&] {
    EXPECT_ANY_THROW(executor->ExecuteBlocking([] {}));
    signal_finished();
  });
  EXPECT_TRUE(WaitForTestToFinish());
}

}  // namespace internal
}  // namespace util
}  // namespace firestore
}  // namespace firebase
