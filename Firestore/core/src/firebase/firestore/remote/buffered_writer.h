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

// GRPC doesn't allow issuing a write operation before the previous write has
// finished. This class helps keep track of pending writes and whether there
// currently is a write operation in progress; it doesn't communicate with GRPC
// directly and expects the following to function correctly:
// - the constructor should be given a function that actually issues the GRPC
//   write operation;
// - each time a write operation finishes, `OnSuccessfulWrite` must be called.
// The invariant is that `BufferedWriter` will never invoke the writing function
// if `OnSuccessfulWrite` hasn't been called since the previous invocation.
//
// The main methods are `Enqueue` and `OnSuccessfulWrite`. `Enqueue` will invoke
// the writing function immediately if there is no operation in progress;
// otherwise, the given `bytes` will be stored in the buffer.
// `OnSuccessfulWrite` will invoke the writing function with the next write in
// buffer, as long as the buffer is not empty (in FIFO order).

// `BufferedWriter` can be `Start`ed and `Stop`ped, which is expected to reflect
// the state of the GRPC call. When `BufferedWriter` is not started, writes can
// be enqueued, but the writing function will not be invoked. Once the
// `BufferedWriter` is started, it will immediately invoke the writing function
// if the buffer is non-empty. When the `BufferedWriter` is first created, it's
// in the stopped state. `BufferedWriter` can be restarted.
class BufferedWriter {
 public:
  using WriteFunction = std::function<void(grpc::ByteBuffer&&)>;

  explicit BufferedWriter(WriteFunction&& write_func);

  bool empty() const {
    return queue_.empty();
  }

  void Enqueue(grpc::ByteBuffer&& bytes);
  void OnSuccessfulWrite();

  // Clears (but doesn't stop) the buffer. If there is an operation in progress,
  // `OnSuccessfulWrite` must still be called for it.
  void Clear();

 private:
  void TryWrite();

  WriteFunction write_func_;

  std::queue<grpc::ByteBuffer> queue_;
  bool has_pending_write_ = false;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H
