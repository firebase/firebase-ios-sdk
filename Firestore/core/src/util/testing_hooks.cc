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

#include "Firestore/core/src/util/testing_hooks.h"

#include <functional>
#include <mutex>
#include <type_traits>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/util/no_destructor.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

/**
 * An implementation of `ListenerRegistration` whose `Remove()` method simply
 * invokes the function specified to the constructor. This allows easily
 * creating `ListenerRegistration` objects that call a lambda.
 */
class RemoveDelegatingListenerRegistration final
    : public api::ListenerRegistration {
 public:
  RemoveDelegatingListenerRegistration(std::function<void()> delegate)
      : delegate_(std::move(delegate)) {
  }

  void Remove() override {
    delegate_();
  }

 private:
  std::function<void()> delegate_;
};

}  // namespace

/** Returns the singleton instance of this class. */
TestingHooks& TestingHooks::GetInstance() {
  static NoDestructor<TestingHooks> instance;
  return *instance;
}

std::shared_ptr<api::ListenerRegistration>
TestingHooks::OnExistenceFilterMismatch(
    ExistenceFilterMismatchCallback callback) {
  // Register the callback.
  std::unique_lock<std::mutex> lock(mutex_);
  const int id = next_id_++;
  existence_filter_mismatch_callbacks_.insert(
      {id,
       std::make_shared<ExistenceFilterMismatchCallback>(std::move(callback))});
  lock.unlock();

  // NOTE: Capturing `this` in the lambda below is safe because the destructor
  // is deleted and, therefore, `this` can never be deleted. The static_assert
  // statements below verify this invariant.
  using this_type = std::remove_pointer<decltype(this)>::type;
  static_assert(std::is_same<this_type, TestingHooks>::value, "");
  static_assert(!std::is_destructible<this_type>::value, "");

  // Create a ListenerRegistration that the caller can use to unregister the
  // callback.
  return std::make_shared<RemoveDelegatingListenerRegistration>([this, id]() {
    std::lock_guard<std::mutex> lock(mutex_);
    auto iter = existence_filter_mismatch_callbacks_.find(id);
    if (iter != existence_filter_mismatch_callbacks_.end()) {
      existence_filter_mismatch_callbacks_.erase(iter);
    }
  });
}

void TestingHooks::NotifyOnExistenceFilterMismatch(
    const ExistenceFilterMismatchInfo& info) {
  std::unique_lock<std::mutex> lock(mutex_);

  // Short-circuit to avoid any unnecessary work if there is nothing to do.
  if (existence_filter_mismatch_callbacks_.empty()) {
    return;
  }

  // Copy the callbacks into a vector so that they can be invoked after
  // releasing the lock.
  std::vector<std::shared_ptr<ExistenceFilterMismatchCallback>> callbacks;
  for (auto&& entry : existence_filter_mismatch_callbacks_) {
    callbacks.push_back(entry.second);
  }

  // Release the lock so that the callback invocations are done _without_
  // holding the lock. This avoids deadlock in the case that invocations are
  // re-entrant.
  lock.unlock();

  for (std::shared_ptr<ExistenceFilterMismatchCallback> callback : callbacks) {
    callback->operator()(info);
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
