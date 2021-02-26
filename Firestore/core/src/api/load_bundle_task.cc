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
#include "absl/algorithm/container.h"

namespace firebase {
namespace firestore {
namespace api {

LoadBundleTask::LoadBundleHandle LoadBundleTask::ObserveState(
    LoadBundleTaskState state, ProgressObserver observer) {
  std::lock_guard<std::mutex> lock(mutex_);

  HandleObservers& observers = GetObservers(state);
  auto handle = util::CreateAutoId();
  observers.push_back({handle, std::move(observer)});

  return handle;
}

void LoadBundleTask::RemoveObserver(const LoadBundleHandle& handle) {
  std::lock_guard<std::mutex> lock(mutex_);

  for (auto& observers : observers_by_states_) {
    auto found = absl::c_find_if(
        observers, [&](const HandleObservers::value_type& observer) {
          return observer.first == handle;
        });
    if (found != observers.end()) {
      observers.erase(found);
    }
  }
}

void LoadBundleTask::RemoveObservers(LoadBundleTaskState state) {
  std::lock_guard<std::mutex> lock(mutex_);

  HandleObservers& observers = GetObservers(state);
  observers.clear();
}

void LoadBundleTask::RemoveAllObservers() {
  std::lock_guard<std::mutex> lock(mutex_);

  for (auto& observers : observers_by_states_) {
    observers.clear();
  }
}

void LoadBundleTask::SetSuccess(LoadBundleTaskProgress success_progress) {
  HARD_ASSERT(success_progress.state() == LoadBundleTaskState::kSuccess,
              "Calling SetSuccess() with a state that is not 'Success'");
  std::lock_guard<std::mutex> lock(mutex_);

  progress_snapshot_ = success_progress;

  for (auto state :
       {LoadBundleTaskState::kInProgress, LoadBundleTaskState::kSuccess}) {
    const auto& observers = GetObservers(state);
    NotifyObservers(observers);
  }
}

void LoadBundleTask::SetError() {
  std::lock_guard<std::mutex> lock(mutex_);

  progress_snapshot_.set_state(LoadBundleTaskState::kError);

  for (auto state :
       {LoadBundleTaskState::kInProgress, LoadBundleTaskState::kError}) {
    const auto& observers = GetObservers(state);
    NotifyObservers(observers);
  }
}

void LoadBundleTask::UpdateProgress(LoadBundleTaskProgress progress) {
  std::lock_guard<std::mutex> lock(mutex_);

  progress_snapshot_ = progress;
  const auto& observers = GetObservers(LoadBundleTaskState::kInProgress);
  NotifyObservers(observers);
}

void LoadBundleTask::NotifyObservers(const HandleObservers& observers) {
  for (const auto& entry : observers) {
    const auto& observer = entry.second;
    const auto& progress = progress_snapshot_;
    user_executor_->Execute([observer, progress] { observer(progress); });
  }
}

LoadBundleTask::HandleObservers& LoadBundleTask::GetObservers(
    LoadBundleTaskState state) {
  return observers_by_states_.at(static_cast<int>(state));
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
