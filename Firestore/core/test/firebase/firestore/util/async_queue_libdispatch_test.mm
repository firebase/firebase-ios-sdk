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

#include "Firestore/core/test/firebase/firestore/util/async_queue_test.h"

#include <memory>

#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

dispatch_queue_t CreateDispatchQueue() {
  return dispatch_queue_create("AsyncQueueTests", DISPATCH_QUEUE_SERIAL);
}

std::unique_ptr<internal::Executor> CreateExecutorFromQueue(
    const dispatch_queue_t queue) {
  return absl::make_unique<internal::ExecutorLibdispatch>(queue);
}

std::unique_ptr<internal::Executor> CreateExecutorLibdispatch() {
  return CreateExecutorFromQueue(CreateDispatchQueue());
}

}  // namespace

INSTANTIATE_TEST_CASE_P(AsyncQueueLibdispatch,
                        AsyncQueueTest,
                        ::testing::Values(CreateExecutorLibdispatch));

class AsyncQueueTestLibdispatchOnly : public TestWithTimeoutMixin,
                                      public ::testing::Test {
 public:
  AsyncQueueTestLibdispatchOnly()
      : underlying_queue{CreateDispatchQueue()},
        queue{CreateExecutorFromQueue(underlying_queue)} {
  }

  dispatch_queue_t underlying_queue;
  AsyncQueue queue;
};

// Additional tests to see how libdispatch-based version of `AsyncQueue`
// interacts with raw usage of libdispatch.

TEST_F(AsyncQueueTestLibdispatchOnly, SameQueueIsAllowedForUnownedActions) {
  internal::DispatchAsync(underlying_queue, [this] {
    queue.Enqueue([this] { signal_finished(); });
  });
  EXPECT_TRUE(WaitForTestToFinish());
}

TEST_F(AsyncQueueTestLibdispatchOnly,
       VerifyIsCurrentQueueRequiresOperationInProgress) {
  internal::DispatchSync(underlying_queue, [this] {
    EXPECT_ANY_THROW(queue.VerifyIsCurrentQueue());
  });
}

TEST_F(AsyncQueueTestLibdispatchOnly,
       VerifyIsCurrentQueueRequiresBeingCalledOnTheQueue) {
  ASSERT_NE(underlying_queue, dispatch_get_main_queue());
  EXPECT_ANY_THROW(queue.VerifyIsCurrentQueue());
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
