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

#ifndef FIRESTORE_CORE_TEST_UNIT_UTIL_THREAD_SAFE_MEMOIZER_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_UTIL_THREAD_SAFE_MEMOIZER_TESTING_H_

#include <cstddef>

#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace testing {

#if defined(GTEST_USES_SIMPLE_RE) || defined(GTEST_USES_RE2)
constexpr const char* FST_RE_DIGIT = "\\d";
#elif defined(GTEST_USES_POSIX_RE)
constexpr const char* FST_RE_DIGIT = "[[:digit:]]";
#endif

/**
 * Generates strings that incorporate a count in a thread-safe manner.
 *
 * The "format" string given to the constructor is literally generated, except
 * that all occurrences of "%s" are replaced with the invocation count, and
 * all occurrences of "%c" are replaced with the cookie, if a cookie is
 * specified.
 *
 * All functions in this class may be safely called concurrently by multiple
 * threads.
 */
class CountingFunc {
 public:
  /**
   * Creates a new `CountingFunc` that generates strings that are equal to
   * the base-10 string representation of the invocation count.
   */
  CountingFunc() : CountingFunc("%s") {
  }

  /**
   * Creates a new `CountingFunc` that generates strings that match the given
   * format.
   * @param format the format to use when generating strings; all occurrences of
   * "%s" will be replaced by the count, which starts at 0 (zero).
   */
  explicit CountingFunc(const std::string& format);

  /**
   * Returns a function that, when invoked, generates a string using the format
   * given to the constructor. Every string returned by the function has a
   * different count.
   *
   * Although each invocation of this function _may_ return a distinct function,
   * they all use the same counter and may be safely called concurrently from
   * multiple threads.
   *
   * The returned function is valid as long as this `CountingFunc` object is
   * valid.
   */
  std::function<std::shared_ptr<std::string>()> func() {
    return func("");
  }

  std::function<std::shared_ptr<std::string>()> func(std::string cookie);

  /**
   * Returns the total number of invocations that have occurred on functions
   * returned by `func()`. A new instance of this class will return 0 (zero).
   */
  int invocation_count() const;

 private:
  std::atomic<int> count_;
  std::mutex mutex;
  std::vector<std::string> chunks_;

  explicit CountingFunc(std::vector<std::string> chunks);
  std::string NextFuncReturnValue(const std::string& cookie);
};

/**
 * A simple implementation of std::latch in C++20.
 *
 * TODO(c++20) Replace with std::latch.
 */
class CountDownLatch {
 public:
  explicit CountDownLatch(int count);
  void arrive_and_wait();

 private:
  std::atomic<int> count_;
};

class SetOnDestructor {
 public:
  explicit SetOnDestructor(std::atomic<bool>& flag) : flag_(flag) {
  }

  ~SetOnDestructor() {
    flag_.store(true);
  }

 private:
  std::atomic<bool>& flag_;
};

/**
 * Returns the largest number of threads that can be truly executed in parallel,
 * or an arbitrary value greater than one if the number of CPU cores cannot be
 * determined.
 */
decltype(std::thread::hardware_concurrency())
max_practical_parallel_threads_for_testing();

/**
 * Generates and returns a random boolean value.
 */
bool GenerateRandomBool();

}  // namespace testing
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_UTIL_THREAD_SAFE_MEMOIZER_TESTING_H_
