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

#include "Firestore/core/src/firebase/firestore/util/async_queue_libdispatch.h"

#include <algorithm>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

// Generic wrapper over dispatch_async_f, providing dispatch_async-like
// interface: accepts an arbitrary invocable object in place of an Objective-C
// block.
template <typename Work>
void DispatchAsync(const dispatch_queue_t queue, Work&& work) {
  // Wrap the passed invocable object into a std::function. It's dynamically
  // allocated to make sure the object is valid by the time libdispatch gets to
  // it.
  const auto wrap = new AsyncQueue::Operation(std::forward<Work>(work));

  dispatch_async_f(queue, wrap, [](void* const raw_operation) {
    const auto unwrap = static_cast<AsyncQueue::Operation*>(raw_operation);
    (*unwrap)();
    delete unwrap;
  });
}

// Similar to DispatchAsync but wraps dispatch_sync_f.
template <typename Work>
void DispatchSync(const dispatch_queue_t queue, Work&& work) {
  // Unlike dispatch_async_f, dispatch_sync_f blocks until the work passed to it
  // is done, so passing a pointer to a local variable is okay.
  AsyncQueue::Operation wrap{std::forward<Work>(work)};

  dispatch_sync_f(queue, &wrap, [](void* const raw_operation) {
    const auto unwrap = static_cast<AsyncQueue::Operation*>(raw_operation);
    (*unwrap)();
  });
}

}  // namespace

namespace internal {

// DelayedOperationImpl contains the logic of scheduling a delayed operation.
//
// An instance of this class exists until it's run, which allows it to schedule
// itself for delayed execution without worrying about lifetime issues.
//
// AsyncQueue holds a shared_ptr to the instance, while DelayedOperation
// handle returned to the code using AsyncQueue holds a weak_ptr.
// Consequently, DelayedOperation is always valid in the sense that it's
// always safe to use, but the lifetime of DelayedOperationImpl only depends
// on the AsyncQueue. AsyncQueue never removes delayed operations on its
// own; only DelayedOperationImpl itself triggers its removal from the queue
// in its HandleDelayElapsed method.
//
// It is impossible to actually cancel work scheduled with libdispatch; to work
// around this, DelayedOperationImpl emulates cancellation by turning itself
// into a no-op. Under the hood, even a "canceled" DelayedOperationImpl will
// still run, and consequently the instance will still be alive until it's run.

class DelayedOperationImpl {
 public:
  DelayedOperationImpl(AsyncQueue* const queue,
                       const TimerId timer_id,
                       const AsyncQueue::Milliseconds delay,
                       AsyncQueue::Operation&& operation)
      : queue_{queue},
        timer_id_{timer_id},
        target_time_{std::chrono::time_point_cast<AsyncQueue::Milliseconds>(
                         std::chrono::system_clock::now()) +
                     delay},
        operation_{std::move(operation)} {
    Start(delay);
  }

  void Cancel() {
    queue_->VerifyIsCurrentQueue();
    done_ = true;
  }

  void SkipDelay() {
    queue_->EnqueueAllowingSameQueue([this] { HandleDelayElapsed(); });
  }

  TimerId timer_id() const {
    return timer_id_;
  }

  bool operator<(const DelayedOperationImpl& rhs) const {
    return target_time_ < rhs.target_time_;
  }

 private:
  void Start(const AsyncQueue::Milliseconds delay) {
    namespace chr = std::chrono;
    const dispatch_time_t delay_ns = dispatch_time(
        DISPATCH_TIME_NOW, chr::duration_cast<chr::nanoseconds>(delay).count());
    dispatch_after_f(
        delay_ns, queue_->dispatch_queue(), this, [](void* const raw_self) {
          const auto self = static_cast<DelayedOperationImpl*>(raw_self);
          self->queue_->EnterCheckedOperation(
              [self] { self->HandleDelayElapsed(); });
        });
  }

  void HandleDelayElapsed() {
    queue_->VerifyIsCurrentQueue();

    if (!done_) {
      done_ = true;
      FIREBASE_ASSERT_MESSAGE(
          operation_, "DelayedOperationImpl contains invalid function object");
      operation_();
    }

    // PORTING NOTE: it's important to *only* remove the operation from the
    // queue *after* it's run, *not* in Cancel method. Because it's
    // impossible to cancel an invocation scheduled with dispatch_after_f,
    // this object must be alive when libdispatch calls HandleDelayElapsed; it
    // the object were removed from the queue in Cancel, it would have been
    // deleted by the time HandleDelayElapsed gets invoked.
    Dequeue();
  }

  void Dequeue() {
    queue_->RemoveDelayedOperation(*this);
  }

  using TimePoint = std::chrono::time_point<std::chrono::system_clock,
                                            AsyncQueue::Milliseconds>;

  AsyncQueue* const queue_;
  const TimerId timer_id_;
  const TimePoint target_time_;
  const AsyncQueue::Operation operation_;
  // True if the operation has either been run or canceled.
  //
  // Note on thread-safety: done_ is only ever accessed from Cancel and
  // HandleDelayElapsed member functions, both of which assert they are being
  // called while on the dispatch queue. In other words, done_ is only accessed
  // when invoked by dispatch_async/dispatch_sync, both of which provide
  // synchronization.
  bool done_ = false;
};

}  // namespace internal

using internal::DelayedOperationImpl;

void DelayedOperation::Cancel() {
  if (std::shared_ptr<DelayedOperationImpl> live_instance = handle_.lock()) {
    live_instance->Cancel();
  }
}

void AsyncQueue::RemoveDelayedOperation(const DelayedOperationImpl& dequeued) {
  const auto new_end =
      std::remove_if(operations_.begin(), operations_.end(),
                     [&dequeued](const DelayedOperationPtr& op) {
                       return op.get() == &dequeued;
                     });
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
      "VerifyIsCurrentQueue called outside EnterCheckedOperation on queue '%s'",
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
  DispatchAsync(dispatch_queue(),
                [this, operation] { EnterCheckedOperation(operation); });
}

void AsyncQueue::EnqueueAllowingSameQueue(const Operation& operation) {
  // Note: can't move operation into lambda until C++14.
  DispatchAsync(dispatch_queue(),
                [this, operation] { EnterCheckedOperation(operation); });
}

DelayedOperation AsyncQueue::EnqueueAfterDelay(const Milliseconds delay,
                                               const TimerId timer_id,
                                               Operation operation) {
  // While not necessarily harmful, we currently don't expect to have multiple
  // callbacks with the same timer_id in the queue, so defensively reject them.
  FIREBASE_ASSERT_MESSAGE(!ContainsDelayedOperation(timer_id),
                          "Attempted to schedule multiple callbacks with id %d",
                          timer_id);

  operations_.push_back(std::make_shared<DelayedOperationImpl>(
      this, timer_id, delay, std::move(operation)));
  return DelayedOperation{operations_.back()};
}

void AsyncQueue::RunSync(const Operation& operation) {
  FIREBASE_ASSERT_MESSAGE(!is_operation_in_progress_ || !OnTargetQueue(),
                          "RunSync called when we are already running on "
                          "target dispatch queue '%s'",
                          GetTargetQueueLabel().data());
  // Note: can't move operation into lambda until C++14.
  DispatchSync(dispatch_queue(),
               [this, operation] { EnterCheckedOperation(operation); });
}

bool AsyncQueue::ContainsDelayedOperation(const TimerId timer_id) const {
  return std::find_if(operations_.begin(), operations_.end(),
                      [timer_id](const DelayedOperationPtr& op) {
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
    std::sort(
        operations_.begin(), operations_.end(),
        [](const DelayedOperationPtr& lhs, const DelayedOperationPtr& rhs) {
          return lhs->operator<(*rhs);
        });

    const auto until = [this, last_timer_id] {
      if (last_timer_id == TimerId::All) {
        return operations_.end();
      }
      const auto found =
          std::find_if(operations_.begin(), operations_.end(),
                       [last_timer_id](const DelayedOperationPtr& op) {
                         return op->timer_id() == last_timer_id;
                       });
      FIREBASE_ASSERT_MESSAGE(
          found != operations_.end(),
          "Attempted to run operations until missing timer id: %d",
          last_timer_id);
      return found + 1;
    }();

    for (auto it = operations_.begin(); it != until; ++it) {
      (*it)->SkipDelay();
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
  return StringViewFromLabel(dispatch_queue_get_label(dispatch_queue()));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
