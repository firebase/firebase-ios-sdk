/*
 * Copyright 2018 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_UTIL_EXECUTOR_LIBDISPATCH_H_
#define FIRESTORE_CORE_SRC_UTIL_EXECUTOR_LIBDISPATCH_H_

#include <dispatch/dispatch.h>

#include <chrono>              // NOLINT(build/c++11)
#include <condition_variable>  // NOLINT(build/c++11)
#include <functional>
#include <memory>
#include <mutex>  // NOLINT(build/c++11)
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>

#include "Firestore/core/src/util/executor.h"
#include "absl/strings/string_view.h"

#if !defined(__OBJC__)
// `dispatch_queue_t` gets defined to different types when compiled in C++ or
// Objective-C mode. Source files including this header should all be compiled
// in the same mode to avoid linker errors.
#error "This header only supports Objective-C++ (see comment for more info)."
#endif  // !defined(__OBJC__)

namespace firebase {
namespace firestore {
namespace util {

// A serial queue built on top of libdispatch. The operations are run on
// a dedicated serial dispatch queue.
class ExecutorLibdispatch : public Executor {
 public:
  explicit ExecutorLibdispatch(dispatch_queue_t dispatch_queue);
  ~ExecutorLibdispatch() override;

  bool IsCurrentExecutor() const override;
  std::string CurrentExecutorName() const override;
  std::string Name() const override;

  void Execute(Operation&& operation) override;
  void ExecuteBlocking(Operation&& operation) override;
  DelayedOperation Schedule(Milliseconds delay,
                            Tag tag,
                            Operation&& operation) override;

  bool IsTagScheduled(Tag tag) const override;
  bool IsIdScheduled(Id id) const override;
  Task* PopFromSchedule() override;

  dispatch_queue_t dispatch_queue() const {
    return dispatch_queue_;
  }

 private:
  using ScheduleMap = std::unordered_map<Id, Task*>;
  using ScheduleEntry = ScheduleMap::value_type;

  void Complete(Task* task) override;
  void Cancel(Id operation_id) override;

  static void InvokeAsync(void* raw_task);
  static void InvokeSync(void* raw_task);

  Id NextIdLocked();

  mutable std::mutex mutex_;

  dispatch_queue_t dispatch_queue_;

  std::unordered_set<Task*> async_tasks_;
  ScheduleMap schedule_;
  Id current_id_ = 0;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_EXECUTOR_LIBDISPATCH_H_
