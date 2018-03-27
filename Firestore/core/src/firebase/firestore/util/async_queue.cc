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

#include "dispatch/dispatch.h"

namespace firebase {
namespace firestore {
namespace util {

DelayedOperation::DelayedOperation(AsyncQueue* const queue,
                                   const TimerId timer_id,
                                   const Duration delay,
                                   Operation&& operation)
    : queue_{queue},
      timer_id_{timer_id},
      target_time_{delay},
      operation_{std::move(operation)} {
  Schedule(delay);
}

void DelayedOperation::Cancel() {
  queue_->VerifyIsCurrentQueue();
  if (!done_) {
    MarkDone();
  }
}

void DelayedOperation::Schedule(const Duration delay) {
  namespace chr = std::chrono;
  const dispatch_time_t delay_ns = dispatch_time(
      DISPATCH_TIME_NOW, chr::duration_cast<chr::nanoseconds>(delay).count());
  dispatch_after_f(
      delay_ns, queue_->native_handle(), this, [](void* const raw_self) {
        const auto self = static_cast<DelayedOperation*>(raw_self);
        self->queue_->EnterCheckedOperation([self] { self->Run(); });
      });
}

void DelayedOperation::Run() {
  queue_->VerifyIsCurrentQueue();
  if (!done_) {
    MarkDone();
    assert(operation_);
    operation_();
  }
}

void DelayedOperation::RunImmediately() {
   queue_->EnqueueAllowingSameQueue([this] {
   Run();
  });
}

void DelayedOperation::MarkDone() {
  done_ = true;
  queue_->Dequeue(*this);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
