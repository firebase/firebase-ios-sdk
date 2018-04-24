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

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {

using internal::Executor;

AsyncQueue::AsyncQueue(std::unique_ptr<Executor> executor)
    : executor_{std::move(executor)} {
  is_operation_in_progress_ = false;
}

void AsyncQueue::VerifyIsAsyncCall() const {
  FIREBASE_ASSERT_MESSAGE(
      executor_->IsAsyncCall(),
      "Expected to be invoked asynchronously on the queue (invoker id: '%s')",
      executor_->GetInvokerId().data());
}

void AsyncQueue::VerifyCalledFromOperation() const {
  VerifyIsAsyncCall();
  FIREBASE_ASSERT_MESSAGE(is_operation_in_progress_,
                          "VerifyCalledFromOperation called when no "
                          "operation is executing (invoker id: '%s')",
                          executor_->GetInvokerId().data());
}

void AsyncQueue::StartExecution(const Operation& operation) {
  VerifyIsAsyncCall();
  FIREBASE_ASSERT_MESSAGE(!is_operation_in_progress_,
                          "StartExecution may not be called "
                          "before the previous operation finishes");

  is_operation_in_progress_ = true;
  operation();
  is_operation_in_progress_ = false;
}

void AsyncQueue::Enqueue(const Operation& operation) {
  VerifySequentialOrder();
  EnqueueAllowingNesting(operation);
}

void AsyncQueue::EnqueueAllowingNesting(const Operation& operation) {
  executor_->Execute(Wrap(operation));
}

DelayedOperation AsyncQueue::EnqueueAfterDelay(const Milliseconds delay,
                                               const TimerId timer_id,
                                               const Operation& operation) {
  VerifyIsAsyncCall();

  // While not necessarily harmful, we currently don't expect to have multiple
  // callbacks with the same timer_id in the queue, so defensively reject
  // them.
  FIREBASE_ASSERT_MESSAGE(
      !IsScheduled(timer_id),
      "Attempted to schedule multiple operations with id %d", timer_id);

  Executor::TaggedOperation tagged{static_cast<int>(timer_id), Wrap(operation)};
  return executor_->ScheduleExecution(delay, std::move(tagged));
}

AsyncQueue::Operation AsyncQueue::Wrap(const Operation& operation) {
  // Decorator pattern: wrap `operation` into a call to `StartExecution` to
  // ensure that it doesn't spawn any nested operations.

  // Note: can't move `operation` into lambda until C++14.
  return [this, operation] { StartExecution(operation); };
}

void AsyncQueue::VerifySequentialOrder() const {
  // This is the inverse of `VerifyCalledFromOperation`.
  FIREBASE_ASSERT_MESSAGE(
      !is_operation_in_progress_ || !executor_->IsAsyncCall(),
      "Enforcing sequential order failed: currently executing operations "
      "cannot enqueue nested operations (invoker id: '%s')",
      executor_->GetInvokerId().c_str());
}

// Test-only functions

void AsyncQueue::EnqueueBlocking(const Operation& operation) {
  VerifySequentialOrder();
  executor_->ExecuteBlocking(Wrap(operation));
}

bool AsyncQueue::IsScheduled(const TimerId timer_id) const {
  VerifyIsAsyncCall();
  return executor_->IsScheduled(static_cast<int>(timer_id));
}

void AsyncQueue::RunScheduledOperationsUntil(const TimerId last_timer_id) {
  FIREBASE_ASSERT_MESSAGE(
      !executor_->IsAsyncCall(),
      "RunScheduledOperationsUntil must not be called on the queue");

  executor_->ExecuteBlocking([this, last_timer_id] {
    FIREBASE_ASSERT_MESSAGE(
        last_timer_id == TimerId::All || IsScheduled(last_timer_id),
        "Attempted to run scheduled operations until missing timer id: %d",
        last_timer_id);
    FIREBASE_ASSERT_MESSAGE(
        !executor_->IsScheduleEmpty(),
        "Attempted to run scheduled operations with an empty schedule");

    Executor::TaggedOperation tagged;
    do {
      tagged = executor_->PopFromSchedule();
      tagged.operation();
    } while (!executor_->IsScheduleEmpty() &&
             tagged.tag != static_cast<int>(last_timer_id));
  });
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
