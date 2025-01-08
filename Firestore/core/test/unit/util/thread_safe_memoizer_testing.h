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

class CountingFunc {
 public:
  explicit CountingFunc(const std::string& format);
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
