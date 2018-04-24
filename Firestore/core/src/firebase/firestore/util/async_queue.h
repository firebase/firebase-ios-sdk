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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_H_

#include <atomic>
#include <chrono>  // NOLINT(build/c++11)
#include <functional>
#include <memory>

#include "Firestore/core/src/firebase/firestore/util/executor.h"

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

// A serial queue that executes given operations asynchronously, one at a time.
// Operations may be scheduled to be executed as soon as possible or in the
// future. Operations scheduled for the same time are FIFO-ordered.
//
// `AsyncQueue` wraps a platform-specific executor, adding checks that enforce
// sequential ordering of operations: an enqueued operation, while being run,
// normally cannot enqueue other operations for immediate execution, called
// "nesting" (but see `EnqueueAllowingNesting`).
//
// `AsyncQueue` methods have particular expectations about whether they must be
// invoked on the queue or not; check "preconditions" section in comments on
// each method.
//
// A significant portion of `AsyncQueue` interface only exists for test purposes
// and must *not* be used in regular code.
class AsyncQueue {
 public:
  using Operation = internal::Executor::Operation;
  // A more-or-less arbitrary unit of time for scheduling operations in the
  // future.
  using Milliseconds = internal::Executor::Milliseconds;

  explicit AsyncQueue(std::unique_ptr<internal::Executor> executor);

  // Asserts for the caller that it is being invoked asynchronously on the
  // `AsyncQueue.`
  void VerifyIsAsyncCall() const;
  // Asserts for the caller that it is being invoked as part of an operation on
  // the `AsyncQueue`.
  void VerifyCalledFromOperation() const;

  // Puts the `operation` on the queue to be executed as soon as possible, while
  // maintaining FIFO order.
  //
  // Precondition: `Enqueue` calls cannot be nested; that is, `Enqueue` may not
  // be called by a previously enqueued operation when it is run (as a special
  // case, destructors invoked when an enqueued operation has run and is being
  // destroyed may invoke `Enqueue`).
  void Enqueue(const Operation& operation);

  // Like `Enqueue`, but allowing nesting.
  void EnqueueAllowingNesting(const Operation& operation);

  // Puts the `operation` on the queue to be executed `delay` milliseconds from
  // now, and returns a handle that allows to cancel the operation (provided it
  // hasn't run already).
  //
  // `operation` is tagged by a `timer_id` which allows to identify the caller.
  // Only one operation tagged with any given `timer_id` may be on the queue at
  // any time; an attempt to put another such operation will result in an
  // assertion failure. In tests, these tags also allow to check for presence of
  // certain operations and to run certain operations in advance.
  //
  // Precondition: `EnqueueAfterDelay` is being invoked asynchronously on the
  // queue.
  DelayedOperation EnqueueAfterDelay(Milliseconds delay,
                                     TimerId timer_id,
                                     const Operation& operation);

  // Immediately executes the `operation` on the queue.
  //
  // Precondition: the queue is idle at the moment of the call (no other
  // operation is currently being executed).
  //
  // Precondition: `StartExecution` is being invoked asynchronously on the
  // queue.
  void StartExecution(const Operation& operation);

  // Test-only interface follows

  // Like `Enqueue`, but blocks until the `operation` is complete.
  void EnqueueBlocking(const Operation& operation);

  // Checks whether an operation tagged with `timer_id` is currently scheduled
  // for execution in the future.
  //
  // Precondition: `StartExecution` is being invoked asynchronously on the
  // queue.
  bool IsScheduled(TimerId timer_id) const;

  // Force runs operations scheduled for future execution, in scheduled order,
  // up to *and including* the operation tagged with `last_timer_id`.
  //
  // Precondition: `RunScheduledOperationsUntil` is *not* being invoked on the
  // queue.
  void RunScheduledOperationsUntil(TimerId last_timer_id);

 private:
  // TODO(varconst): dispatch_queue_t dispatch_queue() const;

  Operation Wrap(const Operation& operation);

  void VerifySequentialOrder() const;

  std::atomic<bool> is_operation_in_progress_;
  std::unique_ptr<internal::Executor> executor_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_H_
