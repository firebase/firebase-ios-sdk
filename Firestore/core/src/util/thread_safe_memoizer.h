/*
 * Copyright 2025 Google LLC
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
#include <utility>

namespace firebase {
namespace firestore {
namespace util {

// Put the C++11 and C++20 implementations into different inline namespaces so
// that if, by chance, parts of the code compile with different values of
// `__cpp_lib_atomic_shared_ptr` this will not result in an ODR-violation
// (at least on account of just the differing `__cpp_lib_atomic_shared_ptr`).
//
// TODO(c++20): Remove the inline namespaces once the other #ifdef checks for
//  __cpp_lib_atomic_shared_ptr are removed.
#ifdef __cpp_lib_atomic_shared_ptr
inline namespace cpp20_atomic_shared_ptr {
#else
inline namespace cpp11_atomic_free_functions {
#endif

/**
 * Stores a memoized value in a manner that is safe to be shared between
 * multiple threads.
 */
template <typename T>
class ThreadSafeMemoizer {
 public:
  /**
   * Creates a new ThreadSafeMemoizer with no memoized value.
   */
  ThreadSafeMemoizer() {
    memoize_clear(memoized_);
  }

  /**
   * Copy constructor: creates a new ThreadSafeMemoizer object with the same
   * memoized value as the ThreadSafeMemoizer object referred to by the given
   * reference.
   *
   * The runtime performance of this function is O(1).
   */
  ThreadSafeMemoizer(const ThreadSafeMemoizer& other) {
    operator=(other);
  }

  /**
   * Copy assignment operator: replaces this object's memoized value with the
   * memoized value of the ThreadSafeMemoizer object referred to by the given
   * reference.
   *
   * The runtime performance of this function is O(1).
   */
  ThreadSafeMemoizer& operator=(const ThreadSafeMemoizer& other) {
    memoize_store(memoized_, other.memoized_);
    return *this;
  }

  /**
   * Move constructor: creates a new ThreadSafeMemoizer object with the same
   * memoized value as the ThreadSafeMemoizer object referred to by the given
   * reference, also clearing its memoized value.
   *
   * The runtime performance of this function is O(1).
   */
  ThreadSafeMemoizer(ThreadSafeMemoizer&& other) noexcept {
    operator=(std::move(other));
  }

  /**
   * Move assignment operator: replaces this object's memoized value with the
   * memoized value of the ThreadSafeMemoizer object referred to by the given
   * reference, also clearing its memoized value.
   *
   * The runtime performance of this function is O(1).
   */
  ThreadSafeMemoizer& operator=(ThreadSafeMemoizer&& other) noexcept {
    memoize_store(memoized_, other.memoized_);
    memoize_clear(other.memoized_);
    return *this;
  }

  /**
   * Return the memoized value, calculating it with the given function if
   * needed.
   *
   * If this object _does_ have a memoized value then this function simply
   * returns a reference to it and does _not_ call the given function.
   *
   * On the other hand, if this object does _not_ have a memoized value then
   * the given function is called to calculate the value to memoize. The value
   * returned by the function is stored internally as the "memoized value" and
   * then returned.
   *
   * The given function *must* be idempotent because it _may_ be called more
   * than once due to the semantics of "weak" compare-and-exchange. No reference
   * to the given function is retained by this object. The given function will
   * be called synchronously by this function, if it is called at all.
   *
   * This function is thread-safe and may be called concurrently by multiple
   * threads.
   *
   * The returned reference should only be considered "valid" as long as this
   * ThreadSafeMemoizer instance is alive.
   */
  const T& value(const std::function<std::shared_ptr<T>()>& func) {
    std::shared_ptr<T> old_memoized = memoize_load(memoized_);

    while (true) {
      if (old_memoized) {
        return *old_memoized;
      }

      std::shared_ptr<T> new_memoized = func();

      if (memoize_compare_exchange(memoized_, old_memoized, new_memoized)) {
        return *new_memoized;
      }
    }
  }

 private:
  // TODO(c++20): Remove the #ifdef checks for __cpp_lib_atomic_shared_ptr and
  //  delete all code that is compiled out when __cpp_lib_atomic_shared_ptr is
  //  defined.
#ifdef __cpp_lib_atomic_shared_ptr
  std::atomic<std::shared_ptr<T>> memoized_;

  static void memoize_store(std::atomic<std::shared_ptr<T>>& memoized,
                            const std::shared_ptr<T>& value) {
    memoized.store(value);
  }

  static std::shared_ptr<T> memoize_load(
      const std::atomic<std::shared_ptr<T>>& memoized) {
    return memoized.load();
  }

  static bool memoize_compare_exchange(
      std::atomic<std::shared_ptr<T>>& memoized,
      std::shared_ptr<T>& expected,
      const std::shared_ptr<T>& desired) {
    return memoized.compare_exchange_weak(expected, desired);
  }

#else  // #ifdef __cpp_lib_atomic_shared_ptr
  // NOTE: Always use the std::atomic_XXX() functions to access this shared_ptr
  // to ensure thread safety.
  // See https://en.cppreference.com/w/cpp/memory/shared_ptr/atomic.
  std::shared_ptr<T> memoized_;

  static void memoize_store(std::shared_ptr<T>& memoized,
                            const std::shared_ptr<T>& value) {
    std::atomic_store(&memoized, value);
  }

  static std::shared_ptr<T> memoize_load(const std::shared_ptr<T>& memoized) {
    return std::atomic_load(&memoized);
  }

  static bool memoize_compare_exchange(std::shared_ptr<T>& memoized,
                                       std::shared_ptr<T>& expected,
                                       const std::shared_ptr<T>& desired) {
    return std::atomic_compare_exchange_weak(&memoized, &expected, desired);
  }

#endif  // #ifdef __cpp_lib_atomic_shared_ptr

  static void memoize_clear(std::shared_ptr<T>& memoized) {
    memoize_store(memoized, std::shared_ptr<T>());
  }
};
}  // namespace cpp20_atomic_shared_ptr/cpp11_atomic_free_functions
}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_THREAD_SAFE_MEMOIZER_H_
