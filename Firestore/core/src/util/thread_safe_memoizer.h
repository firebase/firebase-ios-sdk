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

#include <atomic>
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
  ThreadSafeMemoizer()
      : memoized_(new std::atomic<T*>(nullptr), MemoizedValueDeleter) {
  }

  ThreadSafeMemoizer(const ThreadSafeMemoizer& other) = default;
  ThreadSafeMemoizer& operator=(const ThreadSafeMemoizer& other) = default;
  ThreadSafeMemoizer(ThreadSafeMemoizer&& other) = default;
  ThreadSafeMemoizer& operator=(ThreadSafeMemoizer&& other) = default;

  /**
   * Memoize a value.
   *
   * If there is _no_ memoized value then the given function is called to create
   * the object to memoize. The created object is then stored for use in future
   * invocations as the "memoized value". Finally, a reference to the created
   * object is returned.
   *
   * On the other hand, if there _is_ a memoized value, then a reference to that
   * memoized value object is returned and the given function is _not_ called.
   *
   * The given function *must* be idempotent because it _may_ be called more
   * than once due to the semantics of std::atomic::compare_exchange_weak().
   *
   * No reference to the given function is retained by this object, and the
   * function be called synchronously, if it is called at all.
   */
  const T& memoize(std::function<std::unique_ptr<T>()> func) {
    while (true) {
      T* old_memoized = memoized_->load();
      if (old_memoized) {
        return *old_memoized;
      }

      std::unique_ptr<T> new_memoized = func();

      if (memoized_->compare_exchange_weak(old_memoized, new_memoized.get())) {
        return *new_memoized.release();
      }
    }
  }

 private:
  std::shared_ptr<std::atomic<T*>> memoized_;

  static void MemoizedValueDeleter(std::atomic<T*>* value) {
    delete value->load();
    delete value;
  }
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_THREAD_SAFE_MEMOIZER_H_
