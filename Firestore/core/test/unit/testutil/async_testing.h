/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_ASYNC_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_ASYNC_TESTING_H_

#include <chrono>  // NOLINT(build/c++11)
#include <functional>
#include <future>  // NOLINT(build/c++11)
#include <memory>
#include <thread>  // NOLINT(build/c++11)

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

class AsyncQueue;
class Executor;

}  // namespace util

namespace testutil {

/**
 * Creates an AsyncQueue suitable for testing, based on the default executor
 * for the current platform.
 *
 * @param name A simple name for the kind of executor this is (e.g. "user" for
 *     executors that emulate delivery of user events or "worker" for executors
 *     that back AsyncQueues). If omitted, the name will default to something
 *     derived from the current test case name.
 */
std::unique_ptr<util::Executor> ExecutorForTesting(const char* name = nullptr);

/**
 * Creates an AsyncQueue suitable for testing, based on the default executor
 * for the current platform.
 */
std::shared_ptr<util::AsyncQueue> AsyncQueueForTesting();

constexpr auto kTimeout = std::chrono::seconds(5);

/**
 * An expected outcome of an asynchronous test.
 */
class Expectation {
 public:
  Expectation();

  /**
   * Marks this expectation as fulfilled.
   *
   * Only a single call to `Fulfill` is allowed for any given `Expectaction`. An
   * exception is thrown if `Fulfill` is called more than once.
   */
  void Fulfill();

  /**
   * Returns a callback function, that when invoked, fullfills the expectation.
   *
   * The returned function has a lifetime that's independent of the Expectation
   * that created it.
   */
  std::function<void()> AsCallback() const;

  /**
   * Returns a `shared_future` that represents the completion of this
   * Expectation.
   */
  const std::shared_future<void>& get_future() const {
    return future_;
  }

 private:
  std::shared_ptr<std::promise<void>> promise_;
  std::shared_future<void> future_;
};

/**
 * A mixin that supplies utilities for safely writing asynchronous tests.
 */
class AsyncTest {
 public:
  AsyncTest() = default;

  std::future<void> Async(std::function<void()> action) const;

  /**
   * Waits for the future to become ready.
   *
   * Fails the current test if the timeout occurs.
   */
  void Await(const std::future<void>& future,
             std::chrono::milliseconds timeout = kTimeout) const;

  /**
   * Waits for the shared future to become ready.
   *
   * Fails the current test if the timeout occurs.
   */
  void Await(const std::shared_future<void>& future,
             std::chrono::milliseconds timeout = kTimeout) const;

  /**
   * Waits for the expectation to become fulfilled.
   *
   * Fails the current test if the timeout occurs.
   */
  void Await(Expectation& expectation,  // NOLINT(runtime/references)
             std::chrono::milliseconds timeout = kTimeout) const;

  /**
   * Sleeps the current thread for the given number of milliseconds.
   */
  void SleepFor(int millis) const;

 private:
  testing::ScopedTrace trace_{
      "Test case name", 1,
      testing::Message()
          << testing::UnitTest::GetInstance()->current_test_info()->name()};
};

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_ASYNC_TESTING_H_
