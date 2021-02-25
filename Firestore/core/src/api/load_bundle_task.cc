/*
 * Copyright 2021 Google LLC
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

#include "Firestore/core/src/api/load_bundle_task.h"

#include <mutex>  // NOLINT(build/c++11)
#include <utility>

#include "Firestore/core/src/util/autoid.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace api {

LoadBundleHandle LoadBundleTask::ObserveState(LoadBundleTaskState state,
                                              ProgressObserver callback) {
  std::lock_guard<std::mutex> lock(mutex_);

  HandleObservers& callbacks = GetObservers(state);
  const auto& handle = util::CreateAutoId();
  callbacks.push_back({handle, std::move(callback)});

  return handle;
}

void LoadBundleTask::RemoveObserver(LoadBundleHandle handle) {
  std::lock_guard<std::mutex> lock(mutex_);

  for (auto& callbacks : observers_by_states_) {
    auto found = callbacks.end();
    for (auto iter = callbacks.begin(); iter < callbacks.end(); ++iter) {
      if (iter->first == handle) {
        found = iter;
        break;
      }
    }
    if (found != callbacks.end()) {
      callbacks.erase(found);
    }
  }
}

void LoadBundleTask::RemoveObservers(LoadBundleTaskState state) {
  std::lock_guard<std::mutex> lock(mutex_);

  HandleObservers& callbacks = GetObservers(state);
  callbacks.clear();
}

void LoadBundleTask::RemoveAllObservers() {
  std::lock_guard<std::mutex> lock(mutex_);

  for (auto& callbacks : observers_by_states_) {
    callbacks.clear();
  }
}

void LoadBundleTask::SetSuccess(LoadBundleTaskProgress success_progress) {
  HARD_ASSERT(success_progress.state() == LoadBundleTaskState::Success,
              "Calling SetSuccess() with a state that is not 'Success'");
  std::lock_guard<std::mutex> lock(mutex_);

  progress_snapshot_ = success_progress;
  const auto& callbacks = GetObservers(LoadBundleTaskState::Success);
  ExecuteCallbacks(callbacks);

  const auto& progress_callbacks =
      GetObservers(LoadBundleTaskState::InProgress);
  ExecuteCallbacks(progress_callbacks);
}

void LoadBundleTask::SetError() {
  std::lock_guard<std::mutex> lock(mutex_);

  progress_snapshot_.set_state(LoadBundleTaskState::Error);
  const auto& callbacks = GetObservers(LoadBundleTaskState::Error);
  ExecuteCallbacks(callbacks);

  const auto& progress_callbacks =
      GetObservers(LoadBundleTaskState::InProgress);
  ExecuteCallbacks(progress_callbacks);
}

void LoadBundleTask::UpdateProgress(LoadBundleTaskProgress progress) {
  std::lock_guard<std::mutex> lock(mutex_);

  progress_snapshot_ = progress;
  const auto& callbacks = GetObservers(LoadBundleTaskState::InProgress);
  ExecuteCallbacks(callbacks);
}

void LoadBundleTask::ExecuteCallbacks(const HandleObservers& callbacks) {
  for (const auto& entry : callbacks) {
    const auto& callback = entry.second;
    user_executor_->Execute([=] { callback(progress_snapshot_); });
  }
}

HandleObservers& LoadBundleTask::GetObservers(LoadBundleTaskState state) {
  return observers_by_states_.at(static_cast<uint64_t>(state));
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
