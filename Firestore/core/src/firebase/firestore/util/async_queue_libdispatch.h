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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_LIBDISPATCH_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_LIBDISPATCH_H_

#include "dispatch/dispatch.h"
#include <atomic>
#include <chrono>  // NOLINT(build/c++11)
#include <functional>
#include <memory>
#include <vector>

#include "absl/strings/string_view.h"

/** An implementation of `AsyncQueue` built on top of libdispatch. */

namespace firebase {
namespace firestore {
namespace util {

/**
 * Well-known "timer" ids used when scheduling delayed operations on the
 * AsyncQueue. These ids can then be used from tests to check for the
 * presence of delayed operations or to run them early.
 */
enum class TimerId {
  /** All can be used with `RunDelayedOperationsUntil` to run all timers. */
  All,

  /**
   * The following 4 timers are used in `Stream` for the listen and write
   * streams. The "Idle" timer is used to close the stream due to inactivity.
   * The "ConnectionBackoff" timer is used to restart a stream once the
   * appropriate backoff delay has elapsed.
   */
  ListenStreamIdle,
  ListenStreamConnectionBackoff,
  WriteStreamIdle,
  WriteStreamConnectionBackoff,

  /**
   * A timer used in `OnlineStateTracker` to transition from
   * `OnlineStateUnknown` to `Offline` after a set timeout, rather than waiting
   * indefinitely for success or failure.
   */
  OnlineStateTimeout,
};

namespace internal {
class DelayedOperationImpl;
}  // namespace internal

/**
 * Handle to an operation scheduled via AsyncQueue::EnqueueAfterDelay. Supports
 * cancellation via the cancel method.
 */
class DelayedOperation {
 public:
  /**
   * Cancels the operation if it hasn't already been executed or canceled.
   *
   * As long as the operation has not yet been run, calling `Cancel()` (from an
   * operation already running on the dispatch queue) provides a guarantee that
   * the operation will not be run.
   */
  void Cancel();

  DelayedOperation() = default;

 private:
  // Don't allow callers to create their own `DelayedOperation`s.
  friend class AsyncQueue;
  explicit DelayedOperation(
      const std::shared_ptr<internal::DelayedOperationImpl>& operation)
      : handle_{operation} {
  }

  std::weak_ptr<internal::DelayedOperationImpl> handle_;
};

class AsyncQueue {
 public:
  using Milliseconds = std::chrono::milliseconds;
  using Operation = std::function<void()>;

  explicit AsyncQueue(const dispatch_queue_t dispatch_queue);

  /**
   * Asserts that we are already running on this queue (actually, we can only
   * verify that the queue's label is the same, but hopefully that's good
   * enough).
   */
  void VerifyIsCurrentQueue() const;

  /**
   * Declares that we are already executing on the correct `dispatch_queue_t`
   * and would like to officially execute code on behalf of this `AsyncQueue`.
   * To be used only when called back by some other API directly onto our queue.
   * This allows us to safely dispatch directly onto the worker queue without
   * destroying the invariants this class helps us maintain.
   */
  void EnterCheckedOperation(const Operation& operation);

  /**
   * Same as `dispatch_async()` except it asserts that we're not already on the
   * queue, since this generally indicates a bug (and can lead to re-ordering of
   * operations, etc).
   *
   * @param operation The operation to run.
   */
  void Enqueue(const Operation& operation);

  /**
   * Unlike `Enqueue`, this method does not require you to dispatch to a
   * different queue than the current one (thus it is equivalent to a raw
   * `dispatch_async()`).
   *
   * This is useful, e.g. for dispatching to the user's queue directly from user
   * API call (in which case we don't know if we're already on the user's queue
   * or not).
   *
   * @param operation The operation to run.
   */
  void EnqueueAllowingSameQueue(const Operation& operation);

  /**
   * Schedules an operation after the specified delay.
   *
   * Unlike `Enqueue`, this method does not require you to dispatch to a
   * different queue than the current one.
   *
   * The returned `DelayedOperation` handle can be used to cancel the operation
   * prior to its running.
   *
   * @param delay The delay after which to run the operation.
   * @param timer_id A `TimerId` that is used as a tag to identify which caller
   *     has scheduled this operation. For each value of `TimerId`, only
   *     a single operation tagged with that value can be in the queue at any
   *     given moment; an attempt to schedule a second one will result in an
   *     error. The `TimerId` is mostly intended to be used from tests to check
   *     for the presence of this operation or to schedule it to run early.
   * @param operation The operation to run.
   * @return A `DelayedOperation` instance that can be used for cancellation.
   */
  DelayedOperation EnqueueAfterDelay(Milliseconds delay,
                                     TimerId timer_id,
                                     Operation operation);

  /**
   * Wrapper for `dispatch_sync()`. Mostly meant for use in tests.
   *
   * @param operation The operation to run.
   */
  void RunSync(const Operation& operation);

  /**
   * For tests: determine if a delayed operation with a particular `TimerId`
   * exists.
   */
  bool ContainsDelayedOperation(TimerId timer_id) const;

  /**
   * For tests: runs delayed operations early, blocking until completion.
   *
   * @param last_timer_id Only delayed operations up to and including one that
   *     was scheduled using this `TimerId` will be run. Method crashes if no
   *     matching operation exists.
   */
  void RunDelayedOperationsUntil(TimerId last_timer_id);

  /** The underlying wrapped `dispatch_queue_t`. */
  dispatch_queue_t dispatch_queue() const {
    return dispatch_queue_;
  }

 private:
  void Dispatch(const Operation& operation);

    std::shared_ptr<internal::DelayedOperationImpl> RemoveDelayedOperation(const internal::DelayedOperationImpl& operation);

  bool OnTargetQueue() const;
  void VerifyOnTargetQueue() const;
  // GetLabel functions are guaranteed to never return a "null" string_view
  // (i.e. data() != nullptr).
  absl::string_view GetCurrentQueueLabel() const;
  absl::string_view GetTargetQueueLabel() const;

  // const dispatch_queue_t dispatch_queue_;
  std::atomic<dispatch_queue_t> dispatch_queue_;
  using DelayedOperationPtr = std::shared_ptr<internal::DelayedOperationImpl>;
  std::vector<DelayedOperationPtr> operations_;
  std::atomic<bool> is_operation_in_progress_{false};

  // For access to RemoveDelayedOperation.
  friend class internal::DelayedOperationImpl;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_LIBDISPATCH_H_
