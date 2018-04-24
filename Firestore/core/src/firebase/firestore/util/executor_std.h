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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_EXECUTOR_STD_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_EXECUTOR_STD_H_

#include <algorithm>
#include <atomic>
#include <condition_variable>  // NOLINT(build/c++11)
#include <deque>
#include <mutex>   // NOLINT(build/c++11)
#include <thread>  // NOLINT(build/c++11)
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace util {
namespace internal {

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
template <typename T, typename Duration = std::chrono::system_clock::duration>
class Schedule {
  // Internal invariants:
  // - entries are always in sorted order, leftmost entry is always the most
  //   due;
  // - each operation modifying the queue notifies the condition variable `cv_`.
 public:
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

  // Checks whether the queue contains an entry satisfying the given predicate.
  template <typename Pred>
  bool Contains(const Pred pred) const {
    std::lock_guard<std::mutex> lock{mutex_};

    // While this logically duplicates part of the implementation of `RemoveIf`,
    // a helper function would need two overloads, const and non-const,
    // eliminating any gains in brevity.
    return std::find_if(scheduled_.begin(), scheduled_.end(),
                        [&pred](const Entry& s) { return pred(s.value); }) !=
           scheduled_.end();
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

// A serial queue that executes provided operations on a dedicated background
// thread, using C++11 standard library functionality.
class ExecutorStd : public Executor {
 public:
  ExecutorStd();
  ~ExecutorStd();

  void Execute(Operation&& operation) override;
  void ExecuteBlocking(Operation&& operation) override;

  DelayedOperation ScheduleExecution(Milliseconds delay,
                                     TaggedOperation&& tagged) override;

  bool IsAsyncCall() const override;
  std::string GetInvokerId() const override;

  bool IsScheduled(Tag tag) const override;
  bool IsScheduleEmpty() const override;
  TaggedOperation PopFromSchedule() override;

 private:
  using TimePoint = Schedule<Operation, Milliseconds>::TimePoint;
  // To allow canceling operations, each scheduled operation is assigned
  // a monotonically increasing identifier.
  using Id = unsigned int;

  // If the operation hasn't yet been run, it will be removed from the queue.
  // Otherwise, this function is a no-op.
  void TryCancel(Id operation_id);

  Id DoExecute(Operation&& operation, TimePoint when, Tag tag = -1);

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
    Entry(Operation&& operation,
          const ExecutorStd::Id id,
          const ExecutorStd::Tag tag = NoTag)
        : operation{std::move(operation)}, id{id}, tag{tag} {
    }

    bool IsImmediate() const {
      return tag == NoTag;
    }

    Operation operation;
    Id id = 0;
    static constexpr Tag NoTag = -1;
    Tag tag = NoTag;
  };
  // Operations scheduled for immediate execution are also put on the schedule
  // (with due time set to `Immediate`).
  Schedule<Entry, Milliseconds> schedule_;

  std::thread worker_thread_;
  // Used to stop the worker thread.
  std::atomic<bool> shutting_down_{false};

  std::atomic<Id> current_id_{0};
};

}  // namespace internal
}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_EXECUTOR_STD_H_
