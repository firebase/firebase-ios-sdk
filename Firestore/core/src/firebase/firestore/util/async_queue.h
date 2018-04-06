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
#include <cassert>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <thread>

namespace firebase {
namespace firestore {
namespace util {

template <typename T, typename Duration = std::chrono::system_clock::duration>
class Schedule {
 public:
  using TimePoint =
      std::chrono::time_point<std::chrono::system_clock, Duration>;

  void Push(const T& value, const TimePoint due) {
    std::lock_guard<std::mutex> lock{mutex_};

    Scheduled new_entry{value, due};
    const auto insertion_point =
        std::upper_bound(scheduled_.begin(), scheduled_.end(), new_entry);
    scheduled_.insert(insertion_point, std::move(new_entry));

    cv_.notify_one();
  }

  void Push(T&& value, const TimePoint due) {
    std::lock_guard<std::mutex> lock{mutex_};

    Scheduled new_entry{std::move(value), due};
    const auto insertion_point =
        std::upper_bound(scheduled_.begin(), scheduled_.end(), new_entry);
    scheduled_.insert(insertion_point, std::move(new_entry));

    cv_.notify_one();
  }

  bool PopIfDue(T* out, TimePoint time) {
    assert(out);

    std::lock_guard<std::mutex> lock{mutex_};
    if (HasDue(time)) {
      DoPop(out, scheduled_.begin());
      return true;
    }
    return false;
  }

  template <typename Pred>
  bool PopIf(T* const out, const Pred pred) {
    assert(out);

    std::lock_guard<std::mutex> lock{mutex_};
    const auto found =
        std::find_if(scheduled_.begin(), scheduled_.end(),
                     [&pred](const Scheduled& s) { return pred(s.value); });
    if (found != scheduled_.end()) {
      DoPop(out, found);
      return true;
    }
    return false;
  }

  void PopBlocking(T* out) {
    namespace chr = std::chrono;

    assert(out);

    std::unique_lock<std::mutex> lock{mutex_};

    while (true) {
      cv_.wait(lock, [this] { return !scheduled_.empty(); });

      const auto until = scheduled_.front().due;
      const bool have_due = cv_.wait_until(lock, until, [this] {
        return HasDue(chr::time_point_cast<Duration>(chr::system_clock::now()));
      });

      if (have_due) {
        DoPop(out, scheduled_.begin());
        return;
      }
    }
  }

 private:
  struct Scheduled {
    bool operator<(const Scheduled& rhs) const {
      return due < rhs.due;
    }

    T value;
    TimePoint due;
  };
  using Container = std::deque<Scheduled>;
  using Iterator = typename Container::iterator;

  bool HasDue(const TimePoint& time) const {
    return !scheduled_.empty() && time >= scheduled_.front().due;
  }

  void DoPop(T* out, const Iterator where) {
    assert(!scheduled_.empty());

    if (out) {
      *out = std::move(where->value);
    }
    scheduled_.erase(where);
  }

  std::mutex mutex_;
  std::condition_variable cv_;
  std::deque<Scheduled> scheduled_;
};

class AsyncQueue;

class DelayedOperation {
 public:
  void Cancel();

 private:
  using Tag = unsigned int;

  friend class AsyncQueue;
  DelayedOperation(AsyncQueue* const queue, const Tag tag)
      : queue_{queue}, tag_{tag} {
  }

  AsyncQueue* const queue_ = nullptr;
  const Tag tag_ = 0;
};

class AsyncQueue {
 public:
  using Operation = std::function<void()>;
  using Milliseconds = std::chrono::milliseconds;

 private:
  using TimePoint = Schedule<Operation, Milliseconds>::TimePoint;
  using Tag = DelayedOperation::Tag;

 public:
  AsyncQueue() : worker_thread_{&AsyncQueue::Worker, this} {
  }

  ~AsyncQueue() {
    shutting_down_ = true;
    UnblockQueue();
    worker_thread_.join();
  }

  void Enqueue(Operation&& operation) {
    DoEnqueue(std::move(operation), TimePoint{});
  }

  DelayedOperation EnqueueAfterDelay(const Milliseconds delay,
                                     Operation&& operation) {
    namespace chr = std::chrono;

    const auto now =
        chr::time_point_cast<Milliseconds>(chr::system_clock::now());
    const auto tag = DoEnqueue(std::move(operation), now + delay);

    return DelayedOperation{this, tag};
  }

  void TryCancel(const Tag tag) {
    Entry discard;
    schedule_.PopIf(&discard, [tag](const Entry& e) { return e.tag == tag; });
  }

 private:
  Tag DoEnqueue(Operation&& operation, const TimePoint when) {
    const auto tag = NextTag();
    schedule_.Push(Entry{std::move(operation), tag}, when);
    return tag;
  }

  void Worker() {
    while (!shutting_down_) {
      Entry entry;
      schedule_.PopBlocking(&entry);
      if (entry.operation) {
        entry.operation();
      }
    }
  }

  void UnblockQueue() {
    schedule_.Push(Entry{[] {}, /*tag=*/0}, TimePoint{});
  }

  unsigned int NextTag() {
    return current_tag_++;
  }

  struct Entry {
    Entry() {
    }
    Entry(Operation&& operation, const AsyncQueue::Tag tag)
        : operation{std::move(operation)}, tag{tag} {
    }
    Operation operation;
    unsigned int tag{};
  };
  Schedule<Entry, Milliseconds> schedule_;

  std::thread worker_thread_;
  std::atomic<bool> shutting_down_{false};

  std::atomic<unsigned int> current_tag_{0};
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_H_
