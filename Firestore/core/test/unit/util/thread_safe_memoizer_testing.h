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

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace firebase {
namespace firestore {
namespace testing {

/**
 * Generates strings that incorporate a count in a thread-safe manner.
 *
 * The "format" string given to the constructor is literally generated, except
 * that all occurrences of "%s" are replaced with the invocation count.
 *
 *
 */
class CountingFunc {
 public:
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
   */
  std::function<std::shared_ptr<std::string>()> func();

 private:
  std::atomic<int> count_;
  std::vector<std::string> chunks_;

  explicit CountingFunc(std::vector<std::string> chunks);
  std::string Next();
};

}  // namespace testing
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_UTIL_THREAD_SAFE_MEMOIZER_TESTING_H_
