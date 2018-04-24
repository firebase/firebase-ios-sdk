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

namespace firebase {
namespace firestore {
namespace util {
namespace internal {

namespace {

absl::string_view StringViewFromDispatchLabel(const char* const label) {
  // Make sure string_view's data is not null, because it's used for logging.
  return label ? absl::string_view{label} : absl::string_view{""};
}

}  // namespace

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
  TimeSlot(ExecutorLibdispatch* executor,
           Executor::Milliseconds delay,
           Executor::TaggedOperation&& operation);

  // Returns the operation that was scheduled for this time slot and turns the
  // slot into a no-op.
  Executor::TaggedOperation Unschedule();

  bool operator<(const TimeSlot& rhs) const {
    return target_time_ < rhs.target_time_;
  }
  bool operator==(const Executor::Tag tag) const {
    return tagged_.tag == tag;
  }

  void MarkDone() {
    done_ = true;
  }

  static void InvokedByLibdispatch(void* const raw_self);

 private:
  void Execute();
  void RemoveFromSchedule();

  using TimePoint =
      std::chrono::time_point<std::chrono::system_clock, Executor::Milliseconds>;

  ExecutorLibdispatch* const executor_;
  const TimePoint target_time_;  // Used for sorting
  Executor::TaggedOperation tagged_;

  // True if the operation has either been run or canceled.
  //
  // Note on thread-safety: `done_` is only ever accessed from `Cancel` and
  // `Execute` member functions, and both of them are only ever invoked by the
  // dispatch queue, which provides synchronization.
  bool done_ = false;
};

TimeSlot::TimeSlot(ExecutorLibdispatch* const executor,
                   const Executor::Milliseconds delay,
                   Executor::TaggedOperation&& operation)
    : executor_{executor},
      target_time_{std::chrono::time_point_cast<Executor::Milliseconds>(
                       std::chrono::system_clock::now()) +
                   delay},
      tagged_{std::move(operation)} {
}

Executor::TaggedOperation TimeSlot::Unschedule() {
  if (!done_) {
    RemoveFromSchedule();
  }
  return std::move(tagged_);
}

void TimeSlot::InvokedByLibdispatch(void* const raw_self) {
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

  FIREBASE_ASSERT_MESSAGE(tagged_.operation,
                          "TimeSlot contains an invalid function object");
  tagged_.operation();
}

void TimeSlot::RemoveFromSchedule() {
  executor_->RemoveFromSchedule(this);
}

// ExecutorLibdispatch

ExecutorLibdispatch::ExecutorLibdispatch(const dispatch_queue_t dispatch_queue)
    : dispatch_queue_{dispatch_queue} {
}
ExecutorLibdispatch::ExecutorLibdispatch()
    : ExecutorLibdispatch{dispatch_queue_create("com.google.firebase.firestore",
                                                DISPATCH_QUEUE_SERIAL)} {
}

ExecutorLibdispatch::~ExecutorLibdispatch() {
  // Turn any operations that might still be in the queue into no-ops, lest
  // they try to access `ExecutorLibdispatch` after it gets destroyed. Because
  // the queue is serial, by the time libdispatch gets to the newly-enqueued
  // work, the pending operations that might have been in progress would have
  // already finished.
  ExecuteBlocking([this] {
    while (!schedule_.empty()) {
      RemoveFromSchedule(schedule_.back());
    }
  });
}

bool ExecutorLibdispatch::IsAsyncCall() const {
  return GetCurrentQueueLabel().data() == GetTargetQueueLabel().data();
}
std::string ExecutorLibdispatch::GetInvokerId() const {
  return GetCurrentQueueLabel().data();
}

void ExecutorLibdispatch::Execute(Operation&& operation) {
  DispatchAsync(dispatch_queue(), std::move(operation));
}
void ExecutorLibdispatch::ExecuteBlocking(Operation&& operation) {
  DispatchSync(dispatch_queue(), std::move(operation));
}

DelayedOperation ExecutorLibdispatch::ScheduleExecution(
    const Milliseconds delay, TaggedOperation&& operation) {
  namespace chr = std::chrono;
  const dispatch_time_t delay_ns = dispatch_time(
      DISPATCH_TIME_NOW, chr::duration_cast<chr::nanoseconds>(delay).count());

  // Ownership is fully transferred to libdispatch -- because it's impossible
  // to truly cancel work after it's been dispatched, libdispatch is
  // guaranteed to outlive the executor, and it's possible for work to be
  // invoked by libdispatch after the executor is destroyed. Executor only
  // stores an observer pointer to the operation.

  auto const time_slot = new TimeSlot{this, delay, std::move(operation)};
  dispatch_after_f(delay_ns, dispatch_queue(), time_slot,
                   TimeSlot::InvokedByLibdispatch);
  schedule_.push_back(time_slot);
  return DelayedOperation{[this, time_slot] {
    // `time_slot` might be destroyed by the time cancellation function runs.
    // Therefore, don't access any methods on `time_slot`, only use it as
    // a handle to remove from `schedule_`.
    RemoveFromSchedule(time_slot);
  }};
}

void ExecutorLibdispatch::RemoveFromSchedule(const TimeSlot* const to_remove) {
  const auto found =
      std::find_if(schedule_.begin(), schedule_.end(),
                   [to_remove](const TimeSlot* op) { return op == to_remove; });
  // It's possible for the operation to be missing if libdispatch gets to run
  // it after it was force-run, for example.
  if (found != schedule_.end()) {
    (*found)->MarkDone();
    schedule_.erase(found);
  }
}

// GetLabel functions are guaranteed to never return a "null" string_view
// (i.e. data() != nullptr).
absl::string_view ExecutorLibdispatch::GetCurrentQueueLabel() const {
  // Note: dispatch_queue_get_label may return nullptr if the queue wasn't
  // initialized with a label.
  return StringViewFromDispatchLabel(
      dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
}

absl::string_view ExecutorLibdispatch::GetTargetQueueLabel() const {
  return StringViewFromDispatchLabel(
      dispatch_queue_get_label(dispatch_queue()));
}

// Test-only methods

bool ExecutorLibdispatch::IsScheduled(const Tag tag) const {
  return std::find_if(schedule_.begin(), schedule_.end(),
                      [&tag](const TimeSlot* const operation) {
                        return *operation == tag;
                      }) != schedule_.end();
}

bool ExecutorLibdispatch::IsScheduleEmpty() const {
  return schedule_.empty();
}

Executor::TaggedOperation ExecutorLibdispatch::PopFromSchedule() {
  // Sorting upon each call to `PopFromSchedule` is inefficient, which is
  // consciously ignored. One alternative is to keep `schedule_` sorted, which
  // would impose a performance penalty, however small, on the normal code paths
  // in favor of test-only paths. The other is to expose yet another test-only
  // method for sorting, unnecessarily bloating the interface.
  std::sort(
      schedule_.begin(), schedule_.end(),
      [](const TimeSlot* lhs, const TimeSlot* rhs) { return *lhs < *rhs; });
  const auto nearest = schedule_.begin();
  return (*nearest)->Unschedule();
}

}  // namespace internal
}  // namespace util
}  // namespace firestore
}  // namespace firebase
