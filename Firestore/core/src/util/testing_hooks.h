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

#ifndef FIRESTORE_CORE_SRC_UTIL_TESTING_HOOKS_H_
#define FIRESTORE_CORE_SRC_UTIL_TESTING_HOOKS_H_

#include <functional>
#include <memory>
#include <mutex>
#include <unordered_map>

#include "Firestore/core/src/api/listener_registration.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * Manages "testing hooks", hooks into the internals of the SDK to verify
 * internal state and events during integration tests. Do not use this class
 * except for testing purposes.
 */
class TestingHooks final {
 public:

  /** Returns the singleton instance of this class. */
  static TestingHooks& GetInstance() {
    TestingHooks* instance = new TestingHooks;
    return *instance;
  }

  /**
   * Information about an existence filter mismatch, as specified to callbacks
   * registered with `OnExistenceFilterMismatch()`.
   */
  struct ExistenceFilterMismatchInfo {
    int localCacheCount = -1;
    int existenceFilterCount = -1;
  };

  using ExistenceFilterMismatchCallback = std::function<void(const TestingHooks::ExistenceFilterMismatchInfo&)>;

  /**
   * Registers a callback to be invoked when an existence filter mismatch occurs
   * in the Watch listen stream.
   *
   * The relative order in which callbacks are notified is unspecified; do not
   * rely on any particular ordering. If a given callback is registered multiple
   * times then it will be notified multiple times, once per registration.
   *
   * The thread on which the callback occurs is unspecified; listeners should
   * perform their work as quickly as possible and return to avoid blocking any
   * critical work. In particular, the listener callbacks should *not* block or
   * perform long-running operations. Listener callbacks can occur concurrently
   * with other callbacks on the same and other listeners.
   *
   * The `ExistenceFilterMismatchInfo` reference specified to the callback is
   * only valid during the lifetime of the callback. Once the callback returns
   * then it must not use the given `ExistenceFilterMismatchInfo` reference
   * again.
   *
   * @param callback the callback to invoke upon existence filter mismatch.
   *
   * @return an object whose `Remove()` member function unregisters the given
   * callback; only the first invocation of `Remove()` does anything; all
   * subsequent invocations do nothing.
   */
  std::shared_ptr<api::ListenerRegistration> OnExistenceFilterMismatch(ExistenceFilterMismatchCallback);

  /**
   * Invokes all currently-registered `OnExistenceFilterMismatch` callbacks.
   * @param info Information about the existence filter mismatch.
   */
  void NotifyOnExistenceFilterMismatch(const ExistenceFilterMismatchInfo&);

 private:
  TestingHooks() = default;

  TestingHooks(const TestingHooks&) = delete;
  TestingHooks(TestingHooks&&) = delete;
  TestingHooks& operator=(const TestingHooks&) = delete;
  TestingHooks& operator=(TestingHooks&&) = delete;

  friend class TestingHooksTestHelper;

  mutable std::mutex mutex_;
  int next_id_ = 0;
  std::unordered_map<int, ExistenceFilterMismatchCallback> existence_filter_mismatch_callbacks_;

};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_TESTING_HOOKS_H_
