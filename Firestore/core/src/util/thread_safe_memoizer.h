/*
 * Copyright 2023 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_UTIL_THREAD_SAFE_MEMOIZER_H_
#define FIRESTORE_CORE_SRC_UTIL_THREAD_SAFE_MEMOIZER_H_

#include <functional>
#include <mutex>  // NOLINT(build/c++11)
#include <vector>

namespace firebase {
namespace firestore {
namespace util {

/**
 * Stores a memoized value in a manner that is safe to be shared between
 * multiple threads.
 *
 * TODO(b/299933587) Make `ThreadSafeMemoizer` copyable and moveable.
 */
template <typename T>
class ThreadSafeMemoizer {
 public:
  ThreadSafeMemoizer() = default;

  ~ThreadSafeMemoizer() {
    // Call `std::call_once` in order to synchronize with the "active"
    // invocation of `memoize()`. Without this synchronization, there is a data
    // race between this destructor, which "reads" `memoized_value_` to destroy
    // it, and the write to `memoized_value_` done by the "active" invocation of
    // `memoize()`.
    std::call_once(once_, [&]() {});
  }

  // This class cannot be copied or moved, because it has `std::once_flag`
  // member.
  ThreadSafeMemoizer(const ThreadSafeMemoizer&) = delete;
  ThreadSafeMemoizer(ThreadSafeMemoizer&&) = delete;
  ThreadSafeMemoizer& operator=(const ThreadSafeMemoizer&) = delete;
  ThreadSafeMemoizer& operator=(ThreadSafeMemoizer&&) = delete;

  /**
   * Memoize a value.
   *
   * The std::function object specified by the first invocation of this
   * function (the "active" invocation) will be invoked synchronously.
   * None of the std::function objects specified by the subsequent
   * invocations of this function (the "passive" invocations) will be
   * invoked. All invocations, both "active" and "passive", will return a
   * reference to the std::vector created by copying the return value from
   * the std::function specified by the "active" invocation. It is,
   * therefore, the "active" invocation's job to return the std::vector
   * to memoize.
   */
  const T& memoize(std::function<T()> func) {
    std::call_once(once_, [&]() { memoized_value_ = func(); });
    return memoized_value_;
  }

 private:
  std::once_flag once_;
  T memoized_value_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_THREAD_SAFE_MEMOIZER_H_
