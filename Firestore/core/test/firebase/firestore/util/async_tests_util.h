/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_ASYNC_TESTS_UTIL_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_ASYNC_TESTS_UTIL_H_

#include <chrono>  // NOLINT(build/c++11)
#include <cstdlib>
#include <future>  // NOLINT(build/c++11)

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

inline std::chrono::time_point<std::chrono::system_clock,
                               std::chrono::milliseconds>
now() {
  return std::chrono::time_point_cast<std::chrono::milliseconds>(
      std::chrono::system_clock::now());
}

constexpr auto kTimeout = std::chrono::seconds(5);

// Waits for the future to become ready and returns whether it timed out.
inline bool Await(const std::future<void>& future,
                  const std::chrono::milliseconds timeout = kTimeout) {
  return future.wait_for(timeout) == std::future_status::ready;
}

// Unfortunately, the future returned from std::async blocks in its destructor
// until the async call is finished. If the function called from std::async is
// buggy and hangs forever, the future's destructor will also hang forever. To
// avoid all tests freezing, the only thing to do is to abort (which skips
// destructors).
inline void Abort() {
  ADD_FAILURE();
  std::abort();
}

// Calls std::abort if the future times out.
inline void AbortOnTimeout(const std::future<void>& future) {
  if (!Await(future, kTimeout)) {
    Abort();
  }
}

// The macro calls AbortOnTimeout, but preserves stack trace.
#define ABORT_ON_TIMEOUT(future)                            \
  do {                                                      \
    SCOPED_TRACE("Async operation timed out, aborting..."); \
    AbortOnTimeout(future);                                 \
  } while (0)

class TestWithTimeoutMixin {
 public:
  TestWithTimeoutMixin() : signal_finished{[] {}} {
  }

  // Googletest doesn't contain built-in functionality to block until an async
  // operation completes, and there is no timeout by default. Work around both
  // by resolving a packaged_task in the async operation and blocking on the
  // associated future (with timeout).
  bool WaitForTestToFinish(const std::chrono::seconds timeout = kTimeout) {
    return signal_finished.get_future().wait_for(timeout) ==
           std::future_status::ready;
  }

  std::packaged_task<void()> signal_finished;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_ASYNC_TESTS_UTIL_H_
