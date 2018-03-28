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

#include "dispatch/dispatch.h"

namespace firebase {
namespace firestore {
namespace util {

DelayedOperation::DelayedOperation(AsyncQueue* const queue,
                                   const TimerId timer_id,
                                   const Duration delay,
                                   Operation&& operation)
    : data_{std::make_shared<Data>(
          queue, timer_id, delay, std::move(operation))} {
  Schedule(delay);
}

DelayedOperation::Data::Data(AsyncQueue* const queue,
                             const TimerId timer_id,
                             const Duration delay,
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

void DelayedOperation::Schedule(const Duration delay) {
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

}  // namespace util
}  // namespace firestore
}  // namespace firebase
