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

#include <algorithm>
#include <atomic>
#include <chrono>              // NOLINT(build/c++11)
#include <condition_variable>  // NOLINT(build/c++11)
#include <deque>
#include <functional>
#include <mutex>   // NOLINT(build/c++11)
#include <thread>  // NOLINT(build/c++11)
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace util {

// A thread-safe class similar to a priority queue where the entries are
// prioritized by the time for which they're scheduled. Entries scheduled for
// the exact same time are prioritized in FIFO order.
//
// The main function of `Schedule` is `PopBlocking`, which sleeps until an entry
// becomes available. It correctly handles entries being asynchonously added or
// removed from the schedule.
//
// The details of time management are completely concealed within the class.
// Once an entry is scheduled, there is no way to reschedule or even retrieve
// the time.
template <typename T, typename DurationT = std::chrono::system_clock::duration>
class Schedule {
  // Internal invariants:
  // - entries are always in sorted order, leftmost entry is always the most
  //   due;
  // - each operation modifying the queue notifies the condition variable `cv_`.
 public:
  using Duration = DurationT;
  // Entries are scheduled using absolute time.
  using TimePoint =
      std::chrono::time_point<std::chrono::system_clock, Duration>;

  // Schedules an entry for the specified time due. `due` may be in the past.
  void Push(const T& value, const TimePoint due) {
    InsertPreservingOrder(Entry{value, due});
  }
  void Push(T&& value, const TimePoint due) {
    InsertPreservingOrder(Entry{std::move(value), due});
  }

  // If the queue contains at least one entry for which the scheduled time is
  // due now (according to the system clock), removes the entry which is the
  // most overdue from the queue, moves it into `out`, and returns true. If no
  // entry is due, doesn't modify `out` and returns false. `out` may be
  // `nullptr` (in which case the value will be simply discarded).
  bool PopIfDue(T* const out) {
    std::lock_guard<std::mutex> lock{mutex_};

    if (HasDue()) {
      Extract(out, scheduled_.begin());
      return true;
    }
    return false;
  }

  // Removes the first entry satisfying predicate from the queue, moves it into
  // `out`, and returns true. If no such entry exists, doesn't modify `out` and
  // returns false. Predicate is applied to entries in order according to their
  // scheduled time. `out` may be `nullptr` (in which case the value will be
  // simply discarded).
  //
  // Note that this function doesn't take into account whether the removed entry
  // is past its due time.
  template <typename Pred>
  bool RemoveIf(T* const out, const Pred pred) {
    std::lock_guard<std::mutex> lock{mutex_};
    const auto found =
        std::find_if(scheduled_.begin(), scheduled_.end(),
                     [&pred](const Entry& s) { return pred(s.value); });
    if (found != scheduled_.end()) {
      Extract(out, found);
      return true;
    }
    return false;
  }

  // Blocks until at least one entry is available for which the scheduled time
  // is due now (according to the system clock), removes the entry which is the
  // most overdue from the queue and moves it into `out`. The function will
  // attempt to minimize both the waiting time and busy waiting. `out` may be
  // `nullptr` (in which case the value will be simply discarded).
  void PopBlocking(T* const out) {
    std::unique_lock<std::mutex> lock{mutex_};

    while (true) {
      cv_.wait(lock, [this] { return !scheduled_.empty(); });

      // To minimize busy waiting, sleep until either the nearest entry in the
      // future either changes, or else becomes due.
      const auto until = scheduled_.front().due;
      cv_.wait_until(lock, until,
                     [this, until] { return scheduled_.front().due != until; });
      // There are 3 possibilities why `wait_until` has returned:
      // - `wait_until` has timed out, in which case the current time is at
      //   least `until`, so there must be an overdue entry;
      // - a new entry has been added which comes before `until`. It must be
      //   either overdue (in which case `HasDue` will break the cycle), or else
      //   `until` must be reevaluated (on the next iteration of the loop);
      // - `until` entry has been removed. This means `until` has to be
      //   reevaluated, similar to #2.

      if (HasDue()) {
        Extract(out, scheduled_.begin());
        return;
      }
    }
  }

  bool empty() const {
    std::lock_guard<std::mutex> lock{mutex_};
    return scheduled_.empty();
  }

  size_t size() const {
    std::lock_guard<std::mutex> lock{mutex_};
    return scheduled_.size();
  }

 private:
  struct Entry {
    bool operator<(const Entry& rhs) const {
      return due < rhs.due;
    }

    T value;
    TimePoint due;
  };
  // All removals are on the front, but most insertions are expected to be on
  // the back.
  using Container = std::deque<Entry>;
  using Iterator = typename Container::iterator;

  void InsertPreservingOrder(Entry&& new_entry) {
    std::lock_guard<std::mutex> lock{mutex_};

    const auto insertion_point =
        std::upper_bound(scheduled_.begin(), scheduled_.end(), new_entry);
    scheduled_.insert(insertion_point, std::move(new_entry));

    cv_.notify_one();
  }

  // This function expects the mutex to be already locked.
  bool HasDue() const {
    namespace chr = std::chrono;
    const auto now = chr::time_point_cast<Duration>(chr::system_clock::now());
    return !scheduled_.empty() && now >= scheduled_.front().due;
  }

  // This function expects the mutex to be already locked.
  void Extract(T* const out, const Iterator where) {
    FIREBASE_ASSERT_MESSAGE(!scheduled_.empty(),
                            "Trying to pop an entry from an empty queue.");

    if (out) {
      *out = std::move(where->value);
    }
    scheduled_.erase(where);
    cv_.notify_one();
  }

  mutable std::mutex mutex_;
  std::condition_variable cv_;
  Container scheduled_;
};

class AsyncQueue;

// A non-owning handle to an operation scheduled in the future, allowing to
// cancel the operation.
class DelayedOperation {
 public:
  // If the operation has not been run yet, cancels the operation. Otherwise,
  // it's a no-op.
  void Cancel();

 private:
  using Id = unsigned int;

  // Don't allow callers to create their own `DelayedOperation`s.
  friend class AsyncQueue;
  DelayedOperation(AsyncQueue* const queue, const Id id)
      : queue_{queue}, id_{id} {
  }

  AsyncQueue* const queue_ = nullptr;
  const Id id_ = 0;
};

// A serial queue that executes provided operations on a dedicated background
// thread.
//
// Operations may be scheduled for immediate or delayed execution. Operations
// scheduled for the exact same time are FIFO ordered. Immediate operations
// always come before delayed operations.
//
// The operations are executed sequentially; only a single operation is executed
// at any given time.
//
// Delayed operations may be canceled if they have not already been run.
class AsyncQueue {
 public:
  using Operation = std::function<void()>;
  using Milliseconds = std::chrono::milliseconds;

 public:
  AsyncQueue();
  ~AsyncQueue();

  // Enqueues the `operation` for immediate execution on the background thread.
  void Enqueue(Operation&& operation);
  // Enqueues the `operation` for execution on the background thread once the
  // `delay` from now (according to the system clock) has passed. Returns
  // a handle which allows to cancel the delayed operation.
  //
  // `delay` must be non-negative; use `Enqueue` to schedule operations for
  // immediate execution.
  DelayedOperation EnqueueAfterDelay(Milliseconds delay, Operation&& operation);

 private:
  using TimePoint = Schedule<Operation, Milliseconds>::TimePoint;
  // To allow canceling operations, each scheduled operation is assigned
  // a monotonically increasing identifier.
  using Id = DelayedOperation::Id;

  friend class DelayedOperation;  // For access to `TryCancel`
  // If the operation hasn't yet been run, it will be removed from the queue.
  // Otherwise, this function is a no-op.
  void TryCancel(const DelayedOperation& operation);

  Id DoEnqueue(Operation&& operation, TimePoint when);

  void PollingThread();
  void UnblockQueue();
  Id NextId();

  // As a convention, assign the epoch time to all operations scheduled for
  // immediate execution. Note that it means that an immediate operation is
  // always scheduled before any delayed operation, even in the corner case when
  // the immediate operation was scheduled after a delayed operation was due
  // (but hasn't yet run).
  static TimePoint Immediate() {
    return TimePoint{};
  }

  struct Entry {
    Entry() {
    }
    Entry(Operation&& operation, const AsyncQueue::Id id)
        : operation{std::move(operation)}, id{id} {
    }
    Operation operation;
    Id id = 0;
  };
  // Operations scheduled for immediate execution are also put on the schedule
  // (with due time set to `Immediate`).
  Schedule<Entry, Milliseconds> schedule_;

  std::thread worker_thread_;
  // Used to stop the worker thread.
  std::atomic<bool> shutting_down_{false};

  std::atomic<Id> current_id_{0};
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_H_
