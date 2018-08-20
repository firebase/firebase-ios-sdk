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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H_

#include <queue>

#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"

namespace firebase {
namespace firestore {
namespace remote {

/**
 * `BufferedWriter` accepts GRPC write operations ("writes") on its queue and
 * writes them one by one. Only one write may be in progress ("active") at any
 * given time.
 *
 * Writes are put on the queue using `EnqueueWrite`; if no other write is
 * currently in progress, it will become active immediately, otherwise, it will
 * be "buffered" (put on the queue in this `BufferedWriter`). When a write
 * becomes active, it is executed (via `Execute`); a write is active from the
 * moment it is executed and until `DequeueNextWrite` is called on the
 * `BufferedWriter`. `DequeueNextWrite` makes the next write active, if any.
 *
 * This class exists to help Firestore streams adhere to the gRPC requirement
 * that only one write operation may be active at any given time.
 */
class BufferedWriter {
 public:
  BufferedWriter() = default;
  ~BufferedWriter();
  // Disallow copying for simplicity (there is no use case for it).
  BufferedWriter(const BufferedWriter&) = delete;
  BufferedWriter& operator=(const BufferedWriter&) = delete;

  bool empty() const {
    return queue_.empty();
  }

  // Pending writes are owned by the `BufferedWriter`. Once a write becomes
  // active, `BufferedWriter` releases ownership.
  void EnqueueWrite(GrpcOperation* write);
  void DequeueNextWrite();

  // Doesn't affect the write that is currently in progress.
  void DiscardUnstartedWrites();

 private:
  void TryStartWrite();

  std::queue<GrpcOperation*> queue_;
  bool has_active_write_ = false;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H_
