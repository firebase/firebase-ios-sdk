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
#ifndef FIRESTORE_CORE_SRC_API_LOAD_BUNDLE_TASK_H_
#define FIRESTORE_CORE_SRC_API_LOAD_BUNDLE_TASK_H_

#include <array>
#include <cstdint>
#include <memory>
#include <mutex>  // NOLINT(build/c++11)
#include <string>
#include <vector>

#include "Firestore/core/src/util/executor.h"

namespace firebase {
namespace firestore {
namespace api {

enum class LoadBundleTaskState { Error = 0, InProgress = 1, Success = 2 };

class LoadBundleTaskProgress {
 public:
  LoadBundleTaskProgress() {
  }
  LoadBundleTaskProgress(uint32_t documents_loaded,
                         uint32_t total_documents,
                         uint64_t bytes_loaded,
                         uint64_t total_bytes,
                         LoadBundleTaskState state)
      : documents_loaded_(documents_loaded),
        total_documents_(total_documents),
        bytes_loaded_(bytes_loaded),
        total_bytes_(total_bytes),
        state_(state) {
  }

  uint32_t documents_loaded() const {
    return documents_loaded_;
  }

  uint32_t total_documents() const {
    return total_documents_;
  }

  uint64_t bytes_loaded() const {
    return bytes_loaded_;
  }

  uint64_t total_bytes() const {
    return total_bytes_;
  }

  LoadBundleTaskState state() const {
    return state_;
  }

  void set_state(LoadBundleTaskState state) {
    state_ = state;
  }

 private:
  uint32_t documents_loaded_ = 0;
  uint32_t total_documents_ = 0;
  uint64_t bytes_loaded_ = 0;
  uint64_t total_bytes_ = 0;

  LoadBundleTaskState state_ = LoadBundleTaskState::InProgress;
};

inline bool operator==(const LoadBundleTaskProgress lhs,
                       const LoadBundleTaskProgress& rhs) {
  return lhs.state() == rhs.state() &&
         lhs.bytes_loaded() == rhs.bytes_loaded() &&
         lhs.documents_loaded() == rhs.documents_loaded() &&
         lhs.total_bytes() == rhs.total_bytes() &&
         lhs.total_documents() == rhs.total_documents();
}

inline bool operator!=(const LoadBundleTaskProgress lhs,
                       const LoadBundleTaskProgress& rhs) {
  return !(lhs == rhs);
}

using LoadBundleHandle = std::string;
using ProgressObserver = std::function<void(LoadBundleTaskProgress)>;
using HandleObservers =
    std::vector<std::pair<LoadBundleHandle, ProgressObserver>>;

/**
 * Represents the task of loading a Firestore bundle. It provides progress of
 * bundle loading, as well as task completion and error events.
 */
class LoadBundleTask {
 public:
  explicit LoadBundleTask(std::shared_ptr<util::Executor> user_executor)
      : user_executor_(std::move(user_executor)) {
  }

  /**
   * Instructs the task to notify the specified observer when there is a
   * progress update with the given `LoadBundleTaskState`.
   *
   * @return A handle that can be used to remove the callback from this task.
   */
  LoadBundleHandle ObserveState(LoadBundleTaskState state,
                                ProgressObserver callback);

  /**
   * Removes the observer associated with the given handle, does nothing if the
   * callback cannot be found.
   */
  void RemoveObserver(LoadBundleHandle);

  /**
   * Removes all observers associated with the given `LoadBundleTaskState`.
   */
  void RemoveObservers(LoadBundleTaskState state);

  /** Removes all observers. */
  void RemoveAllObservers();

  /**
   * Notifies observers with a success progress. Both `Success` and `InProgress`
   * observers will get notified.
   */
  void SetSuccess(LoadBundleTaskProgress success_progress);

  /**
   * Notifies observers with a error progress, by changing the last progress
   * this instance has been with an `Error` state.
   *
   * Both `Error` and `InProgress` observers will get notified.
   */
  void SetError();

  /** Notifies observers with a `InProgress` progress. */
  void UpdateProgress(LoadBundleTaskProgress progress);

 private:
  /** Gets all observers associated with the given state. */
  HandleObservers& GetObservers(LoadBundleTaskState state);

  /** Notifies all given observers. */
  void ExecuteCallbacks(const HandleObservers& observers);

  /** The executor to run all observers when notified. */
  std::shared_ptr<util::Executor> user_executor_;

  /** Guard to all internal state mutation. */
  mutable std::mutex mutex_;
  /** An array holds mapping from `LoadBundleTaskState` values to observers. */
  std::array<HandleObservers, 3> observers_by_states_;
  LoadBundleTaskProgress progress_snapshot_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_LOAD_BUNDLE_TASK_H_
