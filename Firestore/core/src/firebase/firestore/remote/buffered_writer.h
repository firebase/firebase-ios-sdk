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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H

#include <functional>
#include <queue>

#include <grpcpp/support/byte_buffer.h>

namespace firebase {
namespace firestore {
namespace remote {

/**
 * `BufferedWriter` accepts `ByteBuffer`s ("writes") on its queue and writes
 * them one by one. Only one write may be in progress ("active") at any given
 * time.
 *
 * Writes are put on the queue using `Enqueue`; if no other write is currently
 * in progress, it will become active immediately, otherwise, it will put on the
 * queue. When a write becomes active, `WriteFunction` is invoked on it. A write
 * is active from the moment `WriteFunction` is invoked and until `DequeueNext`
 * is called on the `BufferedWriter`. `DequeueNext` makes the next write active,
 * if any.
 *
 * This class exists to help Firestore streams adhere to GRPC requirement that
 * only one write operation may be active at any given time.
 */
class BufferedWriter {
 public:
  using WriteFunction = std::function<void(grpc::ByteBuffer&&)>;

  explicit BufferedWriter(WriteFunction&& write_func);

  bool empty() const {
    return queue_.empty();
  }

  void Enqueue(grpc::ByteBuffer&& write);
  void DequeueNext();

  // Doesn't affect the write that is currently in progress.
  void DiscardUnstartedWrites();

 private:
  void TryWrite();

  WriteFunction write_func_;

  std::queue<grpc::ByteBuffer> queue_;
  bool has_active_write_ = false;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H
