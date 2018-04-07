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
  assert(queue_);
  queue_->TryCancel(id_);
}

AsyncQueue::AsyncQueue()  {
  current_id_ = 0;
  shutting_down_ = false;
  worker_thread_ = std::thread{&AsyncQueue::PollingThread, this};
}

AsyncQueue::~AsyncQueue() {
  shutting_down_ = true;
  UnblockQueue();
  worker_thread_.join();
}

void AsyncQueue::Enqueue(Operation&& operation) {
  DoEnqueue(std::move(operation), TimePoint{});
}

DelayedOperation AsyncQueue::EnqueueAfterDelay(const Milliseconds delay,
                                               Operation&& operation) {
  namespace chr = std::chrono;

  const auto now = chr::time_point_cast<Milliseconds>(chr::system_clock::now());
  const auto id = DoEnqueue(std::move(operation), now + delay);

  return DelayedOperation{this, id};
}

void AsyncQueue::TryCancel(const Id id) {
  schedule_.RemoveIf(nullptr, [id](const Entry& e) { return e.id == id; });
}

AsyncQueue::Id AsyncQueue::DoEnqueue(Operation&& operation,
                                     const TimePoint when) {
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
  schedule_.Push(Entry{[] {}, /*id=*/0}, TimePoint{});
}

unsigned int AsyncQueue::NextId() {
  return current_id_++;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
