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

#include "Firestore/core/src/util/hard_assert.h"

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
  /**
   * Creates a new ThreadSafeMemoizer with no memoized value.
   */
  ThreadSafeMemoizer() {
    std::atomic_store(&memoized_, std::shared_ptr<T>());
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
    if (&other == this) {
      return *this;
    }

    std::atomic_store(&memoized_, std::atomic_load(&other.memoized_));
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
    std::atomic_store(&memoized_, std::atomic_load(&other.memoized_));
    std::atomic_store(&other.memoized_, std::shared_ptr<T>());
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
   * then returned. If multiple threads race in calls to this function then
   * more than one of them may have their functions called but only one of them
   * will be memoized, with the others being discarded.
   *
   * The given function will be called synchronously by this function either
   * zero times or one time. No reference to the given function is retained by
   * this object.
   *
   * The given function _must_ return an initialized `std::shared_ptr<T>`; that
   * is, the returned `std::shared_ptr<T>` _must_ evaluate to `true` when
   * converted to `bool`. It is undefined behavior if the returned
   * `std::shared_ptr<T>` does _not_ satisfy this requirement.
   *
   * This function is thread-safe and may be called concurrently by multiple
   * threads.
   *
   * The returned reference is "valid" only as long as this `ThreadSafeMemoizer`
   * object is alive; namely, once this `ThreadSafeMemoizer` object's destructor
   * starts running, the reference returned by this function is invalid and
   * using it is undefined behavior.
   */
  const T& value(const std::function<std::shared_ptr<T>()>& func) {
    std::shared_ptr<T> old_memoized = std::atomic_load(&memoized_);

    std::shared_ptr<T> new_memoized;
    bool new_memoized_is_initialized = false;

    while (true) {
      if (old_memoized) {
        return *old_memoized;
      }

      if (!new_memoized_is_initialized) {
        new_memoized = func();
        new_memoized_is_initialized = true;
        HARD_ASSERT(new_memoized);
      }

      if (std::atomic_compare_exchange_weak(&memoized_, &old_memoized,
                                            new_memoized)) {
        return *new_memoized;
      }
    }
  }

 private:
  // NOTE: Always use the std::atomic_XXX() functions to access the memoized_
  // std::shared_ptr to ensure thread safety.
  // See https://en.cppreference.com/w/cpp/memory/shared_ptr/atomic.

  // TODO(c++20): Use std::atomic<std::shared_ptr<T>> instead of a bare
  //  std::shared_ptr<T> and the std::atomic_XXX() functions. The
  //  std::atomic_XXX() free functions are deprecated in C++20, and are also
  //  more error-prone than their std::atomic<std::shared_ptr<T>> member
  //  function counterparts.

  std::shared_ptr<T> memoized_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_THREAD_SAFE_MEMOIZER_H_
