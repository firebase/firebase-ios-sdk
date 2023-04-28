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

#include <atomic>
#include <mutex>
#include <vector>
#include <unordered_map>

#include "Firestore/core/src/util/no_destructor.h"
#include "Firestore/core/src/util/testing_hooks.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

class RemoveDelegateListenerRegistration final : public api::ListenerRegistration {
 public:
  RemoveDelegateListenerRegistration(std::function<void()> delegate) : delegate_(std::move(delegate)) {
  }

  void Remove() override {
    delegate_();
  }

 private:
  std::function<void()> delegate_;
};


}

std::shared_ptr<api::ListenerRegistration> TestingHooks::OnExistenceFilterMismatch( ExistenceFilterMismatchCallback callback) {
  std::lock_guard<std::mutex> lock(mutex_);
  const int id = next_id_++;
  existence_filter_mismatch_callbacks_.insert({id, std::move(callback)});

  return std::make_shared<RemoveDelegateListenerRegistration>([this, id]() {
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

  // Short-circuit if there is nothing to do.
  if (existence_filter_mismatch_callbacks_.empty()) {
    return;
  }

  // Copy the callbacks into a vector so that we don't need to hold the mutex
  // while making the callbacks. This "copy" is somewhat inefficient; however,
  // it will only ever happen during integration testing so performance is not
  // a concern.
  std::vector<ExistenceFilterMismatchCallback> callbacks;
  for (auto&& entry : existence_filter_mismatch_callbacks_) {
    callbacks.push_back(entry.second);
  }

  // Release the lock so that it is released while calling the callbacks, to
  // avoid any potential deadlock.
  lock.unlock();

  // Notify the callbacks.
  for (auto&& callback : callbacks) {
    callback(info);
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
