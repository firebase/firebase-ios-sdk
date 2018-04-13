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

// Implementation note: it's impossible to guarantee that libdispatch doesn't
// currently hold on to any references to the queue or delayed operations.
// Consequently, the ownership model uses shared and weak pointers. The two main
// classes are `internal::AsyncQueueImpl` and `internal::DelayedOperationImpl`,
// both of which are dynamically allocated. The references to them are as
// follows:
//
// - `AsyncQueue` is the stack-allocated class instantiated by client code. It
//   holds a shared pointer to `AsyncQueueImpl`, forwards all operations to it,
//   and only exists to avoid exposing the ownership model to the callers.
//
// - `DelayedOperation` is a stack-allocated class returned by
//   `EnqueueAfterDelay` to the client code. It holds a weak pointer to a
//   `DelayedOperationImpl`, allowing client code to safely reference an
//   operation that has been run and destroyed, but without unnecessarily
//   extending the operation's lifetime.
//
// - `AsyncQueueImpl` stores a vector of shared pointers to delayed operations,
//   allowing it to access them, for example, to run them preemptively.
//
// - `DelayedOperationImpl` holds a weak pointer to `AsyncQueueImpl`, allowing
//   the operation to dequeue itself, which is a no-op if the queue has already
//   been destroyed.
//
// - libdispatch gets its own shared pointer to the `DelayedOperationImpl`, so
//   that the operation is guaranteed to still be valid by the time it's run
//   (which may happen after the queue is destroyed, because it's impossible to
//   unschedule in libdispatch).
//
// To summarize:
//
// - `AsyncQueue` is the owner of `AsyncQueueImpl`, and `DelayedOperationImpl`
//   is an observer;
// - both `AsyncQueueImpl` and libdispatch are equal owners of
//   a `DelayedOperationImpl`, while a `DelayedOperation` is an observer.

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

class AsyncQueueImpl : public std::enable_shared_from_this<AsyncQueueImpl> {
 public:
  using Milliseconds = AsyncQueue::Milliseconds;
  using Operation = AsyncQueue::Operation;

  explicit AsyncQueueImpl(dispatch_queue_t dispatch_queue);

  void VerifyIsCurrentQueue() const;
  void EnterCheckedOperation(const Operation& operation);

  void Enqueue(const Operation& operation);
  void EnqueueAllowingSameQueue(const Operation& operation);

  DelayedOperation EnqueueAfterDelay(Milliseconds delay,
                                     TimerId timer_id,
                                     Operation operation);

  void RunSync(const Operation& operation);

  bool ContainsDelayedOperation(TimerId timer_id) const;
  void RunDelayedOperationsUntil(TimerId last_timer_id);

  dispatch_queue_t dispatch_queue() const {
    return dispatch_queue_;
  }

 private:
  void Dispatch(const Operation& operation);

  void TryRemoveDelayedOperation(const DelayedOperationImpl& operation);

  bool OnTargetQueue() const;
  void VerifyOnTargetQueue() const;
  // GetLabel functions are guaranteed to never return a "null" string_view
  // (i.e. data() != nullptr).
  absl::string_view GetCurrentQueueLabel() const;
  absl::string_view GetTargetQueueLabel() const;

  std::atomic<dispatch_queue_t> dispatch_queue_;
  using DelayedOperationPtr = std::shared_ptr<DelayedOperationImpl>;
  std::vector<DelayedOperationPtr> operations_;
  std::atomic<bool> is_operation_in_progress_{false};

  // For access to TryRemoveDelayedOperation.
  friend class DelayedOperationImpl;
};

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

class DelayedOperationImpl
    : public std::enable_shared_from_this<DelayedOperationImpl> {
 public:
  DelayedOperationImpl(const std::shared_ptr<AsyncQueueImpl>& queue,
                       const TimerId timer_id,
                       const AsyncQueue::Milliseconds delay,
                       AsyncQueue::Operation&& operation)
      : queue_handle_{queue},
        timer_id_{timer_id},
        target_time_{std::chrono::time_point_cast<AsyncQueue::Milliseconds>(
                         std::chrono::system_clock::now()) +
                     delay},
        operation_{std::move(operation)} {
  }

  // Important: don't call `Start` from the constructor, `shared_from_this`
  // won't work.
  void Start(const dispatch_queue_t dispatch_queue,
             const AsyncQueue::Milliseconds delay) {
    namespace chr = std::chrono;
    const dispatch_time_t delay_ns = dispatch_time(
        DISPATCH_TIME_NOW, chr::duration_cast<chr::nanoseconds>(delay).count());
    // libdispatch must get its own shared pointer to the operation, otherwise
    // the operation might get destroyed by the time it's invoked (e.g., because
    // it was canceled or force-run; libdispatch will still get to run it, even
    // if it will be a no-op).
    const auto self = new StrongSelf(shared_from_this());
    dispatch_after_f(delay_ns, dispatch_queue, self,
                     DelayedOperationImpl::InvokedByLibdispatch);
  }

  void Cancel() {
    if (QueuePtr queue = queue_handle_.lock()) {
      TryDequeue(queue.get());
    }
    done_ = true;
  }

  void SkipDelay() {
    if (QueuePtr queue = queue_handle_.lock()) {
      queue->EnqueueAllowingSameQueue([this] { HandleDelayElapsed(); });
    }
  }

  TimerId timer_id() const {
    return timer_id_;
  }

  bool operator<(const DelayedOperationImpl& rhs) const {
    return target_time_ < rhs.target_time_;
  }

 private:
  using StrongSelf = std::shared_ptr<DelayedOperationImpl>;
  using QueuePtr = std::shared_ptr<AsyncQueueImpl>;

  static void InvokedByLibdispatch(void* const raw_self) {
    auto self = static_cast<StrongSelf*>(raw_self);
    if (QueuePtr queue = (*self)->queue_handle_.lock()) {
      queue->EnterCheckedOperation([self] { (*self)->HandleDelayElapsed(); });
    }
    delete self;
  }

  void HandleDelayElapsed() {
    if (QueuePtr queue = queue_handle_.lock()) {
      TryDequeue(queue.get());

      if (!done_) {
        done_ = true;
        FIREBASE_ASSERT_MESSAGE(
            operation_,
            "DelayedOperationImpl contains invalid function object");
        operation_();
      }
    }
  }

  void TryDequeue(AsyncQueueImpl* const queue) {
    queue->VerifyIsCurrentQueue();
    queue->TryRemoveDelayedOperation(*this);
  }

  using TimePoint = std::chrono::time_point<std::chrono::system_clock,
                                            AsyncQueue::Milliseconds>;

  std::weak_ptr<AsyncQueueImpl> queue_handle_;
  const TimerId timer_id_;
  const TimePoint target_time_;
  const AsyncQueue::Operation operation_;

  // True if the operation has either been run or canceled.
  //
  // Note on thread-safety: `done_` is only ever accessed from `Cancel` and
  // `HandleDelayElapsed` member functions, both of which assert they are being
  // called while on the dispatch queue. In other words, `done_` is only
  // accessed when invoked by dispatch_async/dispatch_sync, both of which
  // provide synchronization.
  bool done_ = false;
};

}  // namespace internal

using internal::AsyncQueueImpl;
using internal::DelayedOperationImpl;

void DelayedOperation::Cancel() {
  if (std::shared_ptr<DelayedOperationImpl> live_instance = handle_.lock()) {
    live_instance->Cancel();
  }
}

// `AsyncQueue` methods are simply wrappers over `AsyncQueueImpl`; `AsyncQueue`
// exists to abstract away the fact that shared pointers are used.

AsyncQueue::AsyncQueue(const dispatch_queue_t dispatch_queue)
    : impl_{std::make_shared<AsyncQueueImpl>(dispatch_queue)} {
}
void AsyncQueue::VerifyIsCurrentQueue() const {
  impl_->VerifyIsCurrentQueue();
}
void AsyncQueue::EnterCheckedOperation(const Operation& operation) {
  impl_->EnterCheckedOperation(operation);
}
void AsyncQueue::Enqueue(const Operation& operation) {
  impl_->Enqueue(operation);
}
void AsyncQueue::EnqueueAllowingSameQueue(const Operation& operation) {
  impl_->EnqueueAllowingSameQueue(operation);
}
DelayedOperation AsyncQueue::EnqueueAfterDelay(Milliseconds delay,
                                               TimerId timer_id,
                                               Operation operation) {
  return impl_->EnqueueAfterDelay(delay, timer_id, std::move(operation));
}
void AsyncQueue::RunSync(const Operation& operation) {
  impl_->RunSync(operation);
}
bool AsyncQueue::ContainsDelayedOperation(TimerId timer_id) const {
  return impl_->ContainsDelayedOperation(timer_id);
}
void AsyncQueue::RunDelayedOperationsUntil(TimerId last_timer_id) {
  impl_->RunDelayedOperationsUntil(last_timer_id);
}
dispatch_queue_t AsyncQueue::dispatch_queue() const {
  return impl_->dispatch_queue();
}

// AsyncQueueImpl

void AsyncQueueImpl::TryRemoveDelayedOperation(
    const DelayedOperationImpl& dequeued) {
  const auto found = std::find_if(operations_.begin(), operations_.end(),
                                  [&dequeued](const DelayedOperationPtr& op) {
                                    return op.get() == &dequeued;
                                  });
  // It's possible for the operation to be missing if libdispatch gets to run it
  // after it was force-run, for example.
  if (found != operations_.end()) {
    operations_.erase(found);
  }
}

AsyncQueueImpl::AsyncQueueImpl(const dispatch_queue_t dispatch_queue) {
  dispatch_queue_ = dispatch_queue;
}

void AsyncQueueImpl::VerifyIsCurrentQueue() const {
  VerifyOnTargetQueue();
  FIREBASE_ASSERT_MESSAGE(is_operation_in_progress_,
                          "VerifyIsCurrentQueue called outside "
                          "EnterCheckedOperation on queue '%s'",
                          GetCurrentQueueLabel().data());
}

void AsyncQueueImpl::EnterCheckedOperation(const Operation& operation) {
  FIREBASE_ASSERT_MESSAGE(!is_operation_in_progress_,
                          "EnterCheckedOperation may not be called when an "
                          "operation is in progress");

  is_operation_in_progress_ = true;

  VerifyIsCurrentQueue();
  operation();

  is_operation_in_progress_ = false;
}

void AsyncQueueImpl::Enqueue(const Operation& operation) {
  FIREBASE_ASSERT_MESSAGE(!is_operation_in_progress_ || !OnTargetQueue(),
                          "Enqueue called when we are already running on "
                          "target dispatch queue '%s'",
                          GetTargetQueueLabel().data());
  // Note: can't move operation into lambda until C++14.
  DispatchAsync(dispatch_queue(),
                [this, operation] { EnterCheckedOperation(operation); });
}

void AsyncQueueImpl::EnqueueAllowingSameQueue(const Operation& operation) {
  // Note: can't move operation into lambda until C++14.
  DispatchAsync(dispatch_queue(),
                [this, operation] { EnterCheckedOperation(operation); });
}

DelayedOperation AsyncQueueImpl::EnqueueAfterDelay(const Milliseconds delay,
                                                   const TimerId timer_id,
                                                   Operation operation) {
  VerifyOnTargetQueue();

  // While not necessarily harmful, we currently don't expect to have multiple
  // callbacks with the same timer_id in the queue, so defensively reject
  // them.
  FIREBASE_ASSERT_MESSAGE(!ContainsDelayedOperation(timer_id),
                          "Attempted to schedule multiple callbacks with id %d",
                          timer_id);

  operations_.push_back(std::make_shared<DelayedOperationImpl>(
      shared_from_this(), timer_id, delay, std::move(operation)));
  operations_.back()->Start(dispatch_queue(), delay);
  return DelayedOperation{operations_.back()};
}

void AsyncQueueImpl::RunSync(const Operation& operation) {
  FIREBASE_ASSERT_MESSAGE(!is_operation_in_progress_ || !OnTargetQueue(),
                          "RunSync called when we are already running on "
                          "target dispatch queue '%s'",
                          GetTargetQueueLabel().data());
  // Note: can't move operation into lambda until C++14.
  DispatchSync(dispatch_queue(),
               [this, operation] { EnterCheckedOperation(operation); });
}

bool AsyncQueueImpl::ContainsDelayedOperation(const TimerId timer_id) const {
  VerifyOnTargetQueue();
  return std::find_if(operations_.begin(), operations_.end(),
                      [timer_id](const DelayedOperationPtr& op) {
                        return op->timer_id() == timer_id;
                      }) != operations_.end();
}

// Private

bool AsyncQueueImpl::OnTargetQueue() const {
  return GetCurrentQueueLabel() == GetTargetQueueLabel();
}

void AsyncQueueImpl::VerifyOnTargetQueue() const {
  FIREBASE_ASSERT_MESSAGE(OnTargetQueue(),
                          "We are running on the wrong dispatch queue. "
                          "Expected '%s' Actual: '%s'",
                          GetTargetQueueLabel().data(),
                          GetCurrentQueueLabel().data());
}

void AsyncQueueImpl::RunDelayedOperationsUntil(const TimerId last_timer_id) {
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

absl::string_view AsyncQueueImpl::GetCurrentQueueLabel() const {
  // Note: dispatch_queue_get_label may return nullptr if the queue wasn't
  // initialized with a label.
  return StringViewFromLabel(
      dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
}

absl::string_view AsyncQueueImpl::GetTargetQueueLabel() const {
  return StringViewFromLabel(dispatch_queue_get_label(dispatch_queue()));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
