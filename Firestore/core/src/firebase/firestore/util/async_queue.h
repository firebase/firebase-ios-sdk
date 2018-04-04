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

  void Push(const T& value, TimePoint due = TimePoint{}) {
    std::lock_guard<std::mutex> lock{mutex_};
    const auto insertion_point =
        std::upper_bound(scheduled_.begin(), scheduled_.end());
    scheduled_.insert(insertion_point, {value, due});
    cv_.notify_one();
  }

  void Push(T&& value, TimePoint due = TimePoint{}) {
    std::lock_guard<std::mutex> lock{mutex_};
    const auto insertion_point =
        std::upper_bound(scheduled_.begin(), scheduled_.end());
    scheduled_.insert(insertion_point, {std::move(value), due});
    cv_.notify_one();
  }

  bool PopIfDue(T* out, TimePoint time) {
    assert(out);

    std::lock_guard<std::mutex> lock{mutex_};
    if (HasDue(time)) {
      DoPop(out);
      return true;
    }
    return false;
  }

  void PopBlocking(T* out, const std::atomic<bool>& break_early) {
    namespace chr = std::chrono;
    assert(out);

    std::unique_lock<std::mutex> lock{mutex_};

    while (true) {
      cv_.wait(lock, [this, &break_early] {
        return !scheduled_.empty() || break_early;
      });
      if (break_early) return;

      const auto until = scheduled_.front().due;
      const bool have_due = cv_.wait_until(lock, until, [this, &break_early] {
        return HasDue(
                   chr::time_point_cast<Duration>(chr::system_clock::now())) ||
               break_early;
      });

      if (break_early) return;

      if (have_due) {
        DoPop(out);
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

  bool HasDue(const TimePoint& time) const {
    return !scheduled_.empty() && time >= scheduled_.front().due;
  }

  void DoPop(T* out) {
    assert(out);
    assert(!scheduled_.empty());

    *out = std::move(scheduled_.front().value);
    scheduled_.pop_front();
  }

  std::mutex mutex_;
  std::condition_variable cv_;
  std::deque<Scheduled> scheduled_;
};

class Queue {
 public:
  using Operation = std::function<void()>;
  using Milliseconds = std::chrono::milliseconds;

  Queue() {
  }

  ~Queue() {
    shutting_down_ = true;
    worker_thread_.join();
  }

  void Worker() {
    while (!shutting_down_) {
      Operation operation;
      schedule_.PopBlocking(&operation, shutting_down_);
      if (operation) {
        operation();
      }
    }
  }

 private:
  Schedule<Operation, Milliseconds> schedule_;
  std::thread worker_thread_;
  std::atomic<bool> shutting_down_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase
