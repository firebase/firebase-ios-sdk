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

#include <assert.h>
#include <algorithm>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

// Generic wrapper over dispatch_async_f
template <typename Fun>
void DispatchAsync(const dispatch_queue_t queue, const Fun& function) {
  const auto wrap = new AsyncQueue::Operation(function);
  dispatch_async_f(queue, wrap, [](void* const raw_operation) {
    const auto unwrap =
        static_cast<const AsyncQueue::Operation*>(raw_operation);
    (*unwrap)();
    delete unwrap;
  });
}

}  // namespace

bool operator==(const DelayedOperation& lhs, const DelayedOperation& rhs) {
  return lhs.data_ == rhs.data_;
}
bool operator<(const DelayedOperation& lhs, const DelayedOperation& rhs) {
  return lhs.data_->target_time_ < rhs.data_->target_time_;
}

DelayedOperation::DelayedOperation(AsyncQueue* const queue,
                                   const TimerId timer_id,
                                   const Seconds delay,
                                   Operation&& operation)
    : data_{std::make_shared<Data>(
          queue, timer_id, delay, std::move(operation))} {
  Schedule(delay);
}

DelayedOperation::Data::Data(AsyncQueue* const queue,
                             const TimerId timer_id,
                             const Seconds delay,
                             Operation&& operation)
    : queue_{queue},
      timer_id_{timer_id},
      target_time_{delay},
      operation_{std::move(operation)} {
}

void DelayedOperation::Cancel() {
  data_->queue_->VerifyIsCurrentQueue();
  if (!data_->done_) {
    MarkDone();
  }
}

void DelayedOperation::Schedule(const Seconds delay) {
  namespace chr = std::chrono;
  const dispatch_time_t delay_ns = dispatch_time(
      DISPATCH_TIME_NOW, chr::duration_cast<chr::nanoseconds>(delay).count());
  dispatch_after_f(
      delay_ns, data_->queue_->native_handle(), this, [](void* const raw_self) {
        const auto self = static_cast<DelayedOperation*>(raw_self);
        self->data_->queue_->EnterCheckedOperation([self] { self->Run(); });
      });
}

void DelayedOperation::Run() {
  data_->queue_->VerifyIsCurrentQueue();
  if (!data_->done_) {
    MarkDone();
    assert(data_->operation_);
    data_->operation_();
  }
}

void DelayedOperation::RunImmediately() {
  data_->queue_->EnqueueAllowingSameQueue([this] { Run(); });
}

void DelayedOperation::MarkDone() {
  data_->done_ = true;
  data_->queue_->Dequeue(*this);
}

// AsyncQueue

void AsyncQueue::Dequeue(const DelayedOperation& dequeued) {
  const auto new_end =
      std::remove(operations_.begin(), operations_.end(), dequeued);
  assert(new_end != operations_.end());
  operations_.erase(new_end, operations_.end());
}

void AsyncQueue::VerifyIsCurrentQueue() const {
  FIREBASE_ASSERT_MESSAGE(
      OnTargetQueue(),
      "We are running on the wrong dispatch queue. Expected '%s' Actual: '%s'",
      GetTargetQueueLabel().data(), GetCurrentQueueLabel().data());
  FIREBASE_ASSERT_MESSAGE(
      is_operation_in_progress_,
      "verifyIsCurrentQueue called outside enterCheckedOperation on queue '%@'",
      GetTargetQueueLabel().data(), GetCurrentQueueLabel().data());
}

void AsyncQueue::EnterCheckedOperation(const Operation& operation) {
  FIREBASE_ASSERT_MESSAGE(!is_operation_in_progress_,
                          "EnterCheckedOperation may not be called when an "
                          "operation is in progress");
  is_operation_in_progress_ = true;
  VerifyIsCurrentQueue();
  operation();
  is_operation_in_progress_ = false;
}

void AsyncQueue::Enqueue(const Operation& operation) {
  FIREBASE_ASSERT_MESSAGE(!is_operation_in_progress_ || !OnTargetQueue(),
                          "Enqueue called when we are already running on "
                          "target dispatch queue '%s'",
                          GetTargetQueueLabel().data());
  // Note: can't move operation into lambda until C++14.
  DispatchAsync(native_handle(),
                [this, operation] { EnterCheckedOperation(operation); });
}

void AsyncQueue::EnqueueAllowingSameQueue(const Operation& operation) {
  // Note: can't move operation into lambda until C++14.
  DispatchAsync(native_handle(),
                [this, operation] { EnterCheckedOperation(operation); });
}

DelayedOperation AsyncQueue::EnqueueWithDelay(const Seconds delay,
                                              const TimerId timer_id,
                                              Operation operation) {
  // While not necessarily harmful, we currently don't expect to have multiple
  // callbacks with the same timer_id in the queue, so defensively reject them.
  FIREBASE_ASSERT_MESSAGE(!ContainsDelayedOperationWithTimerId(timer_id),
                          "Attempted to schedule multiple callbacks with id %u",
                          timer_id);

  operations_.push_back({this, timer_id, delay, std::move(operation)});
  return operations_.back();
}

bool AsyncQueue::ContainsDelayedOperationWithTimerId(
    const TimerId timer_id) const {
  return std::find_if(operations_.begin(), operations_.end(),
                      [timer_id](const DelayedOperation& op) {
                        return op.timer_id() == timer_id;
                      }) != operations_.end();
}

// Private

bool AsyncQueue::OnTargetQueue() const {
  return GetCurrentQueueLabel() == GetTargetQueueLabel();
}

void RunDelayedOperationsUntil(const TimerId last_timer_id) {
  dispatch_semaphore_t doneSemaphore = dispatch_semaphore_create(0);
  (void)last_timer_id;

  dispatch_semaphore_wait(doneSemaphore, DISPATCH_TIME_FOREVER);
}

namespace {

absl::string_view StringViewFromLabel(const char* const label) {
  // Make sure string_view's data is not null, because it's used for logging.
  return label ? absl::string_view{label} : absl::string_view{""};
}

}  // namespace

absl::string_view AsyncQueue::GetCurrentQueueLabel() const {
  // Note: dispatch_queue_get_label may return nullptr if the queue wasn't
  // initialized with a label.
  return StringViewFromLabel(
      dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
}

absl::string_view AsyncQueue::GetTargetQueueLabel() const {
  return StringViewFromLabel(dispatch_queue_get_label(native_handle()));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
