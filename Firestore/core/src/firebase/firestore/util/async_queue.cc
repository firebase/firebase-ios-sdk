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

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {

AsyncQueue::AsyncQueue(std::unique_ptr<Executor> executor)
    : executor_{std::move(executor)} {
  is_operation_in_progress_ = false;
}

// TODO(varconst): assert in destructor that the queue is empty.

void AsyncQueue::VerifyIsCurrentExecutor() const {
  HARD_ASSERT(
      executor_->IsCurrentExecutor(),
      "Expected to be called by the executor associated with this queue "
      "(expected executor: '%s', actual executor: '%s')",
      executor_->Name(), executor_->CurrentExecutorName());
}

void AsyncQueue::VerifyIsCurrentQueue() const {
  VerifyIsCurrentExecutor();
  HARD_ASSERT(is_operation_in_progress_,
              "VerifyIsCurrentQueue called when no operation is executing "
              "(expected executor: '%s', actual executor: '%s')",
              executor_->Name(), executor_->CurrentExecutorName());
}

void AsyncQueue::ExecuteBlocking(const Operation& operation) {
  VerifyIsCurrentExecutor();
  HARD_ASSERT(!is_operation_in_progress_,
              "ExecuteBlocking may not be called "
              "before the previous operation finishes executing");

  is_operation_in_progress_ = true;
  operation();
  is_operation_in_progress_ = false;
}

void AsyncQueue::Enqueue(const Operation& operation) {
  VerifySequentialOrder();
  EnqueueRelaxed(operation);
}

void AsyncQueue::EnqueueRelaxed(const Operation& operation) {
  executor_->Execute(Wrap(operation));
}

DelayedOperation AsyncQueue::EnqueueAfterDelay(const Milliseconds delay,
                                               const TimerId timer_id,
                                               const Operation& operation) {
  VerifyIsCurrentExecutor();

  // While not necessarily harmful, we currently don't expect to have multiple
  // callbacks with the same timer_id in the queue, so defensively reject
  // them.
  HARD_ASSERT(!IsScheduled(timer_id),
              "Attempted to schedule multiple operations with id %s", timer_id);

  Executor::TaggedOperation tagged{static_cast<int>(timer_id), Wrap(operation)};
  return executor_->Schedule(delay, std::move(tagged));
}

AsyncQueue::Operation AsyncQueue::Wrap(const Operation& operation) {
  // Decorator pattern: wrap `operation` into a call to `ExecuteBlocking` to
  // ensure that it doesn't spawn any nested operations.

  // Note: can't move `operation` into lambda until C++14.
  return [this, operation] { ExecuteBlocking(operation); };
}

void AsyncQueue::VerifySequentialOrder() const {
  // This is the inverse of `VerifyIsCurrentQueue`.
  HARD_ASSERT(!is_operation_in_progress_ || !executor_->IsCurrentExecutor(),
              "Enqueue methods cannot be called when we are already running on "
              "target executor "
              "(this queue's executor: '%s', current executor: '%s')",
              executor_->Name(), executor_->CurrentExecutorName());
}

// Test-only functions

void AsyncQueue::EnqueueBlocking(const Operation& operation) {
  VerifySequentialOrder();
  executor_->ExecuteBlocking(Wrap(operation));
}

bool AsyncQueue::IsScheduled(const TimerId timer_id) const {
  return executor_->IsScheduled(static_cast<int>(timer_id));
}

void AsyncQueue::RunScheduledOperationsUntil(const TimerId last_timer_id) {
  HARD_ASSERT(!executor_->IsCurrentExecutor(),
              "RunScheduledOperationsUntil must not be called on the queue");

  executor_->ExecuteBlocking([this, last_timer_id] {
    HARD_ASSERT(
        last_timer_id == TimerId::All || IsScheduled(last_timer_id),
        "Attempted to run scheduled operations until missing timer id: %s",
        last_timer_id);

    for (auto next = executor_->PopFromSchedule(); next.has_value();
         next = executor_->PopFromSchedule()) {
      next->operation();
      if (next->tag == static_cast<int>(last_timer_id)) {
        break;
      }
    }
  });
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
