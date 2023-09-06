/*
 * Copyright 2023 Google
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

#ifndef THREAD_SAFE_MEMOIZER_H_
#define THREAD_SAFE_MEMOIZER_H_

#include <functional>
#include <mutex>
#include <vector>

namespace firebase {
namespace firestore {
namespace core {

/**
 * Stores a memoized value in a manner that is safe to be shared between
 * multiple threads.
 */
template <typename T>
class ThreadSafeMemoizer {
 public:
  ~ThreadSafeMemoizer() {
    // Call `std::call_once` in order to synchronize with the "active"
    // invocation of `memoize()`. Without this synchronization, there is a data
    // race between this destructor, which "reads" `filters_` to destroy it, and
    // the write to `filters_` done by the "active" invocation of `memoize()`.
    std::call_once(once_, [&]() {});
  };

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
  const std::vector<T>& memoize(std::function<std::vector<T>()> func) {
    std::call_once(once_, [&]() { filters_ = func(); });
    return filters_;
  };

 private:
  std::once_flag once_;
  std::vector<T> filters_;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // THREAD_SAFE_MEMOIZER_H_
