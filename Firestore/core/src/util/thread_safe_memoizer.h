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
#include <utility>

namespace firebase {
namespace firestore {
namespace util {

/**
 * Stores a memoized value in a manner that is safe to be shared between
 * multiple threads.
 */
template <typename T>
class ThreadSafeMemoizer {
 public:
  explicit ThreadSafeMemoizer(std::function<std::shared_ptr<T>()> func) : func_(std::move(func)) {
  }

  ThreadSafeMemoizer(const ThreadSafeMemoizer& other) : func_(other.func_), memoized_(std::atomic_load(&other.memoized_)) {}

  ThreadSafeMemoizer& operator=(const ThreadSafeMemoizer& other) {
    func_ = other.func_;
    std::atomic_store(&memoized_, std::atomic_load(&other.memoized_));
    return *this;
  }

  ThreadSafeMemoizer(ThreadSafeMemoizer&& other) noexcept : func_(std::move(other.func_)), memoized_(std::atomic_load(&other.memoized_)) {
  }

  ThreadSafeMemoizer& operator=(ThreadSafeMemoizer&& other) noexcept {
    func_ = std::move(other.func_);
    std::atomic_store(&memoized_, std::atomic_load(&other.memoized_));
    return *this;
  }

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
  const T& value() {
    std::shared_ptr<T> old_memoized = std::atomic_load(&memoized_);
    while (true) {
      if (old_memoized) {
        return *old_memoized;
      }

      std::shared_ptr<T> new_memoized = func_();

      if (std::atomic_compare_exchange_weak(&memoized_, &old_memoized, new_memoized)) {
        return *new_memoized;
      }
    }
  }

 private:
  std::function<std::shared_ptr<T>()> func_;
  std::shared_ptr<T> memoized_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_THREAD_SAFE_MEMOIZER_H_
