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

#include <chrono>  // NOLINT(build/c++11)

#include "Firestore/core/src/firebase/firestore/remote/exponential_backoff.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "Firestore/core/test/firebase/firestore/util/async_tests_util.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::ExecutorStd;
using firebase::firestore::util::TestWithTimeoutMixin;
using firebase::firestore::util::TimerId;

namespace chr = std::chrono;

namespace firebase {
namespace firestore {
namespace remote {

class ExponentialBackoffTest : public TestWithTimeoutMixin,
                               public testing::Test {
 public:
  ExponentialBackoffTest()
      : queue{std::make_shared<AsyncQueue>(absl::make_unique<ExecutorStd>())},
        backoff{queue, timer_id, 1.5, chr::seconds{5}, chr::seconds{30}} {
  }

  TimerId timer_id = TimerId::ListenStreamConnectionBackoff;
  std::shared_ptr<AsyncQueue> queue;
  ExponentialBackoff backoff;
};

TEST_F(ExponentialBackoffTest, CanScheduleOperations) {
  EXPECT_FALSE(queue->IsScheduled(timer_id));

  queue->EnqueueBlocking([&] {
    backoff.BackoffAndRun([&] { signal_finished(); });
    EXPECT_TRUE(queue->IsScheduled(timer_id));
  });

  EXPECT_TRUE(WaitForTestToFinish());
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
  queue->EnqueueBlocking([&] {
    backoff.BackoffAndRun([] {});
    backoff.BackoffAndRun([] {});
    backoff.BackoffAndRun([&] { signal_finished(); });
  });

  // The chosen value of initial_delay is large enough that it shouldn't be
  // realistically possible for backoff to finish already.
  queue->RunScheduledOperationsUntil(timer_id);
  EXPECT_TRUE(WaitForTestToFinish());
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
