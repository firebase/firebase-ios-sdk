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
#include <cassert>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>

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
    if (!scheduled_.empty() && scheduled_.front().due <= time) {
      *out = std::move(scheduled_.front().value);
      scheduled_.pop_front();
      return true;
    }
    return false;
  }

  void PopBlocking(T* out) {
    assert(out);

    std::unique_lock<std::mutex> lock{mutex_};

    while (true) {
      cv_.wait(lock, [this] { return !scheduled_.empty(); });

      const auto until = scheduled_.front().due;
      const bool have_due = cv_.wait_until(lock, until, [this] {
        return !scheduled_.empty() &&
               std::chrono::system_clock::now() >= scheduled_.front().due;
      });

      if (have_due) {
        *out = std::move(scheduled_.front().value);
        scheduled_.pop_front();
        return;
      }
    }
  }

    // while (true) {
    //   if (!scheduled_.empty()) {
    //     if (scheduled_.front().due <= time) {
    //       *out = std::move(scheduled_.front().value);
    //       scheduled_.pop_front();
    //       return;
    //     } else {
    //       const auto until = scheduled_.front().due;
    //       cv_.wait_until(lock, until, [this] {
    //         return std::chrono::system_clock::now() <= scheduled_.front().due;
    //       });
    //     }
    //   } else {
    //     cv_.wait(lock, [this] { return !scheduled_.empty(); });
    //   }
    // }
  // }

 private:
  struct Scheduled {
    bool operator<(const Scheduled& rhs) const {
      return due < rhs.due;
    }

    T value;
    TimePoint due;
  };

  std::mutex mutex_;
  std::condition_variable cv_;
  std::deque<Scheduled> scheduled_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase
