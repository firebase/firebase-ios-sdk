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

#include <assert.h>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <thread>

#include <iostream>

namespace firebase {
namespace firestore {
namespace util {

// A thread-safe class similar to a priority queue where the entries are
// prioritized by the time for which they're scheduled. Entries scheduled for
// the exact same time are prioritized in FIFO order.
template <typename T, typename DurationT = std::chrono::system_clock::duration>
class Schedule {
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
      DoPop(out, scheduled_.begin());
      return true;
    }
    return false;
  }

  // Removes the first entry satisfying predicate from the queue, moves it into
  // `out`, and returns true. If no such entry exists, doesn't modify `out` and
  // returns false. Predicate is applied to entries in order according to their
  // scheduled time. Note that this function doesn't take into account whether
  // the removed entry is past its due time or not. `out` may be `nullptr` (in
  // which case the value will be simply discarded).
  template <typename Pred>
  bool RemoveIf(T* const out, const Pred pred) {
    std::lock_guard<std::mutex> lock{mutex_};
    const auto found =
        std::find_if(scheduled_.begin(), scheduled_.end(),
                     [&pred](const Entry& s) { return pred(s.value); });
    if (found != scheduled_.end()) {
      DoPop(out, found);
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

      // To minimize busy waiting, sleep until the nearest entry in the future
      // becomes due. If a new entry is added in the meantime, condition
      // variable will be notified, in which case the are two possibilities:
      // - the new entry is scheduled for a later time than `until`. In that
      // case, go back to sleep;
      // - the new entry is scheduled for a sooner time than `until`. In that
      // case, go to the next iteration of the loop to reevaluate `until`. This
      // should prevent a situation when the queue is waiting for an entry
      // scheduled at time x+10sec, in the meantime receives an entry scheduled
      // for time x+5sec, but still waits until time x+10sec before unblocking.
      const auto until = scheduled_.front().due;
      cv_.wait_until(lock, until,
                     [this, until] {
                     // return HasDue();
                     // return scheduled_.front().due < until;
                     return scheduled_.front().due != until;
                     });

      if (HasDue()) {
        DoPop(out, scheduled_.begin());
        return;
      }
      std::cout << "loop" << std::endl;
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
  using Container = std::deque<Entry>;
  using Iterator = typename Container::iterator;

  void InsertPreservingOrder(Entry&& new_entry) {
    std::lock_guard<std::mutex> lock{mutex_};

    const auto insertion_point =
        std::upper_bound(scheduled_.begin(), scheduled_.end(), new_entry);
    scheduled_.insert(insertion_point, std::move(new_entry));

    cv_.notify_one();
  }

  bool HasDue() const {
    namespace chr = std::chrono;
    const auto now = chr::time_point_cast<Duration>(chr::system_clock::now());
    return !scheduled_.empty() && now >= scheduled_.front().due;
  }

  void DoPop(T* const out, const Iterator where) {
    assert(!scheduled_.empty());

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

class DelayedOperation {
 public:
  void Cancel();

 private:
  using Id = unsigned int;

  friend class AsyncQueue;
  DelayedOperation(AsyncQueue* const queue, const Id id)
      : queue_{queue}, id_{id} {
  }

  AsyncQueue* const queue_ = nullptr;
  const Id id_ = 0;
};

class AsyncQueue {
 public:
  using Operation = std::function<void()>;
  using Milliseconds = std::chrono::milliseconds;

 private:
  using TimePoint = Schedule<Operation, Milliseconds>::TimePoint;
  using Id = DelayedOperation::Id;

 public:
  AsyncQueue();
  ~AsyncQueue();

  void Enqueue(Operation&& operation);
  DelayedOperation EnqueueAfterDelay(Milliseconds delay, Operation&& operation);
  void TryCancel(Id id);

 private:
  Id DoEnqueue(Operation&& operation, TimePoint when);

  void PollingThread();
  void UnblockQueue();
  unsigned int NextId();

  struct Entry {
    Entry() {
    }
    Entry(Operation&& operation, const AsyncQueue::Id id)
        : operation{std::move(operation)}, id{id} {
    }
    Operation operation;
    unsigned int id = 0;
  };
  Schedule<Entry, Milliseconds> schedule_;

  std::thread worker_thread_;
  std::atomic<bool> shutting_down_{false};

  std::atomic<unsigned int> current_id_{0};
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_H_
