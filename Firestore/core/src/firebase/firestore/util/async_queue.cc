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

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"

namespace firebase {
namespace firestore {
namespace util {

void DelayedOperation::Cancel() {
  FIREBASE_ASSERT_MESSAGE(queue_, "Null pointer to queue.");
  queue_->TryCancel(*this);
}

AsyncQueue::AsyncQueue() {
  // Somewhat counter-intuitively, constructor of `std::atomic` assigns the
  // value non-atomically, so the atomic initialization must be provided here,
  // before the worker thread is started.
  // See [this thread](https://stackoverflow.com/questions/25609858) for context
  // on the constructor.
  current_id_ = 0;
  shutting_down_ = false;
  worker_thread_ = std::thread{&AsyncQueue::PollingThread, this};
}

AsyncQueue::~AsyncQueue() {
  shutting_down_ = true;
  // Make sure the worker thread is not blocked, so that the call to `join`
  // doesn't hang.
  UnblockQueue();
  worker_thread_.join();
}

void AsyncQueue::Enqueue(Operation&& operation) {
  DoEnqueue(std::move(operation), Immediate());
}

DelayedOperation AsyncQueue::EnqueueAfterDelay(const Milliseconds delay,
                                               Operation&& operation) {
  // While negative delay can be interpreted as a request for immediate
  // execution, supporting it would provide a hacky way to modify FIFO ordering
  // of immediate operations.
  FIREBASE_ASSERT_MESSAGE(delay.count() >= 0,
                          "EnqueueAfterDelay: delay cannot be negative");

  namespace chr = std::chrono;

  const auto now = chr::time_point_cast<Milliseconds>(chr::system_clock::now());
  const auto id = DoEnqueue(std::move(operation), now + delay);

  return DelayedOperation{this, id};
}

void AsyncQueue::TryCancel(const DelayedOperation& operation) {
  const auto id = operation.id_;
  schedule_.RemoveIf(nullptr, [id](const Entry& e) { return e.id == id; });
}

AsyncQueue::Id AsyncQueue::DoEnqueue(Operation&& operation,
                                     const TimePoint when) {
  // Note: operations scheduled for immediate execution don't actually need an
  // id. This could be tweaked to reuse the same id for all such operations.
  const auto id = NextId();
  schedule_.Push(Entry{std::move(operation), id}, when);
  return id;
}

void AsyncQueue::PollingThread() {
  while (!shutting_down_) {
    Entry entry;
    schedule_.PopBlocking(&entry);
    if (entry.operation) {
      entry.operation();
    }
  }
}

void AsyncQueue::UnblockQueue() {
  // Put a no-op for immediate execution on the queue to ensure that
  // `schedule_.PopBlocking` returns, and worker thread can notice that shutdown
  // is in progress.
  schedule_.Push(Entry{[] {}, /*id=*/0}, Immediate());
}

AsyncQueue::Id AsyncQueue::NextId() {
  // The wrap around after ~4 billion operations is explicitly ignored. Even if
  // an instance of `AsyncQueue` runs long enough to get `current_id_` to
  // overflow, it's extremely unlikely that any object still holds a reference
  // that is old enough to cause a conflict.
  return current_id_++;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
