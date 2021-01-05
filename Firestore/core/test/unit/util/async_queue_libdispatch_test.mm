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

#include "Firestore/core/test/unit/util/async_queue_test.h"

#include <memory>

#include "Firestore/core/src/util/executor_libdispatch.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

using testutil::Expectation;

dispatch_queue_t CreateDispatchQueue() {
  return dispatch_queue_create("AsyncQueueTests", DISPATCH_QUEUE_SERIAL);
}

std::unique_ptr<Executor> CreateExecutorFromQueue(
    const dispatch_queue_t queue) {
  return absl::make_unique<ExecutorLibdispatch>(queue);
}

std::unique_ptr<Executor> CreateExecutorLibdispatch() {
  return CreateExecutorFromQueue(CreateDispatchQueue());
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(AsyncQueueLibdispatch,
                         AsyncQueueTest,
                         ::testing::Values(CreateExecutorLibdispatch));

class AsyncQueueTestLibdispatchOnly : public ::testing::Test,
                                      public testutil::AsyncTest {
 public:
  AsyncQueueTestLibdispatchOnly()
      : underlying_queue{CreateDispatchQueue()},
        queue{AsyncQueue::Create(CreateExecutorFromQueue(underlying_queue))} {
  }

  dispatch_queue_t underlying_queue;
  std::shared_ptr<AsyncQueue> queue;
};

// Additional tests to see how libdispatch-based version of `AsyncQueue`
// interacts with raw usage of libdispatch.

TEST_F(AsyncQueueTestLibdispatchOnly, SameQueueIsAllowedForUnownedActions) {
  Expectation ran;
  dispatch_async(underlying_queue, ^{
    queue->Enqueue(ran.AsCallback());
  });
  Await(ran);
}

TEST_F(AsyncQueueTestLibdispatchOnly,
       VerifyIsCurrentQueueRequiresOperationInProgress) {
  dispatch_sync(underlying_queue, ^{
    EXPECT_ANY_THROW(queue->VerifyIsCurrentQueue());
  });
}

TEST_F(AsyncQueueTestLibdispatchOnly,
       VerifyIsCurrentQueueRequiresBeingCalledOnTheQueue) {
  ASSERT_NE(underlying_queue, dispatch_get_main_queue());
  EXPECT_ANY_THROW(queue->VerifyIsCurrentQueue());
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
