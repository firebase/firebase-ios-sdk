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

#include "Firestore/core/src/util/thread_safe_memoizer.h"

#include <thread>
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

// Define a simple expensive function for testing.
int ExpensiveFunction() {
  // Simulate an expensive operation
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  return 42;
}

TEST(ThreadSafeMemoizerTest, MultiThreadedMemoization) {
  const int num_threads = 5;
  const int expected_result = 42;

  // Create a thread safe memoizer and multiple threads.
  firebase::firestore::util::ThreadSafeMemoizer<int> memoized_result;
  std::vector<std::thread> threads;

  for (int i = 0; i < num_threads; ++i) {
    threads.emplace_back([&memoized_result, expected_result]() {
      const int& actual_result = memoized_result.memoize(ExpensiveFunction);

      // Verify that all threads get the same memoized result.
      EXPECT_EQ(actual_result, expected_result);
    });
  }

  // Start all threads
  for (auto& thread : threads) {
    thread.join();
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
