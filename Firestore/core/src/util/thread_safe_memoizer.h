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
#include <memory>

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

  ThreadSafeMemoizer(const ThreadSafeMemoizer&) {
  }

  ThreadSafeMemoizer& operator=(const ThreadSafeMemoizer&) {
    return *this;
  }

  ThreadSafeMemoizer(ThreadSafeMemoizer&& other) = default;
  ThreadSafeMemoizer& operator=(ThreadSafeMemoizer&& other) = default;

  ~ThreadSafeMemoizer() {
    delete memoized_.load();
  }

  /**
   * Memoize a value.
   *
   * If there is no memoized value then the given function is called to create
   * the value, returning a reference to the created value and storing the
   * pointer to the created value. On the other hand, if there _is_ a memoized
   * value from a previous invocation then a reference to that object is
   * returned and the given function is not called. Note that the given function
   * may be called more than once and, therefore, must be idempotent.
   */
  const T& memoize(std::function<std::unique_ptr<T>()> func) {
    while (true) {
      T* old_memoized = memoized_.load();
      if (old_memoized) {
        return *old_memoized;
      }

      std::unique_ptr<T> new_memoized = func();

      if (memoized_.compare_exchange_strong(old_memoized, new_memoized.get())) {
        return *new_memoized.release();
      }
    }
  }

 private:
  std::atomic<T*> memoized_ = {nullptr};
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_THREAD_SAFE_MEMOIZER_H_
