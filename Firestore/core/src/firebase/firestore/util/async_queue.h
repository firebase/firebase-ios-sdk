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

#include <chrono>
#include <functional>
#include <memory>
#include <vector>

#include "absl/strings/string_view.h"
#include "dispatch/dispatch.h"

namespace firebase {
namespace firestore {
namespace util {

enum class TimerId : unsigned int {
  /**
   * Well-known "timer" IDs used when scheduling delayed callbacks on the
   * FSTDispatchQueue. These IDs can then be used from tests to check for the
   * presence of callbacks or to run them early.
   */
  /** All can be used with runDelayedCallbacksUntil: to run all timers. */
  All,

  /**
   * The following 4 timers are used in FSTStream for the listen and write
   * streams. The "Idle" timer is used to close the stream due to inactivity.
   * The "ConnectionBackoff" timer is used to restart a stream once the
   * appropriate backoff delay has elapsed.
   */
  ListenStreamIdle,
  ListenStreamConnectionBackoff,
  WriteStreamIdle,
  WriteStreamConnectionBackoff,

  /**
   * A timer used in FSTOnlineStateTracker to transition from FSTOnlineState
   * Unknown to Offline after a set timeout, rather than waiting indefinitely
   * for success or failure.
   */
  OnlineStateTimeout,
};

class AsyncQueue;

/*
// E.g.
class DelayedOperation {
 public:
  void Cancel() {
    if (auto live_instance = impl_.lock()) {
      live_instance->Cancel();
    }
  }
 private:
  std::weak_ptr<impl::DelayedOperation> impl_;
};

namespace impl {
class DelayedOperation {
  // ...
};
}

class AsyncQueue {
  // ...
  std::vector<std::shared_ptr<impl::DelayedOperation>> operations_;
};

 */

/**
 * Handle to a callback scheduled via [FSTDispatchQueue dispatchAfterDelay:].
 * Supports cancellation via the cancel method.
 */
class DelayedOperation {
 public:
  /**
   * Cancels the callback if it hasn't already been executed or canceled.
   *
   * As long as the callback has not yet been run, calling cancel() (from a
   * callback already running on the dispatch queue) provides a guarantee that
   * the operation will not be run.
   */
  void Cancel();

 private:
  using Seconds = std::chrono::seconds;
  using TimePoint = std::chrono::time_point<std::chrono::system_clock, Seconds>;
  using Operation = std::function<void()>;

  DelayedOperation(AsyncQueue* const queue,
                   const TimerId timer_id,
                   const Seconds delay,
                   Operation&& operation);

  // aka StartWithDelay
  void Schedule(Seconds delay);
  // aka delayDidElapse
  void Run();
  // aka SkipDelay
  void RunImmediately();
  void MarkDone();

  TimerId timer_id() const { return data_->timer_id_; }

  struct Data {
    Data(AsyncQueue* const queue,
         const TimerId timer_id,
         const Seconds delay,
         Operation&& operation);

    AsyncQueue* queue_{};
    TimerId timer_id_{};
    TimePoint target_time_;
    Operation operation_;
    // True if the operation has either been run or canceled.
    bool done_{};
  };

  std::shared_ptr<Data> data_;

  friend class AsyncQueue;
  friend bool operator==(const DelayedOperation& lhs, const DelayedOperation& rhs);
  friend bool operator<(const DelayedOperation& lhs, const DelayedOperation& rhs);
  friend struct ByTimerId;
};

class AsyncQueue {
 public:
  using Operation = DelayedOperation::Operation;
  using Seconds = DelayedOperation::Seconds;

  explicit AsyncQueue(const dispatch_queue_t native_handle)
      : native_handle_{native_handle} {
  }

  /**
   * Asserts that we are already running on this queue (actually, we can only
   * verify that the queue's label is the same, but hopefully that's good
   * enough.)
   */
  void VerifyIsCurrentQueue() const;

  /**
   * Declares that we are already executing on the correct dispatch_queue_t and
   * would like to officially execute code on behalf of this FSTDispatchQueue.
   * To be used only when called  back by some other API directly onto our
   * queue. This allows us to safely dispatch directly onto the worker queue
   * without destroying the invariants this class helps us maintain.
   */
  void EnterCheckedOperation(const Operation& operation);

  /**
   * Same as dispatch_async() except it asserts that we're not already on the
   * queue, since this generally indicates a bug (and can lead to re-ordering of
   * operations, etc).
   *
   * @param block The block to run.
   */
  void Enqueue(const Operation& operation);

  /**
   * Unlike dispatchAsync: this method does not require you to dispatch to a
   * different queue than the current one (thus it is equivalent to a raw
   * dispatch_async()).
   *
   * This is useful, e.g. for dispatching to the user's queue directly from user
   * API call (in which case we don't know if we're already on the user's queue
   * or not).
   *
   * @param block The block to run.
   */
  void EnqueueAllowingSameQueue(const Operation& operation);

  /**
   * Schedules a callback after the specified delay.
   *
   * Unlike dispatchAsync: this method does not require you to dispatch to a
   * different queue than the current one.
   *
   * The returned FSTDelayedCallback handle can be used to cancel the callback
   * prior to its running.
   *
   * @param block The block to run.
   * @param delay The delay (in seconds) after which to run the block.
   * @param timerID An FSTTimerID that can be used from tests to check for the
   * presence of this callback or to schedule it to run early.
   * @return A FSTDelayedCallback instance that can be used for cancellation.
   */
  DelayedOperation EnqueueWithDelay(Seconds delay,
                                    TimerId timer_id,
                                    Operation operation);

  /**
   * Wrapper for dispatch_sync(). Mostly meant for use in tests.
   *
   * @param block The block to run.
   */
  // void EnqueueSync(Operation operation);

  /**
   * For Tests: Determine if a delayed callback with a particular FSTTimerID
   * exists.
   */
  bool ContainsOperationWithTimerId(TimerId timer_id) const;

  /**
   * For Tests: Runs delayed callbacks early, blocking until completion.
   *
   * @param lastTimerID Only delayed callbacks up to and including one that was
   * scheduled using this FSTTimerID will be run. Method throws if no matching
   * callback exists.
   */
  void RunDelayedOperationsUntil(TimerId last_timer_id);

  /** The underlying wrapped dispatch_queue_t */
  dispatch_queue_t native_handle() const {
    return native_handle_;
  }

 private:
  void Dispatch(const Operation& operation);

  void Dequeue(const DelayedOperation& operation);

  bool OnTargetQueue() const;
  // GetLabel functions are guaranteed to never return a "null" string_view
  // (i.e. data() != nullptr).
  absl::string_view GetCurrentQueueLabel() const;
  absl::string_view GetTargetQueueLabel() const;

  dispatch_queue_t native_handle_{};
  std::vector<DelayedOperation> operations_;
  using OperationsIterator = std::vector<DelayedOperation>::iterator;
  bool is_operation_in_progress_{};

  friend class DelayedOperation;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase
