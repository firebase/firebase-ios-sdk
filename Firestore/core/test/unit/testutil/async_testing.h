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
#include <mutex>   // NOLINT(build/c++11)
#include <thread>  // NOLINT(build/c++11)
#include <utility>
#include <vector>

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
   * Returns a callback function, that when invoked, fulfills the expectation.
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

/**
 * A class that can be used to "accumulate" objects that is completely thread
 * safe.
 *
 * When testing "listeners" it is common in tests to just create a std::vector,
 * register a "listener", then add objects into the vector when the listener is
 * notified. This, however, is not thread safe because there is typically no
 * synchronization in place, such as via a mutex. Moreover, if the listener
 * receives a notification after the test method completes then the vector,
 * which was allocated on the stack, is deleted. Both of these problems result
 * in undefined behavior, which is bad.
 *
 * Using `AsyncAccumulator` solves both of these problems. First, it protects
 * the std::vector instance with a mutex to eliminate race conditions. Second,
 * instances can only be created as shared_ptr, which can be copied into the
 * listener and will keep the vector alive until the test completes or the
 * listener is deleted, whichever comes last.
 *
 * The constructor of `AsyncAccumulator` is private, in order to force
 * instances to be created with a shared_ptr via the `NewInstance()` method.
 */
template <typename T>
class AsyncAccumulator final
    : public std::enable_shared_from_this<AsyncAccumulator<T>> {
 public:
  /**
   * Creates and returns a std::shared_ptr to a new instance of this class.
   */
  static std::shared_ptr<AsyncAccumulator> NewInstance() {
    return std::shared_ptr<AsyncAccumulator>(new AsyncAccumulator);
  }

  /**
   * Adds a copy of the given object to this object's encapsulated vector and
   * resolves any outstanding std::future objects returned from
   * `WaitForObject()`.
   */
  void AccumulateObject(const T& object) {
    std::lock_guard<std::mutex> lock(mutex_);
    objects_.push_back(object);
    for (auto&& promise : promises_) {
      promise.set_value();
    }
    promises_.clear();
  }

  /**
   * Creates and returns a std::future that resolves when an object is
   * accumulated via a call to `AccumulateObject()`. If there is an object
   * already accumulated in this object's encapsulated vector then the returned
   * future will be resolved immediately.
   */
  std::future<void> WaitForObject() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::promise<void> promise;
    std::future<void> future = promise.get_future();

    if (objects_.empty()) {
      promises_.push_back(std::move(promise));
    } else {
      promise.set_value();
    }

    return future;
  }

  /**
   * Returns whether the encapsulated vector of accumulated objects is empty.
   */
  bool IsEmpty() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return objects_.empty();
  }

  /**
   * Removes the first element from the encapsulated vector and returns it.
   *
   * This function exhibits undefined behavior if the encapsulated vector is
   * empty.
   */
  T Shift() {
    std::lock_guard<std::mutex> lock(mutex_);
    auto iter = objects_.begin();
    T result = std::move(*iter);
    objects_.erase(iter);
    return result;
  }

  /**
   * Creates and returns a function that, when invoked, calls
   * `AccumulateObject()`.
   */
  std::function<void(const T&)> AsCallback() {
    return [shared_this = this->shared_from_this()](const T& object) {
      shared_this->AccumulateObject(object);
    };
  }

 private:
  // Private constructor to force instances to be created via NewInstance().
  AsyncAccumulator() = default;

  mutable std::mutex mutex_;
  std::vector<T> objects_;
  std::vector<std::promise<void>> promises_;
};

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_ASYNC_TESTING_H_
