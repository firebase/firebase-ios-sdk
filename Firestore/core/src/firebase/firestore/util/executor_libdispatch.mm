/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"

#include <atomic>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

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

namespace internal {

void DispatchAsync(const dispatch_queue_t queue, std::function<void()>&& work) {
  // Dynamically allocate the function to make sure the object is valid by the
  // time libdispatch gets to it.
  const auto wrap = new std::function<void()>{std::move(work)};

  dispatch_async_f(queue, wrap, [](void* const raw_work) {
    const auto unwrap = static_cast<std::function<void()>*>(raw_work);
    (*unwrap)();
    delete unwrap;
  });
}

void DispatchSync(const dispatch_queue_t queue, std::function<void()> work) {
  HARD_ASSERT(
      GetCurrentQueueLabel() != GetQueueLabel(queue),
      "Calling DispatchSync on the current queue will lead to a deadlock.");

  // Unlike dispatch_async_f, dispatch_sync_f blocks until the work passed to it
  // is done, so passing a reference to a local variable is okay.
  dispatch_sync_f(queue, &work, [](void* const raw_work) {
    const auto unwrap = static_cast<std::function<void()>*>(raw_work);
    (*unwrap)();
  });
}

}  // namespace internal

namespace {

using internal::DispatchAsync;
using internal::DispatchSync;

template <typename Work>
void RunSynchronized(const ExecutorLibdispatch* const executor, Work&& work) {
  if (executor->IsCurrentExecutor()) {
    work();
  } else {
    DispatchSync(executor->dispatch_queue(), std::forward<Work>(work));
  }
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

class TimeSlot {
 public:
  using TimeSlotId = ExecutorLibdispatch::TimeSlotId;

  TimeSlot(ExecutorLibdispatch* executor,
           Executor::Milliseconds delay,
           Executor::TaggedOperation&& operation,
           TimeSlotId slot_id);

  // Returns the operation that was scheduled for this time slot and turns the
  // slot into a no-op.
  Executor::TaggedOperation Unschedule();

  bool operator<(const TimeSlot& rhs) const {
    // Order by target time, then by the order in which entries were created.
    if (target_time_ < rhs.target_time_) {
      return true;
    }
    if (target_time_ > rhs.target_time_) {
      return false;
    }

    return time_slot_id_ < rhs.time_slot_id_;
  }
  bool operator==(const Executor::Tag tag) const {
    return tagged_.tag == tag;
  }

  void MarkDone() {
    done_ = true;
  }

  static void InvokedByLibdispatch(void* raw_self);

 private:
  void Execute();
  void RemoveFromSchedule();

  using TimePoint = std::chrono::time_point<std::chrono::steady_clock,
                                            Executor::Milliseconds>;

  ExecutorLibdispatch* const executor_;
  const TimePoint target_time_;  // Used for sorting
  Executor::TaggedOperation tagged_;
  TimeSlotId time_slot_id_ = 0;

  // True if the operation has either been run or canceled.
  //
  // Note on thread-safety: this variable is accessed both from the dispatch
  // queue and in the destructor, which may run on any queue.
  std::atomic<bool> done_;
};

TimeSlot::TimeSlot(ExecutorLibdispatch* const executor,
                   const Executor::Milliseconds delay,
                   Executor::TaggedOperation&& operation,
                   TimeSlotId slot_id)
    : executor_{executor},
      target_time_{std::chrono::time_point_cast<Executor::Milliseconds>(
                       std::chrono::steady_clock::now()) +
                   delay},
      tagged_{std::move(operation)},
      time_slot_id_{slot_id} {
  // Only assignment of std::atomic is atomic; initialization in its constructor
  // isn't
  done_ = false;
}

Executor::TaggedOperation TimeSlot::Unschedule() {
  if (!done_) {
    RemoveFromSchedule();
  }
  return std::move(tagged_);
}

void TimeSlot::InvokedByLibdispatch(void* raw_self) {
  auto const self = static_cast<TimeSlot*>(raw_self);
  self->Execute();
  delete self;
}

void TimeSlot::Execute() {
  if (done_) {
    // `done_` might mean that the executor is already destroyed, so don't call
    // `RemoveFromSchedule`.
    return;
  }

  RemoveFromSchedule();

  HARD_ASSERT(tagged_.operation,
              "TimeSlot contains an invalid function object");
  tagged_.operation();
}

void TimeSlot::RemoveFromSchedule() {
  executor_->RemoveFromSchedule(time_slot_id_);
}

// MARK: - ExecutorLibdispatch

ExecutorLibdispatch::ExecutorLibdispatch(const dispatch_queue_t dispatch_queue)
    : dispatch_queue_{dispatch_queue} {
}

ExecutorLibdispatch::~ExecutorLibdispatch() {
  // Turn any operations that might still be in the queue into no-ops, lest
  // they try to access `ExecutorLibdispatch` after it gets destroyed. Because
  // the queue is serial, by the time libdispatch gets to the newly-enqueued
  // work, the pending operations that might have been in progress would have
  // already finished.
  // Note: this is thread-safe, because the underlying variable `done_` is
  // atomic. `RunSynchronized` may result in a deadlock.
  for (const auto& entry : schedule_) {
    entry.second->MarkDone();
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
  DispatchAsync(dispatch_queue(), std::move(operation));
}
void ExecutorLibdispatch::ExecuteBlocking(Operation&& operation) {
  DispatchSync(dispatch_queue(), std::move(operation));
}

DelayedOperation ExecutorLibdispatch::Schedule(const Milliseconds delay,
                                               TaggedOperation&& operation) {
  namespace chr = std::chrono;
  const dispatch_time_t delay_ns = dispatch_time(
      DISPATCH_TIME_NOW, chr::duration_cast<chr::nanoseconds>(delay).count());

  // Ownership is fully transferred to libdispatch -- because it's impossible
  // to truly cancel work after it's been dispatched, libdispatch is
  // guaranteed to outlive the executor, and it's possible for work to be
  // invoked by libdispatch after the executor is destroyed. Executor only
  // stores an observer pointer to the operation.
  TimeSlot* time_slot = nullptr;
  TimeSlotId time_slot_id = 0;
  RunSynchronized(this, [this, delay, &operation, &time_slot, &time_slot_id] {
    time_slot_id = NextId();
    time_slot = new TimeSlot{this, delay, std::move(operation), time_slot_id};
    schedule_[time_slot_id] = time_slot;
  });

  dispatch_after_f(delay_ns, dispatch_queue(), time_slot,
                   TimeSlot::InvokedByLibdispatch);

  return DelayedOperation{[this, time_slot_id] {
    // `time_slot` might have been destroyed by the time cancellation function
    // runs, in which case it's guaranteed to have been removed from the
    // `schedule_`. If the `time_slot_id` refers to a slot that has been
    // removed, the call to `RemoveFromSchedule` will be a no-op.
    RemoveFromSchedule(time_slot_id);
  }};
}

void ExecutorLibdispatch::RemoveFromSchedule(TimeSlotId to_remove) {
  RunSynchronized(this, [this, to_remove] {
    const auto found = schedule_.find(to_remove);

    // It's possible for the operation to be missing if libdispatch gets to run
    // it after it was force-run, for example.
    if (found != schedule_.end()) {
      found->second->MarkDone();
      schedule_.erase(found);
    }
  });
}

// Test-only methods

bool ExecutorLibdispatch::IsScheduled(const Tag tag) const {
  bool result = false;
  RunSynchronized(this, [this, tag, &result] {
    result = std::any_of(schedule_.begin(), schedule_.end(),
                         [&tag](const ScheduleEntry& operation) {
                           return *operation.second == tag;
                         });
  });
  return result;
}

absl::optional<Executor::TaggedOperation>
ExecutorLibdispatch::PopFromSchedule() {
  absl::optional<Executor::TaggedOperation> result;

  RunSynchronized(this, [this, &result]() -> void {
    if (schedule_.empty()) {
      return;
    }

    const auto nearest = std::min_element(
        schedule_.begin(), schedule_.end(),
        [](const ScheduleEntry& lhs, const ScheduleEntry& rhs) {
          return *lhs.second < *rhs.second;
        });

    result = nearest->second->Unschedule();
  });

  return result;
}

ExecutorLibdispatch::TimeSlotId ExecutorLibdispatch::NextId() {
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
