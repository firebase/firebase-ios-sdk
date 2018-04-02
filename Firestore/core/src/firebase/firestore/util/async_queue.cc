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

#include <algorithm>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

using Dispatcher = decltype(dispatch_async_f);

template <typename Dispatched>
void Dispatch(const dispatch_queue_t queue,
              Dispatcher dispatcher,
              const Dispatched& dispatched) {
  const auto wrap = new AsyncQueue::Operation(dispatched);
  dispatcher(queue, wrap, [](void* const raw_operation) {
    const auto unwrap =
        static_cast<const AsyncQueue::Operation*>(raw_operation);
    (*unwrap)();
    delete unwrap;
  });
}

// Generic wrapper over dispatch_async_f
template <typename Dispatched>
void DispatchAsync(const dispatch_queue_t queue, const Dispatched& dispatched) {
  Dispatch(queue, dispatch_async_f, dispatched);
}

// Generic wrapper over dispatch_sync_f
template <typename Dispatched>
void DispatchSync(const dispatch_queue_t queue, const Dispatched& dispatched) {
  Dispatch(queue, dispatch_sync_f, dispatched);
}

}  // namespace

namespace detail {

class DelayedOperationImpl {
 public:
  DelayedOperationImpl(AsyncQueue* const queue,
                       const TimerId timer_id,
                       const AsyncQueue::Milliseconds delay,
                       AsyncQueue::Operation&& operation)
      : queue_{queue},
        timer_id_{timer_id},
        target_time_{delay},
        operation_{std::move(operation)} {
    Schedule(delay);
  }

  void Cancel() {
    queue_->VerifyIsCurrentQueue();
    if (!done_) {
      MarkDone();
    }
  }

  // aka StartWithDelay
  void Schedule(const AsyncQueue::Milliseconds delay) {
    namespace chr = std::chrono;
    const dispatch_time_t delay_ns = dispatch_time(
        DISPATCH_TIME_NOW, chr::duration_cast<chr::nanoseconds>(delay).count());
    dispatch_after_f(
        delay_ns, queue_->native_handle(), this, [](void* const raw_self) {
          const auto self = static_cast<DelayedOperationImpl*>(raw_self);
          self->queue_->EnterCheckedOperation([self] { self->Run(); });
        });
  }

  // aka delayDidElapse
  void Run() {
    queue_->VerifyIsCurrentQueue();
    if (!done_) {
      MarkDone();
      FIREBASE_ASSERT_MESSAGE(operation_,
                              "DelayedOperation contains null function object");
      operation_();
    }
  }

  // aka SkipDelay
  void RunImmediately() {
    queue_->EnqueueAllowingSameQueue([this] { Run(); });
  }

  void MarkDone() {
    done_ = true;
    queue_->Dequeue(*this);
  }

  TimerId timer_id() const {
    return timer_id_;
  }

  bool operator<(const DelayedOperationImpl& rhs) const {
    return target_time_ < rhs.target_time_;
  }

 private:
  using TimePoint = std::chrono::time_point<std::chrono::system_clock,
                                            AsyncQueue::Milliseconds>;

  AsyncQueue* queue_{};
  TimerId timer_id_{};
  TimePoint target_time_;
  AsyncQueue::Operation operation_;
  // True if the operation has either been run or canceled.
  bool done_{};
};

}  // namespace detail

void DelayedOperation::Cancel() {
  if (auto live_instance = handle_.lock()) {
    live_instance->Cancel();
  }
}

using detail::DelayedOperationImpl;

void AsyncQueue::Dequeue(const DelayedOperationImpl& dequeued) {
  const auto new_end = std::remove_if(
      operations_.begin(), operations_.end(),
      [&dequeued](const OperationPtr& op) { return op.get() == &dequeued; });
  FIREBASE_ASSERT_MESSAGE(new_end != operations_.end(),
                          "Delayed operation not found");
  operations_.erase(new_end, operations_.end());
}

void AsyncQueue::VerifyIsCurrentQueue() const {
  FIREBASE_ASSERT_MESSAGE(
      OnTargetQueue(),
      "We are running on the wrong dispatch queue. Expected '%s' Actual: '%s'",
      GetTargetQueueLabel().data(), GetCurrentQueueLabel().data());
  FIREBASE_ASSERT_MESSAGE(
      is_operation_in_progress_,
      "VerifyIsCurrentQueue called outside enterCheckedOperation on queue '%s'",
      GetCurrentQueueLabel().data());
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

DelayedOperation AsyncQueue::EnqueueWithDelay(const Milliseconds delay,
                                              const TimerId timer_id,
                                              Operation operation) {
  // While not necessarily harmful, we currently don't expect to have multiple
  // callbacks with the same timer_id in the queue, so defensively reject them.
  FIREBASE_ASSERT_MESSAGE(!ContainsOperationWithTimerId(timer_id),
                          "Attempted to schedule multiple callbacks with id %u",
                          timer_id);

  operations_.emplace_back(std::make_shared<DelayedOperationImpl>(
          this, timer_id, delay, std::move(operation)));
  return DelayedOperation{operations_.back()};
}

void AsyncQueue::EnqueueSync(const Operation& operation) {
  FIREBASE_ASSERT_MESSAGE(!is_operation_in_progress_ || !OnTargetQueue(),
                          "EnqueueSync called when we are already running on "
                          "target dispatch queue '%s'",
                          GetTargetQueueLabel().data());
  // Note: can't move operation into lambda until C++14.
  DispatchSync(native_handle(),
               [this, operation] { EnterCheckedOperation(operation); });
}

bool AsyncQueue::ContainsOperationWithTimerId(const TimerId timer_id) const {
  return std::find_if(operations_.begin(), operations_.end(),
                      [timer_id](const OperationPtr& op) {
                        return op->timer_id() == timer_id;
                      }) != operations_.end();
}

// Private

bool AsyncQueue::OnTargetQueue() const {
  return GetCurrentQueueLabel() == GetTargetQueueLabel();
}

void AsyncQueue::RunDelayedOperationsUntil(const TimerId last_timer_id) {
  const dispatch_semaphore_t done_semaphore = dispatch_semaphore_create(0);

  Enqueue([this, last_timer_id, done_semaphore] {
    std::sort(operations_.begin(), operations_.end(),
              [](const OperationPtr& lhs, const OperationPtr& rhs) {
                return lhs->operator<(*rhs);
              });

    const auto until = [this, last_timer_id] {
      if (last_timer_id == TimerId::All) {
        return operations_.end();
      }
      const auto found = std::find_if(operations_.begin(), operations_.end(),
                                      [last_timer_id](const OperationPtr& op) {
                                        return op->timer_id() == last_timer_id;
                                      });
      FIREBASE_ASSERT_MESSAGE(
          found != operations_.end(),
          "Attempted to run operations until missing timer id: %u",
          last_timer_id);
      return found + 1;
    }();

    for (auto it = operations_.begin(); it != until; ++it) {
      (*it)->RunImmediately();
    }

    // Now that the callbacks are queued, we want to enqueue an additional item
    // to release the 'done' semaphore.
    EnqueueAllowingSameQueue(
        [done_semaphore] { dispatch_semaphore_signal(done_semaphore); });
  });

  dispatch_semaphore_wait(done_semaphore, DISPATCH_TIME_FOREVER);
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
