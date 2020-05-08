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

#include "Firestore/core/src/util/executor_libdispatch.h"

#include <algorithm>
#include <atomic>

#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/task.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

#if FIRESTORE_TRACE_TASKS
#define TASK_TRACE(...) LOG_WARN(__VA_ARGS__)
#else
#define TASK_TRACE(...)
#endif

absl::string_view StringViewFromDispatchLabel(const char* const label) {
  // Make sure string_view's data is not null, because it's used for logging.
  return label ? absl::string_view{label} : absl::string_view{""};
}

// GetLabel functions are guaranteed to never return a "null" string_view
// (i.e. data() != nullptr).
absl::string_view GetQueueLabel(const dispatch_queue_t queue) {
  return StringViewFromDispatchLabel(dispatch_queue_get_label(queue));
}
absl::string_view GetCurrentQueueLabel() {
  // Note: dispatch_queue_get_label may return nullptr if the queue wasn't
  // initialized with a label.
  return StringViewFromDispatchLabel(
      dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
}

}  // namespace

// MARK: - TimeSlot

// Represents a "busy" time slot on the schedule.
//
// Since libdispatch doesn't provide a way to cancel a scheduled operation, once
// a slot is created, it will always stay in the schedule until the time is
// past. Consequently, it is more useful to think of a time slot than
// a particular scheduled operation -- by the time the slot comes, operation may
// or may not be there (imagine getting to a meeting and finding out it's been
// canceled).
//
// Precondition: all member functions, including the constructor, are *only*
// invoked on the Firestore queue.
//
//   Ownership:
//
// - `TimeSlot` is exclusively owned by libdispatch;
// - `ExecutorLibdispatch` contains non-owning pointers to `TimeSlot`s;
// - invariant: if the executor contains a pointer to a `TimeSlot`, it is
//   a valid object. It is achieved because when libdispatch invokes
//   a `TimeSlot`, it always removes it from the executor before deleting it.
//   The reverse is not true: a canceled time slot is removed from the executor,
//   but won't be destroyed until its original due time is past.

// MARK: - ExecutorLibdispatch

ExecutorLibdispatch::ExecutorLibdispatch(const dispatch_queue_t dispatch_queue)
    : dispatch_queue_{dispatch_queue} {
}

ExecutorLibdispatch::~ExecutorLibdispatch() {
  decltype(async_tasks_) local_async_tasks;
  TASK_TRACE("Executor::~Executor %s", this);

  {
    std::unique_lock<std::mutex> lock(mutex_);

    // Pull ownership of tasks out of the executor members and into locals. This
    // prevents any concurrent execution of calls to `Complete` or `Cancel` from
    // finding tasks (and releasing them).
    //
    // All scheduled operations are also registered in `async_tasks_` so they
    // can be handled in a single loop below.
    local_async_tasks.swap(async_tasks_);
  }

  for (Task* task : local_async_tasks) {
    TASK_TRACE("Executor::~Executor %s canceling %s", this, task);
    task->Cancel();
    task->Release();
  }
}

bool ExecutorLibdispatch::IsCurrentExecutor() const {
  return GetCurrentQueueLabel() == GetQueueLabel(dispatch_queue());
}
std::string ExecutorLibdispatch::CurrentExecutorName() const {
  return GetCurrentQueueLabel().data();
}
std::string ExecutorLibdispatch::Name() const {
  return GetQueueLabel(dispatch_queue()).data();
}

void ExecutorLibdispatch::Execute(Operation&& operation) {
  auto task = new Task(this, std::move(operation));
  {
    std::lock_guard<std::mutex> lock(mutex_);
    async_tasks_.insert(task);
  }

  dispatch_async_f(dispatch_queue_, task, InvokeAsync);
}

void ExecutorLibdispatch::ExecuteBlocking(Operation&& operation) {
  HARD_ASSERT(
      GetCurrentQueueLabel() != GetQueueLabel(dispatch_queue_),
      "Calling DispatchSync on the current queue will lead to a deadlock.");

  auto task = new Task(this, std::move(operation));
  {
    std::lock_guard<std::mutex> lock(mutex_);
    async_tasks_.insert(task);
  }

  dispatch_sync_f(dispatch_queue_, task, InvokeSync);
}

DelayedOperation ExecutorLibdispatch::Schedule(Milliseconds delay,
                                               Tag tag,
                                               Operation&& operation) {
  namespace chr = std::chrono;
  const dispatch_time_t delay_ns = dispatch_time(
      DISPATCH_TIME_NOW, chr::duration_cast<chr::nanoseconds>(delay).count());

  // Ownership is fully transferred to libdispatch -- because it's impossible
  // to truly cancel work after it's been dispatched, libdispatch is guaranteed
  // to outlive the executor, and it's possible for work to be invoked by
  // libdispatch after the executor is destroyed. The Executor only stores an
  // observer pointer to the operation.
  Task* task = nullptr;
  TimePoint target_time = MakeTargetTime(delay);
  Id id = 0;
  {
    std::lock_guard<std::mutex> lock(mutex_);

    id = NextIdLocked();
    task = new Task(this, target_time, tag, id, std::move(operation));
    async_tasks_.insert(task);
    schedule_[id] = task;
  }

  dispatch_after_f(delay_ns, dispatch_queue_, task, InvokeAsync);

  return DelayedOperation(this, id);
}

void ExecutorLibdispatch::Complete(Task* task) {
  bool should_release = false;
  {
    TASK_TRACE("Executor::Complete %s task %s", this, task);
    std::lock_guard<std::mutex> lock(mutex_);

    auto found = async_tasks_.find(task);
    if (found != async_tasks_.end()) {
      should_release = true;
      async_tasks_.erase(found);

      if (!task->is_immediate()) {
        schedule_.erase(task->id());
      }
    }
  }

  if (should_release) {
    task->Release();
  }
}

void ExecutorLibdispatch::Cancel(Id operation_id) {
  Task* found_task = nullptr;
  {
    TASK_TRACE("Executor::Cancel %s task %s", this, task);
    std::lock_guard<std::mutex> lock(mutex_);

    // `time_slot` might have been destroyed by the time cancellation function
    // runs, in which case it's guaranteed to have been removed from the
    // `schedule_`. If the `time_slot_id` refers to a slot that has been
    // removed, the call to `RemoveFromSchedule` will be a no-op.
    const auto found = schedule_.find(operation_id);

    // It's possible for the operation to be missing if libdispatch gets to run
    // it after it was force-run, for example.
    if (found != schedule_.end()) {
      found_task = found->second;
      async_tasks_.erase(found_task);
      schedule_.erase(found);
    }
  }

  if (found_task) {
    found_task->Cancel();
    found_task->Release();
  }
}

void ExecutorLibdispatch::InvokeAsync(void* raw_task) {
  auto task = static_cast<Task*>(raw_task);
  task->Execute();
}

void ExecutorLibdispatch::InvokeSync(void* raw_task) {
  auto task = static_cast<Task*>(raw_task);
  task->Execute();
}

// Test-only methods

bool ExecutorLibdispatch::IsScheduled(Tag tag) const {
  std::unique_lock<std::mutex> lock(mutex_);

  for (const ScheduleEntry& entry : schedule_) {
    Task* task = entry.second;
    if (task->tag() == tag) {
      // There's a race inherent in making IsScheduled checks after a task has
      // executed. The problem is that the task has to lock the Executor to
      // report its completion, but IsScheduled needs that lock too and it can
      // win, indicating that tasks that appear completed are still scheduled.
      //
      // Work around this by waiting for tasks that are currently executing to
      // complete. That is, only tasks that are in the schedule and in the
      // `kInitial` state are considered scheduled.
      //
      // Unfortunately, this has to be done with the Executor unlocked so that
      // the task can report its completion without deadlocking. As the task is
      // completed (and before the lock could be reacquired here) its reference
      // count would go to zero. At that point `AwaitIfRunning` would wake up
      // and lock the just-deleted Task. Retaining the Task here prevents it
      // from being deleted while waiting.
      task->Retain();
      auto release = defer([&] { task->Release(); });

      bool completed;
      {
        lock.unlock();
        auto relock = defer([&] { lock.lock(); });

        completed = task->AwaitIfRunning();
      }
      return !completed;
    }
  }
  return false;
}

bool ExecutorLibdispatch::IsTaskScheduled(Id id) const {
  std::lock_guard<std::mutex> lock(mutex_);

  return schedule_.find(id) != schedule_.end();
}

Task* ExecutorLibdispatch::PopFromSchedule() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (schedule_.empty()) {
    return nullptr;
  }

  const auto nearest =
      std::min_element(schedule_.begin(), schedule_.end(),
                       [](const ScheduleEntry& lhs, const ScheduleEntry& rhs) {
                         return *lhs.second < *rhs.second;
                       });

  Task* task = nearest->second;

  async_tasks_.erase(task);
  schedule_.erase(nearest);
  return task;
}

ExecutorLibdispatch::Id ExecutorLibdispatch::NextIdLocked() {
  // The wrap around after ~4 billion operations is explicitly ignored. Even if
  // an instance of `ExecutorLibdispatch` runs long enough to get `current_id_`
  // to overflow, it's extremely unlikely that any object still holds a
  // reference that is old enough to cause a conflict.
  return current_id_++;
}

// MARK: - Executor

std::unique_ptr<Executor> Executor::CreateSerial(const char* label) {
  dispatch_queue_t queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
  return absl::make_unique<ExecutorLibdispatch>(queue);
}

std::unique_ptr<Executor> Executor::CreateConcurrent(const char* label,
                                                     int threads) {
  HARD_ASSERT(threads > 1);

  // Concurrent queues auto-create enough threads to avoid deadlock so there's
  // no need to honor the threads argument.
  dispatch_queue_t queue =
      dispatch_queue_create(label, DISPATCH_QUEUE_CONCURRENT);
  return absl::make_unique<ExecutorLibdispatch>(queue);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
