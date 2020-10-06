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

#include "Firestore/core/src/remote/exponential_backoff.h"

#include <chrono>  // NOLINT(build/c++11)

#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace chr = std::chrono;

namespace firebase {
namespace firestore {
namespace remote {

using testutil::Expectation;
using util::AsyncQueue;
using util::Executor;
using util::TimerId;

class ExponentialBackoffTest : public testing::Test,
                               public testutil::AsyncTest {
 public:
  ExponentialBackoffTest()
      : queue{testutil::AsyncQueueForTesting()},
        backoff{queue, timer_id, 1.5, chr::seconds{5}, chr::seconds{30}} {
  }

  TimerId timer_id = TimerId::ListenStreamConnectionBackoff;
  std::shared_ptr<AsyncQueue> queue;
  ExponentialBackoff backoff;
};

TEST_F(ExponentialBackoffTest, CanScheduleOperations) {
  EXPECT_FALSE(queue->IsScheduled(timer_id));

  Expectation finished;
  queue->EnqueueBlocking([&] {
    backoff.BackoffAndRun(finished.AsCallback());
    EXPECT_TRUE(queue->IsScheduled(timer_id));
  });

  Await(finished);
  EXPECT_FALSE(queue->IsScheduled(timer_id));
}

TEST_F(ExponentialBackoffTest, CanCancelOperations) {
  std::string str{"untouched"};
  EXPECT_FALSE(queue->IsScheduled(timer_id));

  queue->EnqueueBlocking([&] {
    backoff.BackoffAndRun([&] { str = "Shouldn't be modified"; });
    EXPECT_TRUE(queue->IsScheduled(timer_id));
    backoff.Cancel();
  });

  EXPECT_FALSE(queue->IsScheduled(timer_id));
  EXPECT_EQ(str, "untouched");
}

TEST_F(ExponentialBackoffTest, SequentialCallsToBackoffAndRun) {
  Expectation finished;
  queue->EnqueueBlocking([&] {
    backoff.BackoffAndRun([] {});
    backoff.BackoffAndRun([] {});
    backoff.BackoffAndRun(finished.AsCallback());
  });

  // The chosen value of initial_delay is large enough that it shouldn't be
  // realistically possible for backoff to finish already.
  queue->RunScheduledOperationsUntil(timer_id);
  Await(finished);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
